;;; runtime-module-state.el --- Module execution state  -*- lexical-binding: t; -*-
;;; Commentary:
;;; 1. `my/runtime-module-deps-satisfied-p` now accepts both `ok` AND
;;;    `deferred` as satisfied states.  A deferred module has been
;;;    *registered* (its feature file is loaded, its init is scheduled) –
;;;    downstream modules that only need the feature present can proceed.
;;;    Modules that need the init to have *run* should express that via
;;;    :defer (:after-feature FEAT) instead of :after MODULE.
;;;
;;; 2. Module records are stored in a hash-table keyed by name for O(1)
;;;    lookup, instead of a linear list scan.  The ordered log list is kept
;;;    separately for reporting.
;;;
;;; 3. Record shape gains :started-at / :ended-at timestamps.
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-observer)

;; ---------------------------------------------------------------------------
;; State
;; ---------------------------------------------------------------------------

(defvar my/runtime-module-table (make-hash-table :test #'eq)
  "Map module name → record plist.  Fast lookup by name.")

(defvar my/runtime-module-log nil
  "Ordered list of module records (newest first) for reporting.")

(defvar my/runtime-module-deferred-jobs nil
  "List of deferred scheduling records.")

;; ---------------------------------------------------------------------------
;; Reset
;; ---------------------------------------------------------------------------

(defun my/runtime-module-state-reset ()
  "Clear all module execution state."
  (clrhash my/runtime-module-table)
  (setq my/runtime-module-log nil
        my/runtime-module-deferred-jobs nil))

;; ---------------------------------------------------------------------------
;; Record API
;; ---------------------------------------------------------------------------

(defun my/runtime-module-record (plist)
  "Store module PLIST record.  Returns PLIST.
The :name key is required.  Overwrites any existing record for the name."
  (let ((name (plist-get plist :name)))
    (puthash name plist my/runtime-module-table)
    (push plist my/runtime-module-log)
    ;; Notify observer bus
    (my/observer-emit my/event-module-run plist)
    plist))

(defun my/runtime-module-find-record (name)
  "Return execution record for module NAME, or nil."
  (gethash name my/runtime-module-table))

(defun my/runtime-module-status (name)
  "Return status symbol for module NAME, or nil."
  (plist-get (my/runtime-module-find-record name) :status))

;; ---------------------------------------------------------------------------
;; Dependency satisfaction
;; ---------------------------------------------------------------------------

(defconst my/module-satisfied-statuses
  (list my/module-status-ok my/module-status-deferred)
  "Statuses that satisfy a :after dependency.
`ok'       — module ran synchronously and succeeded.
`deferred' — module is registered and scheduled; its feature is available.")

(defun my/runtime-module-satisfied-p (name)
  "Return non-nil when module NAME is in a dependency-satisfying state."
  (memq (my/runtime-module-status name) my/module-satisfied-statuses))

(defun my/runtime-module-deps-satisfied-p (deps)
  "Return non-nil when all DEPS are in a dependency-satisfying state.
DEPS may be nil, a single symbol, or a list of symbols."
  (let ((dep-list (cond
                   ((null deps)    nil)
                   ((listp deps)   deps)
                   (t              (list deps)))))
    (cl-every #'my/runtime-module-satisfied-p dep-list)))

;; ---------------------------------------------------------------------------
;; Deferred job registry
;; ---------------------------------------------------------------------------

(defun my/runtime-module-register-deferred-job (name strategy)
  "Record deferred module NAME with STRATEGY."
  (let ((job (list :name name
                   :strategy strategy
                   :scheduled-at (current-time))))
    (push job my/runtime-module-deferred-jobs)
    (my/observer-emit my/event-module-deferred
                      (list :name name :strategy strategy))
    job))

;; ---------------------------------------------------------------------------
;; Summary and reporting
;; ---------------------------------------------------------------------------

(defun my/runtime-module-summary ()
  "Return a plist summary of module execution counts."
  (let ((ok 0) (skipped 0) (failed 0) (deferred 0))
    (maphash (lambda (_name rec)
               (pcase (plist-get rec :status)
                 ('ok       (cl-incf ok))
                 ('skipped  (cl-incf skipped))
                 ('failed   (cl-incf failed))
                 ('deferred (cl-incf deferred))))
             my/runtime-module-table)
    (list :ok ok
          :skipped skipped
          :failed failed
          :deferred deferred
          :total (+ ok skipped failed deferred))))

(defun my/runtime-module-report ()
  "Log module execution summary."
  (let* ((s (my/runtime-module-summary)))
    (my/log "[modules] total=%d ok=%d skipped=%d deferred=%d failed=%d"
            (plist-get s :total)
            (plist-get s :ok)
            (plist-get s :skipped)
            (plist-get s :deferred)
            (plist-get s :failed))
    ;; Report failures explicitly
    (maphash (lambda (name rec)
               (when (eq (plist-get rec :status) my/module-status-failed)
                 (my/log "[modules] FAILED: %s reason=%S"
                         name (plist-get rec :reason))))
             my/runtime-module-table)))

(defun my/runtime-module-deferred-report ()
  "Log deferred scheduling summary."
  (when my/runtime-module-deferred-jobs
    (my/log "[modules] deferred: %d scheduled"
            (length my/runtime-module-deferred-jobs))
    (dolist (job (reverse my/runtime-module-deferred-jobs))
      (my/log "[modules]   deferred %s strategy=%S"
              (plist-get job :name)
              (plist-get job :strategy)))))

(provide 'runtime-module-state)
;;; runtime-module-state.el ends here
