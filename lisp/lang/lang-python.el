;;; lang-python.el --- Python adapter -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin glue for Python development.
;;; Code:

(require 'python)

(defgroup my/lang-python nil
  "Python language adapter."
  :group 'my/lang)

(defcustom my/lang-python-fill-docstrings t
  "Whether auto-fill should apply in Python docstrings/comments."
  :type 'boolean
  :group 'my/lang-python)

(defun my/lang-python--setup-mode ()
  "Configure Python buffer defaults."
  (setq-local python-indent-guess-indent-offset-verbose nil)
  (setq-local fill-column 88))

(defun my/lang-python--setup-bindings ()
  "Install Python-local bindings."
  (local-set-key (kbd "C-c C-z") #'run-python)
  (local-set-key (kbd "C-c C-c") #'python-shell-send-buffer)
  (local-set-key (kbd "C-c C-r") #'python-shell-send-region)
  (local-set-key (kbd "C-c C-f") #'python-shell-send-defun))

(defun my/lang-python--setup-formatting ()
  "Configure Python formatting-related behavior."
  (when my/lang-python-fill-docstrings
    (setq-local comment-auto-fill-only-comments t)))

(defun my/lang-python--hook ()
  "Hook for Python buffers."
  (my/lang-python--setup-mode)
  (my/lang-python--setup-bindings)
  (my/lang-python--setup-formatting))

(defun my/lang-python-init ()
  "Initialize Python adapter."
  (add-hook 'python-mode-hook #'my/lang-python--hook)
  (when (boundp 'python-ts-mode-hook)
    (add-hook 'python-ts-mode-hook #'my/lang-python--hook)))

(provide 'lang-python)
;;; lang-python.el ends here
