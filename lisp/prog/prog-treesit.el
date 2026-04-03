;;; prog-treesit.el --- Tree-sitter integration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Native tree-sitter policy for Emacs 30+.
;;; Code:

(defgroup my/prog-treesit nil
  "Tree-sitter integration."
  :group 'my/prog)

(defcustom my/prog-treesit-enable-auto t
  "Whether to enable `treesit-auto' when available."
  :type 'boolean)

(defcustom my/prog-treesit-auto-install 'prompt
  "Installation policy for tree-sitter grammars."
  :type '(choice (const :tag "Never" nil)
                 (const :tag "Prompt" prompt)
                 (const :tag "Always" t)))

(defun my/prog-treesit--native-available-p ()
  "Return non-nil if native treesit is available."
  (fboundp 'treesit-available-p))

(defun my/prog-treesit--setup-native ()
  "Setup native treesit defaults."
  (when (and (my/prog-treesit--native-available-p)
             (treesit-available-p))
    (setq treesit-font-lock-level 4)))

(defun my/prog-treesit--setup-auto ()
  "Setup optional `treesit-auto'."
  (when (and my/prog-treesit-enable-auto
             (my/prog-treesit--native-available-p))
    (use-package treesit-auto
      :defer t
      :if (treesit-available-p)
      :init
      (setq treesit-auto-install my/prog-treesit-auto-install)
      :config
      (global-treesit-auto-mode 1))))

(defun my/prog-treesit-init ()
  "Initialize tree-sitter integration."
  (my/prog-treesit--setup-native)
  (my/prog-treesit--setup-auto))

(provide 'prog-treesit)
;;; prog-treesit.el ends here
