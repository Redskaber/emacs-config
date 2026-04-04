;;; manifest-ux.el --- UX module manifest -*- lexical-binding: t; -*-
;;; Commentary:
;;; Declarative module manifest for UX layer.
;;; Code:

(defconst my/ux-modules
  '((:name ux-completion-read
     :feature my/feature-ux
     :require ux-completion-read
     :init my/ux-completion-read-init)

    (:name ux-completion-at-point
     :feature my/feature-ux
     :after ux-completion-read
     :require ux-completion-at-point
     :init my/ux-completion-at-point-init)

    (:name ux-actions
     :feature my/feature-ux
     :after ux-completion-read
     :require ux-actions
     :init my/ux-actions-init)

    (:name ux-search
     :feature my/feature-ux
     :after ux-completion-read
     :require ux-search
     :init my/ux-search-init)

    (:name ux-help
     :feature my/feature-ux
     :after (ux-completion-read ux-actions)
     :require ux-help
     :init my/ux-help-init)

    (:name ux-history
     :feature my/feature-ux
     :after ux-completion-read
     :require ux-history
     :init my/ux-history-init))
  "Declarative UX module specifications.")

(provide 'manifest-ux)
;;; manifest-ux.el ends here
