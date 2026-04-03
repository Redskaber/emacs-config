;;; manifest-project.el --- Project module manifest -*- lexical-binding: t; -*-
;;; Commentary:
;;; Declarative module manifest for project layer.
;;; Code:

(defconst my/project-modules
  '((:name project-core
     :feature my/feature-project
     :require project-core
     :init my/project-core-init)

    (:name project-search
     :feature my/feature-project-search
     :predicate my/feature-project
     :after project-core
     :require project-search
     :init my/project-search-init)

    (:name project-compile
     :feature my/feature-project-compile
     :predicate my/feature-project
     :after project-core
     :require project-compile
     :init my/project-compile-init)

    (:name project-test
     :feature my/feature-project-test
     :predicate my/feature-project
     :after project-core
     :require project-test
     :init my/project-test-init)

    (:name project-workspace
     :feature my/feature-project-workspace
     :predicate my/feature-project
     :after project-core
     :require project-workspace
     :init my/project-workspace-init))
  "Declarative project module specifications.")

(provide 'manifest-project)
;;; manifest-project.el ends here
