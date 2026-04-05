;;; runtime-feature.el --- Hierarchical feature flag system -*- lexical-binding: t; -*-
;;; Commentary:
;;; 1. A macro `my/deffeature` registers a flag with an optional :parent.
;;; 2. `my/feature-enabled-p` walks up the parent chain – if any ancestor is
;;;    nil the gate is closed regardless of the flag's own value.
;;; 3. The resolver understands: nil, t, bound-symbol, function, plist
;;;    (:and/:or/:not of gates).
;;; 4. A profile system maps a profile name to a set of flag overrides,
;;;    applied at kernel-init time before manifests run.
;;;
;;; Usage:
;;;   (my/deffeature my/feature-app t "Enable application layer.")
;;;   (my/deffeature my/feature-app-llm t "Enable LLM app."
;;;     :parent my/feature-app)
;;;
;;; Resolution:
;;;   (my/feature-enabled-p 'my/feature-app-llm)
;;;   ;; => nil if my/feature-app is nil, regardless of my/feature-app-llm
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ---------------------------------------------------------------------------
;; Internal registry
;; ---------------------------------------------------------------------------

(defvar my/feature-registry (make-hash-table :test #'eq)
  "Map feature symbol → plist (:value BOOL :parent SYMBOL-OR-NIL :doc STRING).")

;; ---------------------------------------------------------------------------
;; Declaration macro
;; ---------------------------------------------------------------------------

(defmacro my/deffeature (sym default doc &rest keys)
  "Declare feature flag SYM with DEFAULT value and DOC string.
Optional keyword args:
  :parent PARENT-SYM  — this flag inherits from PARENT-SYM.
Example:
  (my/deffeature my/feature-app t \"Application layer.\")
  (my/deffeature my/feature-app-llm t \"LLM app.\" :parent my/feature-app)"
  (declare (indent 2))
  (let ((parent (plist-get keys :parent)))
    `(progn
       (defcustom ,sym ,default ,doc
         :type 'boolean
         :group 'my/features)
       (puthash ',sym
                (list :value   ,default
                      :parent  ',parent
                      :doc     ,doc)
                my/feature-registry)
       ',sym)))

;; ---------------------------------------------------------------------------
;; Resolution
;; ---------------------------------------------------------------------------

(defun my/feature--resolve-gate (gate)
  "Resolve a single GATE expression to a boolean.

Supported forms:
  nil                   → t   (absent gate = always enabled)
  t                     → t
  SYMBOL (bound)        → (symbol-value SYMBOL)
  FUNCTION              → (funcall FUNCTION)
  (:and GATE ...)       → all sub-gates must pass
  (:or  GATE ...)       → at least one sub-gate must pass
  (:not GATE)           → invert sub-gate"
  (cond
   ((null gate)    t)
   ((eq gate t)    t)

   ((and (listp gate) (eq (car gate) :and))
    (cl-every #'my/feature--resolve-gate (cdr gate)))

   ((and (listp gate) (eq (car gate) :or))
    (cl-some #'my/feature--resolve-gate (cdr gate)))

   ((and (listp gate) (eq (car gate) :not))
    (not (my/feature--resolve-gate (cadr gate))))

   ((and (symbolp gate) (boundp gate))
    (not (null (symbol-value gate))))

   ((functionp gate)
    (not (null (funcall gate))))

   ((and (symbolp gate) (fboundp gate))
    (not (null (funcall gate))))

   ((symbolp gate)
    (my/log "[feature] unresolved gate symbol: %S" gate)
    nil)

   (t (not (null gate)))))

(defun my/feature--ancestors (sym)
  "Return ordered list of ancestor feature symbols for SYM (nearest first)."
  (let ((spec (gethash sym my/feature-registry))
        ancestors)
    (while spec
      (let ((parent (plist-get spec :parent)))
        (if (and parent (not (memq parent ancestors)))
            (progn
              (push parent ancestors)
              (setq spec (gethash parent my/feature-registry)))
          (setq spec nil))))
    (nreverse ancestors)))

(defun my/feature-enabled-p (gate)
  "Return non-nil when GATE resolves truthy, respecting parent hierarchy.

If GATE names a registered feature, all ancestors are checked first –
the gate is closed if any ancestor is disabled."
  (if (not (symbolp gate))
      ;; Composite or raw form – delegate directly
      (my/feature--resolve-gate gate)
    ;; Registered feature: check ancestry chain first
    (let ((ancestors (my/feature--ancestors gate)))
      (and
       ;; All ancestors must be enabled
       (cl-every (lambda (anc)
                   (my/feature--resolve-gate anc))
                 ancestors)
       ;; Then check the flag itself
       (my/feature--resolve-gate gate)))))

;; Keep V1-compatible alias used by module runner
(defalias 'my/runtime-feature-enabled-p 'my/feature-enabled-p)

;; ---------------------------------------------------------------------------
;; Profile system
;; ---------------------------------------------------------------------------

(defvar my/feature-profiles (make-hash-table :test #'equal)
  "Map profile-name (string) → alist of (feature-symbol . value).")

(defun my/feature-define-profile (name overrides)
  "Define a feature profile NAME with OVERRIDES alist.
Example:
  (my/feature-define-profile \"minimal\"
    \\='((my/feature-app . nil)
      (my/feature-ops  . nil)))"
  (puthash name overrides my/feature-profiles))

(defun my/feature-apply-profile (name)
  "Apply feature profile NAME, overriding individual flag values.
Call this before stages run (inside kernel init)."
  (let ((overrides (gethash name my/feature-profiles)))
    (unless overrides
      (user-error "Unknown feature profile: %s" name))
    (dolist (pair overrides)
      (let ((sym (car pair))
            (val (cdr pair)))
        (when (boundp sym)
          (set sym val)
          (my/log "[feature] profile=%s override %s=%s" name sym val))))
    (my/log "[feature] applied profile: %s" name)))

;; ---------------------------------------------------------------------------
;; Built-in profiles
;; ---------------------------------------------------------------------------

(defun my/feature--register-builtin-profiles ()
  "Register built-in profiles.  Called by my/runtime-feature-init."

  ;; Full: everything on (default)
  (my/feature-define-profile "full" nil)

  ;; Minimal: only kernel-level layers, no app/ops/lang extras
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

  ;; Server: no UI/UX chrome
  (my/feature-define-profile
   "server"
   '((my/feature-ui     . nil)
     (my/feature-app    . nil))))

;; ---------------------------------------------------------------------------
;; Flag declarations
;; (same flags as V1, now with parent linkage)
;; ---------------------------------------------------------------------------

(defgroup my/features nil
  "Feature flags for my Emacs configuration."
  :group 'my)

;; Root layers
(my/deffeature my/feature-ui                t "Enable UI layer.")
(my/deffeature my/feature-ux                t "Enable UX layer.")
(my/deffeature my/feature-editor            t "Enable editor layer.")
(my/deffeature my/feature-project           t "Enable project layer.")
(my/deffeature my/feature-vcs               t "Enable VCS layer.")
(my/deffeature my/feature-prog              t "Enable programming infrastructure layer.")
(my/deffeature my/feature-lang              t "Enable language adapter layer.")
(my/deffeature my/feature-app               t "Enable application layer.")
(my/deffeature my/feature-ops               t "Enable operations layer.")

;; UX children
(my/deffeature my/feature-ux-helpful        t "Enable helpful integration."
  :parent my/feature-ux)
(my/deffeature my/feature-ux-embark         t "Enable embark integration."
  :parent my/feature-ux)

;; Project children
(my/deffeature my/feature-project-search    t "Enable project search."
  :parent my/feature-project)
(my/deffeature my/feature-project-compile   t "Enable project compile workflow."
  :parent my/feature-project)
(my/deffeature my/feature-project-test      t "Enable project test workflow."
  :parent my/feature-project)
(my/deffeature my/feature-project-workspace t "Enable project workspace integration."
  :parent my/feature-project)

;; VCS children
(my/deffeature my/feature-vcs-magit         t "Enable Magit integration."
  :parent my/feature-vcs)
(my/deffeature my/feature-vcs-diff          t "Enable VCS diff UX."
  :parent my/feature-vcs)
(my/deffeature my/feature-vcs-blame         t "Enable VCS blame UX."
  :parent my/feature-vcs)

;; Prog children
(my/deffeature my/feature-prog-ai           t "Enable AI integrations."
  :parent my/feature-prog)
(my/deffeature my/feature-prog-treesit      t "Enable treesit integration."
  :parent my/feature-prog)
(my/deffeature my/feature-prog-lsp          t "Enable LSP integration."
  :parent my/feature-prog)
(my/deffeature my/feature-prog-diagnostics  t "Enable diagnostics integration."
  :parent my/feature-prog)
(my/deffeature my/feature-prog-xref         t "Enable xref enhancements."
  :parent my/feature-prog)
(my/deffeature my/feature-prog-debug        t "Enable debug integration."
  :parent my/feature-prog)
(my/deffeature my/feature-prog-build        t "Enable build integration."
  :parent my/feature-prog)

;; Lang children
(my/deffeature my/feature-lang-python       t "Enable Python adapter."
  :parent my/feature-lang)
(my/deffeature my/feature-lang-rust         t "Enable Rust adapter."
  :parent my/feature-lang)
(my/deffeature my/feature-lang-tsjs         t "Enable TS/JS adapter."
  :parent my/feature-lang)
(my/deffeature my/feature-lang-nix          t "Enable Nix adapter."
  :parent my/feature-lang)
(my/deffeature my/feature-lang-elisp        t "Enable Emacs Lisp adapter."
  :parent my/feature-lang)
(my/deffeature my/feature-lang-go           t "Enable Go adapter."
  :parent my/feature-lang)
(my/deffeature my/feature-lang-web          t "Enable Web adapter."
  :parent my/feature-lang)
(my/deffeature my/feature-lang-markdown     t "Enable Markdown adapter."
  :parent my/feature-lang)
(my/deffeature my/feature-lang-org          t "Enable Org adapter."
  :parent my/feature-lang)
(my/deffeature my/feature-lang-data         t "Enable YAML/JSON/TOML adapter."
  :parent my/feature-lang)

;; App children
(my/deffeature my/feature-app-terminal      t "Enable terminal app."
  :parent my/feature-app)
(my/deffeature my/feature-app-dired         t "Enable dired app."
  :parent my/feature-app)
(my/deffeature my/feature-app-eshell        t "Enable eshell app."
  :parent my/feature-app)
(my/deffeature my/feature-app-vterm         t "Enable vterm app."
  :parent my/feature-app)
(my/deffeature my/feature-app-notes         t "Enable notes app."
  :parent my/feature-app)
(my/deffeature my/feature-app-rss           t "Enable RSS app."
  :parent my/feature-app)
(my/deffeature my/feature-app-llm           t "Enable LLM app."
  :parent my/feature-app)

;; Ops children
(my/deffeature my/feature-ops-startup       t "Enable startup ops."
  :parent my/feature-ops)
(my/deffeature my/feature-ops-profiler      t "Enable profiler ops."
  :parent my/feature-ops)
(my/deffeature my/feature-ops-healthcheck   t "Enable healthcheck ops."
  :parent my/feature-ops)
(my/deffeature my/feature-ops-benchmark     t "Enable benchmark ops."
  :parent my/feature-ops)
(my/deffeature my/feature-ops-sandbox       t "Enable sandbox ops."
  :parent my/feature-ops)

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(defun my/runtime-feature-init ()
  "Initialise runtime feature subsystem."
  (my/feature--register-builtin-profiles)
  (my/log "[feature] hierarchical feature system ready (%d flags)"
          (hash-table-count my/feature-registry)))

(provide 'runtime-feature)
;;; runtime-feature.el ends here
