;;; runtime-pipeline.el --- Runtime pipeline orchestration -*- lexical-binding: t; -*-
;;; Commentary:
;;;  1. Requires runtime-lifecycle and runtime-doctor.
;;;  2. my/runtime-reset-state calls my/lifecycle-reset.
;;;  3. my/runtime-force-reset-state additionally calls my/lifecycle-reset.
;;;  4. my/runtime-final-report calls my/doctor-module-report and
;;;     optionally my/doctor-print-slow-modules.
;;;  5. Stage sequence unchanged: bootstrap → platform → kernel → stages → post-init.
;;;
;;; Code:

(require 'bootstrap-profile)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-context)
(require 'runtime-feature)
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
  "Reset module/lifecycle records (safe for session re-entry).
  Does NOT clear stage sentinels."
  (my/runtime-module-state-reset)
  (my/lifecycle-reset))

(defun my/runtime-force-reset-state ()
  "Force-clear ALL runtime state including stage sentinels and deferred jobs.
  Interactive use only."
  (interactive)
  (my/deferred-reset)
  (my/runtime-module-state-reset)
  (my/lifecycle-reset)
  (my/runtime-stage-state-clear))

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
;; Final report  (includes doctor)
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-final-report ()
  "Emit execution summary including doctor report."
  (my/runtime-module-report)
  (my/runtime-module-deferred-report)
  ;; V2: emit module-level report and slow-module analysis
  (my/doctor-module-report)
  (my/doctor-print-slow-modules 5)
  (my/observer-emit my/event-init-complete
                    (list :elapsed (float-time
                                    (time-subtract (current-time)
                                                   my/emacs-start-time))
                          :gc-count gcs-done)))

(provide 'runtime-pipeline)
;;; runtime-pipeline.el ends here
