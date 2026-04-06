;;; manifest-project.el --- Project module manifest  -*- lexical-binding: t; -*-
;;; Code:

(defconst my/project-modules
  '((:name project-core
     :description "Core project detection and management."
     :tags (:project :core)
     :feature my/feature-project
     :require project-core
     :init my/project-core-init)

    (:name project-search
     :description "Project-wide search (ripgrep, grep)."
     :tags (:project :search)
     :feature my/feature-project-search
     :when my/feature-project
     :after project-core
     :require project-search
     :init my/project-search-init)

    (:name project-compile
     :description "Project build and compilation commands."
     :tags (:project :build)
     :feature my/feature-project-compile
     :when my/feature-project
     :after project-core
     :require project-compile
     :init my/project-compile-init)

    (:name project-test
     :description "Project test runner integration."
     :tags (:project :test)
     :feature my/feature-project-test
     :when my/feature-project
     :after project-core
     :require project-test
     :init my/project-test-init)

    (:name project-workspace
     :description "Multi-root workspace support."
     :tags (:project :workspace)
     :feature my/feature-project-workspace
     :when my/feature-project
     :after project-core
     :require project-workspace
     :init my/project-workspace-init))
  "Declarative project module specifications.")

(provide 'manifest-project)
;;; manifest-project.el ends here
