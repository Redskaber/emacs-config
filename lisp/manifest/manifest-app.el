;;; manifest-app.el --- Application layer manifest  -*- lexical-binding: t; -*-
;;; Code:

(defconst my/app-modules
  '((:name app-terminal
     :description "Terminal integration (ansi-term)."
     :tags (:app :terminal)
     :feature my/feature-app-terminal
     :predicate my/feature-app
     :after (ux-actions project-core)
     :require app-terminal
     :init my/app-terminal-init)

    (:name app-dired
     :description "Enhanced dired experience."
     :tags (:app :dired)
     :feature my/feature-app-dired
     :predicate my/feature-app
     :after ux-actions
     :require app-dired
     :init my/app-dired-init)

    (:name app-eshell
     :description "Eshell configuration and enhancements."
     :tags (:app :shell)
     :feature my/feature-app-eshell
     :predicate my/feature-app
     :after (ux-history project-core)
     :require app-eshell
     :init my/app-eshell-init)

    (:name app-vterm
     :description "Vterm (libvterm) terminal emulator."
     :tags (:app :terminal)
     :feature my/feature-app-vterm
     :predicate my/feature-app
     :after app-terminal
     :require app-vterm
     :init my/app-vterm-init)

    (:name app-notes
     :description "Notes management with Org mode."
     :tags (:app :notes :org)
     :feature my/feature-app-notes
     :predicate my/feature-app
     :after (project-core lang-org)
     :require app-notes
     :init my/app-notes-init)

    (:name app-rss
     :description "RSS feed reader."
     :tags (:app :rss)
     :feature my/feature-app-rss
     :predicate my/feature-app
     :after ux-actions
     :require app-rss
     :init my/app-rss-init
     :defer (:idle 3.0))

    (:name app-llm
     :description "LLM (Large Language Model) assistant integration."
     :tags (:app :ai)
     :feature my/feature-app-llm
     :predicate my/feature-app
     :after (ux-actions prog-core)
     :require app-llm
     :init my/app-llm-init
     :defer (:idle 2.5)))
  "Declarative application layer module specifications.")

(provide 'manifest-app)
;;; manifest-app.el ends here
