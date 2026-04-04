;;; kernel-hooks.el --- Hook registration helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;; Global hooks.
;;; Code:

(defun my/kernel-hooks-init ()
  "Initialize global hooks."
  (add-hook 'focus-out-hook #'garbage-collect))

(provide 'kernel-hooks)
;;; kernel-hooks.el ends here
