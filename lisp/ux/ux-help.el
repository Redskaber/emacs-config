;;; ux-help.el --- Help and discoverability UX -*- lexical-binding: t; -*-
;;; Commentary:
;;; Help and discoverability:
;;; - which-key
;;; - helpful
;;; Code:

(require 'core-lib)

(defgroup my/ux-help nil
  "Help and discoverability UX."
  :group 'my/features)

(defcustom my/feature-ux-helpful t
  "Enable Helpful enhanced help UI."
  :type 'boolean
  :group 'my/ux-help)

(defcustom my/which-key-idle-delay 0.6
  "Idle delay before Which-Key popup."
  :type 'number
  :group 'my/ux-help)

(defun my/ux-help--which-key-init ()
  "Initialize Which-Key."
  (use-package which-key
    :ensure t
    :init
    (setq which-key-idle-delay my/which-key-idle-delay
          which-key-idle-secondary-delay 0.05
          which-key-sort-order 'which-key-prefix-then-key-order
          which-key-sort-uppercase-first nil
          which-key-add-column-padding 1
          which-key-max-display-columns nil
          which-key-min-display-lines 6)
    (which-key-mode 1)))

(defun my/ux-help--helpful-init ()
  "Initialize Helpful."
  (use-package helpful
    :ensure t
    :bind (([remap describe-function] . helpful-callable)
           ([remap describe-command]  . helpful-command)
           ([remap describe-variable] . helpful-variable)
           ([remap describe-key]      . helpful-key)
           ("C-h F" . helpful-function)
           ("C-h C" . helpful-command))))

(defun my/ux-help-init ()
  "Initialize help UX subsystem."
  (my/ux-help--which-key-init)
  (when my/feature-ux-helpful
    (my/ux-help--helpful-init))
  t)

(provide 'ux-help)
;;; ux-help.el ends here
