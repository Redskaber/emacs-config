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
(require 'core-paths)
(require 'core-env)
(require 'core-encoding)
(require 'core-performance)
(require 'core-state)
(require 'core-hooks)
(require 'core-logging)
(require 'core-errors)
(require 'core-keymap)

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
    (my/core-env-init)
    (my/core-encoding-init)
    (my/core-performance-init)
    (my/core-state-init)
    (my/core-hooks-init)
    (my/core-logging-init)
    (my/core-errors-init)
    (my/core-keymap-init))
  (my/profile-stage "post-init"
    (my/restore-startup-state)
    (my/report-startup)))

(provide 'init-pipeline)
;;; init-pipeline.el ends here
