;;; kernel-logging.el --- Leveled structured logger  -*- lexical-binding: t; -*-
;;; Commentary:
;;;   kernel-logging.el with a proper leveled logger.
;;;   Levels (ordered): trace < debug < info < warn < error
;;;
;;; Public API
;;; ----------
;;;   (my/log-trace  TAG FMT &rest ARGS)
;;;   (my/log-debug  TAG FMT &rest ARGS)
;;;   (my/log-info   TAG FMT &rest ARGS)
;;;   (my/log-warn   TAG FMT &rest ARGS)
;;;   (my/log-error  TAG FMT &rest ARGS)
;;;   (my/log-set-level LEVEL)            ; change threshold at runtime
;;;   (my/log-backtrace-on-error BOOL)    ; toggle backtrace capture
;;;
;;; Each entry is written to *Messages* and optionally appended to an
;;; in-memory ring buffer (my/log--ring) accessible for ops/healthcheck.
;;;
;;; Code:

(require 'cl-lib)

;; ---------------------------------------------------------------------------
;; Level definitions
;; ---------------------------------------------------------------------------

(defconst my/log-levels
  '((trace . 0) (debug . 1) (info . 2) (warn . 3) (error . 4))
  "Alist mapping level symbol → numeric priority.")

(defcustom my/log-level 'debug
  "Minimum log level to emit.  One of: trace debug info warn error."
  :type '(choice (const trace) (const debug) (const info)
                 (const warn) (const error))
  :group 'my/logging)

(defcustom my/log-ring-size 512
  "Number of log entries to retain in the in-memory ring buffer."
  :type 'integer
  :group 'my/logging)

(defcustom my/log-backtrace-on-error nil
  "When non-nil, capture `backtrace-string' on every error-level log."
  :type 'boolean
  :group 'my/logging)

;; ---------------------------------------------------------------------------
;; Internal ring buffer
;; ---------------------------------------------------------------------------

(defvar my/log--ring nil
  "Circular list of recent log entries (newest at head).
  Each entry is a plist (:time FLOAT :level SYMBOL :tag STRING :msg STRING).")

(defvar my/log--ring-count 0
  "Number of entries currently in `my/log--ring'.")

(defun my/log--ring-push (entry)
  "Push ENTRY into the ring buffer, evicting oldest when full."
  (push entry my/log--ring)
  (cl-incf my/log--ring-count)
  (when (> my/log--ring-count my/log-ring-size)
    (setq my/log--ring (butlast my/log--ring 1))
    (cl-decf my/log--ring-count)))

(defun my/log-entries ()
  "Return recent log entries as a list (newest first)."
  (copy-sequence my/log--ring))

;; ---------------------------------------------------------------------------
;; Core emit
;; ---------------------------------------------------------------------------

(defun my/log--level-value (level)
  "Return numeric priority of LEVEL, or 999 for unknown."
  (or (cdr (assq level my/log-levels)) 999))

(defun my/log--emit (level tag fmt &rest args)
  "Internal: emit a log line at LEVEL under TAG."
  (when (>= (my/log--level-value level)
             (my/log--level-value my/log-level))
    (let* ((msg      (apply #'format fmt args))
           (prefix   (upcase (symbol-name level)))
           (line     (format "[%s][%s] %s" prefix tag msg))
           (entry    (list :time  (float-time)
                           :level level
                           :tag   tag
                           :msg   msg)))
      (message "%s" line)
      (my/log--ring-push entry)
      (when (and (eq level 'error) my/log-backtrace-on-error)
        (let ((bt (with-output-to-string (backtrace))))
          (message "[ERROR][%s] backtrace:\n%s" tag bt))))))

;; ---------------------------------------------------------------------------
;; Public level functions
;; ---------------------------------------------------------------------------

(defun my/log-trace (tag fmt &rest args)
  "Log FMT/ARGS at TRACE level under TAG."
  (apply #'my/log--emit 'trace tag fmt args))

(defun my/log-debug (tag fmt &rest args)
  "Log FMT/ARGS at DEBUG level under TAG."
  (apply #'my/log--emit 'debug tag fmt args))

(defun my/log-info (tag fmt &rest args)
  "Log FMT/ARGS at INFO level under TAG."
  (apply #'my/log--emit 'info tag fmt args))

(defun my/log-warn (tag fmt &rest args)
  "Log FMT/ARGS at WARN level under TAG."
  (apply #'my/log--emit 'warn tag fmt args))

(defun my/log-error (tag fmt &rest args)
  "Log FMT/ARGS at ERROR level under TAG."
  (apply #'my/log--emit 'error tag fmt args))

;; ---------------------------------------------------------------------------
;; Convenience: set level at runtime
;; ---------------------------------------------------------------------------

(defun my/log-set-level (level)
  "Set the active log level to LEVEL (symbol)."
  (interactive
   (list (intern (completing-read "Log level: "
                                  (mapcar (lambda (p) (symbol-name (car p)))
                                          my/log-levels)
                                  nil t))))
  (unless (assq level my/log-levels)
    (user-error "Unknown log level: %s" level))
  (setq my/log-level level)
  (my/log-info "log" "log level set to %s" level))

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(defgroup my/logging nil
  "Logging settings."
  :group 'my)

(defun my/kernel-logging-init ()
  "Initialise logging subsystem."
  (setq my/log--ring nil
        my/log--ring-count 0)
  (my/log-info "log" "kernel logger initialised (level=%s ring=%d)"
               my/log-level my/log-ring-size))

(provide 'kernel-logging)
;;; kernel-logging.el ends here
