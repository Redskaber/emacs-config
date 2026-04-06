;;; runtime-feature.el --- Hierarchical feature flag system -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. :feature gate  = user/config capability switch (defcustom boolean).
;;;      :when    gate  = environment/runtime condition (any resolvable form).
;;;      The two gates are now semantically distinct and independently evaluated.
;;;
;;;   2. my/deffeature macro unchanged in surface API; gains :tags keyword.
;;;
;;;   3. Gate resolver is extracted to my/gate-resolve — standalone fn usable
;;;      by module-runner without going through feature-enabled-p.
;;;
;;;   4. Profile system preserved; profiles only override :feature flags, never
;;;      :when conditions (which are always runtime-evaluated).
;;;
;;; Gate resolution rules (unchanged from V1 for compatibility):
;;;   nil | absent → t (always enabled)
;;;   t            → t
;;;   SYMBOL       → (symbol-value SYMBOL) when bound, else nil
;;;   FUNCTION     → (funcall FUNCTION)
;;;   (:and …)     → all sub-gates truthy
;;;   (:or  …)     → any sub-gate truthy
;;;   (:not GATE)  → invert
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ---------------------------------------------------------------------------
;; Feature registry
;; ---------------------------------------------------------------------------

(defvar my/feature--registry (make-hash-table :test #'eq)
  "Map feature-symbol →
     (:value BOOL :parent SYMBOL-OR-NIL :doc STRING :tags LIST).")

;; ---------------------------------------------------------------------------
;; Declaration macro
;; ---------------------------------------------------------------------------

(defmacro my/deffeature (sym default doc &rest keys)
  "Declare feature flag SYM with DEFAULT and DOC.

  Keyword args:
    :parent PARENT-SYM   — inherit; gate is closed when parent is disabled.
    :tags   LIST         — keyword tags for introspection.

  Example:
    (my/deffeature my/feature-app t \"Application layer.\")
    (my/deffeature my/feature-app-llm t \"LLM app.\"
      :parent my/feature-app :tags (:ai :app))"
  (declare (indent 2))
  (let ((parent (plist-get keys :parent))
        (tags   (plist-get keys :tags)))
    `(progn
       (defcustom ,sym ,default ,doc
         :type 'boolean
         :group 'my/features)
       (puthash ',sym
                (list :value  ,default
                      :parent ',parent
                      :doc    ,doc
                      :tags   ',tags)
                my/feature--registry)
       ',sym)))

;; ---------------------------------------------------------------------------
;; Gate resolver (standalone – used by runner for :when too)
;; ---------------------------------------------------------------------------

(defun my/gate-resolve (gate)
  "Resolve a single GATE expression to a boolean.

  Supported forms:
    nil / absent              → t
    t                         → t
    SYMBOL (bound variable)   → (symbol-value SYMBOL)
    FUNCTION / (fboundp SYM)  → (funcall …)
    (:and GATE …)             → all sub-gates
    (:or  GATE …)             → any sub-gate
    (:not GATE)               → invert"
  (cond
   ((null gate)   t)
   ((eq gate t)   t)
   ((and (listp gate) (eq (car gate) :and))
    (cl-every #'my/gate-resolve (cdr gate)))
   ((and (listp gate) (eq (car gate) :or))
    (cl-some #'my/gate-resolve (cdr gate)))
   ((and (listp gate) (eq (car gate) :not))
    (not (my/gate-resolve (cadr gate))))
   ((and (symbolp gate) (boundp gate))
    (not (null (symbol-value gate))))
   ((functionp gate)
    (not (null (funcall gate))))
   ((and (symbolp gate) (fboundp gate))
    (not (null (funcall gate))))
   ((symbolp gate)
    (my/log-warn "feature" "unresolved gate symbol: %S" gate)
    nil)
   (t (not (null gate)))))

;; ---------------------------------------------------------------------------
;; Feature-specific resolution (with parent chain)
;; ---------------------------------------------------------------------------

(defun my/feature--ancestors (sym)
  "Return ordered ancestor list for feature SYM (nearest first)."
  (let ((spec (gethash sym my/feature--registry))
        ancestors)
    (while spec
      (let ((parent (plist-get spec :parent)))
        (if (and parent (not (memq parent ancestors)))
            (progn
              (push parent ancestors)
              (setq spec (gethash parent my/feature--registry)))
          (setq spec nil))))
    (nreverse ancestors)))

(defun my/feature-enabled-p (gate)
  "Return non-nil when GATE (feature symbol or gate expression) is truthy.

  For registered feature symbols the full ancestor chain is checked first."
  (if (or (null gate) (eq gate t))
      ;; Fast path: absent / always-on gate
      (my/gate-resolve gate)
    (if (and (symbolp gate) (gethash gate my/feature--registry))
        ;; Registered feature: ancestry check
        (and (cl-every #'my/gate-resolve (my/feature--ancestors gate))
             (my/gate-resolve gate))
      ;; Composite form or unregistered symbol
      (my/gate-resolve gate))))

;; V1 compat alias used by module-runner
(defalias 'my/runtime-feature-enabled-p 'my/feature-enabled-p)

;; ---------------------------------------------------------------------------
;; Profile system
;; ---------------------------------------------------------------------------

(defvar my/feature--profiles (make-hash-table :test #'equal)
  "Map profile-name (string) → alist of (feature-symbol . bool).")

(defun my/feature-define-profile (name overrides)
  "Define feature profile NAME with OVERRIDES alist.
  Overrides only apply to :feature flags, not :when conditions."
  (puthash name overrides my/feature--profiles))

(defun my/feature-apply-profile (name)
  "Apply feature profile NAME before stages run."
  (let ((overrides (gethash name my/feature--profiles)))
    (unless overrides
      (user-error "Unknown feature profile: %s" name))
    (dolist (pair overrides)
      (when (boundp (car pair))
        (set (car pair) (cdr pair))
        (my/log-debug "feature" "profile=%s override %s=%s"
                      name (car pair) (cdr pair))))
    (my/log-info "feature" "applied profile: %s" name)))

;; ---------------------------------------------------------------------------
;; Introspection
;; ---------------------------------------------------------------------------

(defun my/feature-list ()
  "Return list of all registered feature symbols."
  (let (syms)
    (maphash (lambda (k _) (push k syms)) my/feature--registry)
    (sort syms #'string<)))

(defun my/feature-info (sym)
  "Return registry entry plist for feature SYM."
  (gethash sym my/feature--registry))

;; ---------------------------------------------------------------------------
;; Built-in profiles
;; ---------------------------------------------------------------------------

(defun my/feature--register-builtin-profiles ()
  "Register built-in profiles.  Called by my/runtime-feature-init."
  (my/feature-define-profile "full" nil)

  (my/feature-define-profile
   "minimal"
   '((my/feature-app           . nil)
     (my/feature-ops           . nil)
     (my/feature-lang-python   . nil)
     (my/feature-lang-rust     . nil)
     (my/feature-lang-tsjs     . nil)
     (my/feature-lang-go       . nil)
     (my/feature-lang-nix      . nil)
     (my/feature-lang-web      . nil)))

  (my/feature-define-profile
   "server"
   '((my/feature-ui  . nil)
     (my/feature-app . nil))))

;; ---------------------------------------------------------------------------
;; Feature declarations (identical to V1; :tags added where useful)
;; ---------------------------------------------------------------------------

(defgroup my/features nil
  "Feature flags for my Emacs configuration."
  :group 'my)

;; Root layers
(my/deffeature my/feature-ui      t "Enable UI layer."     :tags (:layer))
(my/deffeature my/feature-ux      t "Enable UX layer."     :tags (:layer))
(my/deffeature my/feature-editor  t "Enable editor layer." :tags (:layer))
(my/deffeature my/feature-project t "Enable project layer." :tags (:layer))
(my/deffeature my/feature-vcs     t "Enable VCS layer."    :tags (:layer))
(my/deffeature my/feature-prog    t "Enable programming infrastructure layer." :tags (:layer))
(my/deffeature my/feature-lang    t "Enable language adapter layer." :tags (:layer))
(my/deffeature my/feature-app     t "Enable application layer." :tags (:layer))
(my/deffeature my/feature-ops     t "Enable operations layer." :tags (:layer))

;; UX children
(my/deffeature my/feature-ux-helpful  t "Enable helpful."
  :parent my/feature-ux :tags (:ux))
(my/deffeature my/feature-ux-embark   t "Enable embark."
  :parent my/feature-ux :tags (:ux))

;; Project children
(my/deffeature my/feature-project-search    t "Enable project search."
  :parent my/feature-project :tags (:project))
(my/deffeature my/feature-project-compile   t "Enable project compile."
  :parent my/feature-project :tags (:project))
(my/deffeature my/feature-project-test      t "Enable project test."
  :parent my/feature-project :tags (:project))
(my/deffeature my/feature-project-workspace t "Enable project workspace."
  :parent my/feature-project :tags (:project))

;; VCS children
(my/deffeature my/feature-vcs-magit  t "Enable Magit."
  :parent my/feature-vcs :tags (:vcs))
(my/deffeature my/feature-vcs-diff   t "Enable VCS diff UX."
  :parent my/feature-vcs :tags (:vcs))
(my/deffeature my/feature-vcs-blame  t "Enable VCS blame."
  :parent my/feature-vcs :tags (:vcs))

;; Prog children
(my/deffeature my/feature-prog-ai          t "Enable AI integrations."
  :parent my/feature-prog :tags (:prog :ai))
(my/deffeature my/feature-prog-treesit     t "Enable treesit."
  :parent my/feature-prog :tags (:prog))
(my/deffeature my/feature-prog-lsp         t "Enable LSP."
  :parent my/feature-prog :tags (:prog))
(my/deffeature my/feature-prog-diagnostics t "Enable diagnostics."
  :parent my/feature-prog :tags (:prog))
(my/deffeature my/feature-prog-xref        t "Enable xref."
  :parent my/feature-prog :tags (:prog))
(my/deffeature my/feature-prog-debug       t "Enable debug."
  :parent my/feature-prog :tags (:prog))
(my/deffeature my/feature-prog-build       t "Enable build."
  :parent my/feature-prog :tags (:prog))

;; Lang children
(my/deffeature my/feature-lang-python   t "Enable Python."
  :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-rust     t "Enable Rust."
  :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-tsjs     t "Enable TS/JS."
  :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-nix      t "Enable Nix."
  :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-elisp    t "Enable Emacs Lisp."
  :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-go       t "Enable Go."
  :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-web      t "Enable Web."
  :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-markdown t "Enable Markdown."
  :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-org      t "Enable Org."
  :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-data     t "Enable YAML/JSON/TOML."
  :parent my/feature-lang :tags (:lang))

;; App children
(my/deffeature my/feature-app-terminal  t "Enable terminal app."
  :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-dired     t "Enable dired app."
  :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-eshell    t "Enable eshell app."
  :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-vterm     t "Enable vterm app."
  :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-notes     t "Enable notes app."
  :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-rss       t "Enable RSS app."
  :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-llm       t "Enable LLM app."
  :parent my/feature-app :tags (:app :ai))

;; Ops children
(my/deffeature my/feature-ops-startup     t "Enable startup ops."
  :parent my/feature-ops :tags (:ops))
(my/deffeature my/feature-ops-profiler    t "Enable profiler ops."
  :parent my/feature-ops :tags (:ops))
(my/deffeature my/feature-ops-healthcheck t "Enable healthcheck ops."
  :parent my/feature-ops :tags (:ops))
(my/deffeature my/feature-ops-benchmark   t "Enable benchmark ops."
  :parent my/feature-ops :tags (:ops))
(my/deffeature my/feature-ops-sandbox     t "Enable sandbox ops."
  :parent my/feature-ops :tags (:ops))

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(defun my/runtime-feature-init ()
  "Initialise runtime feature subsystem."
  (my/feature--register-builtin-profiles)
  (my/log-info "feature" "hierarchical feature system ready (%d flags)"
               (hash-table-count my/feature--registry)))

(provide 'runtime-feature)
;;; runtime-feature.el ends here
