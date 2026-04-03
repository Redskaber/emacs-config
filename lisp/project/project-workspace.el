;;; project-workspace.el --- Project workspace integration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Workspace / tab integration for projects using built-in tab-bar.
;;; Code:

(require 'tab-bar)
(require 'subr-x)

(require 'project-core)
(require 'core-logging)

(defgroup my/project-workspace nil
  "Project workspace integration."
  :group 'my/project)

(defcustom my/project-workspace-auto-rename-tab t
  "Rename tab to project name when entering project workspace."
  :type 'boolean)

(defun my/project-workspace-name (&optional project)
  "Return workspace name for PROJECT."
  (format "P:%s" (my/project-name project)))

(defun my/project-workspace-open ()
  "Open current project in a new tab workspace."
  (interactive)
  (let* ((root (my/project-root-or-default))
         (name (my/project-workspace-name)))
    (tab-bar-new-tab)
    (when my/project-workspace-auto-rename-tab
      (tab-bar-rename-tab name))
    (let ((default-directory root))
      (call-interactively #'my/project-find-file))))

(defun my/project-workspace-switch ()
  "Switch project, then open in a dedicated workspace tab."
  (interactive)
  (let ((project-switch-commands
         `((?f "Find file" ,#'project-find-file)
           (?d "Dired" ,#'project-dired))))
    (call-interactively #'project-switch-project)
    (when (and (my/project-in-project-p) my/project-workspace-auto-rename-tab)
      (tab-bar-rename-tab (my/project-workspace-name)))))

(defun my/project-workspace-rename-to-project ()
  "Rename current tab to current project."
  (interactive)
  (if (my/project-in-project-p)
      (tab-bar-rename-tab (my/project-workspace-name))
    (user-error "Not in a project")))

(defun my/project-workspace-close ()
  "Close current workspace tab."
  (interactive)
  (tab-bar-close-tab))

(defun my/project-workspace-init ()
  "Initialize project workspace integration."
  (tab-bar-mode 1)
  (define-key my/project-mode-map (kbd "C-c p w") #'my/project-workspace-open)
  (define-key my/project-mode-map (kbd "C-c p W") #'my/project-workspace-switch)
  (define-key my/project-mode-map (kbd "C-c p ,") #'my/project-workspace-rename-to-project)
  (define-key my/project-mode-map (kbd "C-c p 0") #'my/project-workspace-close)
  (my/log "project-workspace initialized."))

(provide 'project-workspace)
;;; project-workspace.el ends here
