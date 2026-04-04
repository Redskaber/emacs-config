;;; runtime-module-runner.el --- Manifest module executor -*- lexical-binding: t; -*-
;;; Commentary:
;;; Execute manifest module specs with feature/predicate/defer semantics.
;;; Code:

(require 'kernel-errors)
(require 'kernel-logging)
(require 'kernel-require)
(require 'runtime-feature)
(require 'runtime-manifest)
(require 'runtime-module-state)

;; ---------------------------------------------------------------------------
;; Deferred scheduling
;; ---------------------------------------------------------------------------

(defun my/runtime-module--run-deferred-init (name init-fn)
  "Safely run deferred module NAME using INIT-FN."
  (my/with-safe-call (format "module:%s[deferred]" name)
    (funcall init-fn)))

(defun my/runtime-module--schedule-after-init (name init-fn)
  "Schedule deferred module NAME on `after-init-hook'."
  (add-hook 'after-init-hook
            (lambda ()
              (my/runtime-module--run-deferred-init name init-fn))
            90)
  (my/runtime-module-register-deferred-job name '(:hook after-init-hook)))

(defun my/runtime-module--schedule-hook (name init-fn hook &optional append local)
  "Schedule deferred module NAME on HOOK."
  (add-hook hook
            (lambda ()
              (my/runtime-module--run-deferred-init name init-fn))
            append local)
  (my/runtime-module-register-deferred-job name (list :hook hook)))

(defun my/runtime-module--schedule-idle (name init-fn seconds)
  "Schedule deferred module NAME on idle timer after SECONDS."
  (run-with-idle-timer
   seconds nil
   (lambda ()
     (my/runtime-module--run-deferred-init name init-fn)))
  (my/runtime-module-register-deferred-job name (list :idle seconds)))

(defun my/runtime-module--schedule-timer (name init-fn seconds)
  "Schedule deferred module NAME on timer after SECONDS."
  (run-with-timer
   seconds nil
   (lambda ()
     (my/runtime-module--run-deferred-init name init-fn)))
  (my/runtime-module-register-deferred-job name (list :timer seconds)))

(defun my/runtime-module--schedule-after-feature (name init-fn feature)
  "Schedule deferred module NAME after FEATURE is loaded."
  (with-eval-after-load feature
    (my/runtime-module--run-deferred-init name init-fn))
  (my/runtime-module-register-deferred-job name (list :after-feature feature)))

(defun my/runtime-module--schedule-command (name init-fn command)
  "Schedule deferred module NAME before first invocation of COMMAND."
  (let ((fn-name (intern (format "my/runtime-module--deferred:%s:%s" name command))))
    (fset
     fn-name
     (lambda ()
       (when (eq this-command command)
         (remove-hook 'pre-command-hook fn-name)
         (my/runtime-module--run-deferred-init name init-fn))))
    (add-hook 'pre-command-hook fn-name 0)
    (my/runtime-module-register-deferred-job name (list :command command))))

(defun my/runtime-module-schedule-deferred (name init-fn defer)
  "Schedule deferred module NAME according to DEFER strategy.

    Supported forms:
    - t                         => after-init-hook
    - (:hook HOOK)
    - (:idle SECONDS)
    - (:timer SECONDS)
    - (:after-feature FEATURE)
    - (:command COMMAND)"
  (cond
   ((eq defer t)
    (my/runtime-module--schedule-after-init name init-fn))

   ((and (listp defer) (eq (car defer) :hook))
    (my/runtime-module--schedule-hook name init-fn (cadr defer)))

   ((and (listp defer) (eq (car defer) :idle))
    (my/runtime-module--schedule-idle name init-fn (or (cadr defer) 1.0)))

   ((and (listp defer) (eq (car defer) :timer))
    (my/runtime-module--schedule-timer name init-fn (or (cadr defer) 1.0)))

   ((and (listp defer) (eq (car defer) :after-feature))
    (my/runtime-module--schedule-after-feature name init-fn (cadr defer)))

   ((and (listp defer) (eq (car defer) :command))
    (my/runtime-module--schedule-command name init-fn (cadr defer)))

   (t
    (my/log "unknown defer strategy for %s: %S; fallback to after-init" name defer)
    (my/runtime-module--schedule-after-init name init-fn))))

;; ---------------------------------------------------------------------------
;; Module execution
;; ---------------------------------------------------------------------------

(defun my/runtime-module-run-spec (spec)
  "Run a single manifest SPEC."
  (let* ((spec (my/runtime-manifest-normalize-spec spec))
         (name (plist-get spec :name))
         (feature (plist-get spec :feature))
         (predicate (plist-get spec :predicate))
         (after (plist-get spec :after))
         (feature-sym (plist-get spec :require))
         (init-fn (plist-get spec :init))
         (defer (plist-get spec :defer))
         (enabled-p (my/runtime-feature-enabled-p feature))
         (allowed-p (my/runtime-feature-enabled-p predicate))
         (deps-ok-p (my/runtime-module-deps-satisfied-p after)))
    (cond
     ((not enabled-p)
      (my/runtime-module-record
       (list :name name :status 'skipped :reason :feature-disabled))
      (my/log "module skipped (feature): %s" name)
      'skipped)

     ((not allowed-p)
      (my/runtime-module-record
       (list :name name :status 'skipped :reason :predicate-failed))
      (my/log "module skipped (predicate): %s" name)
      'skipped)

     ((not deps-ok-p)
      (my/runtime-module-record
       (list :name name :status 'skipped :reason :dependency-failed :after after))
      (my/log "module skipped (dependency): %s after=%S" name after)
      'skipped)

     ((not (my/safe-require feature-sym nil t))
      (my/runtime-module-record
       (list :name name :status 'failed :reason :require-failed))
      (my/log "module failed (require): %s" name)
      'failed)

     (defer
      (my/runtime-module-schedule-deferred name init-fn defer)
      (my/runtime-module-record
       (list :name name :status 'deferred :defer defer))
      (my/log "module deferred: %s strategy=%S" name defer)
      'deferred)

     (t
      (let ((ok (my/with-safe-call (format "module:%s" name)
                  (funcall init-fn)
                  t)))
        (if ok
            (progn
              (my/runtime-module-record (list :name name :status 'ok))
              (my/log "module ok: %s" name)
              'ok)
          (my/runtime-module-record
           (list :name name :status 'failed :reason :init-failed))
          (my/log "module failed (init): %s" name)
          'failed))))))

(defun my/runtime-module-run-manifest (manifest &optional label)
  "Run all modules in MANIFEST.
Return execution records added during this run (newest-first)."
  (let ((before-count (length my/runtime-module-records))
        (manifest (my/runtime-manifest-normalize manifest)))
    (when label
      (my/log "manifest start: %s" label))
    (dolist (spec manifest)
      (my/runtime-module-run-spec spec))
    (when label
      (my/log "manifest end: %s" label))
    (let ((delta (- (length my/runtime-module-records) before-count)))
      (cl-subseq my/runtime-module-records 0 delta))))

(provide 'runtime-module-runner)
;;; runtime-module-runner.el ends here
