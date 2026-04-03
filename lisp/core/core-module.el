;;; core-module.el --- Manifest-driven module orchestration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Declarative module runner for layered startup pipeline.
;;; Supports feature gates, capability predicates, soft dependencies,
;;; deferred init, stage sentinels, and execution reporting.
;;; Code:

(require 'cl-lib)

(require 'core-lib)
(require 'core-logging)
(require 'core-errors)
(require 'core-require)

(defgroup my/module nil
  "Manifest-driven module orchestration."
  :group 'my/features)

(defvar my/module-run-records nil
  "Execution records of manifest-driven modules.")

(defvar my/stage-sentinels (make-hash-table :test #'eq)
  "Stage execution sentinel table.
Value is a plist, for example:
  (:status ok :started-at <time> :ended-at <time> :detail <any>)")

(defvar my/module-deferred-jobs nil
  "Deferred module scheduling records.")

(defun my/module--resolve-value (value)
  "Resolve VALUE into a runtime boolean-ish value."
  (cond
   ((null value) t)
   ((eq value t) t)

   ;; bound variable flag
   ((and (symbolp value) (boundp value))
    (symbol-value value))

   ;; function / predicate
   ((functionp value)
    (funcall value))
   ((and (symbolp value) (fboundp value))
    (funcall value))

   ;; unknown symbol should not silently pass
   ((symbolp value)
    (my/log "unresolved symbol in manifest gate: %S" value)
    nil)

   ;; raw literal
   (t value)))

(defun my/module--plist-get-required (plist prop)
  "Return PROP from PLIST or signal an error."
  (or (plist-get plist prop)
      (error "Manifest entry missing required key %S: %S" prop plist)))

(defun my/module--find-record (name)
  "Return execution record for module NAME, or nil."
  (cl-find-if (lambda (rec)
                (eq (plist-get rec :name) name))
              my/module-run-records))

(defun my/module--dependency-satisfied-p (deps)
  "Return non-nil when all DEPS have completed successfully."
  (let ((dep-list (cond
                   ((null deps) nil)
                   ((listp deps) deps)
                   (t (list deps)))))
    (cl-every
     (lambda (dep)
       (let ((rec (my/module--find-record dep)))
         (eq (plist-get rec :status) 'ok)))
     dep-list)))

(defun my/module--record (plist)
  "Push PLIST into `my/module-run-records' and return it."
  (push plist my/module-run-records)
  plist)

;;; ---------------------------------------------------------------------------
;;; Stage sentinel
;;; ---------------------------------------------------------------------------

(defun my/stage-sentinel-get (stage)
  "Return sentinel plist for STAGE, or nil."
  (gethash stage my/stage-sentinels))

(defun my/stage-sentinel-status (stage)
  "Return status symbol for STAGE, or nil."
  (plist-get (my/stage-sentinel-get stage) :status))

(defun my/stage-sentinel-set (stage status &optional detail)
  "Set STAGE sentinel to STATUS with optional DETAIL."
  (let* ((old (my/stage-sentinel-get stage))
         (started-at (or (plist-get old :started-at)
                         (current-time)))
         (ended-at (unless (eq status 'running) (current-time))))
    (puthash stage
             (list :status status
                   :started-at started-at
                   :ended-at ended-at
                   :detail detail)
             my/stage-sentinels)))

(defun my/stage-sentinel-clear (&optional stage)
  "Clear sentinel for STAGE, or all sentinels when STAGE is nil."
  (if stage
      (remhash stage my/stage-sentinels)
    (clrhash my/stage-sentinels)))

(defun my/stage-sentinel-done-p (stage)
  "Return non-nil if STAGE has already completed successfully."
  (eq (my/stage-sentinel-status stage) 'ok))

(defun my/stage-sentinel-failed-p (stage)
  "Return non-nil if STAGE failed."
  (eq (my/stage-sentinel-status stage) 'failed))

(defun my/stage-sentinel-running-p (stage)
  "Return non-nil if STAGE is currently running."
  (eq (my/stage-sentinel-status stage) 'running))

(defmacro my/with-stage-sentinel (stage &rest body)
  "Run BODY under STAGE sentinel lifecycle."
  (declare (indent 1))
  `(cond
    ((my/stage-sentinel-done-p ,stage)
     (my/log "stage skipped (already done): %s" ,stage)
     'already-done)
    ((my/stage-sentinel-running-p ,stage)
     (my/log "stage skipped (already running): %s" ,stage)
     'already-running)
    (t
     (my/stage-sentinel-set ,stage 'running)
     (condition-case err
         (let ((result (progn ,@body)))
           (my/stage-sentinel-set ,stage 'ok result)
           result)
       (error
        (my/stage-sentinel-set ,stage 'failed err)
        (signal (car err) (cdr err)))))))

; stage dependency handle func
(defun my/stage-dependencies-satisfied-p (stage)
  "Return non-nil when all stage dependencies of STAGE are satisfied."
  (require 'manifest-registry)
  (let ((deps (my/stage-after stage)))
    (cl-every #'my/stage-sentinel-done-p deps)))

(defun my/module-run-stage-by-spec (stage)
  "Run registered STAGE using declarative stage registry."
  (require 'manifest-registry)
  (let ((enabled-p (my/stage-feature-enabled-p stage))
        (deps-ok-p (my/stage-dependencies-satisfied-p stage)))
    (cond
     ((not enabled-p)
      (my/log "stage skipped (feature): %s" stage)
      'skipped)

     ((not deps-ok-p)
      (my/log "stage skipped (dependency): %s after=%S"
              stage (my/stage-after stage))
      'skipped)

     (t
      (my/module-run-stage stage (my/stage-manifest stage))))))

;;; ---------------------------------------------------------------------------
;;; Deferred scheduling
;;; ---------------------------------------------------------------------------

(defun my/module--register-deferred-job (name strategy)
  "Record deferred module NAME with STRATEGY."
  (push (list :name name
              :strategy strategy
              :scheduled-at (current-time))
        my/module-deferred-jobs))

(defun my/module--run-deferred-init (name init-fn)
  "Safely run deferred module NAME using INIT-FN."
  (my/with-safe-init (format "module:%s[deferred]" name)
    (funcall init-fn)))

(defun my/module--schedule-after-init (name init-fn)
  "Schedule deferred module NAME on `after-init-hook'."
  (add-hook
   'after-init-hook
   (lambda ()
     (my/module--run-deferred-init name init-fn))
   90)
  (my/module--register-deferred-job name '(:hook after-init-hook)))

(defun my/module--schedule-hook (name init-fn hook &optional append local)
  "Schedule deferred module NAME on HOOK."
  (add-hook
   hook
   (lambda ()
     (my/module--run-deferred-init name init-fn))
   append
   local)
  (my/module--register-deferred-job name (list :hook hook)))

(defun my/module--schedule-idle (name init-fn seconds)
  "Schedule deferred module NAME on idle timer after SECONDS."
  (run-with-idle-timer
   seconds nil
   (lambda ()
     (my/module--run-deferred-init name init-fn)))
  (my/module--register-deferred-job name (list :idle seconds)))

(defun my/module--schedule-timer (name init-fn seconds)
  "Schedule deferred module NAME on regular timer after SECONDS."
  (run-with-timer
   seconds nil
   (lambda ()
     (my/module--run-deferred-init name init-fn)))
  (my/module--register-deferred-job name (list :timer seconds)))

(defun my/module--schedule-after-feature (name init-fn feature)
  "Schedule deferred module NAME after FEATURE is loaded."
  (with-eval-after-load feature
    (my/module--run-deferred-init name init-fn))
  (my/module--register-deferred-job name (list :after-feature feature)))

(defun my/module--schedule-command (name init-fn command)
  "Schedule deferred module NAME before first invocation of COMMAND."
  (let ((fn-name (intern (format "my/module--deferred-command:%s:%s" name command))))
    (fset
     fn-name
     (lambda ()
       (when (eq this-command command)
         (remove-hook 'pre-command-hook fn-name)
         (my/module--run-deferred-init name init-fn))))
    (add-hook 'pre-command-hook fn-name 0)
    (my/module--register-deferred-job name (list :command command))))

(defun my/module-schedule-deferred (name init-fn defer)
  "Schedule deferred module NAME with INIT-FN according to DEFER strategy.

Supported forms:
- t                         => after-init-hook
- (:hook HOOK)
- (:idle SECONDS)
- (:timer SECONDS)
- (:after-feature FEATURE)
- (:command COMMAND)"
  (cond
   ((eq defer t)
    (my/module--schedule-after-init name init-fn))

   ((and (listp defer) (eq (car defer) :hook))
    (my/module--schedule-hook name init-fn (cadr defer)))

   ((and (listp defer) (eq (car defer) :idle))
    (my/module--schedule-idle name init-fn (or (cadr defer) 1.0)))

   ((and (listp defer) (eq (car defer) :timer))
    (my/module--schedule-timer name init-fn (or (cadr defer) 1.0)))

   ((and (listp defer) (eq (car defer) :after-feature))
    (my/module--schedule-after-feature name init-fn (cadr defer)))

   ((and (listp defer) (eq (car defer) :command))
    (my/module--schedule-command name init-fn (cadr defer)))

   (t
    (my/log "unknown defer strategy for %s: %S, fallback to after-init" name defer)
    (my/module--schedule-after-init name init-fn))))

(defun my/module-deferred-report ()
  "Log deferred module scheduling summary."
  (when my/module-deferred-jobs
    (my/log "deferred modules scheduled: %d" (length my/module-deferred-jobs))
    (dolist (job (reverse my/module-deferred-jobs))
      (my/log "  deferred: %s %S"
              (plist-get job :name)
              (plist-get job :strategy)))))

;;; ---------------------------------------------------------------------------
;;; Module runner
;;; ---------------------------------------------------------------------------

(defun my/module-run-spec (spec)
  "Run a single manifest SPEC."
  (let* ((name        (my/module--plist-get-required spec :name))
         (feature     (plist-get spec :feature))
         (predicate   (plist-get spec :predicate))
         (after       (plist-get spec :after))
         (feature-sym (my/module--plist-get-required spec :require))
         (init-fn     (my/module--plist-get-required spec :init))
         (defer       (plist-get spec :defer))
         (enabled-p   (my/module--resolve-value feature))
         (allowed-p   (my/module--resolve-value predicate))
         (deps-ok-p   (my/module--dependency-satisfied-p after)))
    (cond
     ((not enabled-p)
      (my/module--record
       (list :name name :status 'skipped :reason :feature-disabled))
      (my/log "module skipped (feature): %s" name)
      'skipped)

     ((not allowed-p)
      (my/module--record
       (list :name name :status 'skipped :reason :predicate-failed))
      (my/log "module skipped (predicate): %s" name)
      'skipped)

     ((not deps-ok-p)
      (my/module--record
       (list :name name :status 'skipped :reason :dependency-failed :after after))
      (my/log "module skipped (dependency): %s after=%S" name after)
      'skipped)

     ((not (my/safe-require feature-sym nil t))
      (my/module--record
       (list :name name :status 'failed :reason :require-failed))
      (my/log "module failed (require): %s" name)
      'failed)

     (defer
      (my/module-schedule-deferred name init-fn defer)
      (my/module--record
       (list :name name :status 'deferred :defer defer))
      (my/log "module deferred: %s strategy=%S" name defer)
      'deferred)

     (t
      (let ((ok (my/with-safe-init (format "module:%s" name)
                  (funcall init-fn)
                  t)))
        (if ok
            (progn
              (my/module--record (list :name name :status 'ok))
              (my/log "module ok: %s" name)
              'ok)
          (my/module--record
           (list :name name :status 'failed :reason :init-failed))
          (my/log "module failed (init): %s" name)
          'failed))))))

(defun my/module-run-manifest (manifest &optional label)
  "Run all modules in MANIFEST.
LABEL is optional and used for logging.
Return execution records for this manifest (newest-first)."
  (let ((before-count (length my/module-run-records)))
    (when label
      (my/log "manifest start: %s" label))
    (dolist (spec manifest)
      (my/module-run-spec spec))
    (when label
      (my/log "manifest end: %s" label))
    (let ((delta (- (length my/module-run-records) before-count)))
      (cl-subseq my/module-run-records 0 delta))))

(defun my/module-summary ()
  "Return a plist summary of module execution."
  (let ((ok 0) (skipped 0) (failed 0) (deferred 0))
    (dolist (rec my/module-run-records)
      (pcase (plist-get rec :status)
        ('ok       (cl-incf ok))
        ('skipped  (cl-incf skipped))
        ('failed   (cl-incf failed))
        ('deferred (cl-incf deferred))))
    (list :ok ok
          :skipped skipped
          :failed failed
          :deferred deferred
          :total (+ ok skipped failed deferred))))

(defun my/module-report ()
  "Log module execution summary."
  (let* ((summary   (my/module-summary))
         (ok        (plist-get summary :ok))
         (skipped   (plist-get summary :skipped))
         (failed    (plist-get summary :failed))
         (deferred  (plist-get summary :deferred))
         (total     (plist-get summary :total)))
    (my/log "modules summary: total=%d ok=%d skipped=%d deferred=%d failed=%d"
            total ok skipped deferred failed)))

;;; ---------------------------------------------------------------------------
;;; Stage runner
;;; ---------------------------------------------------------------------------

(defun my/module-run-stage (stage manifest)
  "Run MANIFEST as STAGE under stage sentinel."
  (my/with-stage-sentinel stage
    (my/log "stage start: %s" stage)
    (let ((records (my/module-run-manifest manifest (symbol-name stage))))
      (my/log "stage end: %s" stage)
      records)))

(defun my/core-module-init ()
  "Initialize module orchestration subsystem."
  (setq my/module-run-records nil
        my/module-deferred-jobs nil)
  (my/stage-sentinel-clear))

(provide 'core-module)
;;; core-module.el ends here
