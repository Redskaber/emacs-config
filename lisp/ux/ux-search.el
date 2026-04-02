;;; ux-search.el --- Search UX workflows -*- lexical-binding: t; -*-
;;; Commentary:
;;; Search-oriented UX workflows built on Consult.
;;; This layer focuses on interactive command ergonomics and keeps
;;; project policy separate from project/* modules.
;;; Code:

(require 'core-lib)

(defgroup my/ux-search nil
  "Search UX workflows."
  :group 'my/features)

(defun my/ux-search-ripgrep-project ()
  "Run `consult-ripgrep' in current project or fallback to current directory."
  (interactive)
  (let ((root (when-let ((proj (project-current nil)))
                (project-root proj))))
    (consult-ripgrep (or root default-directory))))

(defun my/ux-search-find-project ()
  "Run `consult-find' in current project or fallback to current directory."
  (interactive)
  (let ((root (when-let ((proj (project-current nil)))
                (project-root proj))))
    (consult-find (or root default-directory))))

(defun my/ux-search-grep-symbol-at-point ()
  "Search symbol at point in project via `consult-ripgrep'."
  (interactive)
  (let* ((root (when-let ((proj (project-current nil)))
                 (project-root proj)))
         (thing (thing-at-point 'symbol t)))
    (consult-ripgrep (or root default-directory) thing)))

(defun my/ux-search-buffer-outline ()
  "Jump to current buffer outline via `consult-outline'."
  (interactive)
  (consult-outline))

(defun my/ux-search-init ()
  "Initialize search UX subsystem."
  ;; Bindings here intentionally focus on workflow wrappers.
  (global-set-key (kbd "M-s p g") #'my/ux-search-ripgrep-project)
  (global-set-key (kbd "M-s p f") #'my/ux-search-find-project)
  (global-set-key (kbd "M-s p s") #'my/ux-search-grep-symbol-at-point)
  (global-set-key (kbd "M-s o")   #'my/ux-search-buffer-outline)
  t)

(provide 'ux-search)
;;; ux-search.el ends here
