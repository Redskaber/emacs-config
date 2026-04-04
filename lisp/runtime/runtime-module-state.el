;;; runtime-module-state.el --- Module execution state -*- lexical-binding: t; -*-
;;; Commentary:
;;; Execution records and reporting for manifest modules.
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

(defvar my/runtime-module-records nil
  "Execution records of manifest-driven modules.")

(defvar my/runtime-module-deferred-jobs nil
  "Deferred module scheduling records.")

(defun my/runtime-module-state-reset ()
  "Reset module execution state."
  (setq my/runtime-module-records nil
        my/runtime-module-deferred-jobs nil))

(defun my/runtime-module-record (plist)
  "Push PLIST into module records and return PLIST."
  (push plist my/runtime-module-records)
  plist)

(defun my/runtime-module-find-record (name)
  "Return execution record for module NAME, or nil."
  (cl-find-if (lambda (rec)
                (eq (plist-get rec :name) name))
              my/runtime-module-records))

(defun my/runtime-module-ok-p (name)
  "Return non-nil when module NAME completed successfully."
  (eq (plist-get (my/runtime-module-find-record name) :status) 'ok))

(defun my/runtime-module-deps-satisfied-p (deps)
  "Return non-nil when all DEPS have completed successfully."
  (cl-every #'my/runtime-module-ok-p
            (if (listp deps) deps (if deps (list deps) nil))))

(defun my/runtime-module-register-deferred-job (name strategy)
  "Record deferred module NAME with STRATEGY."
  (push (list :name name
              :strategy strategy
              :scheduled-at (current-time))
        my/runtime-module-deferred-jobs))

(defun my/runtime-module-summary ()
  "Return a plist summary of module execution."
  (let ((ok 0) (skipped 0) (failed 0) (deferred 0))
    (dolist (rec my/runtime-module-records)
      (pcase (plist-get rec :status)
        ('ok       (cl-incf ok))
        ('skipped  (cl-incf skipped))
        ('failed   (cl-incf failed))
        ('deferred (cl-incf deferred))))
    (list :ok ok
          :skipped skipped
          :failed failed
          :deferred deferred
          :total (+ ok skipped failed deferred))))

(defun my/runtime-module-report ()
  "Log module execution summary."
  (let* ((summary (my/runtime-module-summary))
         (ok (plist-get summary :ok))
         (skipped (plist-get summary :skipped))
         (failed (plist-get summary :failed))
         (deferred (plist-get summary :deferred))
         (total (plist-get summary :total)))
    (my/log "modules summary: total=%d ok=%d skipped=%d deferred=%d failed=%d"
            total ok skipped deferred failed)))

(defun my/runtime-module-deferred-report ()
  "Log deferred module scheduling summary."
  (when my/runtime-module-deferred-jobs
    (my/log "deferred modules scheduled: %d" (length my/runtime-module-deferred-jobs))
    (dolist (job (reverse my/runtime-module-deferred-jobs))
      (my/log "  deferred: %s %S"
              (plist-get job :name)
              (plist-get job :strategy)))))

(provide 'runtime-module-state)
;;; runtime-module-state.el ends here
