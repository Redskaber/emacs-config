;;; editor-folding.el --- Code folding abstraction -*- lexical-binding: t; -*-
;;; Commentary:
;;; Folding strategy with built-in hideshow as default backend.
;;; Code:
;;; global-set-key to core-keymap.el ?


(require 'core-lib)

(defgroup my/editor-folding nil
  "Code folding abstraction."
  :group 'editing)

(defcustom my/editor-enable-hideshow t
  "Whether to enable built-in hideshow in programming buffers."
  :type 'boolean
  :group 'my/editor-folding)

(defcustom my/editor-enable-vimish-fold nil
  "Whether to enable vimish-fold if installed."
  :type 'boolean
  :group 'my/editor-folding)

(defun my/editor-fold-toggle ()
  "Toggle fold at point."
  (interactive)
  (cond
   ((and (bound-and-true-p hs-minor-mode)
         (fboundp 'hs-toggle-hiding))
    (hs-toggle-hiding))
   ((and (featurep 'vimish-fold)
         (fboundp 'vimish-fold-toggle))
    (vimish-fold-toggle))
   (t
    (user-error "No folding backend available"))))

(defun my/editor-fold-hide-all ()
  "Hide all folds."
  (interactive)
  (cond
   ((and (bound-and-true-p hs-minor-mode)
         (fboundp 'hs-hide-all))
    (hs-hide-all))
   (t
    (user-error "No folding backend available"))))

(defun my/editor-fold-show-all ()
  "Show all folds."
  (interactive)
  (cond
   ((and (bound-and-true-p hs-minor-mode)
         (fboundp 'hs-show-all))
    (hs-show-all))
   (t
    (user-error "No folding backend available"))))

(defun my/editor--hideshow-hook ()
  "Enable hideshow in programming buffers."
  (when my/editor-enable-hideshow
    (hs-minor-mode 1)))

(defun my/editor--vimish-fold-init ()
  "Configure vimish-fold if available."
  (when (and my/editor-enable-vimish-fold
             (require 'vimish-fold nil t))
    (vimish-fold-global-mode 1)))

(defun my/editor--bindings-init ()
  "Install folding bindings."
  (global-set-key (kbd "C-c z") #'my/editor-fold-toggle)
  (global-set-key (kbd "C-c Z h") #'my/editor-fold-hide-all)
  (global-set-key (kbd "C-c Z s") #'my/editor-fold-show-all))

(defun my/editor-folding-init ()
  "Initialize code folding abstraction."
  (add-hook 'prog-mode-hook #'my/editor--hideshow-hook)
  (my/editor--vimish-fold-init)
  (my/editor--bindings-init))

(provide 'editor-folding)
;;; editor-folding.el ends here
