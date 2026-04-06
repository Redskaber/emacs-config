;;; runtime-context.el --- Runtime context with schema -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. Slot registry (my/ctx--schema): each context key has a declared
;;;      type, doc string, and optional :required flag.
;;;   2. my/ctx-set validates value type against schema before storing.
;;;   3. my/ctx-validate-invariants checks all :required slots are non-nil
;;;      after capability declaration.
;;;   4. my/ctx-schema-info returns the schema for introspection/healthcheck.
;;;   5. Phase management and capability helpers unchanged from V1.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ---------------------------------------------------------------------------
;; Schema definition macro
;; ---------------------------------------------------------------------------

(defvar my/ctx--schema (make-hash-table :test #'eq)
  "Map context key → plist (:type TYPE :doc STRING :required BOOL).")

(defmacro my/ctx-defslot (key type doc &rest keys)
  "Declare a context slot KEY with expected TYPE and DOC.

  Optional keyword args:
    :required BOOL  — when t, my/ctx-validate-invariants will error if nil.

  TYPE is a symbol; validated via my/ctx--type-ok-p."
  (declare (indent 2))
  `(puthash ,key
            (list :type ',type :doc ,doc :required ,(plist-get keys :required))
            my/ctx--schema))

;; ---------------------------------------------------------------------------
;; Slot declarations
;; ---------------------------------------------------------------------------

;; Lifecycle
(my/ctx-defslot :phase symbol
  "Current startup phase (bootstrap/platform/kernel/stages/post-init/ready)."
  :required t)

;; Capability flags
(my/ctx-defslot :gui          boolean "Non-nil when running in a GUI frame.")
(my/ctx-defslot :tty          boolean "Non-nil when running in a TTY.")
(my/ctx-defslot :os-linux     boolean "Non-nil on GNU/Linux.")
(my/ctx-defslot :os-macos     boolean "Non-nil on macOS.")
(my/ctx-defslot :os-windows   boolean "Non-nil on Windows.")
(my/ctx-defslot :native-comp  boolean "Non-nil when native-comp is available.")
(my/ctx-defslot :treesit      boolean "Non-nil when tree-sitter is available.")
(my/ctx-defslot :wayland      boolean "Non-nil when Wayland session is active.")

;; Health log
(my/ctx-defslot :health-log   list "Alist of (stage . status) health records.")

;; ---------------------------------------------------------------------------
;; Type predicate
;; ---------------------------------------------------------------------------

(defun my/ctx--type-ok-p (type value)
  "Return non-nil when VALUE is compatible with TYPE.

  Supported types: boolean, symbol, string, integer, float, number, list, any."
  (pcase type
    ('boolean (or (null value) (eq value t) (booleanp value)))
    ('symbol  (symbolp value))
    ('string  (stringp value))
    ('integer (integerp value))
    ('float   (floatp value))
    ('number  (numberp value))
    ('list    (listp value))
    ('any     t)
    (_        t)))                      ; unknown type: permissive

;; ---------------------------------------------------------------------------
;; Runtime context table
;; ---------------------------------------------------------------------------

(defvar my/runtime-context (make-hash-table :test #'eq)
  "Centralised runtime context table.  Keys are keyword symbols.")

;; ---------------------------------------------------------------------------
;; Accessors
;; ---------------------------------------------------------------------------

(defun my/ctx-get (key &optional default)
  "Return KEY from runtime context, or DEFAULT."
  (let ((v (gethash key my/runtime-context :__missing__)))
    (if (eq v :__missing__) default v)))

(defun my/ctx-set (key value)
  "Set KEY to VALUE in runtime context, validating against schema.

  Logs a warning (not an error) on type mismatch to remain non-fatal."
  (let ((slot (gethash key my/ctx--schema)))
    (when (and slot
               (not (my/ctx--type-ok-p (plist-get slot :type) value)))
      (my/log-warn "ctx" "type mismatch for %s: expected %s, got %S"
                   key (plist-get slot :type) value)))
  (puthash key value my/runtime-context)
  value)

(defun my/ctx-update (key fn &optional default)
  "Apply FN to current value of KEY (or DEFAULT) and store result."
  (my/ctx-set key (funcall fn (my/ctx-get key default))))

(defun my/ctx-snapshot ()
  "Return a sorted alist snapshot of the context."
  (let (pairs)
    (maphash (lambda (k v) (push (cons k v) pairs)) my/runtime-context)
    (sort pairs (lambda (a b)
                  (string< (symbol-name (car a)) (symbol-name (car b)))))))

;; ---------------------------------------------------------------------------
;; Invariant validation
;; ---------------------------------------------------------------------------

(defun my/ctx-validate-invariants ()
  "Check that all :required context slots are non-nil.
  Logs errors for violations.  Returns t when all pass, nil otherwise."
  (let ((ok t))
    (maphash (lambda (key slot)
               (when (plist-get slot :required)
                 (let ((v (my/ctx-get key :__unset__)))
                   (when (or (eq v :__unset__) (null v))
                     (my/log-error "ctx" "required slot %s is unset" key)
                     (setq ok nil)))))
             my/ctx--schema)
    ok))

;; ---------------------------------------------------------------------------
;; Schema introspection
;; ---------------------------------------------------------------------------

(defun my/ctx-schema-info ()
  "Return alist of (key . slot-plist) for all declared slots."
  (let (result)
    (maphash (lambda (k v) (push (cons k v) result)) my/ctx--schema)
    (sort result (lambda (a b)
                   (string< (symbol-name (car a)) (symbol-name (car b)))))))

;; ---------------------------------------------------------------------------
;; Phase management
;; ---------------------------------------------------------------------------

(defconst my/ctx-phases
  '(bootstrap platform kernel stages post-init ready)
  "Ordered startup phases.")

(defun my/ctx-phase ()
  "Return current startup phase keyword."
  (my/ctx-get :phase 'bootstrap))

(defun my/ctx-set-phase (phase)
  "Advance startup to PHASE and log the transition."
  (my/log-info "ctx" "phase: %s → %s" (my/ctx-phase) phase)
  (my/ctx-set :phase phase))

;; ---------------------------------------------------------------------------
;; Capability helpers
;; ---------------------------------------------------------------------------

(defun my/ctx-capability-p (cap)
  "Return non-nil when runtime capability CAP is set."
  (my/ctx-get cap nil))

(defun my/ctx-declare-capabilities ()
  "Populate capability slots from current Emacs environment.
  Call once after platform detection."
  (my/ctx-set :gui         (display-graphic-p))
  (my/ctx-set :tty         (not (display-graphic-p)))
  (my/ctx-set :os-linux    (eq system-type 'gnu/linux))
  (my/ctx-set :os-macos    (eq system-type 'darwin))
  (my/ctx-set :os-windows  (memq system-type '(windows-nt ms-dos cygwin)))
  (my/ctx-set :native-comp (featurep 'native-compile))
  (my/ctx-set :treesit     (and (fboundp 'treesit-available-p)
                                (treesit-available-p)))
  (my/ctx-set :wayland     (and (eq system-type 'gnu/linux)
                                (string= (or (getenv "XDG_SESSION_TYPE") "")
                                         "wayland")))
  (my/ctx-validate-invariants)
  (my/log-info "ctx" "capabilities declared"))

;; ---------------------------------------------------------------------------
;; Health log
;; ---------------------------------------------------------------------------

(defun my/ctx-record-health (stage status)
  "Append STAGE STATUS pair to :health-log."
  (my/ctx-update :health-log
                 (lambda (log) (append log (list (cons stage status))))
                 nil))

(defun my/ctx-health-summary ()
  "Return alist of (stage . status) pairs."
  (my/ctx-get :health-log nil))

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(defun my/runtime-context-init ()
  "Initialise runtime context subsystem."
  (clrhash my/runtime-context)
  (my/ctx-set :phase 'bootstrap)
  (my/log-info "ctx" "context initialised"))

(provide 'runtime-context)
;;; runtime-context.el ends here
