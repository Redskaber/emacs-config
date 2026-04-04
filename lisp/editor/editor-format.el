;;; editor-format.el --- Formatting orchestration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Buffer formatting strategy with Apheleia-first policy.
;;; Code:
;;; buffer-local 策略 ?
;;; global-set-key to kernel-keymap.el ?


(require 'kernel-lib)

(defgroup my/editor-format nil
  "Formatting orchestration."
  :group 'editing)

(defcustom my/editor-enable-format-on-save t
  "Whether to format buffers on save when supported."
  :type 'boolean
  :group 'my/editor-format)

(defcustom my/editor-format-fallback-to-indent nil
  "Whether to fallback to `indent-region' if no formatter exists."
  :type 'boolean
  :group 'my/editor-format)

(defvar-local my/editor-format-on-save-local t
  "Buffer-local switch for format-on-save.")

(defun my/editor-format-buffer ()
  "Format current buffer using the best available formatter."
  (interactive)
  (cond
   ((and (bound-and-true-p apheleia-mode)
         (fboundp 'apheleia-format-buffer))
    (apheleia-format-buffer))
   ((and (bound-and-true-p eglot-managed-mode)
         (fboundp 'eglot-format-buffer))
    (eglot-format-buffer))
   ((and (bound-and-true-p lsp-mode)
         (fboundp 'lsp-format-buffer))
    (lsp-format-buffer))
   (my/editor-format-fallback-to-indent
    (indent-region (point-min) (point-max)))))

(defun my/editor-format-buffer-maybe ()
  "Format buffer before save when appropriate."
  (when (and my/editor-enable-format-on-save
             my/editor-format-on-save-local
             (derived-mode-p 'prog-mode 'conf-mode))
    (my/editor-format-buffer)))

(defun my/editor-toggle-format-on-save ()
  "Toggle buffer-local format on save."
  (interactive)
  (setq-local my/editor-format-on-save-local (not my/editor-format-on-save-local))
  (message "my/editor format-on-save: %s"
           (if my/editor-format-on-save-local "enabled" "disabled")))

(defun my/editor--apheleia-init ()
  "Configure Apheleia if available."
  (when (require 'apheleia nil t)
    (apheleia-global-mode -1)))

(defun my/editor--save-hook-init ()
  "Install formatting save hook."
  (add-hook 'before-save-hook #'my/editor-format-buffer-maybe))

(defun my/editor--bindings-init ()
  "Install formatting bindings."
  (global-set-key (kbd "C-c f") #'my/editor-format-buffer)
  (global-set-key (kbd "C-c F") #'my/editor-toggle-format-on-save))

(defun my/editor-format-init ()
  "Initialize formatting orchestration."
  (my/editor--apheleia-init)
  (my/editor--save-hook-init)
  (my/editor--bindings-init))


(provide 'editor-format)
;;; editor-format.el ends here
