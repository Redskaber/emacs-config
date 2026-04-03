;;; vcs-core.el --- Core VCS workflow policy -*- lexical-binding: t; -*-
;;; Commentary:
;;; Built-in VC behavior, Git defaults, and buffer refresh strategy.
;;; Code:

(require 'vc)
(require 'autorevert)

(defgroup my/vcs nil
  "Version control workflow."
  :group 'tools)

(defcustom my/vcs-enable-auto-revert t
  "Whether to enable auto-revert for file and VC buffers."
  :type 'boolean
  :group 'my/vcs)

(defcustom my/vcs-follow-symlinks t
  "Whether to silently follow symlinks to versioned files."
  :type 'boolean
  :group 'my/vcs)

(defcustom my/vcs-make-backup-files nil
  "Whether to create backup files in version-controlled files."
  :type 'boolean
  :group 'my/vcs)

(defcustom my/vcs-create-lockfiles nil
  "Whether to create lockfiles."
  :type 'boolean
  :group 'my/vcs)

(defun my/vcs--setup-vc ()
  "Configure built-in VC."
  ;; Prefer Git, keep VC available for file state in mode line / xref integrations.
  (setq vc-follow-symlinks my/vcs-follow-symlinks
        vc-handled-backends '(Git)
        make-backup-files my/vcs-make-backup-files
        create-lockfiles my/vcs-create-lockfiles))

(defun my/vcs--setup-auto-revert ()
  "Configure auto-revert for VCS workflows."
  (when my/vcs-enable-auto-revert
    (setq auto-revert-verbose nil
          auto-revert-check-vc-info t
          global-auto-revert-non-file-buffers t)
    (global-auto-revert-mode 1)))

(defun my/vcs-core-init ()
  "Initialize core VCS policy."
  (my/vcs--setup-vc)
  (my/vcs--setup-auto-revert))

(provide 'vcs-core)
;;; vcs-core.el ends here
