;;; runtime-registry.el --- Runtime access to stage registry -*- lexical-binding: t; -*-
;;; Code:

(require 'seq)
(require 'kernel-lib)
(require 'runtime-feature)
(require 'manifest-registry)

(defun my/runtime-stage-spec (stage)
  "Return stage spec plist for STAGE."
  (or (seq-find (lambda (spec)
                  (eq (plist-get spec :name) stage))
                my/stage-registry)
      (error "Unknown stage: %S" stage)))

(defun my/runtime-stage-names ()
  "Return all declared stage names."
  (mapcar (lambda (spec) (plist-get spec :name))
          my/stage-registry))

(defun my/runtime-stage-manifest (stage)
  "Return manifest list for STAGE."
  (let* ((spec (my/runtime-stage-spec stage))
         (sym  (plist-get spec :manifest)))
    (unless (and sym (boundp sym))
      (error "Manifest variable not bound for stage %S: %S" stage sym))
    (symbol-value sym)))

(defun my/runtime-stage-after (stage)
  "Return dependency list for STAGE."
  (my/listify (plist-get (my/runtime-stage-spec stage) :after)))

(defun my/runtime-stage-feature-gate (stage)
  "Return feature gate for STAGE."
  (plist-get (my/runtime-stage-spec stage) :feature))

(defun my/runtime-stage-enabled-p (stage)
  "Return non-nil when STAGE feature gate passes."
  (my/runtime-feature-enabled-p (my/runtime-stage-feature-gate stage)))

(provide 'runtime-registry)
;;; runtime-registry.el ends here
