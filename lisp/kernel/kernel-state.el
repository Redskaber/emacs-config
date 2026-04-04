;;; kernel-state.el --- State, backup, autosave, history policy -*- lexical-binding: t; -*-
;;; Commentary:
;;; State persistence and file hygiene.
;;; Code:

(require 'kernel-const)
(require 'kernel-lib)

(defun my/kernel-state-init ()
  "Configure state persistence and file hygiene."
  (setq backup-directory-alist
        `(("." . ,(expand-file-name "backup/" my/var-dir))))
  (setq auto-save-file-name-transforms
        `((".*" ,(expand-file-name "auto-save/" my/var-dir) t)))
  (setq auto-save-list-file-prefix
        (expand-file-name "auto-save/sessions/" my/var-dir))

  (dolist (dir (list (expand-file-name "backup/" my/var-dir)
                     (expand-file-name "auto-save/" my/var-dir)
                     (expand-file-name "auto-save/sessions/" my/var-dir)))
    (my/ensure-dir dir))

  (setq create-lockfiles nil)

  (save-place-mode 1)

  (setq history-length 200
        savehist-file (expand-file-name "savehist" my/var-dir))
  (savehist-mode 1)

  (setq recentf-save-file (expand-file-name "recentf" my/var-dir)
        recentf-max-saved-items 200)
  (recentf-mode 1))

(provide 'kernel-state)
;;; kernel-state.el ends here
