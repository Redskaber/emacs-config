;;; runtime-manifest.el --- Manifest spec normalisation -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - Unknown-key warnings emit :event :manifest/unknown-key for traceability.
;;;     - :predicate deprecation warning includes corr-id (module name).
;;;     - No structural changes; normalization contract is stable.
;;;
;;; Code:

(require 'kernel-lib)
(require 'kernel-logging)

;; ─────────────────────────────────────────────────────────────────────────────
;; Known keys
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/manifest--known-keys
  '(:name :feature :when :predicate :after :require :init :defer
    :description :version :tags :teardown))

(defconst my/manifest--required-keys
  '(:name :require :init))

;; ─────────────────────────────────────────────────────────────────────────────
;; Validation
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-manifest-validate-spec (spec)
  "Signal on missing required keys."
  (dolist (key my/manifest--required-keys)
    (unless (plist-get spec key)
      (error "Manifest spec missing required key %S in spec: %S" key spec)))
  nil)

(defun my/runtime-manifest-validate (manifest)
  "Validate a list of manifest specs."
  (dolist (spec manifest)
    (my/runtime-manifest-validate-spec spec)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Normalisation
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-manifest-normalize-spec (spec)
  "Validate and normalise SPEC plist.  Returns canonical plist."
  (my/runtime-manifest-validate-spec spec)
  (let* ((name        (plist-get spec :name))
         (feature     (plist-get spec :feature))
         (when-gate   (or (plist-get spec :when)
                          (when-let ((p (plist-get spec :predicate)))
                            (my/log-event
                             'warn "manifest"
                             (format "%s uses :predicate (deprecated); use :when" name)
                             :event   :manifest/deprecated-key
                             :corr-id name)
                            p)))
         (after       (my/listify (plist-get spec :after)))
         (require-sym (plist-get spec :require))
         (init        (plist-get spec :init))
         (teardown    (plist-get spec :teardown))
         (defer       (plist-get spec :defer))
         (description (plist-get spec :description))
         (version     (plist-get spec :version))
         (tags        (my/listify (plist-get spec :tags))))
    ;; Warn on unknown keys with structured event
    (cl-loop for (k _v) on spec by #'cddr
             unless (memq k my/manifest--known-keys)
             do (my/log-event
                 'warn "manifest"
                 (format "%s unknown key %S" name k)
                 :event   :manifest/unknown-key
                 :corr-id name))
    (list :name        name
          :feature     feature
          :when        when-gate
          :after       after
          :require     require-sym
          :init        init
          :teardown    teardown
          :defer       defer
          :description description
          :version     version
          :tags        tags)))

(defun my/runtime-manifest-normalize (manifest)
  "Normalise a list of manifest specs."
  (mapcar #'my/runtime-manifest-normalize-spec manifest))

;; ─────────────────────────────────────────────────────────────────────────────
;; Metadata accessors
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/manifest-spec-name        (spec) (plist-get spec :name))
(defun my/manifest-spec-description (spec) (plist-get spec :description))
(defun my/manifest-spec-version     (spec) (plist-get spec :version))
(defun my/manifest-spec-tags        (spec) (plist-get spec :tags))
(defun my/manifest-spec-defer       (spec) (plist-get spec :defer))
(defun my/manifest-spec-when        (spec) (plist-get spec :when))

(provide 'runtime-manifest)
;;; runtime-manifest.el ends here
