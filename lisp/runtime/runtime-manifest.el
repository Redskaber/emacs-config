;;; runtime-manifest.el --- Manifest spec normalisation -*- lexical-binding: t; -*-
;;; Commentary:
;;;  1. Validation contract: my/runtime-manifest-validate-spec signals an
;;;     error (not just a warning) for missing required keys.
;;;  2. :predicate backward-compat alias preserved; warns, then maps to :when.
;;;  3. Unknown key detection is unchanged (warn at trace level).
;;;  4. New: my/runtime-manifest-validate can be called on an entire manifest
;;;     list before execution to fail fast on bad specs.
;;;
;;; Code:

(require 'kernel-lib)
(require 'kernel-logging)

;; ─────────────────────────────────────────────────────────────────────────────
;; Known keys
;; ─────────────────────────────────────────────────────────────────────────────

(defconst my/manifest--known-keys
  '(:name :feature :when :predicate :after :require :init :defer :description :version :tags)
  "All recognised manifest spec keys.")

(defconst my/manifest--required-keys
  '(:name :require :init)
  "Keys that must be present in every manifest spec.")

;; ─────────────────────────────────────────────────────────────────────────────
;; Validation
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-manifest-validate-spec (spec)
  "Signal an error when SPEC is missing required keys.
  Returns nil on success (use normalizer to get the canonical form)."
  (dolist (key my/manifest--required-keys)
    (unless (plist-get spec key)
      (error "Manifest spec missing required key %S in spec: %S" key spec)))
  nil)

(defun my/runtime-manifest-validate (manifest)
  "Validate a list of manifest specs.  Signals on first invalid spec."
  (dolist (spec manifest)
    (my/runtime-manifest-validate-spec spec)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Normalisation
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-manifest-normalize-spec (spec)
  "Validate and normalise SPEC plist.  Returns canonical plist."
  ;; Validate first — fail fast
  (my/runtime-manifest-validate-spec spec)

  (let* ((name        (plist-get spec :name))
         (feature     (plist-get spec :feature))
         (when-gate   (or (plist-get spec :when)
                          (when-let ((p (plist-get spec :predicate)))
                            (my/log-warn "manifest"
                              "%s uses :predicate (deprecated); use :when" name)
                            p)))
         (after       (my/listify (plist-get spec :after)))
         (require-sym (plist-get spec :require))
         (init        (plist-get spec :init))
         (defer       (plist-get spec :defer))
         (description (plist-get spec :description))
         (version     (plist-get spec :version))
         (tags        (my/listify (plist-get spec :tags))))

    ;; Warn on unknown keys
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
