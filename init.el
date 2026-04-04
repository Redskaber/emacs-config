;;; init.el --- Main entrypoint -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin entrypoint. Only path bootstrap + pipeline orchestration.
;;; Code:

(defconst my/emacs-start-time (current-time)
  "Timestamp captured at the beginning of init.")

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file nil 'nomessage))

(let ((lisp-dir (expand-file-name "lisp/" user-emacs-directory)))
  (add-to-list 'load-path lisp-dir)
  (dolist (subdir '("bootstrap" "platform" "kernel" "runtime" "manifest"))
    (add-to-list 'load-path (expand-file-name subdir lisp-dir))))

(require 'init-pipeline)
(my/init-run)

;;; init.el ends here
