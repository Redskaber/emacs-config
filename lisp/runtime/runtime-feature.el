;;; runtime-feature.el --- Hierarchical feature flag system -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - my/feature-list: sort bug fixed (symbol→string before compare)
;;;     - registry: :value field removed; current value always via symbol-value
;;;     - gate semantics: symbol-function gate removed; only variable or lambda
;;;     - cycle guard
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ─────────────────────────────────────────────────────────────────────────────
;; Feature registry
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/feature--registry (make-hash-table :test #'eq)
  "Map feature-symbol → plist (:parent SYMBOL :doc STRING :tags LIST).
  Note: current value is always (symbol-value sym), not stored here.")

(defmacro my/deffeature (sym default doc &rest keys)
  "Declare feature flag SYM with DEFAULT and DOC.
  Keyword args: :parent PARENT-SYM :tags LIST"
  (declare (indent 2))
  (let ((parent (plist-get keys :parent))
        (tags   (plist-get keys :tags)))
    `(progn
       (defcustom ,sym ,default ,doc
         :type 'boolean :group 'my/features)
       (puthash ',sym
                (list :parent ',parent
                      :doc    ,doc
                      :tags   ',tags)
                my/feature--registry)
       ',sym)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Gate resolver  (removed fboundp/symbol-function branch)
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/gate-resolve (gate)
  "Resolve GATE to boolean.

  nil / absent  → t (no gate = always pass)
  t             → t
  (:and …)      → AND of sub-gates
  (:or …)       → OR of sub-gates
  (:not GATE)   → NOT sub-gate
  SYMBOL        → (symbol-value SYMBOL)  [variable/feature flag only]
  FUNCTION      → (funcall FUNCTION)     [lambda or closure, not symbol-function]

  NOTE: Named functions must be passed explicitly as #'fn or
  (function fn).  Bare symbols are treated as variables, not function refs.
  This eliminates ambiguity when a symbol is both a variable and a function."
  (cond
   ((null gate)   t)
   ((eq gate t)   t)
   ((and (listp gate) (eq (car gate) :and))
    (cl-every #'my/gate-resolve (cdr gate)))
   ((and (listp gate) (eq (car gate) :or))
    (cl-some #'my/gate-resolve (cdr gate)))
   ((and (listp gate) (eq (car gate) :not))
    (not (my/gate-resolve (cadr gate))))
   ((symbolp gate)
    (if (boundp gate)
        (not (null (symbol-value gate)))
      (my/log-warn "feature" "unresolved gate symbol: %S (not bound)" gate)
      nil))
   ;; Lambda / closure — explicit callable
   ((functionp gate)
    (not (null (funcall gate))))
   (t (not (null gate)))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Ancestor resolution
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/feature--ancestors (sym)
  "Return ordered ancestor list for SYM (nearest first).
  Returns nil on cycle detection."
  (let ((spec    (gethash sym my/feature--registry))
        (visited (list sym))
        ancestors)
    (while spec
      (let ((parent (plist-get spec :parent)))
        (cond
         ((null parent)
          (setq spec nil))
         ((memq parent visited)
          (my/log-warn "feature"
                       "cycle in :parent chain for %S at %S; aborting" sym parent)
          (setq spec nil ancestors nil))
         (t
          (push parent ancestors)
          (push parent visited)
          (setq spec (gethash parent my/feature--registry))))))
    (nreverse ancestors)))

(defun my/feature-enabled-p (gate)
  "Return non-nil when GATE is truthy, checking ancestor chain for feature symbols."
  (if (or (null gate) (eq gate t))
      (my/gate-resolve gate)
    (if (and (symbolp gate) (gethash gate my/feature--registry))
        (and (cl-every #'my/gate-resolve (my/feature--ancestors gate))
             (my/gate-resolve gate))
      (my/gate-resolve gate))))

(defalias 'my/runtime-feature-enabled-p 'my/feature-enabled-p)

;; ─────────────────────────────────────────────────────────────────────────────
;; Profile system
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/feature--profiles (make-hash-table :test #'equal))

(defun my/feature-define-profile (name overrides)
  "Define feature profile NAME with OVERRIDES alist."
  (puthash name overrides my/feature--profiles))

(defun my/feature-apply-profile (name)
  "Apply feature profile NAME."
  (let ((overrides (gethash name my/feature--profiles)))
    (unless overrides (user-error "Unknown feature profile: %s" name))
    (dolist (pair overrides)
      (when (and (boundp (car pair))
                 (gethash (car pair) my/feature--registry))
        (set (car pair) (cdr pair))
        (my/log-debug "feature" "profile=%s override %s=%s"
                      name (car pair) (cdr pair))))
    (my/log-info "feature" "applied profile: %s" name)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Introspection
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/feature-list ()
  "Return sorted list of all declared feature symbols."
  (let (syms)
    (maphash (lambda (k _) (push k syms)) my/feature--registry)
    ;; compare symbol-name strings, not symbols directly
    (sort syms (lambda (a b) (string< (symbol-name a) (symbol-name b))))))

(defun my/feature-info (sym)
  "Return registry metadata plist for feature SYM.
  Current value is (symbol-value SYM), not in registry."
  (let ((meta (gethash sym my/feature--registry)))
    (when meta
      (append (list :value (and (boundp sym) (symbol-value sym))) meta))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Built-in profiles
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/feature--register-builtin-profiles ()
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

;; ─────────────────────────────────────────────────────────────────────────────
;; Feature declarations  (unchanged)
;; ─────────────────────────────────────────────────────────────────────────────

(defgroup my/features nil "Feature flags." :group 'my)

(my/deffeature my/feature-ui                t "Enable UI layer."                    :tags (:layer))
(my/deffeature my/feature-ux                t "Enable UX layer."                    :tags (:layer))
(my/deffeature my/feature-editor            t "Enable editor layer."                :tags (:layer))
(my/deffeature my/feature-project           t "Enable project layer."               :tags (:layer))
(my/deffeature my/feature-vcs               t "Enable VCS layer."                   :tags (:layer))
(my/deffeature my/feature-prog              t "Enable programming infrastructure."  :tags (:layer))
(my/deffeature my/feature-lang              t "Enable language adapter layer."      :tags (:layer))
(my/deffeature my/feature-app               t "Enable application layer."           :tags (:layer))
(my/deffeature my/feature-ops               t "Enable operations layer."            :tags (:layer))

(my/deffeature my/feature-ux-helpful        t "Enable helpful."           :parent my/feature-ux :tags (:ux))
(my/deffeature my/feature-ux-embark         t "Enable embark."            :parent my/feature-ux :tags (:ux))

(my/deffeature my/feature-project-search    t "Enable project search."    :parent my/feature-project :tags (:project))
(my/deffeature my/feature-project-compile   t "Enable project compile."   :parent my/feature-project :tags (:project))
(my/deffeature my/feature-project-test      t "Enable project test."      :parent my/feature-project :tags (:project))
(my/deffeature my/feature-project-workspace t "Enable project workspace." :parent my/feature-project :tags (:project))

(my/deffeature my/feature-vcs-magit         t "Enable Magit."             :parent my/feature-vcs :tags (:vcs))
(my/deffeature my/feature-vcs-diff          t "Enable VCS diff UX."       :parent my/feature-vcs :tags (:vcs))
(my/deffeature my/feature-vcs-blame         t "Enable VCS blame."         :parent my/feature-vcs :tags (:vcs))

(my/deffeature my/feature-prog-ai           t "Enable AI integrations."   :parent my/feature-prog :tags (:prog :ai))
(my/deffeature my/feature-prog-treesit      t "Enable treesit."           :parent my/feature-prog :tags (:prog))
(my/deffeature my/feature-prog-lsp          t "Enable LSP."               :parent my/feature-prog :tags (:prog))
(my/deffeature my/feature-prog-diagnostics  t "Enable diagnostics."       :parent my/feature-prog :tags (:prog))
(my/deffeature my/feature-prog-xref         t "Enable xref."              :parent my/feature-prog :tags (:prog))
(my/deffeature my/feature-prog-debug        t "Enable debug."             :parent my/feature-prog :tags (:prog))
(my/deffeature my/feature-prog-build        t "Enable build."             :parent my/feature-prog :tags (:prog))

(my/deffeature my/feature-lang-python       t "Enable Python."            :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-rust         t "Enable Rust."              :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-tsjs         t "Enable TS/JS."             :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-nix          t "Enable Nix."               :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-elisp        t "Enable Emacs Lisp."        :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-go           t "Enable Go."                :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-web          t "Enable Web."               :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-markdown     t "Enable Markdown."          :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-org          t "Enable Org."               :parent my/feature-lang :tags (:lang))
(my/deffeature my/feature-lang-data         t "Enable YAML/JSON/TOML."    :parent my/feature-lang :tags (:lang))

(my/deffeature my/feature-app-terminal      t "Enable terminal."          :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-dired         t "Enable dired."             :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-eshell        t "Enable eshell."            :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-vterm         t "Enable vterm."             :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-notes         t "Enable notes."             :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-rss           t "Enable RSS."               :parent my/feature-app :tags (:app))
(my/deffeature my/feature-app-llm           t "Enable LLM app."           :parent my/feature-app :tags (:app :ai))

(my/deffeature my/feature-ops-startup       t "Enable startup ops."       :parent my/feature-ops :tags (:ops))
(my/deffeature my/feature-ops-profiler      t "Enable profiler ops."      :parent my/feature-ops :tags (:ops))
(my/deffeature my/feature-ops-healthcheck   t "Enable healthcheck ops."   :parent my/feature-ops :tags (:ops))
(my/deffeature my/feature-ops-benchmark     t "Enable benchmark ops."     :parent my/feature-ops :tags (:ops))
(my/deffeature my/feature-ops-sandbox       t "Enable sandbox ops."       :parent my/feature-ops :tags (:ops))

;; ─────────────────────────────────────────────────────────────────────────────
;; Init
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-feature-init ()
  (my/feature--register-builtin-profiles)
  (my/log-info "feature" "hierarchical feature system ready (%d flags)"
               (hash-table-count my/feature--registry)))

(provide 'runtime-feature)
;;; runtime-feature.el ends here
