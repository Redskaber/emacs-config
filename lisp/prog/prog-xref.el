;;; prog-xref.el --- Cross-reference and navigation -*- lexical-binding: t; -*-
;;; Commentary:
;;; Xref UX, with optional consult and dumb-jump enhancements.
;;; Code:

(require 'xref)

(defgroup my/prog-xref nil
  "Cross-reference and code navigation."
  :group 'my/prog)

(defun my/prog-xref--setup-core ()
  "Configure core xref behavior."
  (setq xref-search-program
        (cond
         ((executable-find "rg") 'ripgrep)
         ((executable-find "ugrep") 'ugrep)
         ((executable-find "grep") 'grep)
         (t 'grep))))

(defun my/prog-xref--setup-consult ()
  "Use consult-backed xref UI when available."
  (when (require 'consult nil t)
    (setq xref-show-xrefs-function #'consult-xref
          xref-show-definitions-function #'consult-xref)))

(defun my/prog-xref--setup-dumb-jump ()
  "Fallback xref backend via dumb-jump."
  (use-package dumb-jump
    :defer t
    :init
    (add-hook 'xref-backend-functions #'dumb-jump-xref-activate 95)))

(defun my/prog-xref-init ()
  "Initialize xref and navigation."
  (my/prog-xref--setup-core)
  (my/prog-xref--setup-consult)
  (my/prog-xref--setup-dumb-jump)
  (global-set-key (kbd "M-.") #'xref-find-definitions)
  (global-set-key (kbd "M-,") #'xref-go-back)
  (global-set-key (kbd "M-?") #'xref-find-references))

(provide 'prog-xref)
;;; prog-xref.el ends here
