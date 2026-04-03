;;; init-pipeline.el --- Top-level startup orchestration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Deterministic, manifest-driven startup pipeline with stage dependencies.
;;; Code:

;; Bootstrap
(require 'bootstrap-core)
(require 'bootstrap-package)
(require 'bootstrap-use-package)
(require 'bootstrap-profile)

;; Platform
(require 'platform-core)

;; Core
(require 'core-const)
(require 'core-lib)
(require 'core-paths)
(require 'core-env)
(require 'core-encoding)
(require 'core-performance)
(require 'core-state)
(require 'core-hooks)
(require 'core-logging)
(require 'core-errors)
(require 'core-require)
(require 'core-module)
(require 'core-feature-flags)
(require 'core-startup)
(require 'core-keymap)

;; Registry (pulls manifests transitively)
(require 'manifest-registry)

(defun my/init-bootstrap-stage ()
  "Run bootstrap stage."
  (my/with-stage-sentinel 'bootstrap
    (my/profile-stage "bootstrap"
      (my/bootstrap-core-init)
      (my/bootstrap-package-init)
      (my/bootstrap-use-package-init))))

(defun my/init-platform-stage ()
  "Run platform/capability detection stage."
  (my/with-stage-sentinel 'platform
    (my/profile-stage "platform"
      (my/platform-core-init))))

(defun my/init-core-stage ()
  "Run core infrastructure stage."
  (my/with-stage-sentinel 'core
    (my/profile-stage "core"
      ;; Order matters here.
      (my/core-paths-init)
      (my/core-logging-init)
      (my/core-errors-init)
      (my/core-require-init)
      (my/core-module-init)
      (my/core-feature-flags-init)
      (my/core-env-init)
      (my/core-encoding-init)
      (my/core-performance-init)
      (my/core-state-init)
      (my/core-hooks-init)
      (my/core-startup-init)
      (my/core-keymap-init))))

(defun my/init-run-stage (stage)
  "Run a single registered STAGE via stage registry."
  (my/profile-stage (symbol-name stage)
    (my/module-run-stage-by-spec stage)))

(defun my/init-run-all-layer-stages ()
  "Run all registered layer stages in declarative order."
  (dolist (stage (my/stage-names))
    (my/init-run-stage stage)))

(defun my/init-reset-state ()
  "Reset startup runtime records."
  (setq my/profile-records nil
        my/module-run-records nil
        my/module-deferred-jobs nil)
  ;; NOTE:
  ;; Do NOT clear stage sentinels here for normal runtime, otherwise
  ;; repeated `my/init-run' will re-register hooks and global modes.
  )

(defun my/init-force-rerun ()
  "Force clear sentinels and rerun the complete startup pipeline.
Useful during development."
  (interactive)
  (my/stage-sentinel-clear)
  (my/init-run))

(defun my/init-run ()
  "Run the complete startup pipeline."
  (interactive)
  (my/init-reset-state)

  ;; Base runtime
  (my/init-bootstrap-stage)
  (my/init-platform-stage)
  (my/init-core-stage)

  ;; Layered runtime
  (my/init-run-all-layer-stages)

  ;; Finalize
  (my/with-stage-sentinel 'post-init
    (my/module-report)
    (my/module-deferred-report)
    (my/startup-finalize)))

(provide 'init-pipeline)
;;; init-pipeline.el ends here
