;;; prog-build.el --- Build / compile workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Compilation and build orchestration for programming projects.
;;; Code:

(require 'compile)

(require 'ansi-color)

(defgroup my/prog-build nil
  "Build and compile workflow."
  :group 'my/prog)

(defcustom my/prog-build-scroll-output 'first-error
  "Compilation output scrolling behavior."
  :type '(choice (const nil)
                 (const t)
                 (const first-error)))

(defcustom my/prog-build-ask-about-save nil
  "Whether `compile' should ask before saving modified buffers."
  :type 'boolean)

(defun my/prog-build--setup-compile ()
  "Configure compile-mode."
  (setq compilation-scroll-output my/prog-build-scroll-output
        compilation-always-kill t
        compilation-ask-about-save my/prog-build-ask-about-save
        compilation-read-command nil))

(defun my/prog-build--ansi-colorize ()
  "Apply ANSI colors in compilation buffer."
  (when (derived-mode-p 'compilation-mode)
    (ansi-color-apply-on-region compilation-filter-start (point))))

(defun my/prog-build-init ()
  "Initialize build workflow."
  (my/prog-build--setup-compile)
  (add-hook 'compilation-filter-hook #'my/prog-build--ansi-colorize)
  (global-set-key (kbd "C-c c") #'compile)
  (global-set-key (kbd "C-c C-c") #'recompile))

(provide 'prog-build)
;;; prog-build.el ends here
