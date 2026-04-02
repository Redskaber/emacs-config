;;; ux-history.el --- History and recent navigation UX -*- lexical-binding: t; -*-
;;; Commentary:
;;; History persistence and recent navigation:
;;; - savehist
;;; - recentf
;;; Code:

(require 'core-const)
(require 'core-lib)

(defgroup my/ux-history nil
  "History and recent navigation UX."
  :group 'my/features)

(defcustom my/recentf-max-saved-items 300
  "Maximum number of recent files to save."
  :type 'integer
  :group 'my/ux-history)

(defcustom my/recentf-auto-cleanup 'never
  "Auto cleanup policy for Recentf."
  :type '(choice (const :tag "Never" never)
                 (const :tag "Mode" mode)
                 integer)
  :group 'my/ux-history)

(defun my/ux-history--savehist-init ()
  "Initialize Savehist."
  (use-package savehist
    :ensure nil
    :init
    ;; Persist common minibuffer / command histories.
    (setq history-length 200
          savehist-save-minibuffer-history t
          savehist-additional-variables
          '(kill-ring
            search-ring
            regexp-search-ring
            register-alist))
    (savehist-mode 1)))

(defun my/ux-history--recentf-init ()
  "Initialize Recentf."
  (use-package recentf
    :ensure nil
    :init
    (setq recentf-max-saved-items my/recentf-max-saved-items
          recentf-auto-cleanup my/recentf-auto-cleanup
          recentf-save-file (expand-file-name "recentf" my/var-dir))
    :config
    ;; Filter noisy runtime/cache paths.
    (dolist (pattern (list (regexp-quote my/cache-dir)
                           (regexp-quote my/eln-dir)
                           "/tmp/"
                           "/ssh:"))
      (add-to-list 'recentf-exclude pattern))
    (recentf-mode 1)))

(defun my/ux-history-init ()
  "Initialize history UX subsystem."
  (my/ux-history--savehist-init)
  (my/ux-history--recentf-init)
  t)

(provide 'ux-history)
;;; ux-history.el ends here
