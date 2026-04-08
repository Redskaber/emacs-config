;;; runtime-provider.el --- Provider lifecycle abstraction -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - my/provider-load, my/provider-init, my/provider-teardown all use
;;;       my/try-call internally — richer error info, no silent swallow.
;;;     - my/provider-describe includes tags, version, defer strategy.
;;;     - :teardown forwarded from normalised spec.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'kernel-errors)

;; ─────────────────────────────────────────────────────────────────────────────
;; Provider struct
;; ─────────────────────────────────────────────────────────────────────────────

(cl-defstruct (my/provider
               (:constructor my/provider--make)
               (:copier nil))
  "Lifecycle spec for one manifest module."
  (name        nil :read-only t)
  (feature     nil :read-only t)
  (when-gate   nil :read-only t)
  (after       nil :read-only t)
  (require-sym nil :read-only t)
  (init-fn     nil :read-only t)
  (teardown-fn nil :read-only t)
  (defer       nil :read-only t)
  (description nil :read-only t)
  (version     nil :read-only t)
  (tags        nil :read-only t))

;; ─────────────────────────────────────────────────────────────────────────────
;; Constructor
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/provider-from-spec (spec)
  "Build a my/provider from normalised manifest SPEC plist."
  (my/provider--make
   :name        (plist-get spec :name)
   :feature     (plist-get spec :feature)
   :when-gate   (plist-get spec :when)
   :after       (plist-get spec :after)
   :require-sym (plist-get spec :require)
   :init-fn     (plist-get spec :init)
   :teardown-fn (plist-get spec :teardown)
   :defer       (plist-get spec :defer)
   :description (plist-get spec :description)
   :version     (plist-get spec :version)
   :tags        (plist-get spec :tags)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Lifecycle operations  (my/try-call wrapping)
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/provider-load (provider)
  "Load the provider's feature file.  Returns t on success, nil on failure."
  (let* ((sym    (my/provider-require-sym provider))
         (name   (my/provider-name provider))
         (result (my/try-call name (lambda () (require sym nil t)))))
    (if (plist-get result :ok)
        (not (null (plist-get result :value)))
      (my/log-error "provider" "load failed %s -> %S" name
                    (plist-get result :error))
      nil)))

(defun my/provider-init (provider)
  "Call the provider's init function.  Returns t on success, nil on failure."
  (let* ((fn     (my/provider-init-fn provider))
         (name   (my/provider-name provider))
         (result (my/try-call name (lambda () (funcall fn) t))))
    (if (plist-get result :ok)
        (plist-get result :value)
      (my/log-error "provider" "init failed %s -> %S" name
                    (plist-get result :error))
      nil)))

(defun my/provider-teardown (provider)
  "Call the provider's teardown function.
  Returns t on success, nil when no teardown defined or on failure."
  (let ((fn (my/provider-teardown-fn provider)))
    (if (null fn)
        nil
      (let* ((name   (my/provider-name provider))
             (result (my/try-call name (lambda () (funcall fn) t))))
        (if (plist-get result :ok)
            (plist-get result :value)
          (my/log-error "provider" "teardown failed %s -> %S" name
                        (plist-get result :error))
          nil)))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Introspection
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/provider-describe (provider)
  "Return human-readable one-liner for PROVIDER."
  (format "%s [%s]%s%s%s"
          (my/provider-name provider)
          (or (my/provider-description provider) "no description")
          (if (my/provider-version provider)
              (format " v%s" (my/provider-version provider))
            "")
          (if (my/provider-tags provider)
              (format " tags=%S" (my/provider-tags provider))
            "")
          (if (my/provider-defer provider)
              (format " defer=%S" (my/provider-defer provider))
            "")))

(provide 'runtime-provider)
;;; runtime-provider.el ends here
