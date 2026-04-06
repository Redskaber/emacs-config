;;; kernel-logging.el --- Leveled structured logger -*- lexical-binding: t; -*-
;;; Commentary:
;;;   Structured leveled logger.
;;;   Levels (ordered): trace < debug < info < warn < error
;;;
;;; Public API
;;; ----------
;;;   (my/log-trace  TAG FMT &rest ARGS)
;;;   (my/log-debug  TAG FMT &rest ARGS)
;;;   (my/log-info   TAG FMT &rest ARGS)
;;;   (my/log-warn   TAG FMT &rest ARGS)
;;;   (my/log-error  TAG FMT &rest ARGS)
;;;   (my/log-event  LEVEL TAG MESSAGE &rest KEYS)
;;;   (my/log-set-level LEVEL)            ; change threshold at runtime
;;;   (my/log-entries)                    ; inspect in-memory ring
;;;
;;; Notes
;;; -----
;;;   Backtrace capture is intentionally NOT handled here.
;;;   Stack capture belongs to error boundaries / exception sites
;;;   (see `kernel-errors.el`).
;;;
;;; Each entry is written to *Messages* and appended to an in-memory
;;; ring buffer (`my/log--ring`) for ops/healthcheck/inspection.
;;;
;;; Ring entry shape
;;; ----------------
;;;   (:time FLOAT
;;;    :level SYMBOL
;;;    :tag STRING
;;;    :msg STRING
;;;    :data PLIST|NIL)
;;;
;;; Code:

(require 'cl-lib)

;; ---------------------------------------------------------------------------
;; Customization
;; ---------------------------------------------------------------------------

(defgroup my/logging nil
  "Logging settings."
  :group 'my)

(defconst my/log-levels
  '((trace . 0) (debug . 1) (info . 2) (warn . 3) (error . 4))
  "Alist mapping level symbol -> numeric priority.")

(defcustom my/log-level 'debug
  "Minimum log level to emit.
  One of: trace, debug, info, warn, error."
  :type '(choice (const trace)
                 (const debug)
                 (const info)
                 (const warn)
                 (const error))
  :group 'my/logging)

(defcustom my/log-ring-size 512
  "Number of log entries to retain in the in-memory ring buffer."
  :type 'integer
  :group 'my/logging)

;; ---------------------------------------------------------------------------
;; Internal ring buffer
;; ---------------------------------------------------------------------------

(defvar my/log--ring nil
  "Recent log entries (newest first).
  Each entry is a plist:
    (:time FLOAT :level SYMBOL :tag STRING :msg STRING :data PLIST|NIL).")

(defvar my/log--ring-count 0
  "Number of entries currently stored in `my/log--ring'.")

(defun my/log--ring-trim ()
  "Trim `my/log--ring' to `my/log-ring-size'."
  (when (> my/log--ring-count my/log-ring-size)
    ;; Keep newest `my/log-ring-size' entries.
    (setcdr (nthcdr (1- my/log-ring-size) my/log--ring) nil)
    (setq my/log--ring-count my/log-ring-size)))

(defun my/log--ring-push (entry)
  "Push ENTRY into the ring buffer, evicting oldest when full."
  (push entry my/log--ring)
  (cl-incf my/log--ring-count)
  (my/log--ring-trim))

(defun my/log-entries ()
  "Return recent log entries as a fresh list (newest first)."
  (copy-sequence my/log--ring))

(defun my/log-clear ()
  "Clear in-memory log ring."
  (interactive)
  (setq my/log--ring nil
        my/log--ring-count 0)
  (my/log-info "logging" "log ring cleared"))

;; ---------------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------------

(defun my/log--level-value (level)
  "Return numeric priority of LEVEL, or 999 for unknown."
  (or (cdr (assq level my/log-levels)) 999))

(defun my/log-level-valid-p (level)
  "Return non-nil when LEVEL is a known log level symbol."
  (assq level my/log-levels))

(defun my/log--should-emit-p (level)
  "Return non-nil when LEVEL passes current threshold."
  (>= (my/log--level-value level)
      (my/log--level-value my/log-level)))

(defun my/log--prefix (level)
  "Return display prefix string for LEVEL."
  (upcase (symbol-name level)))

;; ---------------------------------------------------------------------------
;; Core emit (structured)
;; ---------------------------------------------------------------------------

(cl-defun my/log-event (level tag message &key data)
  "Emit a structured log event.

  LEVEL is one of `my/log-levels'.
  TAG is a subsystem tag string.
  MESSAGE is the user-visible summary line.
  DATA is optional structured payload (plist) stored in the ring only.

  Example:
    (my/log-event
    'error \"errors\" \"init failed\"
    :data '(:kind handled :label \"boot\" :error (file-missing ...)))"
  (unless (my/log-level-valid-p level)
    (error "Unknown log level: %S" level))
  (unless (stringp tag)
    (error "TAG must be a string, got: %S" tag))
  (unless (stringp message)
    (error "MESSAGE must be a string, got: %S" message))
  (when (and data (not (listp data)))
    (error "DATA must be a plist/list or nil, got: %S" data))
  (when (my/log--should-emit-p level)
    (let* ((line  (format "[%s][%s] %s" (my/log--prefix level) tag message))
           (entry (list :time  (float-time)
                        :level level
                        :tag   tag
                        :msg   message
                        :data  data)))
      (message "%s" line)
      (my/log--ring-push entry))))

(defun my/log--emit (level tag fmt &rest args)
  "Internal compatibility layer for printf-style logging."
  (my/log-event level tag (apply #'format fmt args)))

;; ---------------------------------------------------------------------------
;; Public level functions (compat layer)
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
;; Convenience: runtime control
;; ---------------------------------------------------------------------------

(defun my/log-set-level (level)
  "Set the active log level to LEVEL (symbol)."
  (interactive
   (list (intern
          (completing-read
           "Log level: "
           (mapcar (lambda (p) (symbol-name (car p))) my/log-levels)
           nil t))))
  (unless (my/log-level-valid-p level)
    (user-error "Unknown log level: %s" level))
  (setq my/log-level level)
  (my/log-info "logging" "log level set to %s" level))

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(defun my/kernel-logging-init ()
  "Initialise logging subsystem."
  (setq my/log--ring nil
        my/log--ring-count 0)
  (my/log-info "logging" "kernel logger initialised (level=%s ring=%d)"
               my/log-level my/log-ring-size))

(provide 'kernel-logging)
;;; kernel-logging.el ends here
