;;; runtime-pipeline.el --- Runtime pipeline orchestration  -*- lexical-binding: t; -*-
;;; Commentary:
;;; - Integrates my/ctx-set-phase for visibility into startup progress.
;;; - Emits my/event-init-complete on the observer bus after pipeline finishes.
;;; - my/runtime-reset-state now also resets context health log.
;;; Code:

(require 'bootstrap-profile)
(require 'runtime-types)
(require 'runtime-context)
(require 'runtime-feature)
(require 'runtime-observer)
(require 'runtime-graph)
(require 'runtime-stage)
(require 'runtime-stage-state)
(require 'runtime-module-state)

(defun my/runtime-reset-state ()
  "Reset module execution records (safe for session re-entry)."
  (my/runtime-module-state-reset)
  ;; Do NOT clear stage sentinels on normal re-entry – that would allow
  ;; hooks/timers to be re-registered.  Use my/runtime-force-reset-state.
  )

(defun my/runtime-force-reset-state ()
  "Force-clear all runtime state including stage sentinels.
Interactive use only – may cause duplicate side effects on re-run."
  (interactive)
  (my/runtime-module-state-reset)
  (my/runtime-stage-state-clear)
  (clrhash my/runner--pending-inits))

(defun my/runtime-plan ()
  "Return topologically sorted stage execution plan."
  (my/runtime-graph-stage-plan))

(defun my/runtime-run-all-stages ()
  "Run all declared stages in dependency order.
Advances the context phase to `stages' before running."
  (my/ctx-set-phase 'stages)
  (dolist (stage (my/runtime-plan))
    (my/profile-stage (symbol-name stage)
      (my/runtime-stage-run stage)
      ;; Record stage health in context for ops/healthcheck
      (my/ctx-record-health stage (my/runtime-stage-state-status stage)))))

(defun my/runtime-final-report ()
  "Emit execution summary to *Messages*."
  (my/runtime-module-report)
  (my/runtime-module-deferred-report)
  ;; Emit completion event so observer subscribers (healthcheck, etc.) fire
  (my/observer-emit my/event-init-complete
                    (list :elapsed (float-time
                                    (time-subtract (current-time)
                                                   my/emacs-start-time))
                          :gc-count gcs-done)))

(provide 'runtime-pipeline)
;;; runtime-pipeline.el ends here
