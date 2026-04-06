;;; runtime-module-state.el --- Module execution state -*- lexical-binding: t; -*-
;;; Commentary:
;;;  1. :supersedes is now meaningful:
;;;       - First record for a name: stored normally.
;;;       - Subsequent records (deferred → final): new record is created with
;;;         :supersedes = previous record; both are visible in the append-log.
;;;     This makes the deferred→ok / deferred→failed transition auditable.
;;;  2. my/runtime-module-record accepts an optional :supersedes override;
;;;     callers may also let this module derive it automatically.
;;;  3. «Degraded» stage detection is unchanged in semantics.
;;;  4. Deferred jobs tracked here for reporting only; lifecycle state lives
;;;     in runtime-lifecycle.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-observer)

;; ─────────────────────────────────────────────────────────────────────────────
;; Private state
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/module--table (make-hash-table :test #'eq)
  "Map module-name → latest `my/module-record' (for dependency decisions).")

(defvar my/module--log nil
  "Append-only list of `my/module-record' (newest first).
  When a module transitions from deferred to final the new record has
  :supersedes pointing at the previous record.")

(defvar my/module--deferred-jobs nil
  "List of `my/deferred-job' in scheduling order.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Reset
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-module-state-reset ()
  "Clear all module execution state."
  (clrhash my/module--table)
  (setq my/module--log       nil
        my/module--deferred-jobs nil))

;; ─────────────────────────────────────────────────────────────────────────────
;; Record API
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-module-record (record)
  "Store RECORD in state tables.

  If a record for the same name already exists:
    - The new record's :supersedes is set to the previous record (when
      the caller did not already set it).
    - Both old and new appear in the append-log.
    - The latest-table entry is overwritten (latest-wins for dependency
      resolution)."
  (cl-assert (my/module-record-p record) t
             "my/runtime-module-record: expected my/module-record struct")
  (let* ((name     (my/module-record-name record))
         (existing (gethash name my/module--table))
         ;; Build final record: attach :supersedes when caller omitted it
         (final    (if (and existing
                            (null (my/module-record-supersedes record)))
                       (my/make-module-record
                        :name        name
                        :status      (my/module-record-status     record)
                        :reason      (my/module-record-reason     record)
                        :after       (my/module-record-after      record)
                        :defer       (my/module-record-defer      record)
                        :started-at  (my/module-record-started-at record)
                        :ended-at    (my/module-record-ended-at   record)
                        :supersedes  existing)
                     record)))
    (puthash name final my/module--table)
    (push final my/module--log)
    (my/observer-emit my/event-module-run final)
    final))

(defun my/runtime-module-find-record (name)
  (gethash name my/module--table))

(defun my/runtime-module-status (name)
  (let ((r (my/runtime-module-find-record name)))
    (and r (my/module-record-status r))))

(defun my/runtime-module-log ()
  "Return ordered list of records (newest first)."
  (copy-sequence my/module--log))

(defun my/runtime-module-history (name)
  "Return chronological list of all records for NAME (oldest first).
  Traverses :supersedes chain from the latest record."
  (let ((latest (my/runtime-module-find-record name))
        chain)
    (let ((rec latest))
      (while rec
        (push rec chain)
        (setq rec (my/module-record-supersedes rec))))
    chain))                     ; already oldest-first after push+nreverse

;; ─────────────────────────────────────────────────────────────────────────────
;; Dependency satisfaction
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-module-satisfied-p (name)
  (memq (my/runtime-module-status name) my/module-satisfied-statuses))

(defun my/runtime-module-deps-satisfied-p (deps)
  (let ((dep-list (cond ((null deps)  nil)
                        ((listp deps) deps)
                        (t            (list deps)))))
    (cl-every #'my/runtime-module-satisfied-p dep-list)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Deferred job API
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-module-register-deferred-job (job)
  (cl-assert (my/deferred-job-p job) t
             "my/runtime-module-register-deferred-job: expected my/deferred-job")
  (push job my/module--deferred-jobs)
  (my/observer-emit my/event-module-deferred job)
  job)

(defun my/runtime-module-deferred-jobs ()
  (reverse my/module--deferred-jobs))

;; ─────────────────────────────────────────────────────────────────────────────
;; Summary and reporting
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-module-summary ()
  (let ((ok 0) (skipped 0) (failed 0) (deferred 0) (cancelled 0))
    (maphash (lambda (_name rec)
               (pcase (my/module-record-status rec)
                 ('ok        (cl-incf ok))
                 ('skipped   (cl-incf skipped))
                 ('failed    (cl-incf failed))
                 ('deferred  (cl-incf deferred))
                 ('cancelled (cl-incf cancelled))))
             my/module--table)
    (list :ok ok :skipped skipped :failed failed
          :deferred deferred :cancelled cancelled
          :total (+ ok skipped failed deferred cancelled))))

(defun my/runtime-module-report ()
  (let ((s (my/runtime-module-summary)))
    (my/log-info "modules"
                 "total=%d ok=%d skipped=%d deferred=%d cancelled=%d failed=%d"
                 (plist-get s :total)
                 (plist-get s :ok)
                 (plist-get s :skipped)
                 (plist-get s :deferred)
                 (plist-get s :cancelled)
                 (plist-get s :failed))
    (maphash (lambda (name rec)
               (when (eq (my/module-record-status rec) my/module-status-failed)
                 (my/log-error "modules" "FAILED: %s reason=%S"
                               name (my/module-record-reason rec))))
             my/module--table)))

(defun my/runtime-module-deferred-report ()
  (let ((jobs (my/runtime-module-deferred-jobs)))
    (when jobs
      (my/log-info "modules" "deferred: %d scheduled" (length jobs))
      (dolist (job jobs)
        (my/log-debug "modules" "  deferred %s strategy=%S"
                      (my/deferred-job-name job)
                      (my/deferred-job-strategy job))))))

(provide 'runtime-module-state)
;;; runtime-module-state.el ends here
