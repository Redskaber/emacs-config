;;; runtime-provider.el --- Provider lifecycle abstraction -*- lexical-binding: t; -*-
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)

;; ─────────────────────────────────────────────────────────────────────────────
;; Provider struct
;; ─────────────────────────────────────────────────────────────────────────────

(cl-defstruct (my/provider
               (:constructor my/provider--make)
               (:copier nil))
  "Lifecycle spec for one manifest module."
  ;; Identity
  (name        nil :read-only t)
  ;; Gates
  (feature     nil :read-only t)
  (when-gate   nil :read-only t)
  (after       nil :read-only t)
  ;; Lifecycle fns
  (require-sym nil :read-only t)
  (init-fn     nil :read-only t)
  (teardown-fn nil :read-only t :documentation "Optional cleanup thunk or nil.")
  ;; Scheduling
  (defer       nil :read-only t)
  ;; Metadata
  (description nil :read-only t)
  (version     nil :read-only t)
  (tags        nil :read-only t))

;; ─────────────────────────────────────────────────────────────────────────────
;; Constructor
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/provider-from-spec (spec)
  "Build a `my/provider' from normalised manifest SPEC plist."
  (my/provider--make
   :name        (plist-get spec :name)
   :feature     (plist-get spec :feature)
   :when-gate   (plist-get spec :when)
   :after       (plist-get spec :after)
   :require-sym (plist-get spec :require)
   :init-fn     (plist-get spec :init)
   :teardown-fn (plist-get spec :teardown)   ; optional key
   :defer       (plist-get spec :defer)
   :description (plist-get spec :description)
   :version     (plist-get spec :version)
   :tags        (plist-get spec :tags)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Lifecycle operations
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/provider-load (provider)
  "Load the provider's feature file.  Returns t on success, nil on failure."
  (let ((sym (my/provider-require-sym provider)))
    (condition-case err
        (progn (require sym nil t) t)
      (error
       (my/log-error "provider" "load failed %s -> %S"
                     (my/provider-name provider) err)
       nil))))

(defun my/provider-init (provider)
  "Call the provider's init function.  Returns t on success, nil on failure."
  (let ((fn (my/provider-init-fn provider)))
    (condition-case err
        (progn (funcall fn) t)
      (error
       (my/log-error "provider" "init failed %s -> %S"
                     (my/provider-name provider) err)
       nil))))

(defun my/provider-teardown (provider)
  "Call the provider's teardown function if defined.
  Returns t on success, nil when no teardown or on failure."
  (let ((fn (my/provider-teardown-fn provider)))
    (if (null fn)
        nil
      (condition-case err
          (progn (funcall fn) t)
        (error
         (my/log-error "provider" "teardown failed %s -> %S"
                       (my/provider-name provider) err)
         nil)))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Introspection
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/provider-describe (provider)
  "Return human-readable one-liner for PROVIDER."
  (format "%s [%s]%s%s"
          (my/provider-name provider)
          (or (my/provider-description provider) "no description")
          (if (my/provider-version provider)
              (format " v%s" (my/provider-version provider))
            "")
          (if (my/provider-tags provider)
              (format " tags=%S" (my/provider-tags provider))
            "")))

(provide 'runtime-provider)
;;; runtime-provider.el ends here
