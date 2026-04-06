;;; runtime-lifecycle.el --- Unified module lifecycle FSM -*- lexical-binding: t; -*-
;;; Commentary:
;;;
;;;  This module is the single authoritative record of every
;;;  module's lifecycle state.  It replaces the implicit dual-system that
;;;  existed between runtime-module-state (business state) and
;;;  runtime-deferred (scheduler state).
;;;
;;;  Design
;;;  ──────
;;;  1. Transitions are validated: only forward moves are legal.
;;;     Illegal transitions log a warning and are ignored.
;;;  2. Every transition emits a structured observer event.
;;;  3. The «deferred completion» path is wired here:
;;;     runtime-deferred fires my/event-deferred-complete; this module
;;;     subscribes to that event and transitions the module to ok/failed,
;;;     then emits my/event-module-lifecycle.  No callback argument threading.
;;;  4. Callers never touch the hash table directly — all mutations go
;;;     through my/lifecycle-transition.
;;;
;;;  Legal FSM edges
;;;  ───────────────
;;;    planned   → loading | skipped
;;;    loading   → loaded  | failed
;;;    loaded    → running | deferred | skipped
;;;    deferred  → running | cancelled
;;;    running   → ok      | failed
;;;    (ok | failed | skipped | cancelled) = terminal
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-observer)

;; ─────────────────────────────────────────────────────────────────────────────
;; Event constants
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/event-module-lifecycle :module/lifecycle
  "Emitted on every module state transition.
  Payload: `my/module-record' struct (new state).")

(defconst my/event-deferred-complete :deferred/complete
  "Emitted by runtime-deferred when a deferred init thunk finishes.
  Payload: (:name SYMBOL :ok BOOL :t0 FLOAT :t1 FLOAT).")

;; ─────────────────────────────────────────────────────────────────────────────
;; FSM graph  (from-status → list-of-legal-to-statuses)
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/lifecycle--edges
  '((planned   . (loading  skipped))
    (loading   . (loaded   failed))
    (loaded    . (running  deferred  skipped))
    (deferred  . (running  cancelled))
    (running   . (ok       failed)))
  "Legal FSM transitions.  Terminals have no outgoing edges.")

(defun my/lifecycle--transition-ok-p (from to)
  "Return non-nil when FROM → TO is a legal FSM edge.
  nil → planned is always legal (initial transition)."
  (if (null from)
      (eq to my/module-status-planned)
    (memq to (cdr (assq from my/lifecycle--edges)))))

;; ─────────────────────────────────────────────────────────────────────────────
;; State table  (private)
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/lifecycle--table (make-hash-table :test #'eq)
  "Map module-name-symbol → latest `my/module-record'.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Public API
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/lifecycle-current (name)
  "Return latest `my/module-record' for NAME, or nil."
  (gethash name my/lifecycle--table))

(defun my/lifecycle-status (name)
  "Return current status symbol for NAME, or nil."
  (let ((r (my/lifecycle-current name)))
    (and r (my/module-record-status r))))

(defun my/lifecycle-transition (name new-status &rest args)
  "Advance module NAME to NEW-STATUS with optional ARGS plist.

  ARGS may contain :reason :after :defer :started-at :ended-at.

  Returns the new `my/module-record' on success, nil on illegal transition.
  Illegal transitions are logged at warn level and ignored."
  (let* ((prev   (my/lifecycle-current name))
         (from   (and prev (my/module-record-status prev))))
    (unless (my/lifecycle--transition-ok-p from new-status)
      (my/log-warn "lifecycle"
                   "illegal transition %s: %S → %S (ignored)"
                   name from new-status)
      (cl-return-from my/lifecycle-transition nil))
    (let ((rec (apply #'my/make-module-record
                      :name       name
                      :status     new-status
                      :supersedes prev
                      args)))
      (puthash name rec my/lifecycle--table)
      (my/observer-emit my/event-module-lifecycle rec)
      rec)))

(defun my/lifecycle-reset ()
  "Clear all lifecycle state.  Call between pipeline runs."
  (clrhash my/lifecycle--table))

(defun my/lifecycle-snapshot ()
  "Return alist of (name . my/module-record) for all known modules."
  (let (pairs)
    (maphash (lambda (k v) (push (cons k v) pairs))
             my/lifecycle--table)
    (sort pairs (lambda (a b) (string< (symbol-name (car a))
                                       (symbol-name (car b)))))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Deferred completion wiring
;; ─────────────────────────────────────────────────────────────────────────────
;; runtime-deferred emits :deferred/complete when a thunk fires.
;; We subscribe here so the completion loop is closed without any
;; callback argument threading between the two modules.

(defun my/lifecycle--on-deferred-complete (payload)
  "Handle :deferred/complete event; transition module to ok or failed."
  (let* ((name (plist-get payload :name))
         (ok   (plist-get payload :ok))
         (t0   (plist-get payload :t0))
         (t1   (plist-get payload :t1)))
    (my/lifecycle-transition
     name
     (if ok my/module-status-running my/module-status-running)
     :started-at t0)
    (my/lifecycle-transition
     name
     (if ok my/module-status-ok my/module-status-failed)
     :reason     (unless ok my/reason-init-failed)
     :started-at t0
     :ended-at   t1)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Init
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-lifecycle-init ()
  "Initialise lifecycle subsystem and wire deferred-complete subscription."
  (my/lifecycle-reset)
  (my/observer-subscribe
   my/event-deferred-complete
   'my/lifecycle--deferred-complete-handler
   #'my/lifecycle--on-deferred-complete
   :priority 10)
  (my/log-info "lifecycle" "module lifecycle FSM ready"))

(provide 'runtime-lifecycle)
;;; runtime-lifecycle.el ends here
