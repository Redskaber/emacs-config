;;; editor-basics.el --- Basic editing defaults -*- lexical-binding: t; -*-
;;; Commentary:
;;; Language-agnostic core editing behaviors and sane defaults.
;;; Code:

(require 'kernel-lib)

(defgroup my/editor-basics nil
  "Basic editing defaults."
  :group 'editing)

(defcustom my/editor-enable-auto-revert t
  "Whether to enable global auto-revert."
  :type 'boolean
  :group 'my/editor-basics)

(defcustom my/editor-enable-save-place t
  "Whether to persist point position in files."
  :type 'boolean
  :group 'my/editor-basics)

(defcustom my/editor-large-file-warning-size (* 25 1024 1024)
  "Warn when opening files larger than this size in bytes."
  :type 'integer
  :group 'my/editor-basics)

(defun my/editor--sensible-defaults-init ()
  "Apply sensible built-in editing defaults."
  (setq-default
   indent-tabs-mode nil
   tab-width 4
   fill-column 80
   truncate-lines t
   truncate-partial-width-windows t
   sentence-end-double-space nil
   require-final-newline t
   word-wrap nil
   cursor-in-non-selected-windows nil)

  (setq
   use-short-answers t
   read-extended-command-predicate #'command-completion-default-include-p
   save-interprogram-paste-before-kill t
   kill-do-not-save-duplicates t
   set-mark-command-repeat-pop t
   next-line-add-newlines nil
   make-backup-files nil
   auto-save-default nil
   create-lockfiles nil
   confirm-kill-processes nil
   ring-bell-function #'ignore
   visible-bell nil))

(defun my/editor--selection-replace-init ()
  "Enable replacing active region by typing."
  (delete-selection-mode 1))

(defun my/editor--auto-revert-init ()
  "Enable file auto-revert."
  (when my/editor-enable-auto-revert
    (setq global-auto-revert-non-file-buffers t
          auto-revert-verbose nil)
    (global-auto-revert-mode 1)))

(defun my/editor--save-place-init ()
  "Enable save-place."
  (when my/editor-enable-save-place
    (save-place-mode 1)))

(defun my/editor--savehist-builtins-init ()
  "Enable built-in minibuffer history persistence."
  (savehist-mode 1)
  (recentf-mode 1))

(defun my/editor--large-file-guard ()
  "Guard against opening very large files."
  (when (and buffer-file-name
             (file-exists-p buffer-file-name))
    (let ((attrs (file-attributes buffer-file-name)))
      (when (and attrs
                 (numberp (file-attribute-size attrs))
                 (> (file-attribute-size attrs) my/editor-large-file-warning-size))
        (setq-local bidi-display-reordering nil)
        (setq-local buffer-read-only t)
        (setq-local so-long-threshold 1000)))))

(defun my/editor--long-line-protection-init ()
  "Enable long-line mitigation."
  (global-so-long-mode 1)
  (add-hook 'find-file-hook #'my/editor--large-file-guard))

(defun my/editor-basics-init ()
  "Initialize basic editor defaults."
  (my/editor--sensible-defaults-init)
  (my/editor--selection-replace-init)
  (my/editor--auto-revert-init)
  (my/editor--save-place-init)
  (my/editor--savehist-builtins-init)
  (my/editor--long-line-protection-init))

(provide 'editor-basics)
;;; editor-basics.el ends here
