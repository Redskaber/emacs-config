;;; init-pipeline.el --- Top-level startup orchestration -*- lexical-binding: t; -*-
;;; Commentary:
;;;     Require order matches the four-layer architecture:
;;;       Layer 1: kernel primitives (kernel-logging, kernel-errors, runtime-observer, runtime-types)
;;;       Layer 2: runtime state model (runtime-context, runtime-feature, runtime-registry)
;;;       Layer 3: runtime executor (runtime-lifecycle, runtime-deferred, runtime-graph, ...)
;;;       Layer 4: runtime observability (runtime-doctor)
;;;
;;;   runtime-doctor-init is called after runtime-observer-init so subscriptions
;;;   are wired before any module events fire.
;;;
;;; Code:

;; Bootstrap
(require 'bootstrap-core)
(require 'bootstrap-package)
(require 'bootstrap-use-package)
(require 'bootstrap-profile)
;; Platform
(require 'platform-core)
;; Kernel
(require 'kernel-const)
(require 'kernel-lib)
(require 'kernel-paths)
(require 'kernel-logging)         ; Layer 1
(require 'kernel-errors)          ; Layer 1
(require 'kernel-require)
(require 'kernel-env)
(require 'kernel-encoding)
(require 'kernel-performance)
(require 'kernel-state)
(require 'kernel-hooks)
(require 'kernel-startup)
(require 'kernel-keymap)
;; Runtime (order: types → observer → lifecycle → feature → context → ...)
;; Runtime: Layer 1 (primitives)
(require 'runtime-types)
(require 'runtime-observer)
;; Runtime: Layer 2 (state model)
(require 'runtime-lifecycle)
(require 'runtime-context)
(require 'runtime-feature)
(require 'runtime-registry)
;; Runtime: Layer 3 (executor)
(require 'runtime-provider)
(require 'runtime-manifest)
(require 'runtime-deferred)
(require 'runtime-stage-state)
(require 'runtime-module-state)
(require 'runtime-module-runner)
(require 'runtime-graph)
(require 'runtime-stage)
(require 'runtime-pipeline)
;; Runtime: Layer 4 (observability)
(require 'runtime-doctor)

;; ─────────────────────────────────────────────────────────────────────────────
;; Stage functions
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/init-bootstrap-stage ()
  (my/profile-stage "bootstrap"
    (my/bootstrap-core-init)
    (my/bootstrap-package-init)
    (my/bootstrap-use-package-init)
    (my/ctx-set-phase 'bootstrap)))

(defun my/init-platform-stage ()
  (my/profile-stage "platform"
    (my/platform-core-init)
    (my/ctx-declare-capabilities)
    (my/ctx-set-phase 'platform)))

(defun my/init-kernel-stage ()
  "Initialise kernel subsystems in layer order.

  Layer 1 — primitives first: logging, errors, observer, types.
  Layer 2 — state model: context, feature.
  Layer 3 — executor: lifecycle, deferred, doctor (subscriptions).
  This ordering guarantees that domain event subscriptions (doctor)
  are installed before any module or stage events fire."
  (my/profile-stage "kernel"
    ;; Layer 1
    (my/kernel-paths-init)
    (my/kernel-logging-init)
    (my/kernel-errors-init)
    (my/runtime-observer-init)          ; event bus must be up before subscriptions
    ;; Layer 2
    (my/runtime-context-init)
    (my/runtime-feature-init)
    ;; Layer 3
    (my/runtime-lifecycle-init)         ; subscribes to :deferred/complete
    (my/kernel-require-init)
    (my/kernel-env-init)
    (my/kernel-encoding-init)
    (my/kernel-performance-init)
    (my/kernel-state-init)
    (my/kernel-hooks-init)
    (my/kernel-startup-init)
    (my/kernel-keymap-init)
    ;; Layer 4 — subscriptions wired after observer and lifecycle are ready
    (my/runtime-doctor-init)
    (my/ctx-set-phase 'kernel)))

(defun my/init-post-stage ()
  (my/profile-stage "post-init"
    (my/ctx-set-phase 'post-init)
    (my/runtime-final-report)
    (my/startup-finalize)
    (my/ctx-set-phase 'ready)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Pipeline entry points
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/init-reset-state ()
  (setq my/profile-records nil)
  (my/runtime-reset-state))

(defun my/init-force-rerun ()
  "Force-clear all state and re-run.  Interactive only."
  (interactive)
  (my/runtime-force-reset-state)
  (my/init-run))

(defun my/init-run ()
  "Execute the complete startup pipeline."
  (interactive)
  (my/init-reset-state)
  (my/init-bootstrap-stage)
  (my/init-platform-stage)
  (my/init-kernel-stage)
  (my/runtime-run-all-stages)
  (my/init-post-stage))

(provide 'init-pipeline)
;;; init-pipeline.el ends here
