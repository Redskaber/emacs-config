;;; manifest-ui.el --- UI module manifest  -*- lexical-binding: t; -*-
;;; Code:

(defconst my/ui-modules
  '((:name ui-frame
     :description "GUI frame appearance and behavior."
     :tags (:ui :frame)
     :feature my/feature-ui
     :when my/gui-p
     :require ui-frame
     :init my/ui-frame-init)

    (:name ui-font
     :description "Font configuration for GUI."
     :tags (:ui :font)
     :feature my/feature-ui
     :when my/gui-p
     :require ui-font
     :init my/ui-font-init)

    (:name ui-theme
     :description "Color theme management."
     :tags (:ui :theme)
     :feature my/feature-ui
     :when my/gui-p
     :require ui-theme
     :init my/ui-theme-init)

    (:name ui-chrome
     :description "Window chrome (fringes, scrollbars, etc.)."
     :tags (:ui :chrome)
     :feature my/feature-ui
     :when my/gui-p
     :require ui-chrome
     :init my/ui-chrome-init)

    (:name ui-icons
     :description "Icon support (all-the-icons, etc.)."
     :tags (:ui :icons)
     :feature my/feature-ui
     :when my/gui-p
     :require ui-icons
     :init my/ui-icons-init)

    (:name ui-modeline
     :description "Mode line customization."
     :tags (:ui :modeline)
     :feature my/feature-ui
     :when my/gui-p
     :require ui-modeline
     :init my/ui-modeline-init)

    (:name ui-popup
     :description "Popup window styling (child frames, posframe)."
     :tags (:ui :popup)
     :feature my/feature-ui
     :when my/gui-p
     :require ui-popup
     :init my/ui-popup-init))
  "Declarative UI module specifications.")

(provide 'manifest-ui)
;;; manifest-ui.el ends here
