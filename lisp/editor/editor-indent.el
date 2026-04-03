;;; editor-indent.el --- Indentation policy -*- lexical-binding: t; -*-
;;; Commentary:
;;; Centralized indentation defaults and optional aggressive indentation.
;;; Code:

(require 'cl-lib)

(require 'core-lib)

(defgroup my/editor-indent nil
  "Indentation policy."
  :group 'editing)

(defcustom my/editor-default-tab-width 4
  "Default tab width."
  :type 'integer
  :group 'my/editor-indent)

(defcustom my/editor-default-fill-column 80
  "Default fill column."
  :type 'integer
  :group 'my/editor-indent)

(defcustom my/editor-enable-aggressive-indent nil
  "Whether to enable aggressive-indent in safe modes."
  :type 'boolean
  :group 'my/editor-indent)

(defcustom my/editor-aggressive-indent-modes
  '(emacs-lisp-mode lisp-interaction-mode css-mode)
  "Modes where aggressive-indent may be enabled."
  :type '(repeat symbol)
  :group 'my/editor-indent)

(defun my/editor--defaults-init ()
  "Apply indentation defaults."
  (setq-default
   indent-tabs-mode nil
   tab-width my/editor-default-tab-width
   fill-column my/editor-default-fill-column))

(defun my/editor--electric-indent-init ()
  "Enable electric indentation."
  (electric-indent-mode 1))

(defun my/editor--prog-indent-hook ()
  "Common indentation policy for programming buffers."
  (setq-local show-trailing-whitespace nil))

(defun my/editor--aggressive-indent-enable-maybe ()
  "Enable aggressive-indent in selected major modes."
  (when (and my/editor-enable-aggressive-indent
             (require 'aggressive-indent nil t)
             (cl-some #'derived-mode-p my/editor-aggressive-indent-modes))
    (aggressive-indent-mode 1)))

(defun my/editor--hooks-init ()
  "Install indentation-related hooks."
  (add-hook 'prog-mode-hook #'my/editor--prog-indent-hook)
  (add-hook 'after-change-major-mode-hook #'my/editor--aggressive-indent-enable-maybe))

(defun my/editor-indent-init ()
  "Initialize indentation policy."
  (my/editor--defaults-init)
  (my/editor--electric-indent-init)
  (my/editor--hooks-init))

(provide 'editor-indent)
;;; editor-indent.el ends here
