;;; runtime-deferred.el --- Managed deferred lifecycle  -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. Has an explicit lifecycle:  scheduled → fired | cancelled
;;;   2. Auto-removes hooks/timers after firing.
;;;   3. Stores all generated hook/timer teardown thunks so they can be
;;;      cancelled via my/deferred-cancel.
;;;   4. Uses a dedicated obarray (kept from V1) so trampoline symbols don't
;;;      pollute completion.
;;;   5. The pending-inits table is local to this module; no external access.
;;;
;;; Supported strategies (same as V1 + comments on lifecycle):
;;;   t                         → after-init-hook (priority 90), auto-removed
;;;   (:hook HOOK)              → append to HOOK, auto-removed after firing
;;;   (:hook HOOK :priority N)  → same, with priority N
;;;   (:idle SECONDS)           → run-with-idle-timer, one-shot (repeat nil)
;;;   (:timer SECONDS)          → run-with-timer, one-shot
;;;   (:after-feature FEATURE)  → with-eval-after-load (cannot cancel)
;;;   (:command COMMAND)        → pre-command-hook, one-shot
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)

;; ---------------------------------------------------------------------------
;; Private obarray for trampolines
;; ---------------------------------------------------------------------------

(defvar my/deferred--obarray (make-vector 127 0)
  "Private obarray for deferred-hook trampoline symbols.")

(defun my/deferred--intern (name)
  "Intern NAME into the private obarray."
  (intern name my/deferred--obarray))

;; ---------------------------------------------------------------------------
;; Pending init table
;; ---------------------------------------------------------------------------

(defvar my/deferred--pending (make-hash-table :test #'eq)
  "Map module-name-symbol → init-thunk.
  Entries are removed atomically before calling the thunk.")

;; ---------------------------------------------------------------------------
;; Deferred object
;; ---------------------------------------------------------------------------

(cl-defstruct (my/deferred-obj
               (:constructor my/deferred-obj--make)
               (:copier nil))
  "A scheduled deferred module init."
  (name       nil :documentation "Module name symbol.")
  (strategy   nil :documentation "Strategy spec as provided by manifest.")
  (state      'scheduled :documentation "scheduled | fired | cancelled.")
  ;; Teardown thunk: called by my/deferred-cancel to undo the scheduling.
  ;; nil for strategies that cannot be un-scheduled (e.g. :after-feature).
  (cancel-fn  nil :documentation "Thunk to undo hook/timer registration, or nil."))

;; Registry: name → my/deferred-obj
(defvar my/deferred--registry (make-hash-table :test #'eq)
  "Map module-name-symbol → `my/deferred-obj'.")

;; ---------------------------------------------------------------------------
;; Core: run deferred init
;; ---------------------------------------------------------------------------

(defun my/deferred--run (name)
  "Execute the deferred init for module NAME.
  Called by trampolines.  Returns (ok . result) or (nil . error)."
  (let ((init-fn (gethash name my/deferred--pending)))
    (unless init-fn
      (my/log-warn "deferred" "pending init missing for %s (already ran?)" name)
      (cl-return-from my/deferred--run nil))
    ;; Remove first to prevent double-execution
    (remhash name my/deferred--pending)
    ;; Update object state
    (let ((obj (gethash name my/deferred--registry)))
      (when obj (setf (my/deferred-obj-state obj) 'fired)))
    ;; Execute
    (condition-case err
        (progn (funcall init-fn) t)
      (error
       (my/log-error "deferred" "init failed %s -> %S" name err)
       nil))))

;; ---------------------------------------------------------------------------
;; Trampoline builder
;; ---------------------------------------------------------------------------

(defun my/deferred--make-trampoline (name hook-sym prio)
  "Return a named trampoline fn for NAME that self-removes from HOOK-SYM.
  When HOOK-SYM is nil the trampoline does not remove itself."
  (let ((sym (my/deferred--intern (format "my/deferred:%s" name))))
    (fset sym
          (lambda (&rest _)
            ;; Self-remove from hook if applicable
            (when hook-sym (remove-hook hook-sym sym))
            (my/deferred--run name)))
    sym))

;; ---------------------------------------------------------------------------
;; Schedule
;; ---------------------------------------------------------------------------

(defun my/deferred-schedule (name init-fn strategy)
  "Register INIT-FN for NAME and schedule per STRATEGY.

  Returns a `my/deferred-obj'."
  ;; Store init fn
  (puthash name init-fn my/deferred--pending)

  (let* ((obj      (my/deferred-obj--make :name name :strategy strategy))
         cancel-fn)

    (cond
     ;; ── t  ────────────────────────────────────────────────────────────
     ((eq strategy t)
      (let ((tramp (my/deferred--make-trampoline name 'after-init-hook 90)))
        (add-hook 'after-init-hook tramp 90)
        (setq cancel-fn (lambda () (remove-hook 'after-init-hook tramp)))))

     ;; ── (:hook HOOK [:priority N]) ───────────────────────────────────
     ((and (listp strategy) (eq (car strategy) :hook))
      (let* ((hook (cadr strategy))
             (prio (plist-get (cddr strategy) :priority))
             (tramp (my/deferred--make-trampoline name hook prio)))
        (add-hook hook tramp prio)
        (setq cancel-fn (lambda () (remove-hook hook tramp)))))

     ;; ── (:idle SECONDS) ──────────────────────────────────────────────
     ((and (listp strategy) (eq (car strategy) :idle))
      (let* ((secs  (or (cadr strategy) 1.0))
             (timer (run-with-idle-timer secs nil
                                         (lambda () (my/deferred--run name)))))
        (setq cancel-fn (lambda () (cancel-timer timer)))))

     ;; ── (:timer SECONDS) ─────────────────────────────────────────────
     ((and (listp strategy) (eq (car strategy) :timer))
      (let* ((secs  (or (cadr strategy) 1.0))
             (timer (run-with-timer secs nil
                                    (lambda () (my/deferred--run name)))))
        (setq cancel-fn (lambda () (cancel-timer timer)))))

     ;; ── (:after-feature FEATURE) ─────────────────────────────────────
     ;; with-eval-after-load cannot be cancelled; cancel-fn stays nil.
     ((and (listp strategy) (eq (car strategy) :after-feature))
      (let ((feat (cadr strategy)))
        (with-eval-after-load feat (my/deferred--run name))
        (setq cancel-fn nil)))

     ;; ── (:command COMMAND) ───────────────────────────────────────────
     ((and (listp strategy) (eq (car strategy) :command))
      (let* ((cmd  (cadr strategy))
             (gsym (my/deferred--intern
                    (format "my/deferred-guard:%s:%s" name cmd))))
        (fset gsym
              (lambda ()
                (when (eq this-command cmd)
                  (remove-hook 'pre-command-hook gsym)
                  (my/deferred--run name))))
        (add-hook 'pre-command-hook gsym 0)
        (setq cancel-fn (lambda () (remove-hook 'pre-command-hook gsym)))))

     ;; ── fallback ─────────────────────────────────────────────────────
     (t
      (my/log-warn "deferred" "unknown strategy for %s: %S; fallback after-init" name strategy)
      (let ((tramp (my/deferred--make-trampoline name 'after-init-hook 90)))
        (add-hook 'after-init-hook tramp 90)
        (setq cancel-fn (lambda () (remove-hook 'after-init-hook tramp))))))

    ;; Finalise object
    (setf (my/deferred-obj-cancel-fn obj) cancel-fn)
    (puthash name obj my/deferred--registry)
    (my/log-debug "deferred" "scheduled %s strategy=%S" name strategy)
    obj))

;; ---------------------------------------------------------------------------
;; Cancel
;; ---------------------------------------------------------------------------

(defun my/deferred-cancel (name)
  "Cancel a pending deferred init for module NAME.

  Returns t when successfully cancelled, nil when not found or already fired."
  (let ((obj (gethash name my/deferred--registry)))
    (cond
     ((null obj)
      (my/log-warn "deferred" "cancel: no deferred object for %s" name)
      nil)
     ((eq (my/deferred-obj-state obj) 'fired)
      (my/log-debug "deferred" "cancel: %s already fired" name)
      nil)
     (t
      (when (my/deferred-obj-cancel-fn obj)
        (funcall (my/deferred-obj-cancel-fn obj)))
      (remhash name my/deferred--pending)
      (setf (my/deferred-obj-state obj) 'cancelled)
      (my/log-info "deferred" "cancelled %s" name)
      t))))

;; ---------------------------------------------------------------------------
;; Introspection
;; ---------------------------------------------------------------------------

(defun my/deferred-status (name)
  "Return state of deferred object for NAME: scheduled | fired | cancelled | nil."
  (let ((obj (gethash name my/deferred--registry)))
    (and obj (my/deferred-obj-state obj))))

(defun my/deferred-pending-names ()
  "Return list of module names still pending execution."
  (let (names)
    (maphash (lambda (k _) (push k names)) my/deferred--pending)
    names))

;; ---------------------------------------------------------------------------
;; Reset
;; ---------------------------------------------------------------------------

(defun my/deferred-reset ()
  "Cancel all pending deferred inits and clear registry.
  Safe to call between sessions (e.g. during force-rerun)."
  (maphash (lambda (name _) (my/deferred-cancel name))
           (copy-hash-table my/deferred--registry))
  (clrhash my/deferred--registry)
  (clrhash my/deferred--pending))

(provide 'runtime-deferred)
;;; runtime-deferred.el ends here
