;;; core-hooks.el --- Hook registration helpers -*- lexical-binding: t; -*-

(defun my/core-hooks-init ()
  "Initialize global hooks."
  ;; Keep runtime GC reasonable when focus changes.
  (add-hook 'focus-out-hook #'garbage-collect))

(provide 'core-hooks)
