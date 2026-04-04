;;; kernel-startup.el --- Startup lifecycle management -*- lexical-binding: t; -*-
;;; Commentary:
;;; Startup restoration/finalization.
;;; Code:

(require 'bootstrap-profile)

(defgroup my/startup nil
  "Startup lifecycle settings."
  :group 'my)

(defcustom my/runtime-gc-cons-threshold (* 64 1024 1024)
  "GC threshold used after startup."
  :type 'integer
  :group 'my/startup)

(defcustom my/runtime-gc-cons-percentage 0.1
  "GC percentage used after startup."
  :type 'float
  :group 'my/startup)

(defun my/restore-startup-state ()
  "Restore temporary startup settings to sane runtime defaults."
  (setq gc-cons-threshold my/runtime-gc-cons-threshold)
  (setq gc-cons-percentage my/runtime-gc-cons-percentage)

  (when (boundp 'my/file-name-handler-alist-backup)
    (setq file-name-handler-alist my/file-name-handler-alist-backup)
    (makunbound 'my/file-name-handler-alist-backup)))

(defun my/kernel-startup-init ()
  "Initialize startup lifecycle hooks."
  t)

(defun my/startup-finalize ()
  "Finalize startup lifecycle."
  (my/restore-startup-state)
  (my/report-startup))

(provide 'kernel-startup)
;;; kernel-startup.el ends here
