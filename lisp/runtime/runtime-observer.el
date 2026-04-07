;;; runtime-observer.el --- Runtime event bus -*- lexical-binding: t; -*-
;;; Commentary:
;;;     Priority hook dispatcher: add-hook's 3rd argument is APPEND (bool),
;;;     not a priority integer.
;;;
;;;     Solution (Option B): Internal dispatcher function owns the hook slot.
;;;     Handlers register into an internal priority-sorted list; the dispatcher
;;;     calls them in order.  This gives true priority ordering while remaining
;;;     100% backward-compatible with the my/observer-subscribe API.
;;;
;;;     Affected hooks: after-init-hook (trampoline) is in runtime-deferred.
;;;     This module provides the general observer bus — trampolines in
;;;     runtime-deferred use the same fix pattern independently.
;;;
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
  "Map event-keyword → sorted list of my/observer-sub.")

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
;; Priority hook dispatcher
;; ─────────────────────────────────────────────────────────────────────────────
;; Problem: add-hook 3rd arg is APPEND (bool), not priority.
;; Passing 90 is treated as non-nil APPEND, which is mostly harmless but
;; is semantically wrong and prevents true priority ordering.
;;
;; Solution: a single dispatcher function owns each hook slot.  Callers
;; register handlers into an internal table with a numeric priority;
;; the dispatcher invokes them in sorted order.
;;
;; This table maps hook-symbol → sorted list of (priority . fn) pairs.

(defvar my/observer--hook-dispatchers (make-hash-table :test #'eq)
  "Map hook-symbol → sorted list of (priority . handler-fn).")

(defun my/observer--hook-dispatcher (hook)
  "Return (or create) the dispatcher thunk for HOOK.
  The thunk calls all registered handlers in priority order."
  (let ((sym (intern (format "my/observer--dispatch:%s" hook))))
    (unless (fboundp sym)
      (fset sym (lambda (&rest args)
                  (let ((handlers (gethash hook my/observer--hook-dispatchers)))
                    (dolist (pair handlers)
                      (condition-case err
                          (apply (cdr pair) args)
                        (error
                         (my/log-error "observer"
                                       "hook dispatcher error hook=%s -> %S" hook err))))))))
    sym))

(defun my/observer-hook-add (hook priority fn)
  "Register FN on HOOK at numeric PRIORITY.
  Lower numbers run first.  This is the priority-correct alternative
  to (add-hook hook fn 90)."
  (let* ((handlers (gethash hook my/observer--hook-dispatchers))
         (new-entry (cons priority fn))
         (updated   (sort (cons new-entry
                                (cl-remove-if (lambda (p) (equal (cdr p) fn)) handlers))
                          (lambda (a b) (< (car a) (car b))))))
    (puthash hook updated my/observer--hook-dispatchers)
    (let ((dispatcher (my/observer--hook-dispatcher hook)))
      ;; Add dispatcher with plain append=nil (correct usage)
      (add-hook hook dispatcher))))

(defun my/observer-hook-remove (hook fn)
  "Remove FN from the priority dispatcher for HOOK."
  (let ((updated (cl-remove-if (lambda (p) (equal (cdr p) fn))
                               (gethash hook my/observer--hook-dispatchers))))
    (puthash hook updated my/observer--hook-dispatchers)
    (when (null updated)
      (let ((dispatcher (my/observer--hook-dispatcher hook)))
        (remove-hook hook dispatcher)))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Public API
;; ─────────────────────────────────────────────────────────────────────────────

(cl-defun my/observer-subscribe (event label handler
                                        &key (priority 50) once filter)
  "Subscribe HANDLER to EVENT under LABEL."
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
  "Emit EVENT with PAYLOAD; return count of handlers fired."
  (let ((subs        (gethash event my/observer--registry))
        (fired-count 0)
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
  "Emit EVENT after SECONDS idle time (default 0)."
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
  "Legacy compat; prefer :module/lifecycle in code.")
(defconst my/event-module-deferred :module/deferred)
(defconst my/event-init-complete   :init/complete)

;; ─────────────────────────────────────────────────────────────────────────────
;; Reset / Init
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/observer-reset ()
  "Clear all subscriptions and hook dispatchers."
  (clrhash my/observer--registry)
  (clrhash my/observer--hook-dispatchers))

(defun my/runtime-observer-init ()
  (my/observer-reset)
  (my/log-info "observer" "event bus initialised (priority-hook dispatcher active)"))

(provide 'runtime-observer)
;;; runtime-observer.el ends here
