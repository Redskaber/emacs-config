;;; ux-actions.el --- Action and context dispatch UX -*- lexical-binding: t; -*-
;;; Commentary:
;;; Contextual actions powered by:
;;; - embark
;;; - embark-consult
;;; Code:

(require 'core-lib)

(defgroup my/ux-actions nil
  "Action and context dispatch UX."
  :group 'my/features)

(defcustom my/feature-ux-embark t
  "Enable Embark action system."
  :type 'boolean
  :group 'my/ux-actions)

(defun my/ux-actions--embark-init ()
  "Initialize Embark."
  (use-package embark
    :ensure t
    :bind (("C-." . embark-act)
           ("C-;" . embark-dwim)
           ("C-h B" . embark-bindings))
    :init
    ;; Prefer completing-read-prompter for compatibility with Vertico.
    (setq prefix-help-command #'embark-prefix-help-command)
    :config
    ;; Hide mode line in Embark collect buffers for cleaner UX.
    (add-hook 'embark-collect-mode-hook
              (lambda ()
                (setq-local mode-line-format nil)))))

(defun my/ux-actions--embark-consult-init ()
  "Initialize Embark-Consult integration."
  (use-package embark-consult
    :ensure t
    :after (embark consult)
    :hook
    (embark-collect-mode . consult-preview-at-point-mode)))

(defun my/ux-actions-init ()
  "Initialize action UX subsystem."
  (when my/feature-ux-embark
    (my/ux-actions--embark-init)
    (my/ux-actions--embark-consult-init))
  t)

(provide 'ux-actions)
;;; ux-actions.el ends here
