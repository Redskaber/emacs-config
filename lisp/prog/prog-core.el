;;; prog-core.el --- Language-agnostic programming defaults -*- lexical-binding: t; -*-
;;; Commentary:
;;; Core programming experience for `prog-mode'.
;;; Code:

(require 'imenu)
(require 'elec-pair)
(require 'paren)
(require 'hideshow)

(defgroup my/prog nil
  "Language-agnostic programming infrastructure."
  :group 'tools)

(defcustom my/prog-fill-column 100
  "Default fill column in programming buffers."
  :type 'integer)

(defun my/prog--common-setup ()
  "Common setup for `prog-mode'."
  (setq-local fill-column my/prog-fill-column)
  (display-line-numbers-mode 1)
  (electric-pair-local-mode 1)
  (hs-minor-mode 1)
  (setq-local comment-auto-fill-only-comments t))

(defun my/prog--global-setup ()
  "Global programming UX setup."
  (show-paren-mode 1)
  (which-function-mode 1)
  (setq show-paren-delay 0
        show-paren-when-point-inside-paren t
        show-paren-when-point-in-periphery t
        imenu-auto-rescan t))

(defun my/prog-core-init ()
  "Initialize core programming defaults."
  (add-hook 'prog-mode-hook #'my/prog--common-setup)
  (my/prog--global-setup))

(provide 'prog-core)
;;; prog-core.el ends here
