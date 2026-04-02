;;; core-keymap.el --- Global keymap strategy -*- lexical-binding: t; -*-

(defvar my/leader-map (make-sparse-keymap)
  "Leader keymap for custom commands.")

(defun my/core-keymap-init ()
  "Initialize global key bindings."
  ;; Example leader prefix: C-c m
  (define-key global-map (kbd "C-c m") my/leader-map)

  ;; Quality-of-life defaults
  (global-set-key (kbd "<escape>") #'keyboard-escape-quit)
  (global-set-key (kbd "M-o") #'other-window))

(provide 'core-keymap)
