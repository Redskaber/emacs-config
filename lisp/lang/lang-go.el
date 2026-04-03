;;; lang-go.el --- Go adapter -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin glue for Go development.
;;; Code:

(defgroup my/lang-go nil
  "Go language adapter."
  :group 'my/lang)

(defun my/lang-go--setup-mode ()
  "Configure Go defaults."
  (setq-local tab-width 4))

(defun my/lang-go--setup-format-on-save ()
  "Enable gofmt on save when available."
  (when (fboundp 'gofmt-before-save)
    (add-hook 'before-save-hook #'gofmt-before-save nil t)))

(defun my/lang-go--hook ()
  "Hook for Go buffers."
  (my/lang-go--setup-mode)
  (my/lang-go--setup-format-on-save))

(defun my/lang-go-init ()
  "Initialize Go adapter."
  (with-eval-after-load 'go-mode
    (add-hook 'go-mode-hook #'my/lang-go--hook))
  (when (boundp 'go-ts-mode-hook)
    (add-hook 'go-ts-mode-hook #'my/lang-go--hook)))

(provide 'lang-go)
;;; lang-go.el ends here
