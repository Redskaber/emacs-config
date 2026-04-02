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

(defun my/ui-init ()
  "Initialize UI layer."
  (when (and my/feature-ui my/gui-p)
    (require 'ui-frame)
    (require 'ui-font)
    (require 'ui-theme)
    (require 'ui-chrome)
    (require 'ui-icons)
    (require 'ui-modeline)
    (require 'ui-popup)

    (my/with-safe-init "ui-frame"
      (my/ui-frame-init))

    (my/with-safe-init "ui-font"
      (my/ui-font-init))

    (my/with-safe-init "ui-theme"
      (my/ui-theme-init))

    (my/with-safe-init "ui-chrome"
      (my/ui-chrome-init))

    (my/with-safe-init "ui-icons"
      (my/ui-icons-init))

    (my/with-safe-init "ui-modeline"
      (my/ui-modeline-init))

    (my/with-safe-init "ui-popup"
      (my/ui-popup-init))))

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

  (my/profile-stage "ui"
    (my/with-safe-init "ui"
      (my/ui-init)))

  ;; Future stages:
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
