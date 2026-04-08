;;; runtime-pipeline.el --- Runtime pipeline orchestration -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - my/runtime-reset-state resets doctor evidence store.
;;;     - my/runtime-final-report emits :runtime/* domain events via observer.
;;;     - Layer ordering in require list matches four-layer model.
;;;
;;; Code:

(require 'bootstrap-profile)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-context)
(require 'runtime-feature)
;; Layer 3: executor
(require 'runtime-observer)
(require 'runtime-lifecycle)
(require 'runtime-deferred)
(require 'runtime-graph)
(require 'runtime-stage)
(require 'runtime-stage-state)
(require 'runtime-module-state)
(require 'runtime-doctor)

;; ─────────────────────────────────────────────────────────────────────────────
;; State reset
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-reset-state ()
  "Reset module/lifecycle/evidence records (safe for session re-entry).
  Does NOT clear stage sentinels or deferred jobs."
  (my/runtime-module-state-reset)
  (my/lifecycle-reset)
  ;; Reset doctor evidence so re-runs start clean
  (when (fboundp 'my/doctor--evidence)
    (clrhash my/doctor--evidence)))

(defun my/runtime-force-reset-state ()
  "Force-clear ALL runtime state including stage sentinels and deferred jobs."
  (interactive)
  (my/deferred-reset)
  (my/runtime-module-state-reset)
  (my/lifecycle-reset)
  (my/runtime-stage-state-clear)
  (when (boundp 'my/doctor--evidence)
    (clrhash my/doctor--evidence)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Stage plan
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-plan ()
  (my/runtime-graph-stage-plan))

;; ─────────────────────────────────────────────────────────────────────────────
;; Stage runner
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-run-all-stages ()
  (my/ctx-set-phase 'stages)
  (dolist (stage (my/runtime-plan))
    (my/profile-stage (symbol-name stage)
      (my/runtime-stage-run stage)
      (my/ctx-record-health stage (my/runtime-stage-state-status stage)))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Final report
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-final-report ()
  "Emit execution summary: module report, deferred report, doctor report."
  (my/runtime-module-report)
  (my/runtime-module-deferred-report)
  (my/doctor-module-report)
  (my/doctor-print-slow-modules 5)
  (let ((elapsed (float-time
                  (time-subtract (current-time) my/emacs-start-time))))
    (my/log-event
     'info "pipeline"
     (format "init complete: elapsed=%.3fs gc=%d" elapsed gcs-done)
     :event   :runtime/init-complete
     :data    (list :elapsed elapsed :gc-count gcs-done))
    (my/observer-emit my/event-init-complete
                      (list :elapsed elapsed :gc-count gcs-done))))

(provide 'runtime-pipeline)
;;; runtime-pipeline.el ends here
