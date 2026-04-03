;;; app-vterm.el --- Optional vterm integration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin vterm glue with safe degradation.
;;; Code:

(defgroup my/app-vterm nil
  "Vterm integration."
  :group 'my/app-terminal)

(defun my/app-vterm-open ()
  "Open vterm if available."
  (interactive)
  (if (fboundp 'vterm)
      (vterm)
    (user-error "vterm is not available")))

(defun my/app-vterm-init ()
  "Initialize optional vterm integration."
  (use-package vterm
    :defer t
    :commands (vterm))
  (global-set-key (kbd "C-c T") #'my/app-vterm-open))

(provide 'app-vterm)
;;; app-vterm.el ends here
