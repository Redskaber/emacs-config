;;; lang-tsjs.el --- TypeScript / JavaScript adapter -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin glue for JS/TS development.
;;; Code:

(defgroup my/lang-tsjs nil
  "TypeScript/JavaScript adapter."
  :group 'my/lang)

(defcustom my/lang-tsjs-indent-level 2
  "Indentation width for JS/TS."
  :type 'integer
  :group 'my/lang-tsjs)

(defun my/lang-tsjs--setup-indent ()
  "Configure JS/TS indentation."
  (setq-local js-indent-level my/lang-tsjs-indent-level)
  (when (boundp 'typescript-ts-mode-indent-offset)
    (setq-local typescript-ts-mode-indent-offset my/lang-tsjs-indent-level))
  (when (boundp 'tsx-ts-mode-indent-offset)
    (setq-local tsx-ts-mode-indent-offset my/lang-tsjs-indent-level)))

(defun my/lang-tsjs--hook ()
  "Hook for JS/TS buffers."
  (my/lang-tsjs--setup-indent))

(defun my/lang-tsjs-init ()
  "Initialize TypeScript/JavaScript adapter."
  (dolist (hook '(js-mode-hook
                  js-ts-mode-hook
                  typescript-mode-hook
                  typescript-ts-mode-hook
                  tsx-ts-mode-hook))
    (when (boundp hook)
      (add-hook hook #'my/lang-tsjs--hook))))

(provide 'lang-tsjs)
;;; lang-tsjs.el ends here
