;;; ui-popup.el --- Popup and transient window management -*- lexical-binding: t; -*-

(defgroup my/ui-popup nil
  "Popup management."
  :group 'my/features)

(defun my/ui-popup-init ()
  "Initialize popup management."
  (use-package popper
    :demand t
    :bind (("C-`"   . popper-toggle)
           ("M-`"   . popper-cycle)
           ("C-M-`" . popper-toggle-type))
    :init
    (setq popper-reference-buffers
          '("\\*Messages\\*"
            "\\*Warnings\\*"
            "\\*Compile-Log\\*"
            "\\*Async Shell Command\\*"
            "\\*Backtrace\\*"
            help-mode
            helpful-mode
            compilation-mode
            grep-mode
            occur-mode
            "^\\*eshell.*\\*$"
            "^\\*shell.*\\*$"
            "^\\*term.*\\*$"
            "^\\*vterm.*\\*$"))
    :config
    (popper-mode 1)
    (popper-echo-mode 1)
    (message "[ui:popup] popper enabled")))

(provide 'ui-popup)
