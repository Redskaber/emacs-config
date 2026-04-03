;;; editor-selection.el --- Region and selection ergonomics -*- lexical-binding: t; -*-
;;; Commentary:
;;; Better selection workflows, region expansion, and multiple cursors.
;;; Code:
;;; global-set-key to core-keymap.el ?

(require 'core-lib)

(defgroup my/editor-selection nil
  "Selection ergonomics."
  :group 'editing)

(defcustom my/editor-enable-expand-region t
  "Whether to enable expand-region if installed."
  :type 'boolean
  :group 'my/editor-selection)

(defcustom my/editor-enable-multiple-cursors t
  "Whether to enable multiple-cursors if installed."
  :type 'boolean
  :group 'my/editor-selection)

(defun my/editor--transient-mark-init ()
  "Enable modern region UX."
  (transient-mark-mode 1)
  (setq mark-even-if-inactive nil
        set-mark-command-repeat-pop t))

(defun my/editor--expand-region-init ()
  "Configure expand-region."
  (when (and my/editor-enable-expand-region
             (require 'expand-region nil t))
    (global-set-key (kbd "C-=") #'er/expand-region)
    (global-set-key (kbd "C--") #'er/contract-region)))

(defun my/editor--multiple-cursors-init ()
  "Configure multiple-cursors."
  (when (and my/editor-enable-multiple-cursors
             (require 'multiple-cursors nil t))
    (global-set-key (kbd "C-S-c C-S-c") #'mc/edit-lines)
    (global-set-key (kbd "C->") #'mc/mark-next-like-this)
    (global-set-key (kbd "C-<") #'mc/mark-previous-like-this)
    (global-set-key (kbd "C-c C-<") #'mc/mark-all-like-this)))

(defun my/editor-selection-init ()
  "Initialize selection ergonomics."
  (my/editor--transient-mark-init)
  (my/editor--expand-region-init)
  (my/editor--multiple-cursors-init))

(provide 'editor-selection)
;;; editor-selection.el ends here
