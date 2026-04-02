;;; core-logging.el --- Logging helpers -*- lexical-binding: t; -*-

(defvar my/log-enabled t
  "Whether custom logging is enabled.")

(defun my/log (fmt &rest args)
  "Log message FMT with ARGS under [my] prefix."
  (when my/log-enabled
    (apply #'message (concat "[my] " fmt) args)))

(defun my/core-logging-init ()
  "Initialize logging subsystem."
  (my/log "logging initialized"))

(provide 'core-logging)
