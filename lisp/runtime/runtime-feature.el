;;; runtime-feature.el --- Hierarchical feature flag system -*- lexical-binding: t; -*-
;;; Commentary:
;;;  1. Ancestor resolution has explicit cycle detection (fail-fast).
;;;  2. Principle 5 enforced at code level:
;;;       :feature = policy (profile may override)
;;;       :when    = fact   (profile NEVER overrides)
;;;     my/feature-apply-profile only touches registered feature defcustoms,
;;;     never :when conditions.
;;;  3. my/feature--ancestors now returns nil and logs a warning on cycle
;;;     instead of looping forever.
;;;  4. All feature declarations and profile definitions are identical to V1.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ─────────────────────────────────────────────────────────────────────────────
;; Feature registry
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/feature--registry (make-hash-table :test #'eq)
  "Map feature-symbol → plist (:value BOOL :parent SYMBOL :doc STRING :tags LIST).")

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
                (list :value  ,default
                      :parent ',parent
                      :doc    ,doc
                      :tags   ',tags)
                my/feature--registry)
       ',sym)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Gate resolver
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/gate-resolve (gate)
  "Resolve a single GATE expression to boolean.
  nil/absent → t | t → t | SYMBOL → symbol-value | FN → funcall
  (:and …) | (:or …) | (:not GATE)"
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

;; ─────────────────────────────────────────────────────────────────────────────
;; Ancestor resolution  (V2: cycle-safe)
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/feature--ancestors (sym)
  "Return ordered ancestor list for feature SYM (nearest first).
  Returns nil and logs a warning if a :parent cycle is detected."
  (let ((spec    (gethash sym my/feature--registry))
        (visited (list sym))
        ancestors)
    (while spec
      (let ((parent (plist-get spec :parent)))
        (cond
         ((null parent)
          (setq spec nil))
         ((memq parent visited)
          ;; V2: explicit cycle guard
          (my/log-warn "feature"
                       "cycle detected in :parent chain for %S at %S; aborting"
                       sym parent)
          (setq spec nil
                ancestors nil))       ; discard partial chain on cycle
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
;; Profile system  (policy only; :when conditions are never overridden)
;; ─────────────────────────────────────────────────────────────────────────────

(defvar my/feature--profiles (make-hash-table :test #'equal))

(defun my/feature-define-profile (name overrides)
  "Define feature profile NAME with OVERRIDES alist of (feature-symbol . bool).
  Profiles only affect :feature flags (policy).  :when conditions are facts
  and are never overridden by profiles — see Principle 5."
  (puthash name overrides my/feature--profiles))

(defun my/feature-apply-profile (name)
  "Apply feature profile NAME."
  (let ((overrides (gethash name my/feature--profiles)))
    (unless overrides (user-error "Unknown feature profile: %s" name))
    (dolist (pair overrides)
      (when (and (boundp (car pair))
                 (gethash (car pair) my/feature--registry)) ; registered = policy
        (set (car pair) (cdr pair))
        (my/log-debug "feature" "profile=%s override %s=%s"
                      name (car pair) (cdr pair))))
    (my/log-info "feature" "applied profile: %s" name)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Introspection
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/feature-list ()
  (let (syms)
    (maphash (lambda (k _) (push k syms)) my/feature--registry)
    (sort syms #'string<)))

(defun my/feature-info (sym)
  (gethash sym my/feature--registry))

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
;; Feature declarations  (identical to V1)
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
