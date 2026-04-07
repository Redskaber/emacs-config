;;; kernel-logging.el --- Leveled structured logger -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - ring.el replaces manual list management
;;;     - sink registry: dynamic register/unregister
;;;     - entry gains :event :corr-id :span fields
;;;     - built-in sinks: messages-sink, ring-sink
;;;
;;; Levels (ordered): trace < debug < info < warn < error
;;;
;;; Public API
;;; ----------
;;;   (my/log-trace  TAG FMT &rest ARGS)
;;;   (my/log-debug  TAG FMT &rest ARGS)
;;;   (my/log-info   TAG FMT &rest ARGS)
;;;   (my/log-warn   TAG FMT &rest ARGS)
;;;   (my/log-error  TAG FMT &rest ARGS)
;;;   (my/log-event  LEVEL TAG MESSAGE &rest KEYS)
;;;   (my/log-set-level LEVEL)
;;;   (my/log-entries)
;;;   (my/log-register-sink NAME FN)
;;;   (my/log-unregister-sink NAME)
;;;
;;; Code:

(require 'cl-lib)
(require 'ring)

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
  "Minimum log level to emit."
  :type '(choice (const trace) (const debug) (const info)
                 (const warn) (const error))
  :group 'my/logging)

(defcustom my/log-ring-size 512
  "Number of log entries to retain in the in-memory ring buffer."
  :type 'integer
  :group 'my/logging)

;; ---------------------------------------------------------------------------
;; Internal ring buffer  (use ring.el)
;; ---------------------------------------------------------------------------

(defvar my/log--ring nil
  "ring.el ring holding recent log entries (newest first).")

(defun my/log--ring-ensure ()
  (unless (ring-p my/log--ring)
    (setq my/log--ring (make-ring my/log-ring-size))))

(defun my/log--ring-push (entry)
  (my/log--ring-ensure)
  (ring-insert my/log--ring entry))

(defun my/log-entries ()
  "Return recent log entries as a list (newest first)."
  (my/log--ring-ensure)
  (ring-elements my/log--ring))

(defun my/log-clear ()
  "Clear in-memory log ring."
  (interactive)
  (setq my/log--ring (make-ring my/log-ring-size))
  ;; avoid recursion: write directly to *Messages*
  (message "[INFO][logging] log ring cleared"))

;; ---------------------------------------------------------------------------
;; Sink registry
;; ---------------------------------------------------------------------------

(defvar my/log--sinks (make-hash-table :test #'eq)
  "Map sink-name-symbol → function (entry).
  Each sink receives a raw entry plist and may do anything with it.")

(defun my/log-register-sink (name fn)
  "Register sink NAME (symbol) calling FN on every log entry."
  (unless (symbolp name) (error "sink name must be a symbol"))
  (unless (functionp fn) (error "sink fn must be callable"))
  (puthash name fn my/log--sinks))

(defun my/log-unregister-sink (name)
  "Remove sink NAME."
  (remhash name my/log--sinks))

(defun my/log--dispatch-sinks (entry)
  "Send ENTRY to all registered sinks, catching errors."
  (maphash (lambda (_name fn)
             (condition-case err
                 (funcall fn entry)
               (error (message "[ERROR][logging] sink error: %S" err))))
           my/log--sinks))

;; ---------------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------------

(defun my/log--level-value (level)
  (or (cdr (assq level my/log-levels)) 999))

(defun my/log-level-valid-p (level)
  (assq level my/log-levels))

(defun my/log--should-emit-p (level)
  (>= (my/log--level-value level)
      (my/log--level-value my/log-level)))

(defun my/log--prefix (level)
  (upcase (symbol-name level)))

;; ---------------------------------------------------------------------------
;; Core emit  (:event :corr-id :span fields added)
;; ---------------------------------------------------------------------------

(cl-defun my/log-event (level tag message
                               &key data event corr-id span)
  "Emit a structured log event.

  LEVEL  — one of `my/log-levels'.
  TAG    — subsystem tag string.
  MESSAGE — user-visible summary.
  DATA   — optional payload plist (stored in ring only).
  EVENT  — optional domain event keyword (e.g. :runtime/module-started).
  CORR-ID — optional correlation id (module name, stage name, etc.).
  SPAN   — optional span/trace data."
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
           (entry (list :time     (float-time)
                        :level    level
                        :tag      tag
                        :msg      message
                        :data     data
                        :event    event
                        :corr-id  corr-id
                        :span     span)))
      ;; Built-in messages sink
      (message "%s" line)
      ;; Built-in ring sink
      (my/log--ring-push entry)
      ;; External sinks
      (my/log--dispatch-sinks entry))))

(defun my/log--emit (level tag fmt &rest args)
  "Internal printf-style logging via my/log-event."
  (my/log-event level tag (apply #'format fmt args)))

;; ---------------------------------------------------------------------------
;; Public level functions
;; ---------------------------------------------------------------------------

(defun my/log-trace (tag fmt &rest args)
  (apply #'my/log--emit 'trace tag fmt args))

(defun my/log-debug (tag fmt &rest args)
  (apply #'my/log--emit 'debug tag fmt args))

(defun my/log-info (tag fmt &rest args)
  (apply #'my/log--emit 'info tag fmt args))

(defun my/log-warn (tag fmt &rest args)
  (apply #'my/log--emit 'warn tag fmt args))

(defun my/log-error (tag fmt &rest args)
  (apply #'my/log--emit 'error tag fmt args))

;; ---------------------------------------------------------------------------
;; Runtime control
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
  (setq my/log--ring (make-ring my/log-ring-size))
  (clrhash my/log--sinks)
  (my/log-info "logging" "kernel logger initialised (level=%s ring=%d)"
               my/log-level my/log-ring-size))

(provide 'kernel-logging)
;;; kernel-logging.el ends here
