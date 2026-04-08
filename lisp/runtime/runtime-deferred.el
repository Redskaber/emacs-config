;;; runtime-deferred.el --- Managed deferred lifecycle -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - my/deferred--emit-complete: central helper, unified require
;;;       Both run and cancel go through this — no implicit observer dependency.
;;;     - Cancel noise fix: cancelled state suppressed to debug level
;;;     - Enriched payload: :status :trigger :trigger-data
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)

;; ─────────────────────────────────────────────────────────────────────────────
;; Deferred completion event
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/event-deferred-complete :deferred/complete
  "Emitted when a deferred init thunk finishes.
  Payload: (:name SYMBOL :status ok|failed|cancelled
            :t0 FLOAT :t1 FLOAT :trigger SYMBOL :trigger-data ANY).")

;; ─────────────────────────────────────────────────────────────────────────────
;; Private state
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/deferred--obarray (make-vector 127 0))

(defun my/deferred--intern (name)
  (intern name my/deferred--obarray))

(defvar my/deferred--pending (make-hash-table :test #'eq)
  "Map module-name → init-thunk.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Deferred object
;; ─────────────────────────────────────────────────────────────────────────────

(cl-defstruct (my/deferred-obj
               (:constructor my/deferred-obj--make)
               (:copier nil))
  (name      nil)
  (strategy  nil)
  (trigger   nil :documentation "Strategy kind symbol: hook|idle|timer|feature|command|after-init")
  (trigger-data nil :documentation "Hook name / secs / feature name / command name")
  (state     'scheduled :documentation "scheduled | fired | cancelled")
  (cancel-fn nil)
  (fired-at  nil))

(defvar my/deferred--registry (make-hash-table :test #'eq)
  "Map module-name → my/deferred-obj.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Central emit helper
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred--emit-complete (name status t0 t1 trigger trigger-data)
  "Emit :deferred/complete for NAME with enriched payload.
  This is the single place that requires runtime-observer, eliminating
  the implicit dependency that existed in my/deferred-cancel."
  (require 'runtime-observer)
  (my/observer-emit my/event-deferred-complete
                    (list :name         name
                          :status       status   ; ok | failed | cancelled
                          :t0           t0
                          :t1           t1
                          :trigger      trigger
                          :trigger-data trigger-data)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Core: run thunk
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred--run (name)
  "Execute the deferred init for NAME and emit completion event."
  (let ((init-fn (gethash name my/deferred--pending)))
    (unless init-fn
      ;; if state is cancelled, this is expected — suppress noise
      (let ((obj (gethash name my/deferred--registry)))
        (if (and obj (eq (my/deferred-obj-state obj) 'cancelled))
            (my/log-debug "deferred" "run suppressed (cancelled): %s" name)
          (my/log-warn "deferred" "no pending init for %s (already ran?)" name)))
      (cl-return-from my/deferred--run nil))
    (remhash name my/deferred--pending)
    (let* ((obj (gethash name my/deferred--registry))
           (t0  (float-time))
           (ok  (condition-case err
                    (progn (funcall init-fn) t)
                  (error
                   (my/log-error "deferred" "init failed %s -> %S" name err)
                   nil)))
           (t1  (float-time))
           (trigger      (and obj (my/deferred-obj-trigger obj)))
           (trigger-data (and obj (my/deferred-obj-trigger-data obj))))
      (when obj
        (setf (my/deferred-obj-state    obj) 'fired
              (my/deferred-obj-fired-at obj) t1))
      (my/deferred--emit-complete name
                                  (if ok 'ok 'failed)
                                  t0 t1 trigger trigger-data)
      ok)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Trampoline builder
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred--make-trampoline (name hook-sym _prio)
  "Create a skip function that executes with a delay."
  (let ((sym (my/deferred--intern (format "my/deferred:%s" name))))
    (fset sym
          (lambda (&rest _)
            (when hook-sym (remove-hook hook-sym sym))
            (my/deferred--run name)))
    sym))

;; ─────────────────────────────────────────────────────────────────────────────
;; Schedule  (record trigger kind + data on obj)
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred-schedule (name init-fn strategy)
  "Register INIT-FN for NAME and schedule per STRATEGY.
  Returns a my/deferred-obj."
  (puthash name init-fn my/deferred--pending)
  (let* ((obj (my/deferred-obj--make :name name :strategy strategy))
         cancel-fn)
    (cond
     ((eq strategy t)
      (let ((tramp (my/deferred--make-trampoline name 'after-init-hook 90)))
        (add-hook 'after-init-hook tramp 90)
        (setf (my/deferred-obj-trigger      obj) 'after-init
              (my/deferred-obj-trigger-data obj) 'after-init-hook)
        (setq cancel-fn (lambda () (remove-hook 'after-init-hook tramp)))))

     ((and (listp strategy) (eq (car strategy) :hook))
      (let* ((hook  (cadr strategy))
             (prio  (plist-get (cddr strategy) :priority))
             (tramp (my/deferred--make-trampoline name hook prio)))
        (add-hook hook tramp prio)
        (setf (my/deferred-obj-trigger      obj) 'hook
              (my/deferred-obj-trigger-data obj) hook)
        (setq cancel-fn (lambda () (remove-hook hook tramp)))))

     ((and (listp strategy) (eq (car strategy) :idle))
      (let* ((secs  (or (cadr strategy) 1.0))
             (timer (run-with-idle-timer secs nil
                                         (lambda () (my/deferred--run name)))))
        (setf (my/deferred-obj-trigger      obj) 'idle
              (my/deferred-obj-trigger-data obj) secs)
        (setq cancel-fn (lambda () (cancel-timer timer)))))

     ((and (listp strategy) (eq (car strategy) :timer))
      (let* ((secs  (or (cadr strategy) 1.0))
             (timer (run-with-timer secs nil
                                    (lambda () (my/deferred--run name)))))
        (setf (my/deferred-obj-trigger      obj) 'timer
              (my/deferred-obj-trigger-data obj) secs)
        (setq cancel-fn (lambda () (cancel-timer timer)))))

     ((and (listp strategy) (eq (car strategy) :after-feature))
      (let ((feat (cadr strategy)))
        (with-eval-after-load feat (my/deferred--run name))
        (setf (my/deferred-obj-trigger      obj) 'feature
              (my/deferred-obj-trigger-data obj) feat)
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
        (setf (my/deferred-obj-trigger      obj) 'command
              (my/deferred-obj-trigger-data obj) cmd)
        (setq cancel-fn (lambda () (remove-hook 'pre-command-hook gsym)))))

     (t
      (my/log-warn "deferred"
                   "unknown strategy for %s: %S; fallback after-init" name strategy)
      (let ((tramp (my/deferred--make-trampoline name 'after-init-hook 90)))
        (add-hook 'after-init-hook tramp 90)
        (setf (my/deferred-obj-trigger      obj) 'after-init
              (my/deferred-obj-trigger-data obj) 'after-init-hook)
        (setq cancel-fn (lambda () (remove-hook 'after-init-hook tramp))))))

    (setf (my/deferred-obj-cancel-fn obj) cancel-fn)
    (puthash name obj my/deferred--registry)
    (my/log-debug "deferred" "scheduled %s strategy=%S" name strategy)
    obj))

;; ─────────────────────────────────────────────────────────────────────────────
;; Cancel  (uses my/deferred--emit-complete)
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
      ;; emit via central helper — no inline require needed here
      (my/deferred--emit-complete name
                                  'cancelled
                                  (my/deferred-obj-fired-at obj)
                                  (float-time)
                                  (my/deferred-obj-trigger obj)
                                  (my/deferred-obj-trigger-data obj))
      (my/log-info "deferred" "cancelled %s" name)
      t))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Introspection
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/deferred-status (name)
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
