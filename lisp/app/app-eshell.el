;;; app-eshell.el --- Eshell workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Built-in shell UX tuned for project-centric workflows.
;;; Code:

(require 'eshell)
(require 'em-hist)
(require 'em-smart)

(defgroup my/app-eshell nil
  "Eshell workflow."
  :group 'shell)

(defcustom my/app-eshell-history-size 5000
  "Maximum Eshell history size."
  :type 'integer
  :group 'my/app-eshell)

(defun my/app-eshell--setup-core ()
  "Configure Eshell defaults."
  (setq eshell-history-size my/app-eshell-history-size
        eshell-hist-ignoredups t
        eshell-scroll-to-bottom-on-input t
        eshell-scroll-to-bottom-on-output t
        eshell-destroy-buffer-when-process-dies t
        eshell-buffer-maximum-lines 10000))

(defun my/app-eshell-here ()
  "Open Eshell in current project root or current directory."
  (interactive)
  (let ((default-directory
         (or (when (fboundp 'project-current)
               (when-let ((pr (project-current nil)))
                 (project-root pr)))
             default-directory)))
    (eshell t)))

(defun my/app-eshell-init ()
  "Initialize Eshell workflow."
  (my/app-eshell--setup-core)
  (global-set-key (kbd "C-c e") #'my/app-eshell-here))

(provide 'app-eshell)
;;; app-eshell.el ends here
