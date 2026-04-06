;;; kernel-state.el --- State, backup, autosave, history policy -*- lexical-binding: t; -*-
;;; Commentary:
;;;   recentf-mode is deferred to after-init-hook (3 second idle).
;;;   save-place-mode and savehist-mode remain at startup.
;;;   my/kernel-state-init is consequently split into:
;;;     my/kernel-state-early-init  — everything safe at startup
;;;     my/kernel-state-defer-init  — recentf (registered on after-init-hook)
;;;   my/kernel-state-init calls both for backward compat.
;;;
;;; Code:

(require 'kernel-const)
(require 'kernel-lib)
(require 'kernel-logging)

(defun my/kernel-state-early-init ()
  "Configure backup, autosave, save-place, and savehist at startup."
  ;; Backup
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
  ;; Session state — safe at startup
  (save-place-mode 1)
  (setq history-length 200
        savehist-file (expand-file-name "savehist" my/var-dir))
  (savehist-mode 1))

(defun my/kernel-state-defer-init ()
  "Defer recentf-mode to after startup."
  (run-with-idle-timer
   3.0 nil
   (lambda ()
     (setq recentf-save-file (expand-file-name "recentf" my/var-dir)
           recentf-max-saved-items 200)
     (recentf-mode 1)
     (my/log-debug "state" "recentf-mode activated (deferred)"))))

(defun my/kernel-state-init ()
  "Initialize state persistence subsystem."
  (my/kernel-state-early-init)
  (my/kernel-state-defer-init))

(provide 'kernel-state)
;;; kernel-state.el ends here
