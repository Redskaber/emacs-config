;;; kernel-errors.el --- Error boundary helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - my/try-call: result monad, distinguishes nil-value from error
;;;     - wrapper identity guard: detects double-wrap
;;;     - backtrace policy levels: nil/handled/unhandled/all
;;;
;;; Public API
;;; ----------
;;;   (my/with-safe-call LABEL BODY...)
;;;   (my/with-safe-call-bt LABEL BODY...)
;;;   (my/try-call LABEL THUNK)         → (:ok t :value V) | (:ok nil :error E :backtrace BT)
;;;   (my/errors-command-error-handler-installed-p)
;;;   (my/errors-reinstall-command-error-handler)
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

(defcustom my/errors-backtrace-policy nil
  "Backtrace capture policy.
  nil / never  — never capture.
  handled      — capture for handled (my/with-safe-call) errors only.
  unhandled    — capture for command-error-function errors only.
  all          — capture for all errors."
  :type '(choice (const :tag "Never" nil)
                 (const :tag "Handled only" handled)
                 (const :tag "Unhandled only" unhandled)
                 (const :tag "All" all))
  :group 'my/errors)

;; ---------------------------------------------------------------------------
;; Internal state
;; ---------------------------------------------------------------------------

(defvar my/errors--installed nil
  "Non-nil when command-error-function wrapper has been installed.")

(defvar my/errors--orig-command-error-function nil
  "Original value of command-error-function before wrapper installation.")

;; Wrapper identity symbol
(defvar my/errors--command-error-wrapper nil
  "The lambda installed as command-error-function by this module.
  Used to detect double-wrap and support reinstall.")

;; ---------------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------------

(defun my/errors--capture-backtrace ()
  "Return current backtrace as a string."
  (with-output-to-string (backtrace)))

(defun my/errors--should-capture-p (kind)
  "Return non-nil when KIND (:handled | :unhandled) should capture bt."
  (pcase my/errors-backtrace-policy
    ('nil      nil)
    ('never    nil)
    ('handled   (eq kind :handled))
    ('unhandled (eq kind :unhandled))
    ('all       t)
    (_          nil)))

(defun my/errors--emit-handled (label err backtrace)
  (my/log-event
   'error "errors"
   (format "handled error: %s -> %S" label err)
   :event   :errors/handled
   :corr-id label
   :data    (list :kind :handled :label label :error err :backtrace backtrace)))

(defun my/errors--emit-unhandled (data context signal backtrace)
  (my/log-event
   'error "errors"
   (format "unhandled command error: %s: %S" (or context "command error") data)
   :event   :errors/unhandled
   :corr-id context
   :data    (list :kind :unhandled :context context :signal signal
                  :error data :backtrace backtrace)))

;; ---------------------------------------------------------------------------
;; Core macros
;; ---------------------------------------------------------------------------

(defmacro my/with-safe-call (label &rest body)
  "Execute BODY safely; log LABEL on failure.  Returns BODY value or nil."
  (declare (indent 1))
  `(condition-case err
       (progn ,@body)
     (error
      (let ((bt (when (my/errors--should-capture-p :handled)
                  (my/errors--capture-backtrace))))
        (my/errors--emit-handled ,label err bt))
      nil)))

(defmacro my/with-safe-call-bt (label &rest body)
  "Like my/with-safe-call but forces backtrace capture regardless of policy."
  (declare (indent 1))
  `(let ((my/errors-backtrace-policy 'all))
     (my/with-safe-call ,label ,@body)))

;; ---------------------------------------------------------------------------
;; Result monad
;; ---------------------------------------------------------------------------

(defun my/try-call (label thunk)
  "Call THUNK inside an error boundary.  Returns a result plist.

  On success: (:ok t  :value VALUE)
  On error:   (:ok nil :error ERR :backtrace BT-OR-NIL)

  Unlike my/with-safe-call, the caller can distinguish a successful nil
  return from a caught error by inspecting :ok."
  (condition-case err
      (let ((v (funcall thunk)))
        (list :ok t :value v))
    (error
     (let ((bt (when (my/errors--should-capture-p :handled)
                 (my/errors--capture-backtrace))))
       (my/errors--emit-handled label err bt)
       (list :ok nil :error err :backtrace bt)))))

;; ---------------------------------------------------------------------------
;; Command-error handler
;; ---------------------------------------------------------------------------

(defun my/errors--command-error-handler (data context signal)
  "Log unhandled command errors.  Does not suppress user-facing display."
  (let ((bt (when (my/errors--should-capture-p :unhandled)
              (my/errors--capture-backtrace))))
    (my/errors--emit-unhandled data context signal bt)))

;; ---------------------------------------------------------------------------
;; Wrapper identity & install
;; ---------------------------------------------------------------------------

(defun my/errors-command-error-handler-installed-p ()
  "Return non-nil when our wrapper is the current command-error-function."
  (and my/errors--installed
       (eq command-error-function my/errors--command-error-wrapper)))

(defun my/errors--install-command-error-handler ()
  "Install command-error-function wrapper exactly once.
  Detects double-wrap via identity check."
  (when (my/errors-command-error-handler-installed-p)
    ;; Already installed — skip
    (cl-return-from my/errors--install-command-error-handler nil))
  (when my/errors--installed
    ;; installed flag set but wrapper was replaced — log and continue
    (my/log-warn "errors" "command-error-function was replaced since last install; reinstalling"))
  (setq my/errors--orig-command-error-function command-error-function)
  (let ((wrapper (lambda (data context signal)
                   (my/errors--command-error-handler data context signal)
                   (when my/errors--orig-command-error-function
                     (funcall my/errors--orig-command-error-function
                              data context signal)))))
    (setq my/errors--command-error-wrapper wrapper)
    (setq command-error-function wrapper)
    (setq my/errors--installed t)))

(defun my/errors-reinstall-command-error-handler ()
  "Force-reinstall the command-error-function wrapper.
  Use when the wrapper was inadvertently replaced."
  (interactive)
  (setq my/errors--installed nil
        my/errors--command-error-wrapper nil)
  (my/errors--install-command-error-handler)
  (my/log-info "errors" "command-error-function handler reinstalled"))

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(defun my/kernel-errors-init ()
  "Initialise error boundary helpers."
  (my/errors--install-command-error-handler)
  (my/log-info "errors"
               "error boundary ready (policy=%s installed=%s)"
               my/errors-backtrace-policy
               my/errors--installed))

(provide 'kernel-errors)
;;; kernel-errors.el ends here
