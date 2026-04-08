;;; project-search.el --- Project search workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Project-local search with pluggable backends.
;;; Code:

(require 'subr-x)

(require 'project-core)
(require 'kernel-logging)

(defgroup my/project-search nil
  "Project search settings."
  :group 'my/project)

(defcustom my/project-search-prefer-consult t
  "Prefer Consult-based search when available."
  :type 'boolean)

(defcustom my/project-search-ripgrep-command "rg"
  "Ripgrep executable."
  :type 'string)

(defun my/project-search--root ()
  "Return project search root."
  (my/project-root-or-default))

(defun my/project-search--rg-available-p ()
  "Return non-nil if ripgrep is available."
  (executable-find my/project-search-ripgrep-command))

(defun my/project-search--consult-available-p ()
  "Return non-nil if Consult ripgrep is available."
  (fboundp 'consult-ripgrep))

(defun my/project-search ()
  "Search text in current project."
  (interactive)
  (let ((root (my/project-search--root)))
    (cond
     ((and my/project-search-prefer-consult
           (my/project-search--consult-available-p)
           (my/project-search--rg-available-p))
      (consult-ripgrep root))
     ((fboundp 'project-find-regexp)
      (call-interactively #'project-find-regexp))
     (t
      (rgrep (read-string "Search for: ")
             "*"
             root)))))

(defun my/project-search-symbol-at-point ()
  "Search symbol at point in current project."
  (interactive)
  (let* ((root (my/project-search--root))
         (thing (thing-at-point 'symbol t)))
    (unless thing
      (user-error "No symbol at point"))
    (cond
     ((and my/project-search-prefer-consult
           (my/project-search--consult-available-p)
           (my/project-search--rg-available-p))
      (consult-ripgrep root thing))
     ((fboundp 'project-find-regexp)
      (project-find-regexp thing))
     (t
      (rgrep thing "*" root)))))

(defun my/project-search-file ()
  "Find file in current project."
  (interactive)
  (call-interactively #'my/project-find-file))

(defun my/project-search-todo ()
  "Search TODO/FIXME/NOTE markers in current project."
  (interactive)
  (let ((root (my/project-search--root))
        (pattern "TODO|FIXME|BUG|HACK|NOTE|XXX"))
    (cond
     ((and my/project-search-prefer-consult
           (my/project-search--consult-available-p)
           (my/project-search--rg-available-p))
      (consult-ripgrep root pattern))
     ((fboundp 'project-find-regexp)
      (project-find-regexp pattern))
     (t
      (rgrep pattern "*" root)))))

(defun my/project-search-init ()
  "Initialize project search."
  (define-key my/project-mode-map (kbd "C-c p s") #'my/project-search)
  (define-key my/project-mode-map (kbd "C-c p .") #'my/project-search-symbol-at-point)
  (define-key my/project-mode-map (kbd "C-c p /") #'my/project-search-todo)
  (my/log-info "project" "project-search initialized."))

(provide 'project-search)
;;; project-search.el ends here
