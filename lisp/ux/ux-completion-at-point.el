;;; ux-completion-at-point.el --- In-buffer completion UX -*- lexical-binding: t; -*-
;;; Commentary:
;;; Modern in-buffer completion stack:
;;; - corfu
;;; - cape
;;; Built on standard CAPF for maximal composability.
;;; Code:

(require 'kernel-lib)

(defgroup my/ux-completion-at-point nil
  "In-buffer completion UX."
  :group 'my/features)

(defcustom my/corfu-auto t
  "Whether Corfu should auto popup."
  :type 'boolean
  :group 'my/ux-completion-at-point)

(defcustom my/corfu-auto-delay 0.12
  "Delay before Corfu auto popup."
  :type 'number
  :group 'my/ux-completion-at-point)

(defcustom my/corfu-auto-prefix 2
  "Minimum prefix length for Corfu auto popup."
  :type 'integer
  :group 'my/ux-completion-at-point)

(defcustom my/corfu-cycle t
  "Whether Corfu should cycle candidates."
  :type 'boolean
  :group 'my/ux-completion-at-point)

(defun my/ux-completion-at-point--corfu-enable-in-minibuffer ()
  "Enable Corfu in minibuffer when completion is active."
  (when (where-is-internal #'completion-at-point (list (current-local-map)))
    (setq-local corfu-auto nil)
    (corfu-mode 1)))

(defun my/ux-completion-at-point--capf-setup ()
  "Augment standard CAPF stack with Cape."
  ;; Keep dabbrev / file / keyword helpers broadly available.
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-keyword))

(defun my/ux-completion-at-point--corfu-init ()
  "Initialize Corfu."
  (use-package corfu
    :ensure t
    :custom
    (corfu-auto my/corfu-auto)
    (corfu-auto-delay my/corfu-auto-delay)
    (corfu-auto-prefix my/corfu-auto-prefix)
    (corfu-cycle my/corfu-cycle)
    (corfu-quit-at-boundary 'separator)
    (corfu-quit-no-match 'separator)
    (corfu-preview-current nil)
    :bind
    (:map corfu-map
          ("M-SPC" . corfu-insert-separator)
          ("TAB"   . corfu-next)
          ([tab]   . corfu-next)
          ("S-TAB" . corfu-previous)
          ([backtab] . corfu-previous))
    :init
    (global-corfu-mode 1)
    (add-hook 'minibuffer-setup-hook
              #'my/ux-completion-at-point--corfu-enable-in-minibuffer)))

(defun my/ux-completion-at-point--cape-init ()
  "Initialize Cape."
  (use-package cape
    :ensure t
    :init
    (my/ux-completion-at-point--capf-setup)))

(defun my/ux-completion-at-point-init ()
  "Initialize in-buffer completion-at-point UX subsystem."
  (my/ux-completion-at-point--corfu-init)
  (my/ux-completion-at-point--cape-init)
  t)

(provide 'ux-completion-at-point)
;;; ux-completion-at-point.el ends here
