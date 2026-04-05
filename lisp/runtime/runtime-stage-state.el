;;; runtime-stage-state.el --- Stage execution state  -*- lexical-binding: t; -*-
;;; Commentary:
;;; 1. DEGRADED STATUS
;;;    inspects the module results after a stage runs and sets:
;;;      ok       — all modules ok or skipped/deferred (no failures)
;;;      degraded — some modules failed but stage completed
;;;      failed   — stage could not execute (dependency / internal error)
;;;      skipped  — stage gate was closed
;;;
;;; 2. OBSERVER INTEGRATION
;;;    Stage start/end events are emitted to the observer bus, so ops
;;;    layer can receive them without being imported by runtime-stage.
;;;
;;; 3. `my/runtime-stage-done-p` now accepts both `ok` AND `degraded`
;;;    as "done" for the purposes of downstream stage dependency resolution.
;;;    A degraded stage still ran; its downstream should proceed.
;;; Code:

(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-observer)

;; ---------------------------------------------------------------------------
;; State table
;; ---------------------------------------------------------------------------

(defvar my/runtime-stage-table (make-hash-table :test #'eq)
  "Map stage-name symbol → state plist.
Shape: (:status STATUS :started-at TIME :ended-at TIME :detail ANY)")

;; ---------------------------------------------------------------------------
;; Accessors
;; ---------------------------------------------------------------------------

(defun my/runtime-stage-state-get (stage)
  "Return state plist for STAGE, or nil."
  (gethash stage my/runtime-stage-table))

(defun my/runtime-stage-state-status (stage)
  "Return status symbol for STAGE, or nil."
  (plist-get (my/runtime-stage-state-get stage) :status))

(defun my/runtime-stage-state-set (stage status &optional detail)
  "Set STAGE to STATUS with optional DETAIL."
  (let* ((old        (my/runtime-stage-state-get stage))
         (started-at (or (plist-get old :started-at) (current-time)))
         (ended-at   (unless (eq status my/stage-status-running)
                       (current-time))))
    (puthash stage
             (list :status     status
                   :started-at started-at
                   :ended-at   ended-at
                   :detail     detail)
             my/runtime-stage-table)))

(defun my/runtime-stage-state-clear (&optional stage)
  "Clear state for STAGE, or all stages when STAGE is nil."
  (if stage
      (remhash stage my/runtime-stage-table)
    (clrhash my/runtime-stage-table)))

;; ---------------------------------------------------------------------------
;; Predicates
;; ---------------------------------------------------------------------------

(defconst my/stage-done-statuses
  (list my/stage-status-ok my/stage-status-degraded)
  "Statuses that count as 'done' for dependency resolution.
A degraded stage still executed; downstream stages should proceed.")

(defun my/runtime-stage-done-p (stage)
  "Return non-nil if STAGE completed (ok or degraded)."
  (memq (my/runtime-stage-state-status stage) my/stage-done-statuses))

(defun my/runtime-stage-ok-p (stage)
  "Return non-nil if STAGE completed without any module failures."
  (eq (my/runtime-stage-state-status stage) my/stage-status-ok))

(defun my/runtime-stage-degraded-p (stage)
  "Return non-nil if STAGE completed with some module failures."
  (eq (my/runtime-stage-state-status stage) my/stage-status-degraded))

(defun my/runtime-stage-failed-p (stage)
  "Return non-nil if STAGE failed to execute."
  (eq (my/runtime-stage-state-status stage) my/stage-status-failed))

(defun my/runtime-stage-running-p (stage)
  "Return non-nil if STAGE is currently running."
  (eq (my/runtime-stage-state-status stage) my/stage-status-running))

;; ---------------------------------------------------------------------------
;; Stage lifecycle macro
;; ---------------------------------------------------------------------------

(defun my/runtime-stage--compute-status (results)
  "Derive stage status from list of module RESULTS.
Returns `ok' if no failures, `degraded' if some modules failed."
  (if (memq my/module-status-failed results)
      my/stage-status-degraded
    my/stage-status-ok))

(defmacro my/with-runtime-stage-state (stage &rest body)
  "Execute BODY under STAGE lifecycle tracking.
BODY should return a list of module status symbols (the results of
my/runtime-module-run-manifest).

Transitions:
  pending   → running  (on entry)
  running   → ok       (BODY returned; no module failures)
  running   → degraded (BODY returned; some module failures)
  running   → failed   (BODY signalled an error)

Already-done or already-running stages are skipped."
  (declare (indent 1))
  `(cond
    ((my/runtime-stage-done-p ,stage)
     (my/log "[stage] skip (already done): %s" ,stage)
     my/reason-already-done)

    ((my/runtime-stage-running-p ,stage)
     (my/log "[stage] skip (already running): %s" ,stage)
     nil)

    (t
     (my/runtime-stage-state-set ,stage my/stage-status-running)
     (my/observer-emit my/event-stage-start
                       (list :stage ,stage :time (current-time)))
     (condition-case err
         (let* ((results (progn ,@body))
                (status  (my/runtime-stage--compute-status
                          (if (listp results) results (list results)))))
           (my/runtime-stage-state-set ,stage status results)
           (my/observer-emit my/event-stage-end
                             (list :stage ,stage
                                   :status status
                                   :time (current-time)))
           (when (eq status my/stage-status-degraded)
             (my/log "[stage] DEGRADED: %s (some modules failed)" ,stage))
           results)
       (error
        (my/runtime-stage-state-set ,stage my/stage-status-failed err)
        (my/observer-emit my/event-stage-end
                          (list :stage ,stage
                                :status my/stage-status-failed
                                :time (current-time)))
        (signal (car err) (cdr err)))))))

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(defun my/runtime-stage-state-init ()
  "Initialise stage state subsystem."
  (my/runtime-stage-state-clear))

(provide 'runtime-stage-state)
;;; runtime-stage-state.el ends here
