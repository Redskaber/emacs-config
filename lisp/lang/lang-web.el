;;; lang-web.el --- Web stack adapter -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin glue for HTML/CSS/web templates.
;;; Code:

(defgroup my/lang-web nil
  "Web language adapter."
  :group 'my/lang)

(defcustom my/lang-web-markup-indent 2
  "Indentation width for web markup."
  :type 'integer
  :group 'my/lang-web)

(defun my/lang-web--setup-web-mode ()
  "Configure `web-mode' defaults."
  (setq-local web-mode-markup-indent-offset my/lang-web-markup-indent
              web-mode-code-indent-offset my/lang-web-markup-indent
              web-mode-css-indent-offset my/lang-web-markup-indent))

(defun my/lang-web--hook ()
  "Hook for web buffers."
  (when (derived-mode-p 'web-mode)
    (my/lang-web--setup-web-mode)))

(defun my/lang-web-init ()
  "Initialize Web adapter."
  (with-eval-after-load 'web-mode
    (add-hook 'web-mode-hook #'my/lang-web--hook)))

(provide 'lang-web)
;;; lang-web.el ends here
