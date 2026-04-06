;;; runtime-pipeline.el --- Runtime pipeline orchestration -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. my/runtime-force-reset-state now calls my/deferred-reset (safe cancel).
;;;   2. Imports updated for new modules (kernel-logging, runtime-deferred).
;;;   3. my/runtime-final-report logs via kernel-logging (not bare message).
;;;   4. Otherwise unchanged: bootstrap → platform → kernel → stages → post-init.
;;;
;;; Code:

(require 'bootstrap-profile)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-context)
(require 'runtime-feature)
(require 'runtime-observer)
(require 'runtime-deferred)
(require 'runtime-graph)
(require 'runtime-stage)
(require 'runtime-stage-state)
(require 'runtime-module-state)

;; ---------------------------------------------------------------------------
;; State reset
;; ---------------------------------------------------------------------------

(defun my/runtime-reset-state ()
  "Reset module execution records (safe for session re-entry).
  Does NOT clear stage sentinels — prevents duplicate hook registration."
  (my/runtime-module-state-reset))

(defun my/runtime-force-reset-state ()
  "Force-clear ALL runtime state including stage sentinels and deferred jobs.

  Interactive use only.  May produce duplicate hook/timer side effects
  on re-run.  Deferred jobs are cancelled before clearing."
  (interactive)
  (my/deferred-reset)
  (my/runtime-module-state-reset)
  (my/runtime-stage-state-clear))

;; ---------------------------------------------------------------------------
;; Stage plan
;; ---------------------------------------------------------------------------

(defun my/runtime-plan ()
  "Return topologically sorted stage execution plan."
  (my/runtime-graph-stage-plan))

;; ---------------------------------------------------------------------------
;; Stage runner
;; ---------------------------------------------------------------------------

(defun my/runtime-run-all-stages ()
  "Run all declared stages in dependency order."
  (my/ctx-set-phase 'stages)
  (dolist (stage (my/runtime-plan))
    (my/profile-stage (symbol-name stage)
      (my/runtime-stage-run stage)
      (my/ctx-record-health stage (my/runtime-stage-state-status stage)))))

;; ---------------------------------------------------------------------------
;; Final report
;; ---------------------------------------------------------------------------

(defun my/runtime-final-report ()
  "Emit execution summary."
  (my/runtime-module-report)
  (my/runtime-module-deferred-report)
  (my/observer-emit my/event-init-complete
                    (list :elapsed (float-time
                                    (time-subtract (current-time)
                                                   my/emacs-start-time))
                          :gc-count gcs-done)))

(provide 'runtime-pipeline)
;;; runtime-pipeline.el ends here
