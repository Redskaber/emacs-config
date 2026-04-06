;;; runtime-context.el --- Runtime context -*- lexical-binding: t; -*-
;;; Commentary:
;;;  Three distinct namespaces are enforced via key prefix convention:
;;;
;;;    :fact/*   — immutable system facts (set once at capability detection).
;;;                Reading a :fact/* key after it's set is always safe.
;;;                Attempting to overwrite a :fact/* key logs a warning.
;;;
;;;    :state/*  — mutable runtime state (phase, health-log, etc.).
;;;                Normal read/write; type-validated against schema.
;;;
;;;    :view/*   — derived / computed views (never stored; always re-computed).
;;;                my/ctx-view defines a named thunk; my/ctx-get-view evaluates it.
;;;
;;;  Legacy keys without a namespace prefix are still accepted for backward
;;;  compatibility but log a deprecation warning on first access.
;;;
;;;  Schema, phase management, capability helpers, and health log are preserved
;;;  from V1 with namespace-aware updates.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ─────────────────────────────────────────────────────────────────────────────
;; Namespace helpers
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx--key-namespace (key)
  "Return namespace symbol of KEY: fact | state | legacy.
  KEY is a keyword symbol like :fact/os-linux or :phase."
  (let ((name (symbol-name key)))
    (cond
     ((string-prefix-p ":fact/"  name) 'fact)
     ((string-prefix-p ":state/" name) 'state)
     ((string-prefix-p ":view/"  name) 'view)
     (t                                 'legacy))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Schema definition
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/ctx--schema (make-hash-table :test #'eq)
  "Map context key → plist (:type TYPE :doc STRING :required BOOL :ns SYMBOL).")

(defmacro my/ctx-defslot (key type doc &rest keys)
  "Declare context slot KEY with TYPE and DOC.
  Optional: :required BOOL"
  (declare (indent 2))
  `(puthash ,key
            (list :type     ',type
                  :doc      ,doc
                  :required ,(plist-get keys :required)
                  :ns       ',(let ((name (symbol-name key)))
                                (cond ((string-prefix-p ":fact/"  name) 'fact)
                                      ((string-prefix-p ":state/" name) 'state)
                                      (t                                 'legacy))))
            my/ctx--schema))

;; ── Fact slots (immutable after capability detection) ─────────────────────────
(my/ctx-defslot :fact/gui         boolean "Non-nil in a GUI frame.")
(my/ctx-defslot :fact/tty         boolean "Non-nil in a TTY.")
(my/ctx-defslot :fact/os-linux    boolean "Non-nil on GNU/Linux.")
(my/ctx-defslot :fact/os-macos    boolean "Non-nil on macOS.")
(my/ctx-defslot :fact/os-windows  boolean "Non-nil on Windows.")
(my/ctx-defslot :fact/native-comp boolean "Non-nil when native-comp is available.")
(my/ctx-defslot :fact/treesit     boolean "Non-nil when tree-sitter is available.")
(my/ctx-defslot :fact/wayland     boolean "Non-nil on a Wayland session.")
(my/ctx-defslot :fact/emacs-version string "Emacs version string.")

;; ── State slots (mutable runtime state) ───────────────────────────────────────
(my/ctx-defslot :state/phase      symbol
  "Current startup phase (bootstrap/platform/kernel/stages/post-init/ready)."
  :required t)
(my/ctx-defslot :state/health-log list
  "Alist of (stage . status) health records.")

;; ── Legacy slots (backward compat; will warn on access) ────────────────────
;; Keep the V1 keyword aliases so existing callers don't break immediately.
(my/ctx-defslot :phase            symbol "Legacy alias for :state/phase.")
(my/ctx-defslot :gui              boolean "Legacy alias for :fact/gui.")
(my/ctx-defslot :tty              boolean "Legacy alias for :fact/tty.")
(my/ctx-defslot :os-linux         boolean "Legacy alias for :fact/os-linux.")
(my/ctx-defslot :os-macos         boolean "Legacy alias for :fact/os-macos.")
(my/ctx-defslot :os-windows       boolean "Legacy alias for :fact/os-windows.")
(my/ctx-defslot :native-comp      boolean "Legacy alias for :fact/native-comp.")
(my/ctx-defslot :treesit          boolean "Legacy alias for :fact/treesit.")
(my/ctx-defslot :wayland          boolean "Legacy alias for :fact/wayland.")
(my/ctx-defslot :health-log       list    "Legacy alias for :state/health-log.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Type predicate
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx--type-ok-p (type value)
  "Return non-nil when VALUE is compatible with declared TYPE."
  (pcase type
    ('boolean (or (null value) (eq value t) (booleanp value)))
    ('symbol  (symbolp value))
    ('string  (stringp value))
    ('integer (integerp value))
    ('float   (floatp value))
    ('number  (numberp value))
    ('list    (listp value))
    ('any     t)
    (_        t)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Runtime context tables
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/runtime-context (make-hash-table :test #'eq)
  "Centralised runtime context table.")

;; Track which :fact/* keys have been set (immutability guard)
(defvar my/ctx--facts-set (make-hash-table :test #'eq)
  "Set of :fact/* keys that have been written at least once.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Accessors
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx-get (key &optional default)
  "Return KEY from context, or DEFAULT.
  Legacy keys emit a deprecation warning on first read."
  (when (eq (my/ctx--key-namespace key) 'legacy)
    (my/log-debug "ctx" "legacy key access: %s (prefer :fact/* or :state/*)" key))
  (let ((v (gethash key my/runtime-context :__missing__)))
    (if (eq v :__missing__) default v)))

(defun my/ctx-set (key value)
  "Set KEY to VALUE.
  :fact/* keys are write-once; subsequent writes are warned and ignored.
  Type is validated against schema (warn only, non-fatal)."
  (let ((ns (my/ctx--key-namespace key)))
    ;; Immutability guard for facts
    (when (and (eq ns 'fact) (gethash key my/ctx--facts-set))
      (my/log-warn "ctx" "attempt to overwrite immutable fact %s (ignored)" key)
      (cl-return-from my/ctx-set value))
    ;; Legacy key warning
    (when (eq ns 'legacy)
      (my/log-debug "ctx" "legacy key write: %s (prefer :fact/* or :state/*)" key))
    ;; Type check
    (let ((slot (gethash key my/ctx--schema)))
      (when (and slot
                 (not (my/ctx--type-ok-p (plist-get slot :type) value)))
        (my/log-warn "ctx" "type mismatch for %s: expected %s got %S"
                     key (plist-get slot :type) value)))
    ;; Store
    (puthash key value my/runtime-context)
    (when (eq ns 'fact)
      (puthash key t my/ctx--facts-set))
    value))

(defun my/ctx-update (key fn &optional default)
  "Apply FN to current value of KEY (or DEFAULT) and store result."
  (my/ctx-set key (funcall fn (my/ctx-get key default))))

(defun my/ctx-snapshot ()
  "Return sorted alist snapshot of the context."
  (let (pairs)
    (maphash (lambda (k v) (push (cons k v) pairs)) my/runtime-context)
    (sort pairs (lambda (a b)
                  (string< (symbol-name (car a)) (symbol-name (car b)))))))

;; ─────────────────────────────────────────────────────────────────────────────
;; View layer  (derived / computed — never stored)
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/ctx--views (make-hash-table :test #'eq)
  "Map :view/* key → thunk (no args) that computes the derived value.")

(defmacro my/ctx-defview (key doc &rest body)
  "Define a derived context view KEY computed by BODY.
  BODY is evaluated fresh on each call to my/ctx-get-view."
  (declare (indent 2))
  `(puthash ,key (lambda () ,@body) my/ctx--views))

(defun my/ctx-get-view (key)
  "Evaluate and return the derived view for KEY."
  (let ((thunk (gethash key my/ctx--views)))
    (if thunk
        (funcall thunk)
      (error "No view defined for %S" key))))

;; Built-in views
(my/ctx-defview :view/os-name "Current OS as a friendly string."
  (cond ((my/ctx-get :fact/os-macos)   "macOS")
        ((my/ctx-get :fact/os-linux)   "Linux")
        ((my/ctx-get :fact/os-windows) "Windows")
        (t                              "unknown")))

(my/ctx-defview :view/display-type "gui or tty string."
  (if (my/ctx-get :fact/gui) "gui" "tty"))

;; ─────────────────────────────────────────────────────────────────────────────
;; Invariant validation
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx-validate-invariants ()
  "Check that :required slots are non-nil.  Returns t on success."
  (let ((ok t))
    (maphash (lambda (key slot)
               (when (plist-get slot :required)
                 (let ((v (my/ctx-get key :__unset__)))
                   (when (or (eq v :__unset__) (null v))
                     (my/log-error "ctx" "required slot %s is unset" key)
                     (setq ok nil)))))
             my/ctx--schema)
    ok))

;; ─────────────────────────────────────────────────────────────────────────────
;; Schema introspection
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx-schema-info ()
  "Return alist of (key . slot-plist) for declared slots."
  (let (result)
    (maphash (lambda (k v) (push (cons k v) result)) my/ctx--schema)
    (sort result (lambda (a b)
                   (string< (symbol-name (car a)) (symbol-name (car b)))))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Phase management  (uses :state/phase; :phase is legacy alias)
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/ctx-phases
  '(bootstrap platform kernel stages post-init ready)
  "Ordered startup phases.")

(defun my/ctx-phase ()
  "Return current startup phase."
  (or (my/ctx-get :state/phase)
      (my/ctx-get :phase 'bootstrap)))

(defun my/ctx-set-phase (phase)
  "Advance startup phase and log the transition."
  (my/log-info "ctx" "phase: %s → %s" (my/ctx-phase) phase)
  (my/ctx-set :state/phase phase)
  ;; Keep legacy alias in sync
  (puthash :phase phase my/runtime-context))

;; ─────────────────────────────────────────────────────────────────────────────
;; Capability helpers  (write to :fact/* namespace)
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx-capability-p (cap)
  "Return non-nil when capability CAP is set."
  (my/ctx-get cap nil))

(defun my/ctx-declare-capabilities ()
  "Populate :fact/* slots from current Emacs environment.
  Call once after platform detection.  Facts are immutable thereafter."
  ;; Core facts
  (my/ctx-set :fact/gui         (display-graphic-p))
  (my/ctx-set :fact/tty         (not (display-graphic-p)))
  (my/ctx-set :fact/os-linux    (eq system-type 'gnu/linux))
  (my/ctx-set :fact/os-macos    (eq system-type 'darwin))
  (my/ctx-set :fact/os-windows  (memq system-type '(windows-nt ms-dos cygwin)))
  (my/ctx-set :fact/native-comp (featurep 'native-compile))
  (my/ctx-set :fact/treesit     (and (fboundp 'treesit-available-p)
                                     (treesit-available-p)))
  (my/ctx-set :fact/wayland     (and (eq system-type 'gnu/linux)
                                     (string= (or (getenv "XDG_SESSION_TYPE") "")
                                              "wayland")))
  (my/ctx-set :fact/emacs-version emacs-version)
  ;; Keep legacy aliases in sync (read-only copy; no fact guard needed here
  ;; because we puthash directly, bypassing the guard)
  (dolist (pair '((:gui         . :fact/gui)
                  (:tty         . :fact/tty)
                  (:os-linux    . :fact/os-linux)
                  (:os-macos    . :fact/os-macos)
                  (:os-windows  . :fact/os-windows)
                  (:native-comp . :fact/native-comp)
                  (:treesit     . :fact/treesit)
                  (:wayland     . :fact/wayland)))
    (puthash (car pair)
             (gethash (cdr pair) my/runtime-context)
             my/runtime-context))
  (my/ctx-validate-invariants)
  (my/log-info "ctx" "capabilities declared [%s/%s]"
               (my/ctx-get-view :view/os-name)
               (my/ctx-get-view :view/display-type)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Health log  (uses :state/health-log; :health-log is legacy alias)
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx-record-health (stage status)
  "Append STAGE STATUS pair to health log."
  (my/ctx-update :state/health-log
                 (lambda (log) (append log (list (cons stage status))))
                 nil)
  (puthash :health-log
           (my/ctx-get :state/health-log)
           my/runtime-context))

(defun my/ctx-health-summary ()
  "Return alist of (stage . status) pairs."
  (my/ctx-get :state/health-log nil))

;; ─────────────────────────────────────────────────────────────────────────────
;; Init
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-context-init ()
  "Initialise runtime context subsystem."
  (clrhash my/runtime-context)
  (clrhash my/ctx--facts-set)
  (my/ctx-set :state/phase 'bootstrap)
  (puthash :phase 'bootstrap my/runtime-context)
  (my/log-info "ctx" "context initialised (fact/state/view layering active)"))

(provide 'runtime-context)
;;; runtime-context.el ends here
