;;; manifest-registry.el --- Declarative stage manifest registry -*- lexical-binding: t; -*-
;;; Commentary:
;;; Pure data registry for stage manifest.
;;; Code:

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

(provide 'manifest-registry)
;;; manifest-registry.el ends here
