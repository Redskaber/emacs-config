;;; prog-lsp.el --- LSP client integration (Eglot-first) -*- lexical-binding: t; -*-
;;; Commentary:
;;; Eglot-first LSP policy for modern Emacs.
;;; Code:

(defgroup my/prog-lsp nil
  "LSP client integration."
  :group 'my/prog)

(defcustom my/prog-lsp-enable-eglot t
  "Whether to enable Eglot integration."
  :type 'boolean)

(defcustom my/prog-lsp-managed-modes
  '(python-mode python-ts-mode
    go-mode go-ts-mode
    rust-mode rust-ts-mode
    js-mode js-ts-mode
    typescript-mode typescript-ts-mode
    tsx-ts-mode
    web-mode
    nix-mode nix-ts-mode
    yaml-mode yaml-ts-mode
    json-mode json-ts-mode)
  "Major modes that should auto-start Eglot."
  :type '(repeat symbol))

(defun my/prog-lsp--eglot-ensure-maybe ()
  "Start Eglot in supported buffers."
  (when (and my/prog-lsp-enable-eglot
             (featurep 'eglot)
             (memq major-mode my/prog-lsp-managed-modes))
    (eglot-ensure)))

(defun my/prog-lsp--setup-eglot ()
  "Configure Eglot."
  (when (and my/prog-lsp-enable-eglot
             (require 'eglot nil t))
    (setq eglot-autoshutdown t
          eglot-sync-connect 1
          eglot-events-buffer-size 0
          eglot-report-progress nil)
    (dolist (mode-hook '(python-mode-hook
                         python-ts-mode-hook
                         go-mode-hook
                         go-ts-mode-hook
                         rust-mode-hook
                         rust-ts-mode-hook
                         js-mode-hook
                         js-ts-mode-hook
                         typescript-mode-hook
                         typescript-ts-mode-hook
                         tsx-ts-mode-hook
                         web-mode-hook
                         nix-mode-hook
                         nix-ts-mode-hook
                         yaml-mode-hook
                         yaml-ts-mode-hook
                         json-mode-hook
                         json-ts-mode-hook))
      (add-hook mode-hook #'my/prog-lsp--eglot-ensure-maybe))))

(defun my/prog-lsp-init ()
  "Initialize LSP integration."
  (my/prog-lsp--setup-eglot))

(provide 'prog-lsp)
;;; prog-lsp.el ends here
