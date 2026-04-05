;;; runtime-manifest.el --- Manifest spec helpers  -*- lexical-binding: t; -*-
;;; Commentary:
;;; manifest spec gains first-class metadata fields.
;;;
;;; New optional fields:
;;;   :description STRING  — human-readable summary (for healthcheck UI)
;;;   :version     STRING  — semver or arbitrary version tag
;;;   :tags        LIST    — keyword list e.g. (:completion :ui)
;;;
;;; These fields are preserved on the normalised record and are available
;;; to the observer bus, healthcheck, and any introspection tooling.
;;;
;;; Required fields remain: :name :require :init
;;; Continued optional: :feature :predicate :after :defer
;;; Code:

(require 'kernel-lib)

;; ---------------------------------------------------------------------------
;; Normalisation
;; ---------------------------------------------------------------------------

(defun my/runtime-manifest-normalize-spec (spec)
  "Normalise manifest SPEC plist and validate required keys.
Returns a canonical plist with all known keys present (nil for absent)."
  (let ((name        (my/plist-get-required spec :name))
        (feature     (plist-get spec :feature))
        (predicate   (plist-get spec :predicate))
        (after       (my/listify (plist-get spec :after)))
        (require-sym (my/plist-get-required spec :require))
        (init        (my/plist-get-required spec :init))
        (defer       (plist-get spec :defer))
        (description (plist-get spec :description))
        (version     (plist-get spec :version))
        (tags        (my/listify (plist-get spec :tags))))
    (list :name        name
          :feature     feature
          :predicate   predicate
          :after       after
          :require     require-sym
          :init        init
          :defer       defer
          :description description
          :version     version
          :tags        tags)))

(defun my/runtime-manifest-normalize (manifest)
  "Normalise a list of manifest specs."
  (mapcar #'my/runtime-manifest-normalize-spec manifest))

;; ---------------------------------------------------------------------------
;; Metadata accessors (convenience)
;; ---------------------------------------------------------------------------

(defun my/manifest-spec-name        (spec) (plist-get spec :name))
(defun my/manifest-spec-description (spec) (plist-get spec :description))
(defun my/manifest-spec-version     (spec) (plist-get spec :version))
(defun my/manifest-spec-tags        (spec) (plist-get spec :tags))
(defun my/manifest-spec-defer       (spec) (plist-get spec :defer))

(provide 'runtime-manifest)
;;; runtime-manifest.el ends here
