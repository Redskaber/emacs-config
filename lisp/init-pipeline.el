;;; init-pipeline.el --- Top-level startup orchestration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Deterministic startup pipeline:
;;; bootstrap -> platform -> kernel -> runtime(stages) -> post-init
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
(require 'runtime-feature)
(require 'runtime-stage-state)
(require 'runtime-module-state)
(require 'runtime-manifest)
(require 'runtime-registry)
(require 'runtime-graph)
(require 'runtime-module-runner)
(require 'runtime-stage)
(require 'runtime-pipeline)

(defun my/init-bootstrap-stage ()
  "Run bootstrap stage."
  (my/profile-stage "bootstrap"
    (my/bootstrap-core-init)
    (my/bootstrap-package-init)
    (my/bootstrap-use-package-init)))

(defun my/init-platform-stage ()
  "Run platform capability detection stage."
  (my/profile-stage "platform"
    (my/platform-core-init)))

(defun my/init-kernel-stage ()
  "Run kernel infrastructure stage."
  (my/profile-stage "kernel"
    ;; Order matters here.
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
    (my/kernel-keymap-init)))

(defun my/init-post-stage ()
  "Run post-init finalization."
  (my/profile-stage "post-init"
    (my/runtime-final-report)
    (my/startup-finalize)))

(defun my/init-reset-state ()
  "Reset startup runtime records."
  (setq my/profile-records nil)
  (my/runtime-reset-state))

(defun my/init-force-rerun ()
  "Force clear sentinels and rerun the complete startup pipeline."
  (interactive)
  (my/runtime-force-reset-state)
  (my/init-run))

(defun my/init-run ()
  "Run the complete startup pipeline."
  (interactive)
  (my/init-reset-state)

  ;; Base runtime
  (my/init-bootstrap-stage)
  (my/init-platform-stage)
  (my/init-kernel-stage)

  ;; Layered runtime
  (my/runtime-run-all-stages)

  ;; Finalize
  (my/init-post-stage))

(provide 'init-pipeline)
;;; init-pipeline.el ends here
