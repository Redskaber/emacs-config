;;; app-dired.el --- Dired as file manager -*- lexical-binding: t; -*-
;;; Commentary:
;;; Opinionated Dired UX with modern defaults.
;;; Code:

(require 'dired)
(require 'dired-x)

(defgroup my/app-dired nil
  "Dired application workflow."
  :group 'files)

(defcustom my/app-dired-listing-switches "-alh --group-directories-first"
  "Preferred Dired listing switches."
  :type 'string
  :group 'my/app-dired)

(defun my/app-dired--setup-core ()
  "Configure Dired defaults."
  (setq dired-listing-switches my/app-dired-listing-switches
        dired-dwim-target t
        dired-kill-when-opening-new-dired-buffer t
        delete-by-moving-to-trash t
        dired-auto-revert-buffer #'dired-directory-changed-p))

(defun my/app-dired--setup-aux ()
  "Configure optional Dired helpers."
  (put 'dired-find-alternate-file 'disabled nil)
  (add-hook 'dired-mode-hook #'dired-hide-details-mode))

(defun my/app-dired-open-config ()
  "Open current Emacs config root in Dired."
  (interactive)
  (dired user-emacs-directory))

(defun my/app-dired-init ()
  "Initialize Dired application workflow."
  (my/app-dired--setup-core)
  (my/app-dired--setup-aux)
  (global-set-key (kbd "C-x C-j") #'dired-jump)
  (global-set-key (kbd "C-x C-p") #'my/app-dired-open-config))

(provide 'app-dired)
;;; app-dired.el ends here
