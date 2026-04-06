;;; runtime-provider.el --- Provider lifecycle abstraction  -*- lexical-binding: t; -*-
;;; Commentary:
;;; A Provider wraps the full lifecycle of a manifest module:
;;;   load   → (require :require)   — make the feature available
;;;   init   → (funcall :init)      — activate / configure
;;;   teardown → optional cleanup   — future use
;;;
;;; Provider is a cl-defstruct created from a normalised manifest spec.
;;; The runner calls my/provider-load and my/provider-init separately,
;;; enabling:
;;;   - load-time errors to be isolated from init-time errors
;;;   - deferred-init without re-loading the feature file
;;;   - future :teardown / :reload hooks
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ---------------------------------------------------------------------------
;; Provider struct
;; ---------------------------------------------------------------------------

(cl-defstruct (my/provider
               (:constructor my/provider--make)
               (:copier nil))
  "Lifecycle spec for one manifest module."
  ;; Identity
  (name        nil :read-only t :documentation "Module name symbol.")
  ;; Gates (evaluated by runner, not here)
  (feature     nil :read-only t :documentation ":feature gate.")
  (when-gate   nil :read-only t :documentation ":when environment condition.")
  (after       nil :read-only t :documentation ":after dependency list.")
  ;; Lifecycle fns
  (require-sym nil :read-only t :documentation "Symbol passed to (require …).")
  (init-fn     nil :read-only t :documentation "Thunk called to activate module.")
  ;; Scheduling
  (defer       nil :read-only t :documentation "Defer strategy or nil.")
  ;; Metadata
  (description nil :read-only t :documentation "Human-readable summary.")
  (version     nil :read-only t :documentation "Semver or arbitrary tag.")
  (tags        nil :read-only t :documentation "Keyword tag list."))

;; ---------------------------------------------------------------------------
;; Constructor from manifest spec plist
;; ---------------------------------------------------------------------------

(defun my/provider-from-spec (spec)
  "Build a `my/provider' from normalised manifest SPEC plist."
  (my/provider--make
   :name        (plist-get spec :name)
   :feature     (plist-get spec :feature)
   :when-gate   (plist-get spec :when)          ; V2 new field
   :after       (plist-get spec :after)
   :require-sym (plist-get spec :require)
   :init-fn     (plist-get spec :init)
   :defer       (plist-get spec :defer)
   :description (plist-get spec :description)
   :version     (plist-get spec :version)
   :tags        (plist-get spec :tags)))

;; ---------------------------------------------------------------------------
;; Lifecycle operations
;; ---------------------------------------------------------------------------

(defun my/provider-load (provider)
  "Load the provider's feature file via (require :require-sym).
  Returns t on success, nil on failure.  Never signals."
  (let ((sym (my/provider-require-sym provider)))
    (condition-case err
        (progn (require sym nil t) t)
      (error
       (my/log-error "provider" "load failed %s -> %S"
                     (my/provider-name provider) err)
       nil))))

(defun my/provider-init (provider)
  "Call the provider's init function.
  Returns t on success, nil on failure.  Never signals."
  (let ((fn (my/provider-init-fn provider)))
    (condition-case err
        (progn (funcall fn) t)
      (error
       (my/log-error "provider" "init failed %s -> %S"
                     (my/provider-name provider) err)
       nil))))

;; ---------------------------------------------------------------------------
;; Introspection helpers
;; ---------------------------------------------------------------------------

(defun my/provider-describe (provider)
  "Return human-readable one-liner for PROVIDER."
  (format "%s [%s]%s"
          (my/provider-name provider)
          (or (my/provider-description provider) "no description")
          (if (my/provider-version provider)
              (format " v%s" (my/provider-version provider))
            "")))

(provide 'runtime-provider)
;;; runtime-provider.el ends here
