;;; init-pipeline.el --- Top-level initialization pipeline -*- lexical-binding: t; -*-
;;; Commentary:
;;; Orchestrates startup in explicit stages.
;;; Code:

(require 'bootstrap-profile)
(require 'bootstrap-core)
(require 'bootstrap-package)
(require 'bootstrap-use-package)

(require 'platform-core)

(require 'core-const)
(require 'core-lib)
(require 'core-paths)
(require 'core-feature-flags)
(require 'core-env)
(require 'core-encoding)
(require 'core-performance)
(require 'core-state)
(require 'core-hooks)
(require 'core-logging)
(require 'core-errors)
(require 'core-keymap)
(require 'core-startup)

(defun my/init-run ()
  "Run the Emacs initialization pipeline."
  (interactive)
  (my/profile-stage "bootstrap"
    (my/bootstrap-core-init)
    (my/bootstrap-package-init)
    (my/bootstrap-use-package-init))

  (my/profile-stage "platform"
    (my/platform-init))

  (my/profile-stage "core"
    (my/core-paths-init)
    (my/core-feature-flags-init)
    (my/core-env-init)
    (my/core-encoding-init)
    (my/core-performance-init)
    (my/core-state-init)
    (my/core-hooks-init)
    (my/core-logging-init)
    (my/core-errors-init)
    (my/core-keymap-init)
    (my/core-startup-init))

  ;; Future stages:
  ;; (my/profile-stage "ui" ...)
  ;; (my/profile-stage "ux" ...)
  ;; (my/profile-stage "editor" ...)
  ;; (my/profile-stage "project" ...)
  ;; (my/profile-stage "vcs" ...)
  ;; (my/profile-stage "prog" ...)
  ;; (my/profile-stage "lang" ...)
  ;; (my/profile-stage "app" ...)
  ;; (my/profile-stage "ops" ...)

  (my/profile-stage "post-init"
    (my/startup-finalize)))

(provide 'init-pipeline)
;;; init-pipeline.el ends here
