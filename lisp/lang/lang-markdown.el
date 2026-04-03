;;; lang-markdown.el --- Markdown adapter -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin glue for Markdown authoring.
;;; Code:

(defgroup my/lang-markdown nil
  "Markdown language adapter."
  :group 'my/lang)

(defcustom my/lang-markdown-fill-column 80
  "Preferred fill column for Markdown."
  :type 'integer
  :group 'my/lang-markdown)

(defun my/lang-markdown--hook ()
  "Hook for Markdown buffers."
  (visual-line-mode 1)
  (setq-local fill-column my/lang-markdown-fill-column))

(defun my/lang-markdown-init ()
  "Initialize Markdown adapter."
  (with-eval-after-load 'markdown-mode
    (add-hook 'markdown-mode-hook #'my/lang-markdown--hook))
  (when (boundp 'gfm-mode-hook)
    (add-hook 'gfm-mode-hook #'my/lang-markdown--hook)))

(provide 'lang-markdown)
;;; lang-markdown.el ends here
