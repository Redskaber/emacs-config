;;; kernel-errors.el --- Error boundary helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;;   Error boundaries and unhandled command error reporting.
;;;
;;; Design
;;; ------
;;;   1. Backtrace capture lives exclusively here (NOT in `kernel-logging`).
;;;   2. Logger is output/transport only; exception semantics stay here.
;;;   3. Handled errors are reported via `my/with-safe-call`.
;;;   4. Unhandled interactive command errors are reported via
;;;      `command-error-function`.
;;;   5. Backtrace is stored as structured event payload (:data), not appended
;;;      inline to the human-facing log line.
;;;
;;; Public API
;;; ----------
;;;   (my/with-safe-call LABEL BODY...)
;;;   (my/with-safe-call-bt LABEL BODY...)
;;;   (my/kernel-errors-init)
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ---------------------------------------------------------------------------
;; Customization
;; ---------------------------------------------------------------------------

(defgroup my/errors nil
  "Error boundary settings."
  :group 'my)

(defcustom my/errors-capture-backtrace nil
  "When non-nil, error boundaries capture a backtrace on handled/unhandled errors."
  :type 'boolean
  :group 'my/errors)

;; ---------------------------------------------------------------------------
;; Internal state
;; ---------------------------------------------------------------------------

(defvar my/errors--installed nil
  "Non-nil when `command-error-function` wrapper has been installed.")

(defvar my/errors--orig-command-error-function nil
  "Original value of `command-error-function` before wrapper installation.")

;; ---------------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------------

(defun my/errors--capture-backtrace ()
  "Return current backtrace as a string."
  (with-output-to-string
    (backtrace)))

(defun my/errors--emit-handled (label err backtrace)
  "Emit a structured handled error event.
  LABEL is the boundary label.
  ERR is the condition object from `condition-case`.
  BACKTRACE is a string or nil."
  (my/log-event
   'error "errors"
   (format "handled error: %s -> %S" label err)
   :data (list :kind 'handled
               :label label
               :error err
               :backtrace backtrace)))

(defun my/errors--emit-unhandled (data context signal backtrace)
  "Emit a structured unhandled command error event.
  DATA, CONTEXT, SIGNAL are from `command-error-function`.
  BACKTRACE is a string or nil."
  (my/log-event
   'error "errors"
   (format "unhandled command error: %s: %S"
           (or context "command error")
           data)
   :data (list :kind 'unhandled
               :context context
               :signal signal
               :error data
               :backtrace backtrace)))

;; ---------------------------------------------------------------------------
;; Core macros
;; ---------------------------------------------------------------------------

(defmacro my/with-safe-call (label &rest body)
  "Execute BODY safely; log LABEL on failure.

  On success:
    - return BODY result

  On error:
    - emit a structured ERROR event
    - optionally capture backtrace when `my/errors-capture-backtrace' is non-nil
    - return nil"
  (declare (indent 1))
  `(condition-case err
       (progn ,@body)
     (error
      (let ((bt (when my/errors-capture-backtrace
                  (my/errors--capture-backtrace))))
        (my/errors--emit-handled ,label err bt))
      nil)))

(defmacro my/with-safe-call-bt (label &rest body)
  "Like `my/with-safe-call' but always captures backtrace."
  (declare (indent 1))
  `(let ((my/errors-capture-backtrace t))
     (my/with-safe-call ,label ,@body)))

;; ---------------------------------------------------------------------------
;; Unhandled command error reporter
;; ---------------------------------------------------------------------------

(defun my/errors--command-error-handler (data context signal)
  "Log unhandled command errors via `kernel-logging`.
  This does not suppress normal user-facing error display."
  (let ((bt (when my/errors-capture-backtrace
              (my/errors--capture-backtrace))))
    (my/errors--emit-unhandled data context signal bt)))

;; ---------------------------------------------------------------------------
;; Init / install
;; ---------------------------------------------------------------------------

(defun my/errors--install-command-error-handler ()
  "Install `command-error-function` wrapper exactly once."
  (unless my/errors--installed
    (setq my/errors--orig-command-error-function command-error-function)
    (setq command-error-function
          (lambda (data context signal)
            (my/errors--command-error-handler data context signal)
            (when my/errors--orig-command-error-function
              (funcall my/errors--orig-command-error-function
                       data context signal))))
    (setq my/errors--installed t)))

(defun my/kernel-errors-init ()
  "Initialise error boundary helpers."
  (my/errors--install-command-error-handler)
  (my/log-info "errors" "error boundary ready (bt=%s installed=%s)"
               my/errors-capture-backtrace
               my/errors--installed))

(provide 'kernel-errors)
;;; kernel-errors.el ends here
