;;; runtime-stage-state.el --- Stage execution state -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. Stage records are `my/stage-record' structs (from runtime-types).
;;;   2. All state access goes through API — no external hash-table access.
;;;   3. "degraded" resolution is the same: any module failure → degraded.
;;;   4. my/with-runtime-stage-state macro preserved, adapted for structs.
;;;   5. Observer events carry `my/stage-record' structs instead of plists.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-observer)

;; ---------------------------------------------------------------------------
;; Private state table
;; ---------------------------------------------------------------------------

(defvar my/stage--table (make-hash-table :test #'eq)
  "Map stage-name-symbol → `my/stage-record'.")

;; ---------------------------------------------------------------------------
;; Accessors (API — no external hash access)
;; ---------------------------------------------------------------------------

(defun my/runtime-stage-state-get (stage)
  "Return `my/stage-record' for STAGE, or nil."
  (gethash stage my/stage--table))

(defun my/runtime-stage-state-status (stage)
  "Return status symbol for STAGE, or nil."
  (let ((r (my/runtime-stage-state-get stage)))
    (and r (my/stage-record-status r))))

(defun my/runtime-stage-state-set (stage status &optional detail)
  "Set STAGE to STATUS with optional DETAIL.

  If a record already exists its :started-at is preserved."
  (let* ((old (my/runtime-stage-state-get stage))
         (t0  (if old (my/stage-record-started-at old) (float-time)))
         (t1  (unless (eq status my/stage-status-running) (float-time)))
         (rec (my/make-stage-record
               :name stage :status status
               :started-at t0 :ended-at t1 :detail detail)))
    (puthash stage rec my/stage--table)
    rec))

(defun my/runtime-stage-state-clear (&optional stage)
  "Clear state for STAGE, or all stages when STAGE is nil."
  (if stage
      (remhash stage my/stage--table)
    (clrhash my/stage--table)))

(defun my/runtime-stage-state-init ()
  "Initialise stage state subsystem."
  (my/runtime-stage-state-clear))

;; ---------------------------------------------------------------------------
;; Predicates
;; ---------------------------------------------------------------------------

(defun my/runtime-stage-done-p (stage)
  "Return non-nil if STAGE completed (ok or degraded)."
  (memq (my/runtime-stage-state-status stage) my/stage-done-statuses))

(defun my/runtime-stage-ok-p (stage)
  "Return non-nil if STAGE completed without failures."
  (eq (my/runtime-stage-state-status stage) my/stage-status-ok))

(defun my/runtime-stage-degraded-p (stage)
  "Return non-nil if STAGE completed with some module failures."
  (eq (my/runtime-stage-state-status stage) my/stage-status-degraded))

(defun my/runtime-stage-failed-p (stage)
  "Return non-nil if STAGE failed to execute."
  (eq (my/runtime-stage-state-status stage) my/stage-status-failed))

(defun my/runtime-stage-running-p (stage)
  "Return non-nil if STAGE is currently executing."
  (eq (my/runtime-stage-state-status stage) my/stage-status-running))

;; ---------------------------------------------------------------------------
;; Status computation from module results
;; ---------------------------------------------------------------------------

(defun my/runtime-stage--compute-status (results)
  "Derive stage status from list of module status symbols RESULTS.
  Returns `degraded' if any module failed; `ok' otherwise."
  (if (memq my/module-status-failed results)
      my/stage-status-degraded
    my/stage-status-ok))

;; ---------------------------------------------------------------------------
;; Stage lifecycle macro
;; ---------------------------------------------------------------------------

(defmacro my/with-runtime-stage-state (stage &rest body)
  "Execute BODY under STAGE lifecycle tracking.

  BODY should return a list of module status symbols.

  Transitions:
    (absent)  → running  (on entry)
    running   → ok       (no module failures)
    running   → degraded (some module failures)
    running   → failed   (BODY signalled)

  Already-done or already-running stages are skipped safely."
  (declare (indent 1))
  `(cond
    ((my/runtime-stage-done-p ,stage)
     (my/log-debug "stage" "skip (already done): %s" ,stage)
     my/reason-already-done)

    ((my/runtime-stage-running-p ,stage)
     (my/log-warn "stage" "skip (already running): %s" ,stage)
     nil)

    (t
     (let ((rec (my/runtime-stage-state-set ,stage my/stage-status-running)))
       (my/observer-emit my/event-stage-start
                         (list :stage ,stage :time (float-time) :record rec)))

     (condition-case err
         (let* ((results (progn ,@body))
                (status  (my/runtime-stage--compute-status
                          (if (listp results) results (list results))))
                (rec     (my/runtime-stage-state-set ,stage status results)))
           (my/observer-emit my/event-stage-end
                             (list :stage ,stage :status status
                                   :time (float-time) :record rec))
           (when (eq status my/stage-status-degraded)
             (my/log-warn "stage" "DEGRADED: %s (some modules failed)" ,stage))
           results)

       (error
        (let ((rec (my/runtime-stage-state-set ,stage my/stage-status-failed err)))
          (my/observer-emit my/event-stage-end
                            (list :stage ,stage :status my/stage-status-failed
                                  :time (float-time) :record rec)))
        (signal (car err) (cdr err)))))))

(provide 'runtime-stage-state)
;;; runtime-stage-state.el ends here
