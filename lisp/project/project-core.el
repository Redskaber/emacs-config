;;; project-core.el --- Core project workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Language-agnostic project primitives built on top of project.el.
;;; Code:

(require 'project)
(require 'cl-lib)
(require 'subr-x)

(require 'kernel-lib)
(require 'kernel-logging)
(require 'kernel-keymap)

(defgroup my/project nil
  "Project workflow."
  :group 'convenience)

(defcustom my/project-known-roots nil
  "Additional project roots to register or consider."
  :type '(repeat directory))

(defcustom my/project-switch-action #'project-find-file
  "Default action after switching to a project."
  :type 'function)

(defvar my/project-mode-map (make-sparse-keymap)
  "Keymap for `my/project-mode'.")

;;;###autoload
(define-minor-mode my/project-mode
  "Global project workflow mode."
  :global t
  :lighter " MyProj"
  :keymap my/project-mode-map)

(defun my/project-current ()
  "Return current project instance or nil."
  (ignore-errors (project-current)))

(defun my/project-root (&optional project)
  "Return root directory for PROJECT or current project."
  (when-let* ((pr (or project (my/project-current))))
    (expand-file-name (project-root pr))))

(defun my/project-root-or-default ()
  "Return project root or `default-directory'."
  (or (my/project-root) default-directory))

(defun my/project-name (&optional project)
  "Return a human-readable name for PROJECT."
  (let ((root (my/project-root project)))
    (if root
        (file-name-nondirectory (directory-file-name root))
      "no-project")))

(defun my/project-in-project-p ()
  "Return non-nil if current buffer is in a project."
  (not (null (my/project-current))))

(defun my/project-switch ()
  "Switch project and run `my/project-switch-action'."
  (interactive)
  (if (fboundp 'project-switch-project)
      (let ((project-switch-commands
             `((?f "Find file" ,#'project-find-file)
               (?d "Dired" ,#'project-dired)
               (?s "Search" ,#'project-find-regexp)
               (?g "VC Dir" ,#'project-vc-dir)
               (?c "Compile" ,#'project-compile))))
        (call-interactively #'project-switch-project))
    (user-error "project-switch-project is unavailable")))

(defun my/project-find-file ()
  "Find file in current project."
  (interactive)
  (if (my/project-in-project-p)
      (call-interactively #'project-find-file)
    (call-interactively #'find-file)))

(defun my/project-dired ()
  "Open project root in Dired."
  (interactive)
  (dired (my/project-root-or-default)))

(defun my/project-forget-zombie-projects ()
  "Remove non-existing projects from `project--list'."
  (interactive)
  (when (boundp 'project--list)
    (setq project--list
          (cl-remove-if-not #'file-directory-p project--list))
    (my/log "Cleaned stale entries in project list.")))

(defun my/project-browse-root ()
  "Browse project root in file manager / Dired."
  (interactive)
  (my/project-dired))

(defun my/project-eshell-here ()
  "Open Eshell in project root."
  (interactive)
  (let ((default-directory (my/project-root-or-default)))
    (if (fboundp 'eshell)
        (eshell t)
      (user-error "Eshell is unavailable"))))

(defun my/project-shell-command (command)
  "Run shell COMMAND at project root."
  (interactive "sProject shell command: ")
  (let ((default-directory (my/project-root-or-default)))
    (async-shell-command command)))

(defun my/project-register-keybindings ()
  "Register project keybindings."
  ;; 建议你最终统一挂到 kernel-keymap leader 上；这里先提供兜底。
  (define-key my/project-mode-map (kbd "C-c p p") #'my/project-switch)
  (define-key my/project-mode-map (kbd "C-c p f") #'my/project-find-file)
  (define-key my/project-mode-map (kbd "C-c p d") #'my/project-dired)
  (define-key my/project-mode-map (kbd "C-c p r") #'my/project-browse-root)
  (define-key my/project-mode-map (kbd "C-c p !") #'my/project-shell-command)
  (define-key my/project-mode-map (kbd "C-c p e") #'my/project-eshell-here))

(defun my/project-core-init ()
  "Initialize project core."
  (my/project-register-keybindings)
  (my/project-mode 1)
  (my/log "project-core initialized."))

(provide 'project-core)
;;; project-core.el ends here
