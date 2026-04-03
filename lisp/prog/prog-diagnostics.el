;;; prog-diagnostics.el --- Diagnostics and error UX -*- lexical-binding: t; -*-
;;; Commentary:
;;; Flymake-first diagnostics strategy for Emacs 30.
;;; Code:

(require 'flymake)

(defgroup my/prog-diagnostics nil
  "Diagnostics and error presentation."
  :group 'my/prog)

(defcustom my/prog-diagnostics-enable-flymake t
  "Whether to enable Flymake in programming buffers."
  :type 'boolean)

(defun my/prog-diagnostics--setup-flymake ()
  "Configure Flymake."
  (when my/prog-diagnostics-enable-flymake
    (setq flymake-fringe-indicator-position 'left-fringe
          flymake-suppress-zero-counters t
          flymake-no-changes-timeout 0.5
          flymake-start-on-flymake-mode t
          flymake-show-diagnostics-at-end-of-line nil)
    (add-hook 'prog-mode-hook #'flymake-mode)))

(defun my/prog-diagnostics-init ()
  "Initialize diagnostics UX."
  (my/prog-diagnostics--setup-flymake)
  (global-set-key (kbd "M-g n") #'flymake-goto-next-error)
  (global-set-key (kbd "M-g p") #'flymake-goto-prev-error)
  (global-set-key (kbd "C-c ! l") #'flymake-show-buffer-diagnostics)
  (global-set-key (kbd "C-c ! p") #'flymake-show-project-diagnostics))

(provide 'prog-diagnostics)
;;; prog-diagnostics.el ends here
