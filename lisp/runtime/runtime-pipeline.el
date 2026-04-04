;;; runtime-pipeline.el --- Runtime pipeline orchestration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Topological execution of runtime stages.
;;; Code:

(require 'bootstrap-profile)
(require 'runtime-feature)
(require 'runtime-graph)
(require 'runtime-stage)
(require 'runtime-stage-state)
(require 'runtime-module-state)

(defun my/runtime-reset-state ()
  "Reset runtime execution records."
  (my/runtime-module-state-reset)
  ;; NOTE:
  ;; For normal re-entry during a session, do not clear stage state automatically,
  ;; otherwise repeated runs may duplicate hooks/global side effects.
  )

(defun my/runtime-force-reset-state ()
  "Force reset all runtime state including stage sentinels."
  (interactive)
  (my/runtime-module-state-reset)
  (my/runtime-stage-state-clear))

(defun my/runtime-plan ()
  "Return stage execution plan."
  (my/runtime-graph-stage-plan))

(defun my/runtime-run-all-stages ()
  "Run all declared layer stages in topological order."
  (dolist (stage (my/runtime-plan))
    (my/profile-stage (symbol-name stage)
      (my/runtime-stage-run stage))))

(defun my/runtime-final-report ()
  "Emit runtime execution reports."
  (my/runtime-module-report)
  (my/runtime-module-deferred-report))

(provide 'runtime-pipeline)
;;; runtime-pipeline.el ends here
