;;; bootstrap-core.el --- Bootstrap primitives -*- lexical-binding: t; -*-

(defun my/bootstrap-core-init ()
  "Initialize bootstrap primitives."
  ;; Reserved for future macros, bootstrap guards, feature flags, etc.
  t)

(defun my/restore-startup-state ()
  "Restore temporary startup settings."
  ;; Restore GC to sane runtime defaults.
  (setq gc-cons-threshold (* 64 1024 1024))
  (setq gc-cons-percentage 0.1)

  ;; Restore file-name handlers if early-init disabled them.
  (when (boundp 'my/file-name-handler-alist-backup)
    (setq file-name-handler-alist my/file-name-handler-alist-backup)
    (makunbound 'my/file-name-handler-alist-backup)))

(provide 'bootstrap-core)
