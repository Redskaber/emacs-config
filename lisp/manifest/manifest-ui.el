;;; manifest-ui.el --- UI module manifest -*- lexical-binding: t; -*-
;;; Commentary:
;;; Declarative module manifest for UI layer.
;;; Code:

(defconst my/ui-modules
  '((:name ui-frame
     :feature my/feature-ui
     :predicate my/gui-p
     :require ui-frame
     :init my/ui-frame-init)

    (:name ui-font
     :feature my/feature-ui
     :predicate my/gui-p
     :require ui-font
     :init my/ui-font-init)

    (:name ui-theme
     :feature my/feature-ui
     :predicate my/gui-p
     :require ui-theme
     :init my/ui-theme-init)

    (:name ui-chrome
     :feature my/feature-ui
     :predicate my/gui-p
     :require ui-chrome
     :init my/ui-chrome-init)

    (:name ui-icons
     :feature my/feature-ui
     :predicate my/gui-p
     :require ui-icons
     :init my/ui-icons-init)

    (:name ui-modeline
     :feature my/feature-ui
     :predicate my/gui-p
     :require ui-modeline
     :init my/ui-modeline-init)

    (:name ui-popup
     :feature my/feature-ui
     :predicate my/gui-p
     :require ui-popup
     :init my/ui-popup-init))
  "Declarative UI module specifications.")

(provide 'manifest-ui)
;;; manifest-ui.el ends here
