;;; core-env.el --- Environment normalization -*- lexical-binding: t; -*-

(defun my/core-env-init ()
  "Normalize environment settings."
  ;; Keep process output performant.
  (setq read-process-output-max (* 1024 1024)) ; 1MB

  ;; Prefer y/n.
  (fset 'yes-or-no-p 'y-or-n-p))

(provide 'core-env)
