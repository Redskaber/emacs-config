;;; runtime-observer.el --- Runtime event bus -*- lexical-binding: t; -*-
;;; Commentary:
;;; A minimal publish/subscribe bus that decouples the ops layer from
;;; the runtime core.  The runtime emits events; observers (healthcheck,
;;; profiler, benchmark, sandbox) subscribe without being imported by core.
;;;
;;; Design constraints:
;;; - Zero dependencies except kernel-logging.
;;; - No circular requires: runtime/* may require this; manifest/* and ops/*
;;;   may also require this to subscribe.
;;; - Synchronous by default; deferred emission supported via :defer t.
;;; Code:

(require 'kernel-logging)

;; ---------------------------------------------------------------------------
;; Registry
;; ---------------------------------------------------------------------------

(defvar my/observer-registry (make-hash-table :test #'eq)
  "Event → list of (label . handler-fn) pairs.")

;; ---------------------------------------------------------------------------
;; API
;; ---------------------------------------------------------------------------

(defun my/observer-subscribe (event label handler)
  "Subscribe HANDLER to EVENT under LABEL.
HANDLER receives a plist payload.
If a subscription for LABEL already exists on EVENT it is replaced."
  (let* ((subs (gethash event my/observer-registry))
         (existing (assq label subs)))
    (if existing
        (setcdr existing handler)
      (puthash event
               (cons (cons label handler) subs)
               my/observer-registry))))

(defun my/observer-unsubscribe (event label)
  "Remove LABEL subscription from EVENT."
  (puthash event
           (assq-delete-all label (gethash event my/observer-registry))
           my/observer-registry))

(defun my/observer-emit (event &optional payload)
  "Emit EVENT with PAYLOAD plist to all subscribers.
Errors in handlers are caught and logged – a bad observer must not
break the runtime."
  (dolist (sub (gethash event my/observer-registry))
    (condition-case err
        (funcall (cdr sub) payload)
      (error
       (my/log "[observer] handler error event=%s label=%s -> %S"
               event (car sub) err)))))

(defun my/observer-emit-deferred (event &optional payload seconds)
  "Emit EVENT with PAYLOAD after SECONDS idle time (default 0)."
  (run-with-idle-timer
   (or seconds 0) nil
   (lambda () (my/observer-emit event payload))))

;; ---------------------------------------------------------------------------
;; Standard event keywords
;; (document here so ops layer can discover them without reading runtime code)
;; ---------------------------------------------------------------------------

(defconst my/event-stage-start     :stage/start
  "Emitted when a stage begins.  Payload: (:stage NAME :time TIME).")

(defconst my/event-stage-end       :stage/end
  "Emitted when a stage finishes.  Payload: (:stage NAME :status STATUS :time TIME).")

(defconst my/event-module-run      :module/run
  "Emitted after a module is executed.  Payload: full module record plist.")

(defconst my/event-module-deferred :module/deferred
  "Emitted when a module is scheduled for deferred init.
Payload: (:name NAME :strategy STRATEGY).")

(defconst my/event-init-complete   :init/complete
  "Emitted when the full startup pipeline finishes.
Payload: (:elapsed FLOAT :gc-count INT).")

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(defun my/runtime-observer-init ()
  "Initialise observer bus (clears all subscriptions)."
  (clrhash my/observer-registry)
  (my/log "[observer] event bus initialised"))

(provide 'runtime-observer)
;;; runtime-observer.el ends here
