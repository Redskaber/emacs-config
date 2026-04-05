;;; manifest-vcs.el --- VCS module manifest  -*- lexical-binding: t; -*-
;;; Code:

(defconst my/vcs-modules
  '((:name vcs-core
     :description "Core version control system integration."
     :tags (:vcs :core)
     :feature my/feature-vcs
     :require vcs-core
     :init my/vcs-core-init)

    (:name vcs-magit
     :description "Magit porcelain for Git."
     :tags (:vcs :git :magit)
     :feature my/feature-vcs-magit
     :predicate my/feature-vcs
     :after vcs-core
     :require vcs-magit
     :init my/vcs-magit-init)

    (:name vcs-diff
     :description "Enhanced diff viewing and navigation."
     :tags (:vcs :diff)
     :feature my/feature-vcs-diff
     :predicate my/feature-vcs
     :after vcs-core
     :require vcs-diff
     :init my/vcs-diff-init)

    (:name vcs-blame
     :description "VCS blame/annotate annotations."
     :tags (:vcs :blame)
     :feature my/feature-vcs-blame
     :predicate my/feature-vcs
     :after (vcs-core vcs-magit)
     :require vcs-blame
     :init my/vcs-blame-init))
  "Declarative VCS module specifications.")

(provide 'manifest-vcs)
;;; manifest-vcs.el ends here
