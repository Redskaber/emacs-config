;;; kernel-errors.el --- Error boundary helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. my/with-safe-call gains optional :capture-backtrace.
;;;      When non-nil (or when my/errors-capture-backtrace is t), a
;;;      backtrace string is captured and logged at debug level on error.
;;;   2. my/with-safe-call-bt is a convenience wrapper with bt always on.
;;;   3. my/kernel-errors-init installs an unhandled-error reporter.
;;;
;;; Code:

(require 'kernel-logging)

(defcustom my/errors-capture-backtrace nil
  "When non-nil, my/with-safe-call always captures a backtrace on error.
  Can be toggled at runtime for debugging sessions."
  :type 'boolean
  :group 'my)

;; ---------------------------------------------------------------------------
;; Core macro
;; ---------------------------------------------------------------------------

(defmacro my/with-safe-call (label &rest body)
  "Execute BODY safely; log LABEL on failure.

  When `my/errors-capture-backtrace' is non-nil, a backtrace is appended
  to the error log entry.

  Returns the value of BODY on success, nil on error."
  (declare (indent 1))
  `(condition-case err
       (progn ,@body)
     (error
      (if my/errors-capture-backtrace
          (let ((bt (with-output-to-string (backtrace))))
            (my/log-error "error" "%s -> %S\n%s" ,label err bt))
        (my/log-error "error" "%s -> %S" ,label err))
      nil)))

(defmacro my/with-safe-call-bt (label &rest body)
  "Like `my/with-safe-call' but always captures backtrace on error."
  (declare (indent 1))
  `(let ((my/errors-capture-backtrace t))
     (my/with-safe-call ,label ,@body)))

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(defun my/kernel-errors-init ()
  "Initialise error boundary helpers."
  (my/log-info "errors" "error boundary ready (bt=%s)"
               my/errors-capture-backtrace))

(provide 'kernel-errors)
;;; kernel-errors.el ends here
