;;; runtime-stage-state.el --- Stage execution state -*- lexical-binding: t; -*-
;;; Commentary:
;;; Stage lifecycle state and sentinels.
;;; Code:

(require 'kernel-logging)

(defvar my/runtime-stage-table (make-hash-table :test #'eq)
  "Stage execution sentinel table.
    Value plist shape:
      (:status ok|failed|running
      :started-at <time>
      :ended-at <time>
      :detail <any>)")

(defun my/runtime-stage-state-get (stage)
  "Return state plist for STAGE, or nil."
  (gethash stage my/runtime-stage-table))

(defun my/runtime-stage-state-status (stage)
  "Return status symbol for STAGE."
  (plist-get (my/runtime-stage-state-get stage) :status))

(defun my/runtime-stage-state-set (stage status &optional detail)
  "Set STAGE STATUS with optional DETAIL."
  (let* ((old (my/runtime-stage-state-get stage))
         (started-at (or (plist-get old :started-at)
                         (current-time)))
         (ended-at (unless (eq status 'running) (current-time))))
    (puthash stage
             (list :status status
                   :started-at started-at
                   :ended-at ended-at
                   :detail detail)
             my/runtime-stage-table)))

(defun my/runtime-stage-state-clear (&optional stage)
  "Clear STAGE state, or all stage state when STAGE is nil."
  (if stage
      (remhash stage my/runtime-stage-table)
    (clrhash my/runtime-stage-table)))

(defun my/runtime-stage-done-p (stage)
  "Return non-nil if STAGE completed successfully."
  (eq (my/runtime-stage-state-status stage) 'ok))

(defun my/runtime-stage-failed-p (stage)
  "Return non-nil if STAGE failed."
  (eq (my/runtime-stage-state-status stage) 'failed))

(defun my/runtime-stage-running-p (stage)
  "Return non-nil if STAGE is currently running."
  (eq (my/runtime-stage-state-status stage) 'running))

(defmacro my/with-runtime-stage-state (stage &rest body)
  "Run BODY under STAGE lifecycle state."
  (declare (indent 1))
  `(cond
    ((my/runtime-stage-done-p ,stage)
     (my/log "stage skipped (already done): %s" ,stage)
     'already-done)
    ((my/runtime-stage-running-p ,stage)
     (my/log "stage skipped (already running): %s" ,stage)
     'already-running)
    (t
     (my/runtime-stage-state-set ,stage 'running)
     (condition-case err
         (let ((result (progn ,@body)))
           (my/runtime-stage-state-set ,stage 'ok result)
           result)
       (error
        (my/runtime-stage-state-set ,stage 'failed err)
        (signal (car err) (cdr err)))))))

(defun my/runtime-stage-state-init ()
  "Initialize stage state subsystem."
  (my/runtime-stage-state-clear))

(provide 'runtime-stage-state)
;;; runtime-stage-state.el ends here
