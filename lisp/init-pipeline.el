;;; init-pipeline.el --- Top-level startup orchestration -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. Requires kernel-logging (replaces kernel-logging as primary log sink).
;;;   2. Requires runtime-deferred.
;;;   3. my/runtime-force-reset-state is the canonical force-clear entry.
;;;   4. Stage sequence unchanged: bootstrap → platform → kernel → stages → post-init.
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

;; Runtime (order: types → observer → feature → context → ...)
(require 'runtime-types)
(require 'runtime-observer)
(require 'runtime-feature)
(require 'runtime-context)
(require 'runtime-provider)
(require 'runtime-manifest)
(require 'runtime-deferred)
(require 'runtime-stage-state)
(require 'runtime-module-state)
(require 'runtime-module-runner)
(require 'runtime-registry)
(require 'runtime-graph)
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
    (my/ctx-declare-capabilities)
    (my/ctx-set-phase 'platform)))

(defun my/init-kernel-stage ()
  "Kernel: core infrastructure."
  (my/profile-stage "kernel"
    ;; Standard kernel modules
    (my/kernel-paths-init)
    (my/kernel-logging-init)
    (my/kernel-errors-init)
    (my/kernel-require-init)
    ;; Context + observer must come first
    (my/runtime-context-init)
    (my/runtime-observer-init)
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
  "Force-clear all state and re-run the complete pipeline.
Interactive use only.  May produce duplicate side effects."
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
