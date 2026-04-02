;;; ux-completion-read.el --- Minibuffer completion UX -*- lexical-binding: t; -*-
;;; Commentary:
;;; Modern minibuffer completion stack:
;;; - vertico
;;; - orderless
;;; - marginalia
;;; - consult
;;; Code:

(require 'core-lib)

(defgroup my/ux-completion-read nil
  "Minibuffer completion UX."
  :group 'my/features)

(defcustom my/vertico-cycle t
  "Whether Vertico should cycle candidates."
  :type 'boolean
  :group 'my/ux-completion-read)

(defcustom my/consult-preview-key "M-."
  "Preview key for Consult commands.
Set to nil to disable manual preview key."
  :type '(choice (const :tag "Disabled" nil)
                 string)
  :group 'my/ux-completion-read)

(defun my/ux-completion-read--completion-styles-init ()
  "Configure completion styles."
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides
        '((file (styles partial-completion basic)))))

(defun my/ux-completion-read--vertico-init ()
  "Initialize Vertico."
  (use-package vertico
    :ensure t
    :init
    (setq vertico-cycle my/vertico-cycle)
    (vertico-mode 1)))

(defun my/ux-completion-read--orderless-init ()
  "Initialize Orderless."
  (use-package orderless
    :ensure t
    :init
    (my/ux-completion-read--completion-styles-init)))

(defun my/ux-completion-read--marginalia-init ()
  "Initialize Marginalia."
  (use-package marginalia
    :ensure t
    :after vertico
    :init
    (marginalia-mode 1)))

(defun my/ux-completion-read--consult-init ()
  "Initialize Consult."
  (use-package consult
    :ensure t
    :bind (("C-s"     . consult-line)
           ("C-M-l"   . consult-imenu)
           ("C-x b"   . consult-buffer)
           ("C-x 4 b" . consult-buffer-other-window)
           ("C-x 5 b" . consult-buffer-other-frame)
           ("M-y"     . consult-yank-pop)
           ("M-g g"   . consult-goto-line)
           ("M-g M-g" . consult-goto-line)
           ("M-g i"   . consult-imenu)
           ("M-s l"   . consult-line)
           ("M-s L"   . consult-line-multi)
           ("M-s g"   . consult-ripgrep)
           ("M-s f"   . consult-find)
           ("M-s r"   . consult-recent-file))
    :init
    (when my/consult-preview-key
      (setq consult-preview-key my/consult-preview-key))
    :config
    ;; Use Consult for xref UI if available.
    (setq xref-show-xrefs-function #'consult-xref
          xref-show-definitions-function #'consult-xref)))

(defun my/ux-completion-read-init ()
  "Initialize minibuffer completion-read UX subsystem."
  (my/ux-completion-read--vertico-init)
  (my/ux-completion-read--orderless-init)
  (my/ux-completion-read--marginalia-init)
  (my/ux-completion-read--consult-init)
  t)

(provide 'ux-completion-read)
;;; ux-completion-read.el ends here
