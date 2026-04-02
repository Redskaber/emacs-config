;;; ui-icons.el --- Icon system -*- lexical-binding: t; -*-

(require 'platform-core)

(defgroup my/ui-icons nil
  "Icon system."
  :group 'my/features)

(defcustom my/ui-icons-enable t
  "Whether to enable icon packages in GUI sessions."
  :type 'boolean
  :group 'my/ui-icons)

(defun my/ui-icons-init ()
  "Initialize icon system."
  (when (and my/ui-icons-enable my/gui-p)
    (use-package nerd-icons
      :demand t
      :config
      (message "[ui:icons] nerd-icons ready"))))

(provide 'ui-icons)
