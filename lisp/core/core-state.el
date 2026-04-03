;;; core-state.el --- State, backup, autosave, history policy -*- lexical-binding: t; -*-

(require 'core-const)
(require 'core-lib)

(defun my/core-state-init ()
  "Configure state persistence and file hygiene."
  ;; Keep backup and autosave out of project trees.
  (setq backup-directory-alist `(("." . ,(expand-file-name "backup/" my/var-dir))))
  (setq auto-save-file-name-transforms
        `((".*" ,(expand-file-name "auto-save/" my/var-dir) t)))
  (setq auto-save-list-file-prefix
        (expand-file-name "auto-save/sessions/" my/var-dir))

  ;; Create subdirs if needed.
  (dolist (dir (list (expand-file-name "backup/" my/var-dir)
                     (expand-file-name "auto-save/" my/var-dir)
                     (expand-file-name "auto-save/sessions/" my/var-dir)))
    (my/ensure-dir dir))

  ;; Lockfiles often annoy in modern workflows.
  (setq create-lockfiles nil)

  ;; Save cursor positions.
  (save-place-mode 1)

  ;; Save minibuffer history.
  (savehist-mode 1)
  (setq history-length 200
        savehist-file (expand-file-name "savehist" my/var-dir))

  ;; Recent files.
  (recentf-mode 1)
  (setq recentf-save-file (expand-file-name "recentf" my/var-dir)
        recentf-max-saved-items 200))

(provide 'core-state)
