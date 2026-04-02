;;; init.el --- Main entrypoint -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin entrypoint. Only path bootstrap + pipeline orchestration.
;;; Code:

(defconst my/emacs-start-time (current-time)
  "Timestamp captured at the beginning of init.")

;; Keep Custom out of init.el.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file nil 'nomessage))

;; Add local lisp roots.
(let ((default-directory (expand-file-name "lisp/" user-emacs-directory)))
  (add-to-list 'load-path default-directory)
  (add-to-list 'load-path (expand-file-name "bootstrap" default-directory))
  (add-to-list 'load-path (expand-file-name "platform" default-directory))
  (add-to-list 'load-path (expand-file-name "core" default-directory)))

(require 'init-pipeline)

(my/init-run)

;;; init.el ends here
