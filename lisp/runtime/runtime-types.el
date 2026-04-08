;;; runtime-types.el --- Canonical runtime type contracts -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - DeferredJob gains :trigger and :trigger-data fields (aligns with
;;;       payload enrichment in runtime-deferred).
;;;     - my/module-record :supersedes chain helper: my/module-record-chain.
;;;     - This file is the shared type contract and must not import from higher layers.
;;;
;;;  Module status (ordered lifecycle):
;;;    planned → loading → loaded → deferred → running → ok / failed / skipped / cancelled
;;;
;;; Code:

(require 'cl-lib)

;; ─────────────────────────────────────────────────────────────────────────────
;; Module status — single authoritative enumeration
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/module-status-planned   'planned
  "Module in manifest but not yet evaluated by runner.")
(defconst my/module-status-loading   'loading
  "Runner issued (require …); load in progress.")
(defconst my/module-status-loaded    'loaded
  "Feature file loaded; init not yet called.")
(defconst my/module-status-deferred  'deferred
  "Init scheduled; will run later.")
(defconst my/module-status-running   'running
  "Init function currently executing.")
(defconst my/module-status-ok        'ok
  "Init completed successfully.")
(defconst my/module-status-failed    'failed
  "Init (or load) raised an error.")
(defconst my/module-status-skipped   'skipped
  "Skipped by feature/when/dependency gate.")
(defconst my/module-status-cancelled 'cancelled
  "A previously deferred init was cancelled.")

(defconst my/module-statuses
  (list my/module-status-planned
        my/module-status-loading
        my/module-status-loaded
        my/module-status-deferred
        my/module-status-running
        my/module-status-ok
        my/module-status-failed
        my/module-status-skipped
        my/module-status-cancelled)
  "All legal module status symbols (ordered by lifecycle).")

;; Statuses that count as «satisfied» for :after dependency resolution.
;; Deferred counts: the feature file is loaded and init will run.
(defconst my/module-satisfied-statuses
  (list my/module-status-ok my/module-status-deferred)
  "Module statuses that satisfy an :after dependency.")

(defconst my/module-terminal-statuses
  (list my/module-status-ok
        my/module-status-failed
        my/module-status-skipped
        my/module-status-cancelled)
  "Terminal statuses — no further transitions possible.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Stage status
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/stage-status-pending   'pending)
(defconst my/stage-status-running   'running)
(defconst my/stage-status-ok        'ok)
(defconst my/stage-status-degraded  'degraded)
(defconst my/stage-status-failed    'failed)
(defconst my/stage-status-skipped   'skipped)

(defconst my/stage-done-statuses
  (list my/stage-status-ok my/stage-status-degraded)
  "Stage statuses considered done for dependency resolution.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Skip / fail reason keywords
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/reason-feature-disabled  :feature-disabled)
(defconst my/reason-predicate-failed  :predicate-failed)
(defconst my/reason-dependency-failed :dependency-failed)
(defconst my/reason-require-failed    :require-failed)
(defconst my/reason-init-failed       :init-failed)
(defconst my/reason-already-done      :already-done)
(defconst my/reason-idempotent-skip   :idempotent-skip)
(defconst my/reason-cancelled         :cancelled)

;; ─────────────────────────────────────────────────────────────────────────────
;; Struct: ModuleRecord  (adds :supersedes)
;; ─────────────────────────────────────────────────────────────────────────────

(cl-defstruct (my/module-record
               (:constructor my/module-record--make)
               (:copier nil))
  "Immutable execution record for a single manifest module.

  When a deferred module transitions to its final state a new record
  is created with :supersedes pointing at the previous record.  The
  append-log therefore retains the full transition history."
  (name        nil :read-only t :documentation "Module name symbol.")
  (status      nil :read-only t :documentation "One of `my/module-statuses'.")
  (reason      nil :read-only t :documentation "Reason keyword or nil.")
  (after       nil :read-only t :documentation ":after dependency list.")
  (defer       nil :read-only t :documentation "Defer strategy spec or nil.")
  (started-at  nil :read-only t :documentation "float-time when init started, or nil.")
  (ended-at    nil :read-only t :documentation "float-time when init ended, or nil.")
  (supersedes  nil :read-only t :documentation "Previous my/module-record this replaces, or nil."))

(defun my/make-module-record (&rest args)
  "Create a `my/module-record' from keyword ARGS.

  Required: :name :status
  Optional: :reason :after :defer :started-at :ended-at :supersedes

  Signals `error' on missing required keys or unknown :status."
  (let ((name   (or (plist-get args :name)
                    (error "my/make-module-record: :name required")))
        (status (or (plist-get args :status)
                    (error "my/make-module-record: :status required"))))
    (unless (memq status my/module-statuses)
      (error "my/make-module-record: unknown status %S" status))
    (my/module-record--make
     :name       name
     :status     status
     :reason     (plist-get args :reason)
     :after      (plist-get args :after)
     :defer      (plist-get args :defer)
     :started-at (plist-get args :started-at)
     :ended-at   (plist-get args :ended-at)
     :supersedes (plist-get args :supersedes))))

(defun my/module-record-chain (record)
  "Return chronological list of all records in the :supersedes chain.
  Oldest record first, RECORD last.  Useful for full audit traversal."
  (let (chain (r record))
    (while r
      (push r chain)
      (setq r (my/module-record-supersedes r)))
    chain))  ; push+no-reverse = oldest first

;; ─────────────────────────────────────────────────────────────────────────────
;; Struct: StageRecord
;; ─────────────────────────────────────────────────────────────────────────────

(cl-defstruct (my/stage-record
               (:constructor my/stage-record--make)
               (:copier nil))
  "Execution record for a startup stage."
  (name       nil :read-only t)
  (status     nil :read-only t)
  (started-at nil :read-only t)
  (ended-at   nil :read-only t)
  (detail     nil :read-only t :documentation "Error object or results list."))

(defun my/make-stage-record (&rest args)
  "Create a `my/stage-record'.  Required: :name :status."
  (my/stage-record--make
   :name       (or (plist-get args :name)
                   (error "my/make-stage-record: :name required"))
   :status     (or (plist-get args :status)
                   (error "my/make-stage-record: :status required"))
   :started-at (plist-get args :started-at)
   :ended-at   (plist-get args :ended-at)
   :detail     (plist-get args :detail)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Struct: DeferredJob  (adds :fired-at :trigger :trigger-data)
;; ─────────────────────────────────────────────────────────────────────────────

(cl-defstruct (my/deferred-job
               (:constructor my/deferred-job--make)
               (:copier nil))
  "Scheduler record for a deferred-init job."
  (name         nil :read-only t)
  (strategy     nil :read-only t)
  (scheduled-at nil :read-only t)
  (trigger      nil :read-only t
                :documentation "Trigger kind: after-init|hook|idle|timer|feature|command")
  (trigger-data nil :read-only t
                :documentation "Hook name / secs / feature sym / command sym")
  (fired-at     nil
                :documentation "float-time when the thunk actually ran."))

(defun my/make-deferred-job (name strategy &optional trigger trigger-data)
  "Create a my/deferred-job for NAME with STRATEGY."
  (my/deferred-job--make
   :name         (or name (error "my/make-deferred-job: name required"))
   :strategy     strategy
   :scheduled-at (float-time)
   :trigger      trigger
   :trigger-data trigger-data))

(provide 'runtime-types)
;;; runtime-types.el ends here
