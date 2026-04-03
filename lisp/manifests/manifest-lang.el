;;; manifest-lang.el --- Language adapter manifest -*- lexical-binding: t; -*-

(defconst my/lang-modules
  '((:name lang-elisp
     :feature my/feature-lang-elisp
     :predicate my/feature-lang
     :after (prog-core prog-xref)
     :require lang-elisp
     :init my/lang-elisp-init)

    (:name lang-python
     :feature my/feature-lang-python
     :predicate my/feature-lang
     :after (prog-core project-core)
     :require lang-python
     :init my/lang-python-init)

    (:name lang-go
     :feature my/feature-lang-go
     :predicate my/feature-lang
     :after (prog-core project-core)
     :require lang-go
     :init my/lang-go-init)

    (:name lang-rust
     :feature my/feature-lang-rust
     :predicate my/feature-lang
     :after (prog-core project-core)
     :require lang-rust
     :init my/lang-rust-init)

    (:name lang-tsjs
     :feature my/feature-lang-tsjs
     :predicate my/feature-lang
     :after (prog-core project-core)
     :require lang-tsjs
     :init my/lang-tsjs-init)

    (:name lang-nix
     :feature my/feature-lang-nix
     :predicate my/feature-lang
     :after (prog-core project-core)
     :require lang-nix
     :init my/lang-nix-init)

    (:name lang-web
     :feature my/feature-lang-web
     :predicate my/feature-lang
     :after (prog-core project-core)
     :require lang-web
     :init my/lang-web-init)

    (:name lang-markdown
     :feature my/feature-lang-markdown
     :predicate my/feature-lang
     :after project-core
     :require lang-markdown
     :init my/lang-markdown-init)

    (:name lang-org
     :feature my/feature-lang-org
     :predicate my/feature-lang
     :after project-core
     :require lang-org
     :init my/lang-org-init)

    (:name lang-yaml-json-toml
     :feature my/feature-lang-data
     :predicate my/feature-lang
     :after (prog-core project-core)
     :require lang-yaml-json-toml
     :init my/lang-yaml-json-toml-init))
  "Declarative language module specifications.")

(provide 'manifest-lang)
;;; manifest-lang.el ends here
