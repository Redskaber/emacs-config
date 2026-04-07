;;; runtime-lifecycle.el --- Unified module lifecycle FSM -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - Standard runtime domain event protocol:
;;;         :runtime/module-registered, :runtime/module-skipped,
;;;         :runtime/module-started, :runtime/module-finished,
;;;         :runtime/module-failed, :runtime/module-deferred,
;;;         :runtime/deferred-complete, :runtime/stage-entered,
;;;         :runtime/stage-finished
;;;     - lifecycle is the SSOT; deferred only holds scheduler handles.
;;;     - Deferred payload v2: :status ok|failed|cancelled, :trigger, :trigger-data
;;;
;;;  FSM edges
;;;  ─────────
;;;    planned   → loading | skipped
;;;    loading   → loaded  | failed
;;;    loaded    → running | deferred | skipped
;;;    deferred  → running | cancelled
;;;    running   → ok      | failed
;;;    terminals: ok | failed | skipped | cancelled
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-observer)

;; ─────────────────────────────────────────────────────────────────────────────
;; Domain event protocol
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/event-module-lifecycle    :module/lifecycle)
(defconst my/event-deferred-complete   :deferred/complete)

;; Standard runtime domain events
(defconst my/event-runtime-module-registered :runtime/module-registered)
(defconst my/event-runtime-module-skipped    :runtime/module-skipped)
(defconst my/event-runtime-module-started    :runtime/module-started)
(defconst my/event-runtime-module-finished   :runtime/module-finished)
(defconst my/event-runtime-module-failed     :runtime/module-failed)
(defconst my/event-runtime-module-deferred   :runtime/module-deferred)
(defconst my/event-runtime-deferred-complete :runtime/deferred-complete)
(defconst my/event-runtime-stage-entered     :runtime/stage-entered)
(defconst my/event-runtime-stage-finished    :runtime/stage-finished)

;; ─────────────────────────────────────────────────────────────────────────────
;; FSM graph
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/lifecycle--edges
  '((planned   . (loading  skipped))
    (loading   . (loaded   failed))
    (loaded    . (running  deferred  skipped))
    (deferred  . (running  cancelled))
    (running   . (ok       failed))))

(defun my/lifecycle--transition-ok-p (from to)
  (if (null from)
      (eq to my/module-status-planned)
    (memq to (cdr (assq from my/lifecycle--edges)))))

;; ─────────────────────────────────────────────────────────────────────────────
;; State table
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/lifecycle--table (make-hash-table :test #'eq)
  "Map module-name-symbol → latest my/module-record.  This is the SSOT.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Domain event emitters
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/lifecycle--emit-domain-event (status rec)
  "Emit the appropriate domain event for STATUS transition with record REC."
  (let ((name (my/module-record-name rec)))
    (pcase status
      ('planned
       (my/observer-emit my/event-runtime-module-registered
                         (list :name name :record rec)))
      ('skipped
       (my/observer-emit my/event-runtime-module-skipped
                         (list :name name :reason (my/module-record-reason rec) :record rec)))
      ('running
       (my/observer-emit my/event-runtime-module-started
                         (list :name name :started-at (my/module-record-started-at rec) :record rec)))
      ('ok
       (my/observer-emit my/event-runtime-module-finished
                         (list :name name :record rec)))
      ('failed
       (my/observer-emit my/event-runtime-module-failed
                         (list :name name :reason (my/module-record-reason rec) :record rec)))
      ('deferred
       (my/observer-emit my/event-runtime-module-deferred
                         (list :name name :defer (my/module-record-defer rec) :record rec))))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Public API
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/lifecycle-current (name)
  (gethash name my/lifecycle--table))

(defun my/lifecycle-status (name)
  (let ((r (my/lifecycle-current name)))
    (and r (my/module-record-status r))))

(defun my/lifecycle-transition (name new-status &rest args)
  "Advance module NAME to NEW-STATUS with optional ARGS plist.
  Emits :module/lifecycle and the appropriate domain event."
  (let* ((prev (my/lifecycle-current name))
         (from (and prev (my/module-record-status prev))))
    (unless (my/lifecycle--transition-ok-p from new-status)
      (my/log-warn "lifecycle"
                   "illegal transition %s: %S → %S (ignored)" name from new-status)
      (cl-return-from my/lifecycle-transition nil))
    (let ((rec (apply #'my/make-module-record
                      :name       name
                      :status     new-status
                      :supersedes prev
                      args)))
      (puthash name rec my/lifecycle--table)
      ;; Backward compat event
      (my/observer-emit my/event-module-lifecycle rec)
      ;; Domain event protocol
      (my/lifecycle--emit-domain-event new-status rec)
      rec)))

(defun my/lifecycle-reset ()
  (clrhash my/lifecycle--table))

(defun my/lifecycle-snapshot ()
  (let (pairs)
    (maphash (lambda (k v) (push (cons k v) pairs)) my/lifecycle--table)
    (sort pairs (lambda (a b) (string< (symbol-name (car a))
                                       (symbol-name (car b)))))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Deferred completion wiring
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/lifecycle--on-deferred-complete (payload)
  "Handle :deferred/complete event from runtime-deferred.
  Uses enriched payload: :status ok|failed|cancelled."
  (let* ((name   (plist-get payload :name))
         (status (plist-get payload :status))  ; ok | failed | cancelled
         (t0     (plist-get payload :t0))
         (t1     (plist-get payload :t1)))
    (cond
     ((eq status 'cancelled)
      (my/lifecycle-transition name my/module-status-cancelled
                                :reason my/reason-cancelled
                                :started-at t0 :ended-at t1)
      ;; Emit domain event
      (my/observer-emit my/event-runtime-deferred-complete
                        (list :name name :status 'cancelled :t0 t0 :t1 t1)))
     (t
      ;; running → ok/failed
      (my/lifecycle-transition name my/module-status-running :started-at t0)
      (my/lifecycle-transition
       name
       (if (eq status 'ok) my/module-status-ok my/module-status-failed)
       :reason     (unless (eq status 'ok) my/reason-init-failed)
       :started-at t0 :ended-at t1)
      (my/observer-emit my/event-runtime-deferred-complete
                        (list :name name :status status :t0 t0 :t1 t1))))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Init
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-lifecycle-init ()
  "Initialise lifecycle subsystem."
  (my/lifecycle-reset)
  (my/observer-subscribe
   my/event-deferred-complete
   'my/lifecycle--deferred-complete-handler
   #'my/lifecycle--on-deferred-complete
   :priority 10)
  (my/log-info "lifecycle" "module lifecycle FSM ready (domain-event protocol active)"))

(provide 'runtime-lifecycle)
;;; runtime-lifecycle.el ends here
