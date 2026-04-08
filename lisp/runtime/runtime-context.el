;;; runtime-context.el --- Runtime context -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - Canonical alias map: legacy keys canonicalized on read/write
;;;       No more dual-write / state-drift for :phase / :health-log etc.
;;;     - Once-only legacy warnings per key
;;;     - my/ctx-get auto-dispatches :view/* to my/ctx-get-view
;;;     - my/ctx-defslot supports :view/* namespace
;;;
;;; Three namespaces:
;;;   :fact/*   immutable after capability detection
;;;   :state/*  mutable runtime state
;;;   :view/*   derived (computed on demand, never stored)
;;;   legacy    canonicalized to :fact/* or :state/* transparently
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ─────────────────────────────────────────────────────────────────────────────
;; Canonical alias map
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/ctx--aliases
  '((:phase       . :state/phase)
    (:health-log  . :state/health-log)
    (:gui         . :fact/gui)
    (:tty         . :fact/tty)
    (:os-linux    . :fact/os-linux)
    (:os-macos    . :fact/os-macos)
    (:os-windows  . :fact/os-windows)
    (:native-comp . :fact/native-comp)
    (:treesit     . :fact/treesit)
    (:wayland     . :fact/wayland))
  "Alist mapping legacy keyword → canonical :fact/* or :state/* key.
  Bottom layer stores only canonical keys; legacy keys are transparent aliases.")

(defun my/ctx--canonicalize (key)
  "Return canonical key for KEY, resolving legacy aliases."
  (or (cdr (assq key my/ctx--aliases)) key))

;; ─────────────────────────────────────────────────────────────────────────────
;; Namespace helpers
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx--key-namespace (key)
  "Return namespace symbol: fact | state | view | legacy."
  (let ((name (symbol-name key)))
    (cond
     ((string-prefix-p ":fact/"  name) 'fact)
     ((string-prefix-p ":state/" name) 'state)
     ((string-prefix-p ":view/"  name) 'view)
     (t                                'legacy))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Once-only legacy warning tables
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/ctx--legacy-read-warned  (make-hash-table :test #'eq))
(defvar my/ctx--legacy-write-warned (make-hash-table :test #'eq))

(defun my/ctx--warn-legacy-read (key canonical)
  (unless (gethash key my/ctx--legacy-read-warned)
    (puthash key t my/ctx--legacy-read-warned)
    (my/log-debug "ctx" "legacy key read: %s → %s (first-time warning)" key canonical)))

(defun my/ctx--warn-legacy-write (key canonical)
  (unless (gethash key my/ctx--legacy-write-warned)
    (puthash key t my/ctx--legacy-write-warned)
    (my/log-debug "ctx" "legacy key write: %s → %s (first-time warning)" key canonical)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Schema
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/ctx--schema (make-hash-table :test #'eq))

(defmacro my/ctx-defslot (key type doc &rest keys)
  "Declare context slot KEY with TYPE, DOC, and optional :required."
  (declare (indent 2))
  `(puthash ,key
            (list :type    ',type
                  :doc      ,doc
                  :required ,(plist-get keys :required)
                  :ns      ',(let ((name (symbol-name key)))
                                (cond ((string-prefix-p ":fact/"  name) 'fact)
                                      ((string-prefix-p ":state/" name) 'state)
                                      ((string-prefix-p ":view/"  name) 'view)
                                      (t                                 'legacy))))
            my/ctx--schema))

;; Fact slots
(my/ctx-defslot :fact/gui           boolean "Non-nil in a GUI frame.")
(my/ctx-defslot :fact/tty           boolean "Non-nil in a TTY.")
(my/ctx-defslot :fact/os-linux      boolean "Non-nil on GNU/Linux.")
(my/ctx-defslot :fact/os-macos      boolean "Non-nil on macOS.")
(my/ctx-defslot :fact/os-windows    boolean "Non-nil on Windows.")
(my/ctx-defslot :fact/native-comp   boolean "Non-nil when native-comp available.")
(my/ctx-defslot :fact/treesit       boolean "Non-nil when tree-sitter available.")
(my/ctx-defslot :fact/wayland       boolean "Non-nil on Wayland.")
(my/ctx-defslot :fact/emacs-version string  "Emacs version string.")

;; State slots
(my/ctx-defslot :state/phase      symbol
  "Current startup phase."
  :required t)
(my/ctx-defslot :state/health-log list
  "Alist of (stage . status) health records.")

;; View slots  (:view/* supported in schema)
(my/ctx-defslot :view/os-name      any "Current OS as friendly string (computed).")
(my/ctx-defslot :view/display-type any "gui or tty string (computed).")

;; Legacy slots (no :required — they are pure aliases)
(my/ctx-defslot :phase        symbol  "Legacy alias → :state/phase.")
(my/ctx-defslot :health-log   list    "Legacy alias → :state/health-log.")
(my/ctx-defslot :gui          boolean "Legacy alias → :fact/gui.")
(my/ctx-defslot :tty          boolean "Legacy alias → :fact/tty.")
(my/ctx-defslot :os-linux     boolean "Legacy alias → :fact/os-linux.")
(my/ctx-defslot :os-macos     boolean "Legacy alias → :fact/os-macos.")
(my/ctx-defslot :os-windows   boolean "Legacy alias → :fact/os-windows.")
(my/ctx-defslot :native-comp  boolean "Legacy alias → :fact/native-comp.")
(my/ctx-defslot :treesit      boolean "Legacy alias → :fact/treesit.")
(my/ctx-defslot :wayland      boolean "Legacy alias → :fact/wayland.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Type predicate
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx--type-ok-p (type value)
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
;; Runtime tables
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/runtime-context (make-hash-table :test #'eq)
  "Centralised runtime context table.  Stores only canonical keys.")

(defvar my/ctx--facts-set (make-hash-table :test #'eq)
  "Set of :fact/* keys that have been written at least once (immutability guard).")

;; ─────────────────────────────────────────────────────────────────────────────
;; Accessors
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx-get (key &optional default)
  "Return KEY from context (or DEFAULT).

  :view/* keys are auto-dispatched to my/ctx-get-view.
  Legacy keys are canonicalized transparently.
  First-use legacy warning fires once per key."
  (let ((ns (my/ctx--key-namespace key)))
    (cond
     ;; view/* — compute on demand
     ((eq ns 'view)
      (my/ctx-get-view key))
     ;; legacy — canonicalize + once-only warn
     ((eq ns 'legacy)
      (let ((canonical (my/ctx--canonicalize key)))
        (my/ctx--warn-legacy-read key canonical)
        (let ((v (gethash canonical my/runtime-context :__missing__)))
          (if (eq v :__missing__) default v))))
     ;; fact or state — direct lookup
     (t
      (let ((v (gethash key my/runtime-context :__missing__)))
        (if (eq v :__missing__) default v))))))

(defun my/ctx-set (key value)
  "Set KEY to VALUE.
  :view/* keys signal an error — views are computed, never stored.
  Legacy keys canonicalized; original key is NOT stored (no dual-write).
  :fact/* keys are write-once.
  Type is validated (warn, non-fatal)."
  (let ((ns (my/ctx--key-namespace key)))
    (when (eq ns 'view)
      (error "ctx: cannot set a :view/* key (%S); views are computed" key))
    (let* ((canonical (if (eq ns 'legacy)
                          (progn (my/ctx--warn-legacy-write key (my/ctx--canonicalize key))
                                 (my/ctx--canonicalize key))
                        key))
           (cns (my/ctx--key-namespace canonical)))
      ;; Immutability guard for facts
      (when (and (eq cns 'fact) (gethash canonical my/ctx--facts-set))
        (my/log-warn "ctx" "attempt to overwrite immutable fact %s (ignored)" canonical)
        (cl-return-from my/ctx-set value))
      ;; Type check
      (let ((slot (gethash canonical my/ctx--schema)))
        (when (and slot (not (my/ctx--type-ok-p (plist-get slot :type) value)))
          (my/log-warn "ctx" "type mismatch for %s: expected %s got %S"
                       canonical (plist-get slot :type) value)))
      ;; Store under canonical key only
      (puthash canonical value my/runtime-context)
      (when (eq cns 'fact)
        (puthash canonical t my/ctx--facts-set))
      value)))

(defun my/ctx-update (key fn &optional default)
  "Apply FN to current value of KEY (or DEFAULT) and store result."
  (my/ctx-set key (funcall fn (my/ctx-get key default))))

(defun my/ctx-snapshot ()
  "Return sorted alist snapshot of the context (canonical keys only)."
  (let (pairs)
    (maphash (lambda (k v) (push (cons k v) pairs)) my/runtime-context)
    (sort pairs (lambda (a b)
                  (string< (symbol-name (car a)) (symbol-name (car b)))))))

;; ─────────────────────────────────────────────────────────────────────────────
;; View layer
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/ctx--views (make-hash-table :test #'eq)
  "Map :view/* key → thunk (no args).")

(defmacro my/ctx-defview (key doc &rest body)
  "Define derived context view KEY computed by BODY."
  (declare (indent 2))
  `(puthash ,key (lambda () ,@body) my/ctx--views))

(defun my/ctx-get-view (key)
  "Evaluate and return the derived view for KEY."
  (let ((thunk (gethash key my/ctx--views)))
    (if thunk
        (funcall thunk)
      (error "No view defined for %S" key))))

(my/ctx-defview :view/os-name "Current OS as a friendly string."
  (cond ((my/ctx-get :fact/os-macos)   "macOS")
        ((my/ctx-get :fact/os-linux)   "Linux")
        ((my/ctx-get :fact/os-windows) "Windows")
        (t                             "unknown")))

(my/ctx-defview :view/display-type "gui or tty string."
  (if (my/ctx-get :fact/gui) "gui" "tty"))

;; ─────────────────────────────────────────────────────────────────────────────
;; Invariant validation
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx-validate-invariants ()
  "Check required slots.  Returns t on success."
  (let ((ok t))
    (maphash (lambda (key slot)
               (when (plist-get slot :required)
                 ;; Only validate canonical keys (skip legacy aliases)
                 (when (memq (plist-get slot :ns) '(fact state))
                   (let ((v (gethash key my/runtime-context :__unset__)))
                     (when (or (eq v :__unset__) (null v))
                       (my/log-error "ctx" "required slot %s is unset" key)
                       (setq ok nil))))))
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
;; Phase management
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/ctx-phases
  '(bootstrap platform kernel stages post-init ready))

(defun my/ctx-phase ()
  "Return current startup phase."
  (or (gethash :state/phase my/runtime-context) 'bootstrap))

(defun my/ctx-set-phase (phase)
  "Advance startup phase and log the transition."
  (my/log-info "ctx" "phase: %s → %s" (my/ctx-phase) phase)
  (puthash :state/phase phase my/runtime-context))

;; ─────────────────────────────────────────────────────────────────────────────
;; Capability helpers
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx-capability-p (cap)
  (my/ctx-get cap nil))

(defun my/ctx-declare-capabilities ()
  "Populate :fact/* slots from current Emacs environment.
  Call once.  All writes go through my/ctx-set so immutability is enforced."
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
  (my/ctx-validate-invariants)
  (my/log-info "ctx" "capabilities declared [%s/%s]"
               (my/ctx-get-view :view/os-name)
               (my/ctx-get-view :view/display-type)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Health log
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/ctx-record-health (stage status)
  "Append STAGE STATUS pair to health log."
  (my/ctx-update :state/health-log
                 (lambda (log) (append log (list (cons stage status))))
                 nil))

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
  (clrhash my/ctx--legacy-read-warned)
  (clrhash my/ctx--legacy-write-warned)
  (puthash :state/phase 'bootstrap my/runtime-context)
  (my/log-info "ctx" "context initialised (alias-canonicalization active)"))

(provide 'runtime-context)
;;; runtime-context.el ends here
