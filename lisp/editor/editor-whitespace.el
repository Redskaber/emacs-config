;;; editor-whitespace.el --- Whitespace hygiene -*- lexical-binding: t; -*-
;;; Commentary:
;;; Whitespace cleanup and visual aids.
;;; Code:
;;; buffer-local 策略 ?

(require 'kernel-lib)

(defgroup my/editor-whitespace nil
  "Whitespace hygiene."
  :group 'editing)

(defcustom my/editor-enable-ws-butler t
  "Whether to use ws-butler if installed."
  :type 'boolean
  :group 'my/editor-whitespace)

(defcustom my/editor-enable-fill-column-indicator t
  "Whether to display fill-column indicator in programming buffers."
  :type 'boolean
  :group 'my/editor-whitespace)

(defcustom my/editor-show-trailing-whitespace-in-prog t
  "Whether to show trailing whitespace in programming buffers."
  :type 'boolean
  :group 'my/editor-whitespace)

(defun my/editor--prog-whitespace-hook ()
  "Apply whitespace policy in programming buffers."
  (setq-local show-trailing-whitespace my/editor-show-trailing-whitespace-in-prog)
  (when my/editor-enable-fill-column-indicator
    (display-fill-column-indicator-mode 1)))

(defun my/editor--text-whitespace-hook ()
  "Apply whitespace policy in text buffers."
  (setq-local show-trailing-whitespace nil)
  (when my/editor-enable-fill-column-indicator
    (display-fill-column-indicator-mode 1)
    (setq-local truncate-lines nil)))

(defun my/editor--ws-butler-init ()
  "Configure ws-butler if available."
  (when (and my/editor-enable-ws-butler
             (require 'ws-butler nil t))
    (add-hook 'prog-mode-hook #'ws-butler-mode)
    (add-hook 'text-mode-hook #'ws-butler-mode)))

(defun my/editor--fallback-cleanup-init ()
  "Install conservative fallback cleanup if ws-butler is unavailable."
  (unless (featurep 'ws-butler)
    (add-hook
     'before-save-hook
     (lambda ()
       (when (derived-mode-p 'prog-mode)
         (delete-trailing-whitespace))))))

(defun my/editor--hooks-init ()
  "Install whitespace hooks."
  (add-hook 'prog-mode-hook #'my/editor--prog-whitespace-hook)
  (add-hook 'text-mode-hook #'my/editor--text-whitespace-hook))

(defun my/editor-whitespace-init ()
  "Initialize whitespace hygiene."
  (my/editor--ws-butler-init)
  (my/editor--fallback-cleanup-init)
  (my/editor--hooks-init))

(provide 'editor-whitespace)
;;; editor-whitespace.el ends here
