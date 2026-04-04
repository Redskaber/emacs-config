;;; kernel-env.el --- Environment normalization -*- lexical-binding: t; -*-
;;; Commentary:
;;; Global environment defaults.
;;; Code:

(defun my/kernel-env-init ()
  "Normalize environment settings."
  (setq read-process-output-max (* 1024 1024)) ; 1MB
  (fset 'yes-or-no-p 'y-or-n-p))

(provide 'kernel-env)
;;; kernel-env.el ends here
