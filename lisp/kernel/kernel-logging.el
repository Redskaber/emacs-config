;;; kernel-logging.el --- Logging helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;; Minimal logging API for kernel/runtime.
;;; Code:

(defgroup my/logging nil
  "Logging settings."
  :group 'my)

(defcustom my/log-enabled t
  "Whether custom logging is enabled."
  :type 'boolean
  :group 'my/logging)

(defun my/log (fmt &rest args)
  "Log FMT with ARGS under [my] prefix."
  (when my/log-enabled
    (apply #'message (concat "[my] " fmt) args)))

(defun my/kernel-logging-init ()
  "Initialize logging subsystem."
  (my/log "kernel logging initialized"))

(provide 'kernel-logging)
;;; kernel-logging.el ends here
