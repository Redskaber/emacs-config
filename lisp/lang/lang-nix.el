;;; lang-nix.el --- Nix adapter -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin glue for Nix development.
;;; Code:

(defgroup my/lang-nix nil
  "Nix language adapter."
  :group 'my/lang)

(defcustom my/lang-nix-format-on-save nil
  "Whether to auto-format Nix buffers on save."
  :type 'boolean
  :group 'my/lang-nix)

(defun my/lang-nix--format-buffer ()
  "Format Nix buffer with available formatter."
  (interactive)
  (cond
   ((fboundp 'nixfmt-format-buffer)
    (nixfmt-format-buffer))
   ((fboundp 'alejandra-format-buffer)
    (alejandra-format-buffer))
   ((fboundp 'eglot-format-buffer)
    (eglot-format-buffer))))

(defun my/lang-nix--setup-format-on-save ()
  "Enable Nix format on save."
  (when my/lang-nix-format-on-save
    (add-hook 'before-save-hook #'my/lang-nix--format-buffer nil t)))

(defun my/lang-nix--hook ()
  "Hook for Nix buffers."
  (my/lang-nix--setup-format-on-save))

(defun my/lang-nix-init ()
  "Initialize Nix adapter."
  (with-eval-after-load 'nix-mode
    (add-hook 'nix-mode-hook #'my/lang-nix--hook))
  (when (boundp 'nix-ts-mode-hook)
    (add-hook 'nix-ts-mode-hook #'my/lang-nix--hook)))

(provide 'lang-nix)
;;; lang-nix.el ends here
