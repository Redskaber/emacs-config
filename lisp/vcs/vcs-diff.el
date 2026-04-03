;;; vcs-diff.el --- Diff and merge workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Diff highlighting, Ediff ergonomics, and merge conflict helpers.
;;; Code:

(require 'ediff)
(require 'smerge-mode)

(defgroup my/vcs-diff nil
  "Diff and merge workflow."
  :group 'my/vcs)

(defcustom my/vcs-diff-enable-diff-hl t
  "Whether to enable diff-hl when available."
  :type 'boolean)

(defun my/vcs-diff--setup-ediff ()
  "Configure Ediff."
  (setq ediff-window-setup-function #'ediff-setup-windows-plain
        ediff-split-window-function #'split-window-horizontally))

(defun my/vcs-diff--maybe-enable-smerge ()
  "Enable `smerge-mode' when conflict markers are detected."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^<<<<<<< " nil t)
      (smerge-mode 1))))

(defun my/vcs-diff--setup-smerge ()
  "Enable smerge helpers in conflict buffers."
  (add-hook 'find-file-hook #'my/vcs-diff--maybe-enable-smerge))

(defun my/vcs-diff--setup-diff-hl ()
  "Enable diff-hl if installed."
  (when my/vcs-diff-enable-diff-hl
    (use-package diff-hl
      :hook ((prog-mode . diff-hl-mode)
             (text-mode . diff-hl-mode)
             (dired-mode . diff-hl-dired-mode)
             (magit-post-refresh . diff-hl-magit-post-refresh))
      :init
      (setq diff-hl-draw-borders nil
            diff-hl-side 'left))))

(defun my/vcs-diff-init ()
  "Initialize diff and merge workflow."
  (my/vcs-diff--setup-ediff)
  (my/vcs-diff--setup-smerge)
  (my/vcs-diff--setup-diff-hl))

(provide 'vcs-diff)
;;; vcs-diff.el ends here
