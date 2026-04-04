;;; lang-elisp.el --- Emacs Lisp adapter -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin glue for Emacs Lisp development on top of core prog infrastructure.
;;; Code:

(require 'elisp-mode)
(require 'checkdoc)

(defgroup my/lang-elisp nil
  "Emacs Lisp language adapter."
  :group 'my/lang)

(defcustom my/lang-elisp-enable-eldoc t
  "Whether to enable richer Eldoc support in Emacs Lisp buffers."
  :type 'boolean
  :group 'my/lang-elisp)

(defun my/lang-elisp--setup-mode ()
  "Configure Emacs Lisp editing defaults."
  (setq-local mode-name "Elisp"))

(defun my/lang-elisp--setup-eval-bindings ()
  "Install Emacs Lisp evaluation bindings."
  (local-set-key (kbd "C-c C-b") #'eval-buffer)
  (local-set-key (kbd "C-c C-r") #'eval-region)
  (local-set-key (kbd "C-c C-e") #'eval-last-sexp)
  (local-set-key (kbd "C-c C-d") #'checkdoc))

(defun my/lang-elisp--setup-eldoc ()
  "Configure Eldoc for Emacs Lisp."
  (when my/lang-elisp-enable-eldoc
    (eldoc-mode 1)))

(defun my/lang-elisp--hook ()
  "Hook for `emacs-lisp-mode'."
  (my/lang-elisp--setup-mode)
  (my/lang-elisp--setup-eval-bindings)
  (my/lang-elisp--setup-eldoc))

(defun my/lang-elisp-init ()
  "Initialize Emacs Lisp adapter."
  (add-hook 'emacs-lisp-mode-hook #'my/lang-elisp--hook)
  (add-hook 'lisp-interaction-mode-hook #'my/lang-elisp--hook))

(provide 'lang-elisp)
;;; lang-elisp.el ends here
