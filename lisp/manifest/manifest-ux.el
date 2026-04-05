;;; manifest-ux.el --- UX module manifest  -*- lexical-binding: t; -*-
;;; Code:

(defconst my/ux-modules
  '((:name ux-completion-read
     :description "Completion framework for minibuffer reads (vertico, etc.)."
     :tags (:ux :completion)
     :feature my/feature-ux
     :require ux-completion-read
     :init my/ux-completion-read-init)

    (:name ux-completion-at-point
     :description "In-buffer completion at point (corfu, cape)."
     :tags (:ux :completion)
     :feature my/feature-ux
     :after ux-completion-read
     :require ux-completion-at-point
     :init my/ux-completion-at-point-init)

    (:name ux-actions
     :description "Action dispatch system (embark, which-key)."
     :tags (:ux :actions)
     :feature my/feature-ux
     :after ux-completion-read
     :require ux-actions
     :init my/ux-actions-init)

    (:name ux-search
     :description "Incremental search and navigation."
     :tags (:ux :search)
     :feature my/feature-ux
     :after ux-completion-read
     :require ux-search
     :init my/ux-search-init)

    (:name ux-help
     :description "Enhanced help system (helpful)."
     :tags (:ux :help)
     :feature my/feature-ux
     :after (ux-completion-read ux-actions)
     :require ux-help
     :init my/ux-help-init)

    (:name ux-history
     :description "Command and minibuffer history management."
     :tags (:ux :history)
     :feature my/feature-ux
     :after ux-completion-read
     :require ux-history
     :init my/ux-history-init))
  "Declarative UX module specifications.")

(provide 'manifest-ux)
;;; manifest-ux.el ends here
