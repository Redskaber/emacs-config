;;; project-test.el --- Project test workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Project-local test commands with overridable providers.
;;; Code:

(require 'compile)
(require 'subr-x)

(require 'project-core)
(require 'kernel-logging)

(defgroup my/project-test nil
  "Project test workflow."
  :group 'my/project)

(defcustom my/project-test-command-alist
  '(("Cargo.toml" . "cargo test")
    ("go.mod" . "go test ./...")
    ("package.json" . "npm test")
    ("flake.nix" . "nix flake check")
    ("Makefile" . "make test")
    ("makefile" . "make test")
    ("Justfile" . "just test"))
  "Project test command detectors by marker file."
  :type '(alist :key-type string :value-type string))

(defvar-local my/project-test-command nil
  "Buffer-local override for project test command.")

(defvar my/project-test-command-provider-functions nil
  "Hook-like list of functions that return a test command string or nil.

Each function is called with one argument ROOT.")

(defun my/project-test--root ()
  "Return test root."
  (my/project-root-or-default))

(defun my/project-test--detect-by-files (root)
  "Detect test command from ROOT marker files."
  (catch 'found
    (dolist (entry my/project-test-command-alist)
      (let ((marker (car entry))
            (cmd (cdr entry)))
        (when (file-exists-p (expand-file-name marker root))
          (throw 'found cmd))))
    nil))

(defun my/project-test--from-providers (root)
  "Get test command from provider functions for ROOT."
  (catch 'found
    (dolist (fn my/project-test-command-provider-functions)
      (when (functionp fn)
        (let ((cmd (funcall fn root)))
          (when (and (stringp cmd) (not (string-empty-p cmd)))
            (throw 'found cmd)))))
    nil))

(defun my/project-test-default-command ()
  "Return default test command for current project."
  (let ((root (my/project-test--root)))
    (or my/project-test-command
        (my/project-test--from-providers root)
        (my/project-test--detect-by-files root)
        "echo 'No test command configured for this project'")))

(defun my/project-test (&optional edit)
  "Run tests for current project.
With prefix EDIT, prompt for command."
  (interactive "P")
  (let* ((default-directory (my/project-test--root))
         (default-cmd (my/project-test-default-command))
         (command (if edit
                      (read-shell-command "Test command: " default-cmd)
                    default-cmd)))
    (compile command)))

(defun my/project-set-test-command (command)
  "Set project-local test COMMAND for current session."
  (interactive "sSet project test command: ")
  (setq-local my/project-test-command command)
  (my/log-info "Project test command set: %s" command))

(defun my/project-test-file ()
  "Run test command for current file if a provider exists, else fallback."
  (interactive)
  ;; 这里先做语言无关 fallback。
  ;; 真正的 file-level test 细节建议由 lang 层 provider 注入。
  (call-interactively #'my/project-test))

(defun my/project-test-init ()
  "Initialize project test workflow."
  (define-key my/project-mode-map (kbd "C-c p t") #'my/project-test)
  (define-key my/project-mode-map (kbd "C-c p T") (lambda ()
                                                    (interactive)
                                                    (my/project-test t)))
  (define-key my/project-mode-map (kbd "C-c p v") #'my/project-test-file)
  (define-key my/project-mode-map (kbd "C-c p -") #'my/project-set-test-command)
  (my/log-info "project-test initialized."))

(provide 'project-test)
;;; project-test.el ends here
