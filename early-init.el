;;; early-init.el --- Early startup initialization -*- lexical-binding: t; -*-
;;; Commentary:
;;; Early startup stage. Keep this file minimal and side-effect controlled.
;;; Code:

;; Do not let package.el initialize itself before init.el.
(setq package-enable-at-startup nil)

;; Reduce GC pressure during startup.
(setq gc-cons-threshold most-positive-fixnum)
(setq gc-cons-percentage 0.6)

;; Speed up startup by temporarily disabling file-name handlers.
(defvar my/file-name-handler-alist-backup file-name-handler-alist
  "Backup of `file-name-handler-alist' during early startup.")
(setq file-name-handler-alist nil)

;; Prefer quiet startup UI.
(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil)

;; Native compilation cache directory (preferred modern API).
(when (and (fboundp 'startup-redirect-eln-cache)
           (featurep 'native-compile))
  (startup-redirect-eln-cache
   (expand-file-name "eln-cache/" user-emacs-directory)))

;; Frame chrome policy (safe defaults).
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars . nil) default-frame-alist)

;; Avoid expensive frame resizing during startup.
(setq frame-inhibit-implied-resize t)

;; Use pixelwise resize for modern displays.
(setq frame-resize-pixelwise t)

(provide 'early-init)
;;; early-init.el ends here
