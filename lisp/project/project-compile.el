;;; project-compile.el --- Project compile workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Project-local compile commands with overridable providers.
;;; Code:

(require 'compile)
(require 'subr-x)

(require 'project-core)
(require 'kernel-logging)

(defgroup my/project-compile nil
  "Project compile workflow."
  :group 'my/project)

(defcustom my/project-compile-command-alist
  '(("Cargo.toml" . "cargo build")
    ("go.mod" . "go build ./...")
    ("package.json" . "npm run build")
    ("flake.nix" . "nix build")
    ("Makefile" . "make -k")
    ("makefile" . "make -k")
    ("Justfile" . "just build"))
  "Project compile command detectors by marker file."
  :type '(alist :key-type string :value-type string))

(defvar-local my/project-compile-command nil
  "Buffer-local override for project compile command.")

(defvar my/project-compile-command-provider-functions nil
  "Hook-like list of functions that return a compile command string or nil.

Each function is called with one argument ROOT.")

(defun my/project-compile--root ()
  "Return compile root."
  (my/project-root-or-default))

(defun my/project-compile--detect-by-files (root)
  "Detect compile command from ROOT marker files."
  (catch 'found
    (dolist (entry my/project-compile-command-alist)
      (let ((marker (car entry))
            (cmd (cdr entry)))
        (when (file-exists-p (expand-file-name marker root))
          (throw 'found cmd))))
    nil))

(defun my/project-compile--from-providers (root)
  "Get compile command from provider functions for ROOT."
  (catch 'found
    (dolist (fn my/project-compile-command-provider-functions)
      (when (functionp fn)
        (let ((cmd (funcall fn root)))
          (when (and (stringp cmd) (not (string-empty-p cmd)))
            (throw 'found cmd)))))
    nil))

(defun my/project-compile-default-command ()
  "Return default compile command for current project."
  (let ((root (my/project-compile--root)))
    (or my/project-compile-command
        (my/project-compile--from-providers root)
        (my/project-compile--detect-by-files root)
        compile-command)))

(defun my/project-compile (&optional edit)
  "Compile current project.
With prefix EDIT, prompt for command."
  (interactive "P")
  (let* ((default-directory (my/project-compile--root))
         (compile-command (my/project-compile-default-command))
         (command (if edit
                      (read-shell-command "Compile command: " compile-command)
                    compile-command)))
    (compile command)))

(defun my/project-recompile ()
  "Re-run last compile command."
  (interactive)
  (let ((default-directory (my/project-compile--root)))
    (recompile)))

(defun my/project-set-compile-command (command)
  "Set project-local compile COMMAND for current session."
  (interactive "sSet project compile command: ")
  (setq-local my/project-compile-command command)
  (my/log "Project compile command set: %s" command))

(defun my/project-compile-init ()
  "Initialize project compile workflow."
  (define-key my/project-mode-map (kbd "C-c p c") #'my/project-compile)
  (define-key my/project-mode-map (kbd "C-c p C") (lambda ()
                                                    (interactive)
                                                    (my/project-compile t)))
  (define-key my/project-mode-map (kbd "C-c p R") #'my/project-recompile)
  (define-key my/project-mode-map (kbd "C-c p =") #'my/project-set-compile-command)
  (my/log "project-compile initialized."))

(provide 'project-compile)
;;; project-compile.el ends here
