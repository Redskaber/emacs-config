;;; manifest-registry.el --- Stage manifest registry -*- lexical-binding: t; -*-
;;; Commentary:
;;; Central registry for manifest-driven startup stages.
;;; Code:
;;; TODO: Stage Topological Sort

(require 'seq)

(require 'manifest-ui)
(require 'manifest-ux)
(require 'manifest-editor)
(require 'manifest-project)
(require 'manifest-vcs)
(require 'manifest-prog)
(require 'manifest-lang)
(require 'manifest-app)
(require 'manifest-ops)

(defconst my/stage-registry
  '((:name ui
     :manifest my/ui-modules
     :feature my/feature-ui)

    (:name ux
     :manifest my/ux-modules
     :feature my/feature-ux)

    (:name editor
     :manifest my/editor-modules
     :feature my/feature-editor)

    (:name project
     :manifest my/project-modules
     :feature my/feature-project)

    (:name vcs
     :manifest my/vcs-modules
     :feature my/feature-vcs
     :after (project))

    (:name prog
     :manifest my/prog-modules
     :feature my/feature-prog
     :after (project))

    (:name lang
     :manifest my/lang-modules
     :feature my/feature-lang
     :after (prog))

    (:name app
     :manifest my/app-modules
     :feature my/feature-app
     :after (ux project vcs prog lang))

    (:name ops
     :manifest my/ops-modules
     :feature my/feature-ops
     :after (ui ux editor project vcs prog lang app)))
  "Declarative startup stage registry.")

(defun my/stage-spec-get (stage)
  "Return stage spec plist for STAGE."
  (or (seq-find (lambda (spec)
                  (eq (plist-get spec :name) stage))
                my/stage-registry)
      (error "Unknown stage: %S" stage)))

(defun my/stage-manifest (stage)
  "Return manifest list for STAGE."
  (let* ((spec (my/stage-spec-get stage))
         (sym  (plist-get spec :manifest)))
    (unless (and sym (boundp sym))
      (error "Manifest variable is not bound for stage %S: %S" stage sym))
    (symbol-value sym)))

(defun my/stage-feature-enabled-p (stage)
  "Return non-nil when STAGE feature gate passes."
  (let* ((spec (my/stage-spec-get stage))
         (flag (plist-get spec :feature)))
    (cond
     ((null flag) t)
     ((and (symbolp flag) (boundp flag)) (symbol-value flag))
     (t flag))))

(defun my/stage-after (stage)
  "Return stage dependency list for STAGE."
  (let ((deps (plist-get (my/stage-spec-get stage) :after)))
    (cond
     ((null deps) nil)
     ((listp deps) deps)
     (t (list deps)))))

(defun my/stage-names ()
  "Return ordered stage names."
  (mapcar (lambda (spec) (plist-get spec :name)) my/stage-registry))

(provide 'manifest-registry)
;;; manifest-registry.el ends here
