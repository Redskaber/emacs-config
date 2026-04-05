;;; init-pipeline.el --- Top-level startup orchestration  -*- lexical-binding: t; -*-
;;; Commentary:
;;; - Requires runtime-context and runtime-observer (two new modules).
;;; - Calls my/runtime-context-init and my/runtime-observer-init in kernel stage.
;;; - Calls my/ctx-set-phase at each phase boundary for observability.
;;; - Calls my/ctx-declare-capabilities after platform detection so downstream
;;;   code can read capabilities from context rather than raw variables.
;;;
;;; The startup sequence remains:
;;;   bootstrap → platform → kernel → stages → post-init
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
(require 'kernel-logging)
(require 'kernel-errors)
(require 'kernel-require)
(require 'kernel-env)
(require 'kernel-encoding)
(require 'kernel-performance)
(require 'kernel-state)
(require 'kernel-hooks)
(require 'kernel-startup)
(require 'kernel-keymap)

;; Runtime
(require 'runtime-types)
(require 'runtime-context)
(require 'runtime-observer)
(require 'runtime-feature)
(require 'runtime-stage-state)
(require 'runtime-module-state)
(require 'runtime-manifest)
(require 'runtime-registry)
(require 'runtime-graph)
(require 'runtime-module-runner)
(require 'runtime-stage)
(require 'runtime-pipeline)

;; ---------------------------------------------------------------------------
;; Stage functions
;; ---------------------------------------------------------------------------

(defun my/init-bootstrap-stage ()
  "Bootstrap: package management and use-package."
  (my/profile-stage "bootstrap"
    (my/bootstrap-core-init)
    (my/bootstrap-package-init)
    (my/bootstrap-use-package-init)))

(defun my/init-platform-stage ()
  "Platform: capability detection."
  (my/profile-stage "platform"
    (my/platform-core-init)
    ;; populate context with resolved capabilities
    (my/ctx-declare-capabilities)
    (my/ctx-set-phase 'platform)))

(defun my/init-kernel-stage ()
  "Kernel: core infrastructure."
  (my/profile-stage "kernel"
    ;; initialise context and observer bus first
    (my/runtime-context-init)
    (my/runtime-observer-init)
    ;; Then standard kernel modules (order matters)
    (my/kernel-paths-init)
    (my/kernel-logging-init)
    (my/kernel-errors-init)
    (my/kernel-require-init)
    (my/runtime-feature-init)
    (my/kernel-env-init)
    (my/kernel-encoding-init)
    (my/kernel-performance-init)
    (my/kernel-state-init)
    (my/kernel-hooks-init)
    (my/kernel-startup-init)
    (my/kernel-keymap-init)
    (my/ctx-set-phase 'kernel)))

(defun my/init-post-stage ()
  "Post-init: finalisation and reporting."
  (my/profile-stage "post-init"
    (my/ctx-set-phase 'post-init)
    (my/runtime-final-report)
    (my/startup-finalize)
    (my/ctx-set-phase 'ready)))

;; ---------------------------------------------------------------------------
;; Pipeline entry points
;; ---------------------------------------------------------------------------

(defun my/init-reset-state ()
  "Reset startup records before a run."
  (setq my/profile-records nil)
  (my/runtime-reset-state))

(defun my/init-force-rerun ()
  "Force-clear all sentinels and re-run the complete startup pipeline.
Useful for development iteration.  May produce duplicate side effects."
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
