;;; lang-rust.el --- Rust adapter -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin glue for Rust development.
;;; Code:

(defgroup my/lang-rust nil
  "Rust language adapter."
  :group 'my/lang)

(defcustom my/lang-rust-format-on-save t
  "Whether to format Rust buffers on save."
  :type 'boolean
  :group 'my/lang-rust)

(defun my/lang-rust--setup-format-on-save ()
  "Enable rustfmt on save when available."
  (when (and my/lang-rust-format-on-save
             (fboundp 'eglot-format-buffer))
    (add-hook 'before-save-hook #'eglot-format-buffer nil t)))

(defun my/lang-rust--hook ()
  "Hook for Rust buffers."
  (my/lang-rust--setup-format-on-save))

(defun my/lang-rust-init ()
  "Initialize Rust adapter."
  (with-eval-after-load 'rust-mode
    (add-hook 'rust-mode-hook #'my/lang-rust--hook))
  (when (boundp 'rust-ts-mode-hook)
    (add-hook 'rust-ts-mode-hook #'my/lang-rust--hook)))

(provide 'lang-rust)
;;; lang-rust.el ends here
