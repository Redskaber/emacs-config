;;; lang-org.el --- Org adapter -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin glue for Org authoring and note workflows.
;;; Code:

(require 'kernel-const)
(require 'kernel-lib)
(require 'org)

(defgroup my/lang-org nil
  "Org language adapter."
  :group 'my/lang)

(defcustom my/lang-org-directory (expand-file-name "org/" my/var-dir)
  "Default Org workspace directory."
  :type 'directory
  :group 'my/lang-org)

(defun my/lang-org--setup-core ()
  "Configure Org defaults."
  (setq org-directory my/lang-org-directory
        org-startup-indented t
        org-hide-emphasis-markers t
        org-pretty-entities t
        org-return-follows-link nil))

(defun my/lang-org--hook ()
  "Hook for Org buffers."
  (visual-line-mode 1)
  (org-indent-mode 1))

(defun my/lang-org-init ()
  "Initialize Org adapter."
  (my/lang-org--setup-core)
  (add-hook 'org-mode-hook #'my/lang-org--hook))

(provide 'lang-org)
;;; lang-org.el ends here
