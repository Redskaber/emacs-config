;;; manifest-vcs.el --- VCS module manifest -*- lexical-binding: t; -*-

(defconst my/vcs-modules
  '((:name vcs-core
     :feature my/feature-vcs
     :require vcs-core
     :init my/vcs-core-init)

    (:name vcs-magit
     :feature my/feature-vcs-magit
     :predicate my/feature-vcs
     :after vcs-core
     :require vcs-magit
     :init my/vcs-magit-init)

    (:name vcs-diff
     :feature my/feature-vcs-diff
     :predicate my/feature-vcs
     :after vcs-core
     :require vcs-diff
     :init my/vcs-diff-init)

    (:name vcs-blame
     :feature my/feature-vcs-blame
     :predicate my/feature-vcs
     :after (vcs-core vcs-magit)
     :require vcs-blame
     :init my/vcs-blame-init))
  "Declarative VCS module specifications.")

(provide 'manifest-vcs)
