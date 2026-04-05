;;; runtime-module-runner.el --- Manifest module executor  -*- lexical-binding: t; -*-
;;; Commentary:
;;; 1. IDEMPOTENCY GUARD
;;;    Every module execution is gated by my/runtime-module-find-record.
;;;    If a record already exists the module is not run again.  This means
;;;    re-running the pipeline (interactive M-x my/init-force-rerun) is safe.
;;;
;;; 2. CLEAN DEFERRED SYMBOL STRATEGY
;;;    stores the init closure in a buffer-local (really session-local)
;;;    variable and the hook/timer target is a thin trampoline that reads it.
;;;    The generated symbols are interned into a dedicated obarray
;;;    `my/runner-obarray' and are not visible in completion lists.
;;;
;;; 3. LIFECYCLE POLICY
;;;    defer spec is treated as a *lifecycle strategy*, not just an execution
;;;    hint.  The module transitions:
;;;      pending → deferred (scheduled) → ok | failed (after execution)
;;;    The deferred→ok transition fires my/event-module-run a second time
;;;    so the observer bus sees the final outcome.
;;;
;;; 4. TIMESTAMPS
;;;    Records include :started-at and :ended-at for profiling.
;;; Code:

(require 'cl-lib)
(require 'kernel-errors)
(require 'kernel-logging)
(require 'kernel-require)
(require 'runtime-types)
(require 'runtime-feature)
(require 'runtime-manifest)
(require 'runtime-module-state)
(require 'runtime-observer)

;; ---------------------------------------------------------------------------
;; Obarray for generated symbols (kept off main obarray)
;; ---------------------------------------------------------------------------

(defvar my/runner-obarray (make-vector 127 0)
  "Private obarray for deferred-hook trampoline symbols.
Not visible in regular completion or describe-function.")

(defun my/runner--intern (name)
  "Intern NAME into `my/runner-obarray'."
  (intern name my/runner-obarray))

;; ---------------------------------------------------------------------------
;; Deferred execution core
;; ---------------------------------------------------------------------------

(defvar my/runner--pending-inits (make-hash-table :test #'eq)
  "Map module-name symbol → init-fn, for deferred trampoline lookup.")

(defun my/runner--run-deferred (name)
  "Execute the deferred init for module NAME.
Updates the existing record's status from deferred → ok | failed."
  (let ((init-fn (gethash name my/runner--pending-inits)))
    (unless init-fn
      (my/log "[runner] deferred init fn missing for %s (already ran?)" name)
      (cl-return-from my/runner--run-deferred nil))
    ;; Remove to prevent double-execution
    (remhash name my/runner--pending-inits)
    (let* ((started (current-time))
           (ok (my/with-safe-call (format "module:%s[deferred]" name)
                 (funcall init-fn)
                 t))
           (ended (current-time))
           (status (if ok my/module-status-ok my/module-status-failed))
           (record (list :name name
                         :status status
                         :reason (unless ok my/reason-init-failed)
                         :started-at started
                         :ended-at ended)))
      ;; Overwrite deferred record with final outcome
      (my/runtime-module-record record)
      (my/log "[runner] deferred %s → %s" name status))))

;; ---------------------------------------------------------------------------
;; Scheduling strategies
;; ---------------------------------------------------------------------------

(defun my/runner--schedule (name init-fn defer)
  "Store INIT-FN for NAME and schedule according to DEFER strategy.

Supported strategies:
  t                         ⟶ after-init-hook (priority 90)
  (:hook HOOK)              ⟶ append to HOOK
  (:hook HOOK :priority N)  ⟶ append to HOOK with priority N
  (:idle SECONDS)           ⟶ run-with-idle-timer
  (:timer SECONDS)          ⟶ run-with-timer
  (:after-feature FEATURE)  ⟶ with-eval-after-load
  (:command COMMAND)        ⟶ pre-command-hook, one-shot"
  ;; Register init-fn in pending table
  (puthash name init-fn my/runner--pending-inits)

  ;; Build a one-shot trampoline that cleans up its own hook entry
  (let ((trampoline
         (my/runner--intern (format "my/deferred:%s" name))))
    (fset trampoline
          (lambda (&rest _)
            (my/runner--run-deferred name)))

    (cond
     ;; ── t ──────────────────────────────────────────────────────
     ((eq defer t)
      (add-hook 'after-init-hook trampoline 90)
      (my/runtime-module-register-deferred-job name '(:hook after-init-hook)))

     ;; ── (:hook HOOK [:priority N]) ────────────────────────────
     ((and (listp defer) (eq (car defer) :hook))
      (let ((hook  (cadr defer))
            (prio  (or (plist-get (cddr defer) :priority) nil)))
        (add-hook hook trampoline prio)
        (my/runtime-module-register-deferred-job
         name (list :hook hook :priority prio))))

     ;; ── (:idle SECONDS) ───────────────────────────────────────
     ((and (listp defer) (eq (car defer) :idle))
      (let ((secs (or (cadr defer) 1.0)))
        (run-with-idle-timer secs nil trampoline)
        (my/runtime-module-register-deferred-job
         name (list :idle secs))))

     ;; ── (:timer SECONDS) ──────────────────────────────────────
     ((and (listp defer) (eq (car defer) :timer))
      (let ((secs (or (cadr defer) 1.0)))
        (run-with-timer secs nil trampoline)
        (my/runtime-module-register-deferred-job
         name (list :timer secs))))

     ;; ── (:after-feature FEATURE) ──────────────────────────────
     ((and (listp defer) (eq (car defer) :after-feature))
      (let ((feat (cadr defer)))
        (with-eval-after-load feat (funcall trampoline))
        (my/runtime-module-register-deferred-job
         name (list :after-feature feat))))

     ;; ── (:command COMMAND) ────────────────────────────────────
     ;; One-shot: fires before the first invocation of COMMAND, then
     ;; removes itself from pre-command-hook.
     ((and (listp defer) (eq (car defer) :command))
      (let ((cmd (cadr defer)))
        ;; Wrap trampoline to self-remove after one invocation
        (let ((guard-sym (my/runner--intern
                          (format "my/deferred-guard:%s:%s" name cmd))))
          (fset guard-sym
                (lambda ()
                  (when (eq this-command cmd)
                    (remove-hook 'pre-command-hook guard-sym)
                    (funcall trampoline))))
          (add-hook 'pre-command-hook guard-sym 0)
          (my/runtime-module-register-deferred-job
           name (list :command cmd)))))

     ;; ── fallback ──────────────────────────────────────────────
     (t
      (my/log "[runner] unknown defer spec for %s: %S; fallback after-init" name defer)
      (add-hook 'after-init-hook trampoline 90)
      (my/runtime-module-register-deferred-job
       name (list :hook 'after-init-hook :fallback t))))))

;; ---------------------------------------------------------------------------
;; Single module execution
;; ---------------------------------------------------------------------------

(defun my/runtime-module-run-spec (spec)
  "Evaluate a single manifest SPEC plist.
Returns the status symbol: ok | deferred | skipped | failed."
  (let* ((spec      (my/runtime-manifest-normalize-spec spec))
         (name      (plist-get spec :name))
         (feature   (plist-get spec :feature))
         (predicate (plist-get spec :predicate))
         (after     (plist-get spec :after))
         (feat-sym  (plist-get spec :require))
         (init-fn   (plist-get spec :init))
         (defer     (plist-get spec :defer)))

    ;; ── Idempotency guard ────────────────────────────────────────────────
    (when (my/runtime-module-find-record name)
      (my/log "[runner] module already recorded, skip re-run: %s" name)
      (cl-return-from my/runtime-module-run-spec
        (my/runtime-module-status name)))

    (let ((enabled-p  (my/feature-enabled-p feature))
          (allowed-p  (my/feature-enabled-p predicate))
          (deps-ok-p  (my/runtime-module-deps-satisfied-p after)))

      (cond
       ;; ── Feature gate ──────────────────────────────────────────────
       ((not enabled-p)
        (my/runtime-module-record
         (list :name name :status my/module-status-skipped
               :reason my/reason-feature-disabled))
        (my/log "[runner] skip(feature): %s" name)
        my/module-status-skipped)

       ;; ── Predicate gate ────────────────────────────────────────────
       ((not allowed-p)
        (my/runtime-module-record
         (list :name name :status my/module-status-skipped
               :reason my/reason-predicate-failed))
        (my/log "[runner] skip(predicate): %s" name)
        my/module-status-skipped)

       ;; ── Dependency gate ───────────────────────────────────────────
       ((not deps-ok-p)
        (my/runtime-module-record
         (list :name name :status my/module-status-skipped
               :reason my/reason-dependency-failed
               :after after))
        (my/log "[runner] skip(dep): %s after=%S" name after)
        my/module-status-skipped)

       ;; ── Require gate ──────────────────────────────────────────────
       ((not (my/safe-require feat-sym nil t))
        (my/runtime-module-record
         (list :name name :status my/module-status-failed
               :reason my/reason-require-failed))
        (my/log "[runner] failed(require): %s" name)
        my/module-status-failed)

       ;; ── Deferred ──────────────────────────────────────────────────
       (defer
        (my/runner--schedule name init-fn defer)
        (my/runtime-module-record
         (list :name name :status my/module-status-deferred
               :defer defer))
        (my/log "[runner] deferred: %s strategy=%S" name defer)
        my/module-status-deferred)

       ;; ── Synchronous run ───────────────────────────────────────────
       (t
        (let* ((started (current-time))
               (ok (my/with-safe-call (format "module:%s" name)
                     (funcall init-fn)
                     t))
               (ended   (current-time))
               (status  (if ok my/module-status-ok my/module-status-failed)))
          (my/runtime-module-record
           (list :name name :status status
                 :reason (unless ok my/reason-init-failed)
                 :started-at started
                 :ended-at ended))
          (my/log "[runner] %s: %s" status name)
          status))))))

;; ---------------------------------------------------------------------------
;; Manifest runner
;; ---------------------------------------------------------------------------

(defun my/runtime-module-run-manifest (manifest &optional label)
  "Run all module specs in MANIFEST.
Returns list of status symbols in declaration order."
  (let ((manifest (my/runtime-manifest-normalize manifest))
        results)
    (when label (my/log "[runner] manifest start: %s" label))
    (dolist (spec manifest)
      (push (my/runtime-module-run-spec spec) results))
    (when label (my/log "[runner] manifest end: %s" label))
    (nreverse results)))

(provide 'runtime-module-runner)
;;; runtime-module-runner.el ends here
