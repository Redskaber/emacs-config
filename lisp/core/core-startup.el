;;; core-startup.el --- Startup lifecycle management -*- lexical-binding: t; -*-

(require 'bootstrap-profile)
(require 'core-feature-flags)

(defcustom my/runtime-gc-cons-threshold (* 64 1024 1024)
  "GC threshold used after startup."
  :type 'integer
  :group 'my/features)

(defcustom my/runtime-gc-cons-percentage 0.1
  "GC percentage used after startup."
  :type 'float
  :group 'my/features)

(defun my/restore-startup-state ()
  "Restore temporary startup settings to sane runtime defaults."
  ;; Restore GC to sane runtime defaults.
  (setq gc-cons-threshold my/runtime-gc-cons-threshold)
  (setq gc-cons-percentage my/runtime-gc-cons-percentage)

  ;; Restore file-name handlers if early-init disabled them.
  (when (boundp 'my/file-name-handler-alist-backup)
    (setq file-name-handler-alist my/file-name-handler-alist-backup)
    (makunbound 'my/file-name-handler-alist-backup)))

(defun my/core-startup-init ()
  "Initialize startup lifecycle hooks."
  ;; Optional place for future startup-specific hooks.
  t)

(defun my/startup-finalize ()
  "Finalize startup lifecycle."
  (my/restore-startup-state)
  (my/report-startup))

(provide 'core-startup)
