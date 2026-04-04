;;; kernel-keymap.el --- Global keymap strategy -*- lexical-binding: t; -*-
;;; Commentary:
;;; Global keymap and leader policy.
;;; Code:

(defvar my/leader-map (make-sparse-keymap)
  "Leader keymap for custom commands.")

(defun my/kernel-keymap-init ()
  "Initialize global key bindings."
  (define-key global-map (kbd "C-c m") my/leader-map)
  (global-set-key (kbd "<escape>") #'keyboard-escape-quit)
  (global-set-key (kbd "M-o") #'other-window))

(provide 'kernel-keymap)
;;; kernel-keymap.el ends here
