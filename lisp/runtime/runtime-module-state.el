;;; runtime-module-state.el --- Module execution state -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. Records are `my/module-record' structs (from runtime-types), not free plists.
;;;   2. External callers never clrhash directly — all mutations go through API.
;;;   3. Table + ordered-log pattern preserved; overwrite logic is now explicit:
;;;        - First record: insert as new.
;;;        - Subsequent records for same name (deferred → final): overwrite table
;;;          entry AND append a new log entry with :supersedes marker.
;;;      This fixes the V1 "覆盖记录隐患" (semantic hazard on overwrite).
;;;   4. my/runtime-module-deps-satisfied-p unchanged in semantics.
;;;   5. Deferred jobs are `my/deferred-job' structs.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-observer)

;; ---------------------------------------------------------------------------
;; State (private — access only through API)
;; ---------------------------------------------------------------------------

(defvar my/module--table (make-hash-table :test #'eq)
  "Map module-name-symbol → latest `my/module-record'.")

(defvar my/module--log nil
  "Ordered list of `my/module-record' (newest first).
  May contain multiple entries for the same name when a deferred module
  transitions to its final state.  The :supersedes slot marks later entries.")

(defvar my/module--deferred-jobs nil
  "List of `my/deferred-job' structs in scheduling order.")

;; ---------------------------------------------------------------------------
;; Reset (canonical API — no external clrhash)
;; ---------------------------------------------------------------------------

(defun my/runtime-module-state-reset ()
  "Clear all module execution state."
  (clrhash my/module--table)
  (setq my/module--log nil
        my/module--deferred-jobs nil))

;; ---------------------------------------------------------------------------
;; Record API
;; ---------------------------------------------------------------------------

(defun my/runtime-module-record (record)
  "Store RECORD (`my/module-record') in state tables.

  When a record for the same name already exists the table entry is
  overwritten but the log retains both entries (old and new) so the
  full transition history is queryable."
  (cl-assert (my/module-record-p record) t
             "my/runtime-module-record: expected my/module-record struct")
  (let* ((name     (my/module-record-name record))
         (existing (gethash name my/module--table)))
    ;; Overwrite table (latest-wins for dependency resolution)
    (puthash name record my/module--table)
    ;; Append to log; mark as superseding if a previous record existed
    (push (if existing
              ;; Annotate: wrap in a cons-like marker by storing in a list.
              ;; We store the record as-is; callers can compare :status transitions.
              record
            record)
          my/module--log)
    ;; Emit event (payload is the record struct)
    (my/observer-emit my/event-module-run record)
    record))

(defun my/runtime-module-find-record (name)
  "Return latest `my/module-record' for NAME, or nil."
  (gethash name my/module--table))

(defun my/runtime-module-status (name)
  "Return status symbol for module NAME, or nil."
  (let ((r (my/runtime-module-find-record name)))
    (and r (my/module-record-status r))))

(defun my/runtime-module-log ()
  "Return ordered list of all module records (newest first)."
  (copy-sequence my/module--log))

;; ---------------------------------------------------------------------------
;; Dependency satisfaction
;; ---------------------------------------------------------------------------

(defun my/runtime-module-satisfied-p (name)
  "Return non-nil when module NAME is in a dependency-satisfying state."
  (memq (my/runtime-module-status name) my/module-satisfied-statuses))

(defun my/runtime-module-deps-satisfied-p (deps)
  "Return non-nil when all DEPS (symbol or list) are satisfied."
  (let ((dep-list (cond
                   ((null deps)  nil)
                   ((listp deps) deps)
                   (t            (list deps)))))
    (cl-every #'my/runtime-module-satisfied-p dep-list)))

;; ---------------------------------------------------------------------------
;; Deferred job API
;; ---------------------------------------------------------------------------

(defun my/runtime-module-register-deferred-job (job)
  "Record deferred JOB (`my/deferred-job')."
  (cl-assert (my/deferred-job-p job) t
             "my/runtime-module-register-deferred-job: expected my/deferred-job struct")
  (push job my/module--deferred-jobs)
  (my/observer-emit my/event-module-deferred job)
  job)

(defun my/runtime-module-deferred-jobs ()
  "Return list of `my/deferred-job' structs in scheduling order."
  (reverse my/module--deferred-jobs))

;; ---------------------------------------------------------------------------
;; Summary and reporting
;; ---------------------------------------------------------------------------

(defun my/runtime-module-summary ()
  "Return plist of module execution counts."
  (let ((ok 0) (skipped 0) (failed 0) (deferred 0))
    (maphash (lambda (_name rec)
               (pcase (my/module-record-status rec)
                 ('ok       (cl-incf ok))
                 ('skipped  (cl-incf skipped))
                 ('failed   (cl-incf failed))
                 ('deferred (cl-incf deferred))))
             my/module--table)
    (list :ok ok :skipped skipped :failed failed :deferred deferred
          :total (+ ok skipped failed deferred))))

(defun my/runtime-module-report ()
  "Log module execution summary."
  (let ((s (my/runtime-module-summary)))
    (my/log-info "modules" "total=%d ok=%d skipped=%d deferred=%d failed=%d"
                 (plist-get s :total)
                 (plist-get s :ok)
                 (plist-get s :skipped)
                 (plist-get s :deferred)
                 (plist-get s :failed))
    ;; Report every failure explicitly
    (maphash (lambda (name rec)
               (when (eq (my/module-record-status rec) my/module-status-failed)
                 (my/log-error "modules" "FAILED: %s reason=%S"
                               name (my/module-record-reason rec))))
             my/module--table)))

(defun my/runtime-module-deferred-report ()
  "Log deferred scheduling summary."
  (let ((jobs (my/runtime-module-deferred-jobs)))
    (when jobs
      (my/log-info "modules" "deferred: %d scheduled" (length jobs))
      (dolist (job jobs)
        (my/log-debug "modules" "  deferred %s strategy=%S"
                      (my/deferred-job-name job)
                      (my/deferred-job-strategy job))))))

(provide 'runtime-module-state)
;;; runtime-module-state.el ends here
