;;; core-encoding.el --- Encoding defaults -*- lexical-binding: t; -*-

(defun my/core-encoding-init ()
  "Set UTF-8 as default encoding policy."
  (prefer-coding-system 'utf-8-unix)
  (set-default-coding-systems 'utf-8-unix)
  (set-terminal-coding-system 'utf-8-unix)
  (set-keyboard-coding-system 'utf-8-unix)
  (setq locale-coding-system 'utf-8-unix))

(provide 'core-encoding)
