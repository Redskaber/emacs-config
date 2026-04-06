;;; runtime-manifest.el --- Manifest spec normalisation -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. :predicate renamed to :when (environment / runtime condition).
;;;      Backward-compat: :predicate still accepted during normalization and
;;;      mapped to :when.  Emits a deprecation warning.
;;;   2. :description :version :tags preserved from V1.
;;;   3. Normalizer validates required keys and logs unknown keys at trace level.
;;;
;;; Required fields: :name :require :init
;;; Optional fields: :feature :when (:predicate deprecated) :after :defer
;;;                  :description :version :tags
;;;
;;; Code:

(require 'kernel-lib)
(require 'kernel-logging)

;; ---------------------------------------------------------------------------
;; Normalisation
;; ---------------------------------------------------------------------------

(defconst my/manifest--known-keys
  '(:name :feature :when :predicate :after :require :init :defer
    :description :version :tags)
  "All recognised manifest spec keys.")

(defun my/runtime-manifest-normalize-spec (spec)
  "Normalise manifest SPEC plist and validate required keys.
  Returns canonical plist with all known keys present (nil for absent).

  :predicate is accepted as a backward-compat alias for :when."
  (let* ((name        (my/plist-get-required spec :name))
         (feature     (plist-get spec :feature))
         ;; :when wins; :predicate is compat alias
         (when-gate   (or (plist-get spec :when)
                          (when-let ((p (plist-get spec :predicate)))
                            (my/log-warn "manifest"
                              "%s uses :predicate (deprecated); use :when" name)
                            p)))
         (after       (my/listify (plist-get spec :after)))
         (require-sym (my/plist-get-required spec :require))
         (init        (my/plist-get-required spec :init))
         (defer       (plist-get spec :defer))
         (description (plist-get spec :description))
         (version     (plist-get spec :version))
         (tags        (my/listify (plist-get spec :tags))))

    ;; Warn on unknown keys (helps catch typos in manifests)
    (cl-loop for (k _v) on spec by #'cddr
             unless (memq k my/manifest--known-keys)
             do (my/log-warn "manifest" "%s unknown key %S" name k))

    (list :name        name
          :feature     feature
          :when        when-gate
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
;; Metadata accessors
;; ---------------------------------------------------------------------------

(defun my/manifest-spec-name        (spec) (plist-get spec :name))
(defun my/manifest-spec-description (spec) (plist-get spec :description))
(defun my/manifest-spec-version     (spec) (plist-get spec :version))
(defun my/manifest-spec-tags        (spec) (plist-get spec :tags))
(defun my/manifest-spec-defer       (spec) (plist-get spec :defer))
(defun my/manifest-spec-when        (spec) (plist-get spec :when))

(provide 'runtime-manifest)
;;; runtime-manifest.el ends here
