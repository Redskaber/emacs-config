;;; runtime-types.el --- Canonical runtime type contracts  -*- lexical-binding: t; -*-
;;; Commentary:
;;;
;;;   1. Status symbols promoted to defconst groups with doc strings.
;;;   2. cl-defstruct for ModuleRecord / StageRecord / DeferredJob.
;;;      - Struct slots are typed and documented; no more free-form plists as records.
;;;      - Accessor names are explicit and grep-able.
;;;   3. Reason constants renamed for clarity (no collision with status names).
;;;   4. Constructor helpers validate required fields at creation time.
;;;
;;; Public API
;;; ----------
;;;   Constructors : my/make-module-record  my/make-stage-record  my/make-deferred-job
;;;   Predicates   : my/module-record-p     my/stage-record-p     my/deferred-job-p
;;;   Accessors    : my/module-record-{name,status,reason,after,defer,started-at,ended-at}
;;;                  my/stage-record-{name,status,started-at,ended-at,detail}
;;;                  my/deferred-job-{name,strategy,scheduled-at}
;;;
;;; Code:

(require 'cl-lib)

;; ---------------------------------------------------------------------------
;; Module status
;; ---------------------------------------------------------------------------

(defconst my/module-status-pending   'pending
  "Module registered but not yet evaluated.")
(defconst my/module-status-ok        'ok
  "Module initialised successfully.")
(defconst my/module-status-deferred  'deferred
  "Module scheduled for deferred initialisation.")
(defconst my/module-status-failed    'failed
  "Module initialisation failed.")
(defconst my/module-status-skipped   'skipped
  "Module was skipped (feature / predicate / dependency gate).")

(defconst my/module-statuses
  (list my/module-status-pending
        my/module-status-ok
        my/module-status-deferred
        my/module-status-failed
        my/module-status-skipped)
  "All legal module status symbols.")

;; Statuses that satisfy an :after dependency
(defconst my/module-satisfied-statuses
  (list my/module-status-ok my/module-status-deferred)
  "Module statuses that count as satisfied for dependency resolution.")

;; ---------------------------------------------------------------------------
;; Stage status
;; ---------------------------------------------------------------------------

(defconst my/stage-status-pending   'pending   "Stage not yet started.")
(defconst my/stage-status-running   'running   "Stage currently executing.")
(defconst my/stage-status-ok        'ok        "Stage completed; no module failures.")
(defconst my/stage-status-degraded  'degraded  "Stage completed; some modules failed.")
(defconst my/stage-status-failed    'failed    "Stage could not complete.")
(defconst my/stage-status-skipped   'skipped   "Stage skipped by gate or dependency.")

(defconst my/stage-done-statuses
  (list my/stage-status-ok my/stage-status-degraded)
  "Stage statuses that count as done for downstream dependency resolution.")

;; ---------------------------------------------------------------------------
;; Skip / fail reason keywords
;; ---------------------------------------------------------------------------

(defconst my/reason-feature-disabled  :feature-disabled
  "Module/stage skipped: feature flag was nil.")
(defconst my/reason-predicate-failed  :predicate-failed
  "Module skipped: :predicate evaluated nil.")
(defconst my/reason-dependency-failed :dependency-failed
  "Module/stage skipped: :after dependency not satisfied.")
(defconst my/reason-require-failed    :require-failed
  "Module failed: (require :require) signalled an error.")
(defconst my/reason-init-failed       :init-failed
  "Module failed: :init function signalled an error.")
(defconst my/reason-already-done      :already-done
  "Stage skipped: it already ran in this session.")
(defconst my/reason-idempotent-skip   :idempotent-skip
  "Module skipped: a record already exists (idempotency guard).")

;; ---------------------------------------------------------------------------
;; Struct: ModuleRecord
;; ---------------------------------------------------------------------------

(cl-defstruct (my/module-record
               (:constructor my/module-record--make)
               (:copier nil))
  "Immutable execution record for a single manifest module."
  (name        nil :read-only t :documentation "Module name symbol.")
  (status      nil :read-only t :documentation "One of `my/module-statuses'.")
  (reason      nil :read-only t :documentation "Reason keyword or nil.")
  (after       nil :read-only t :documentation ":after dependency list.")
  (defer       nil :read-only t :documentation "Defer strategy spec or nil.")
  (started-at  nil :read-only t :documentation "float-time when init started.")
  (ended-at    nil :read-only t :documentation "float-time when init ended."))

(defun my/make-module-record (&rest args)
  "Create a `my/module-record' from keyword ARGS.

Required: :name :status
Optional: :reason :after :defer :started-at :ended-at

Signals an error when required keys are missing or status is unknown."
  (let ((name   (or (plist-get args :name)
                    (error "my/make-module-record: :name is required")))
        (status (or (plist-get args :status)
                    (error "my/make-module-record: :status is required"))))
    (unless (memq status my/module-statuses)
      (error "my/make-module-record: unknown status %S" status))
    (my/module-record--make
     :name       name
     :status     status
     :reason     (plist-get args :reason)
     :after      (plist-get args :after)
     :defer      (plist-get args :defer)
     :started-at (plist-get args :started-at)
     :ended-at   (plist-get args :ended-at))))

;; ---------------------------------------------------------------------------
;; Struct: StageRecord
;; ---------------------------------------------------------------------------

(cl-defstruct (my/stage-record
               (:constructor my/stage-record--make)
               (:copier nil))
  "Execution record for a startup stage."
  (name       nil :read-only t :documentation "Stage name symbol.")
  (status     nil :read-only t :documentation "One of stage status constants.")
  (started-at nil :read-only t :documentation "float-time when stage started.")
  (ended-at   nil :read-only t :documentation "float-time when stage ended.")
  (detail     nil :read-only t :documentation "Extra context (error, results list …)."))

(defun my/make-stage-record (&rest args)
  "Create a `my/stage-record' from keyword ARGS.

  Required: :name :status
  Optional: :started-at :ended-at :detail"
  (my/stage-record--make
   :name       (or (plist-get args :name)
                   (error "my/make-stage-record: :name is required"))
   :status     (or (plist-get args :status)
                   (error "my/make-stage-record: :status is required"))
   :started-at (plist-get args :started-at)
   :ended-at   (plist-get args :ended-at)
   :detail     (plist-get args :detail)))

;; ---------------------------------------------------------------------------
;; Struct: DeferredJob
;; ---------------------------------------------------------------------------

(cl-defstruct (my/deferred-job
               (:constructor my/deferred-job--make)
               (:copier nil))
  "Record of a scheduled deferred-init job."
  (name         nil :read-only t :documentation "Module name symbol.")
  (strategy     nil :read-only t :documentation "Defer strategy plist.")
  (scheduled-at nil :read-only t :documentation "float-time when scheduled."))

(defun my/make-deferred-job (name strategy)
  "Create a `my/deferred-job' for NAME with STRATEGY."
  (my/deferred-job--make
   :name         (or name (error "my/make-deferred-job: name required"))
   :strategy     strategy
   :scheduled-at (float-time)))

;; ---------------------------------------------------------------------------
;; Init (no-op: constants and structs are defined at load time)
;; ---------------------------------------------------------------------------

(defun my/runtime-types-init ()
  "No-op; types are constants/structs loaded at require time."
  t)

(provide 'runtime-types)
;;; runtime-types.el ends here
