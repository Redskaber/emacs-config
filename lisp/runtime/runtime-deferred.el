;;; runtime-deferred.el --- Managed deferred lifecycle -*- lexical-binding: t; -*-
;;; Commentary:
;;;  1. «Deferred completion» is now event-driven:
;;;     When the init thunk fires my/deferred--run emits
;;;     my/event-deferred-complete instead of calling a direct callback.
;;;     runtime-lifecycle subscribes to that event and updates module state.
;;;     This closes the loop without circular dependency between modules.
;;;  2. Scheduler internal state (scheduled/fired/cancelled) stays inside
;;;     my/deferred-obj.  Module-level state (deferred/running/ok/failed)
;;;     lives in runtime-lifecycle exclusively.
;;;  3. my/deferred-obj gains :fired-at timestamp.
;;;  4. All supported strategies are unchanged from V1.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)

;; ─────────────────────────────────────────────────────────────────────────────
;; Deferred completion event constant
;; (forward-declared here; canonical defconst is in runtime-lifecycle)
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/event-deferred-complete :deferred/complete
  "Emitted when a deferred init thunk finishes.
  Payload: (:name SYMBOL :ok BOOL :t0 FLOAT :t1 FLOAT).")

;; ─────────────────────────────────────────────────────────────────────────────
;; Private obarray + pending table
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/deferred--obarray (make-vector 127 0)
  "Private obarray for trampoline symbols.")

(defun my/deferred--intern (name)
  (intern name my/deferred--obarray))

(defvar my/deferred--pending (make-hash-table :test #'eq)
  "Map module-name → init-thunk (removed atomically before calling).")

;; ─────────────────────────────────────────────────────────────────────────────
;; Deferred object  (scheduler internal state only)
;; ─────────────────────────────────────────────────────────────────────────────

(cl-defstruct (my/deferred-obj
               (:constructor my/deferred-obj--make)
               (:copier nil))
  (name      nil)
  (strategy  nil)
  (state     'scheduled :documentation "scheduled | fired | cancelled")
  (cancel-fn nil)
  (fired-at  nil :documentation "float-time when thunk actually ran"))

(defvar my/deferred--registry (make-hash-table :test #'eq)
  "Map module-name → my/deferred-obj.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Core: run thunk and emit completion event
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred--run (name)
  "Execute the deferred init for NAME.
  Emits :deferred/complete; runtime-lifecycle handles state update."
  (let ((init-fn (gethash name my/deferred--pending)))
    (unless init-fn
      (my/log-warn "deferred" "no pending init for %s (already ran?)" name)
      (cl-return-from my/deferred--run nil))
    (remhash name my/deferred--pending)
    (let* ((obj (gethash name my/deferred--registry))
           (t0  (float-time))
           (ok  (condition-case err
                    (progn (funcall init-fn) t)
                  (error
                   (my/log-error "deferred" "init failed %s -> %S" name err)
                   nil)))
           (t1  (float-time)))
      (when obj
        (setf (my/deferred-obj-state    obj) 'fired
              (my/deferred-obj-fired-at obj) t1))
      ;; V2: emit event instead of direct callback
      ;; runtime-lifecycle is subscribed to :deferred/complete
      (require 'runtime-observer)
      (my/observer-emit my/event-deferred-complete
                        (list :name name :ok ok :t0 t0 :t1 t1))
      ok)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Trampoline builder
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred--make-trampoline (name hook-sym _prio)
  "Return a self-removing trampoline fn for NAME on HOOK-SYM."
  (let ((sym (my/deferred--intern (format "my/deferred:%s" name))))
    (fset sym
          (lambda (&rest _)
            (when hook-sym (remove-hook hook-sym sym))
            (my/deferred--run name)))
    sym))

;; ─────────────────────────────────────────────────────────────────────────────
;; Schedule
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred-schedule (name init-fn strategy)
  "Register INIT-FN for NAME and schedule per STRATEGY.
  Returns a `my/deferred-obj'."
  (puthash name init-fn my/deferred--pending)
  (let* ((obj (my/deferred-obj--make :name name :strategy strategy))
         cancel-fn)
    (cond
     ((eq strategy t)
      (let ((tramp (my/deferred--make-trampoline name 'after-init-hook 90)))
        (add-hook 'after-init-hook tramp 90)
        (setq cancel-fn (lambda () (remove-hook 'after-init-hook tramp)))))

     ((and (listp strategy) (eq (car strategy) :hook))
      (let* ((hook  (cadr strategy))
             (prio  (plist-get (cddr strategy) :priority))
             (tramp (my/deferred--make-trampoline name hook prio)))
        (add-hook hook tramp prio)
        (setq cancel-fn (lambda () (remove-hook hook tramp)))))

     ((and (listp strategy) (eq (car strategy) :idle))
      (let* ((secs  (or (cadr strategy) 1.0))
             (timer (run-with-idle-timer secs nil
                                         (lambda () (my/deferred--run name)))))
        (setq cancel-fn (lambda () (cancel-timer timer)))))

     ((and (listp strategy) (eq (car strategy) :timer))
      (let* ((secs  (or (cadr strategy) 1.0))
             (timer (run-with-timer secs nil
                                    (lambda () (my/deferred--run name)))))
        (setq cancel-fn (lambda () (cancel-timer timer)))))

     ((and (listp strategy) (eq (car strategy) :after-feature))
      (let ((feat (cadr strategy)))
        (with-eval-after-load feat (my/deferred--run name))
        (setq cancel-fn nil)))

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

     (t
      (my/log-warn "deferred"
                   "unknown strategy for %s: %S; fallback after-init" name strategy)
      (let ((tramp (my/deferred--make-trampoline name 'after-init-hook 90)))
        (add-hook 'after-init-hook tramp 90)
        (setq cancel-fn (lambda () (remove-hook 'after-init-hook tramp))))))

    (setf (my/deferred-obj-cancel-fn obj) cancel-fn)
    (puthash name obj my/deferred--registry)
    (my/log-debug "deferred" "scheduled %s strategy=%S" name strategy)
    obj))

;; ─────────────────────────────────────────────────────────────────────────────
;; Cancel
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred-cancel (name)
  "Cancel pending deferred init for NAME.  Returns t on success."
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
      ;; Emit completion event so lifecycle transitions to :cancelled
      (my/observer-emit my/event-deferred-complete
                        (list :name name :ok nil
                              :t0 (my/deferred-obj-fired-at obj)
                              :t1 (float-time)
                              :cancelled t))
      (my/log-info "deferred" "cancelled %s" name)
      t))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Introspection
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred-status (name)
  "Return scheduler state: scheduled | fired | cancelled | nil."
  (let ((obj (gethash name my/deferred--registry)))
    (and obj (my/deferred-obj-state obj))))

(defun my/deferred-pending-names ()
  (let (names)
    (maphash (lambda (k _) (push k names)) my/deferred--pending)
    names))

;; ─────────────────────────────────────────────────────────────────────────────
;; Reset
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred-reset ()
  "Cancel all pending inits and clear registry."
  (maphash (lambda (name _) (my/deferred-cancel name))
           (copy-hash-table my/deferred--registry))
  (clrhash my/deferred--registry)
  (clrhash my/deferred--pending))

(provide 'runtime-deferred)
;;; runtime-deferred.el ends here
