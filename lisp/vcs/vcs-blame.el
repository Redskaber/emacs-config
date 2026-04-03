;;; vcs-blame.el --- Blame / annotate workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Unified blame entrypoint with optional blamer overlay support.
;;; Code:

(require 'vc-annotate)

(defgroup my/vcs-blame nil
  "Blame and annotate workflow."
  :group 'my/vcs)

(defcustom my/vcs-blame-enable-inline t
  "Whether to enable inline blame overlays when available."
  :type 'boolean)

(defun my/vcs-blame-line ()
  "Blame current line using best available backend."
  (interactive)
  (cond
   ((fboundp 'blamer-show-commit-info)
    (blamer-show-commit-info))
   ((fboundp 'magit-blame-addition)
    (magit-blame-addition))
   (t
    (call-interactively #'vc-annotate))))

(defun my/vcs-blame--setup-inline ()
  "Configure optional inline blame overlays."
  (when my/vcs-blame-enable-inline
    (use-package blamer
      :defer t
      :commands (blamer-mode blamer-show-commit-info)
      :hook (prog-mode . blamer-mode)
      :init
      (setq blamer-idle-time 0.5
            blamer-min-offset 40
            blamer-max-commit-message-length 100))))

(defun my/vcs-blame-init ()
  "Initialize blame workflow."
  (global-set-key (kbd "C-c v b") #'my/vcs-blame-line)
  (my/vcs-blame--setup-inline))

(provide 'vcs-blame)
;;; vcs-blame.el ends here
