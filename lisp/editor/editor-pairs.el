;;; editor-pairs.el --- Pair insertion and structural editing -*- lexical-binding: t; -*-
;;; Commentary:
;;; Built-in pair management with optional structural editing enhancements.
;;; Code:
;;; 不建议同时“强依赖 electric-pair + smartparens 全开 ?

(require 'core-lib)

(defgroup my/editor-pairs nil
  "Pair insertion and structural editing."
  :group 'editing)

(defcustom my/editor-enable-smartparens t
  "Whether to enable smartparens if installed."
  :type 'boolean
  :group 'my/editor-pairs)

(defcustom my/editor-use-builtin-electric-pair t
  "Whether to enable built-in `electric-pair-mode'."
  :type 'boolean
  :group 'my/editor-pairs)

(defun my/editor--builtin-pairs-init ()
  "Configure built-in pairing."
  (show-paren-mode 1)
  (setq show-paren-delay 0
        show-paren-context-when-offscreen 'overlay)

  (when my/editor-use-builtin-electric-pair
    (electric-pair-mode 1))

  (electric-indent-mode 1))

(defun my/editor--smartparens-init ()
  "Configure smartparens if available."
  (when (and my/editor-enable-smartparens
             (require 'smartparens-config nil t))
    (add-hook 'prog-mode-hook #'smartparens-mode)
    (add-hook 'markdown-mode-hook #'smartparens-mode)
    (add-hook 'org-mode-hook #'smartparens-mode)

    (with-eval-after-load 'smartparens
      (require 'smartparens-bindings nil t))))

(defun my/editor-pairs-init ()
  "Initialize pair insertion and structural editing."
  (my/editor--builtin-pairs-init)
  (my/editor--smartparens-init))

(provide 'editor-pairs)
;;; editor-pairs.el ends here
