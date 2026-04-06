;;; runtime-observer.el --- Runtime event bus  -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. :priority — integer; lower fires first (default 50).
;;;   2. :once     — subscription auto-removes after first invocation.
;;;   3. :filter   — predicate fn called with payload; handler skipped unless t.
;;;   4. Subscription is a cl-defstruct for introspection / healthcheck.
;;;   5. my/observer-subscriptions returns the live subscription table.
;;;   6. my/observer-reset is the canonical reset (not clrhash).
;;;
;;; Standard event constants are unchanged from V1.
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ---------------------------------------------------------------------------
;; Subscription struct
;; ---------------------------------------------------------------------------

(cl-defstruct (my/observer-sub
               (:constructor my/observer-sub--make)
               (:copier nil))
  "A single event subscription."
  (event    nil :read-only t  :documentation "Event keyword this sub is on.")
  (label    nil :read-only t  :documentation "Unique subscriber label (symbol).")
  (handler  nil :read-only t  :documentation "Function called with payload plist.")
  (priority 50  :read-only t  :documentation "Firing order: lower = earlier.")
  (once     nil :read-only t  :documentation "When non-nil, auto-remove after first call.")
  (filter   nil :read-only t  :documentation "Optional predicate fn(payload)→bool."))

;; ---------------------------------------------------------------------------
;; Registry
;; ---------------------------------------------------------------------------

(defvar my/observer--registry (make-hash-table :test #'eq)
  "Map event-keyword → sorted list of `my/observer-sub' structs.")

;; ---------------------------------------------------------------------------
;; Internal helpers
;; ---------------------------------------------------------------------------

(defun my/observer--sort-subs (subs)
  "Return SUBS sorted by :priority ascending."
  (sort (copy-sequence subs)
        (lambda (a b) (< (my/observer-sub-priority a)
                         (my/observer-sub-priority b)))))

(defun my/observer--remove-sub (event label)
  "Remove subscription with LABEL from EVENT (mutates registry)."
  (puthash event
           (cl-remove-if (lambda (s) (eq (my/observer-sub-label s) label))
                         (gethash event my/observer--registry))
           my/observer--registry))

;; ---------------------------------------------------------------------------
;; Public API
;; ---------------------------------------------------------------------------

(cl-defun my/observer-subscribe (event label handler
                                        &key (priority 50) once filter)
  "Subscribe HANDLER to EVENT under LABEL.

  Keyword args:
    :priority INTEGER   — firing order, lower first (default 50).
    :once     BOOL      — auto-remove after first successful invocation.
    :filter   FN        — called with payload; handler runs only when non-nil.

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
  "Emit EVENT with PAYLOAD to all subscribers in priority order.

  Errors in handlers are caught and logged – a bad observer must not
  break the runtime.  :once subscriptions are removed after firing."
  (let ((subs  (gethash event my/observer--registry))
        remove-these)
    (dolist (sub subs)
      (condition-case err
          (when (or (null (my/observer-sub-filter sub))
                    (funcall (my/observer-sub-filter sub) payload))
            (funcall (my/observer-sub-handler sub) payload)
            (when (my/observer-sub-once sub)
              (push (my/observer-sub-label sub) remove-these)))
        (error
         (my/log-error "observer"
                       "handler error event=%s label=%s -> %S"
                       event (my/observer-sub-label sub) err))))
    (dolist (lbl remove-these)
      (my/observer--remove-sub event lbl))))

(defun my/observer-emit-deferred (event &optional payload seconds)
  "Emit EVENT with PAYLOAD after SECONDS idle time (default 0)."
  (run-with-idle-timer
   (or seconds 0) nil
   (lambda () (my/observer-emit event payload))))

(defun my/observer-subscriptions (&optional event)
  "Return all subscriptions, or those for EVENT when given."
  (if event
      (gethash event my/observer--registry)
    (let (all)
      (maphash (lambda (_k subs) (setq all (append all subs)))
               my/observer--registry)
      all)))

;; ---------------------------------------------------------------------------
;; Standard event keywords (unchanged from V1)
;; ---------------------------------------------------------------------------

(defconst my/event-stage-start     :stage/start
  "Emitted when a stage begins.
  Payload: (:stage SYMBOL :time FLOAT).")

(defconst my/event-stage-end       :stage/end
  "Emitted when a stage finishes.
  Payload: (:stage SYMBOL :status SYMBOL :time FLOAT).")

(defconst my/event-module-run      :module/run
  "Emitted after a module record is stored.
  Payload: `my/module-record' struct.")

(defconst my/event-module-deferred :module/deferred
  "Emitted when a module is scheduled for deferred init.
  Payload: `my/deferred-job' struct.")

(defconst my/event-init-complete   :init/complete
  "Emitted when the full startup pipeline finishes.
  Payload: (:elapsed FLOAT :gc-count INT).")

;; ---------------------------------------------------------------------------
;; Reset / Init
;; ---------------------------------------------------------------------------

(defun my/observer-reset ()
  "Clear all event subscriptions.  Prefer this over clrhash."
  (clrhash my/observer--registry))

(defun my/runtime-observer-init ()
  "Initialise observer bus."
  (my/observer-reset)
  (my/log-info "observer" "event bus initialised"))

(provide 'runtime-observer)
;;; runtime-observer.el ends here
