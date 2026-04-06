;;; runtime-observer.el --- Runtime event bus -*- lexical-binding: t; -*-
;;; Commentary:
;;; No semantic changes, minor hardening.
;;;    - my/observer-emit returns the number of handlers that fired.
;;;    - my/observer-emit-deferred accepts nil seconds (fires immediately
;;;      after current command via run-with-idle-timer 0).
;;;    - Standard event constants extended with :module/lifecycle and
;;;      :deferred/complete (defined in runtime-lifecycle but declared here
;;;      for discoverability; the defconsts in lifecycle.el take precedence).
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ─────────────────────────────────────────────────────────────────────────────
;; Subscription struct
;; ─────────────────────────────────────────────────────────────────────────────

(cl-defstruct (my/observer-sub
               (:constructor my/observer-sub--make)
               (:copier nil))
  (event    nil :read-only t)
  (label    nil :read-only t)
  (handler  nil :read-only t)
  (priority 50  :read-only t)
  (once     nil :read-only t)
  (filter   nil :read-only t))

;; ─────────────────────────────────────────────────────────────────────────────
;; Registry
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/observer--registry (make-hash-table :test #'eq)
  "Map event-keyword → sorted list of `my/observer-sub'.")

(defun my/observer--sort-subs (subs)
  (sort (copy-sequence subs)
        (lambda (a b) (< (my/observer-sub-priority a)
                         (my/observer-sub-priority b)))))

(defun my/observer--remove-sub (event label)
  (puthash event
           (cl-remove-if (lambda (s) (eq (my/observer-sub-label s) label))
                         (gethash event my/observer--registry))
           my/observer--registry))

;; ─────────────────────────────────────────────────────────────────────────────
;; Public API
;; ─────────────────────────────────────────────────────────────────────────────

(cl-defun my/observer-subscribe (event label handler
                                        &key (priority 50) once filter)
  "Subscribe HANDLER to EVENT under LABEL.
  Re-subscribing with the same LABEL replaces the previous subscription."
  (my/observer--remove-sub event label)
  (let ((sub (my/observer-sub--make
              :event    event
              :label    label
              :handler  handler
              :priority priority
              :once     once
              :filter   filter)))
    (puthash event
             (my/observer--sort-subs
              (cons sub (gethash event my/observer--registry)))
             my/observer--registry)
    sub))

(defun my/observer-unsubscribe (event label)
  "Remove LABEL subscription from EVENT."
  (my/observer--remove-sub event label))

(defun my/observer-emit (event &optional payload)
  "Emit EVENT with PAYLOAD; return count of handlers fired.
  Errors in handlers are caught and logged."
  (let ((subs         (gethash event my/observer--registry))
        (fired-count  0)
        remove-these)
    (dolist (sub subs)
      (condition-case err
          (when (or (null (my/observer-sub-filter sub))
                    (funcall (my/observer-sub-filter sub) payload))
            (funcall (my/observer-sub-handler sub) payload)
            (cl-incf fired-count)
            (when (my/observer-sub-once sub)
              (push (my/observer-sub-label sub) remove-these)))
        (error
         (my/log-error "observer"
                       "handler error event=%s label=%s -> %S"
                       event (my/observer-sub-label sub) err))))
    (dolist (lbl remove-these)
      (my/observer--remove-sub event lbl))
    fired-count))

(defun my/observer-emit-deferred (event &optional payload seconds)
  "Emit EVENT after SECONDS idle time (default 0 = next idle moment)."
  (run-with-idle-timer
   (or seconds 0) nil
   (lambda () (my/observer-emit event payload))))

(defun my/observer-subscriptions (&optional event)
  "Return all subscriptions, or those for EVENT."
  (if event
      (copy-sequence (gethash event my/observer--registry))
    (let (all)
      (maphash (lambda (_k subs) (setq all (append all subs)))
               my/observer--registry)
      all)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Standard event keywords
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/event-stage-start     :stage/start)
(defconst my/event-stage-end       :stage/end)
(defconst my/event-module-run      :module/run
  "Legacy compat; prefer :module/lifecycle in V2 code.")
(defconst my/event-module-deferred :module/deferred)
(defconst my/event-init-complete   :init/complete)

;; ─────────────────────────────────────────────────────────────────────────────
;; Reset / Init
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/observer-reset ()
  "Clear all subscriptions."
  (clrhash my/observer--registry))

(defun my/runtime-observer-init ()
  (my/observer-reset)
  (my/log-info "observer" "event bus initialised"))

(provide 'runtime-observer)
;;; runtime-observer.el ends here
