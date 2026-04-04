;;; runtime-manifest.el --- Manifest spec helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;; Manifest spec normalization and accessors.
;;; Code:

(require 'kernel-lib)

(defun my/runtime-manifest-normalize-spec (spec)
  "Normalize manifest SPEC and validate required keys."
  (let ((name (my/plist-get-required spec :name))
        (feature (plist-get spec :feature))
        (predicate (plist-get spec :predicate))
        (after (my/listify (plist-get spec :after)))
        (require-sym (my/plist-get-required spec :require))
        (init (my/plist-get-required spec :init))
        (defer (plist-get spec :defer)))
    (list :name name
          :feature feature
          :predicate predicate
          :after after
          :require require-sym
          :init init
          :defer defer)))

(defun my/runtime-manifest-normalize (manifest)
  "Normalize MANIFEST list."
  (mapcar #'my/runtime-manifest-normalize-spec manifest))

(provide 'runtime-manifest)
;;; runtime-manifest.el ends here
