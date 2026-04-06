;;; manifest-lang.el --- Language adapter manifest  -*- lexical-binding: t; -*-
;;; Code:

(defconst my/lang-modules
  '((:name lang-elisp
     :description "Emacs Lisp development environment."
     :tags (:lang :elisp)
     :feature my/feature-lang-elisp
     :after (prog-core prog-xref)
     :require lang-elisp
     :init my/lang-elisp-init)

    (:name lang-python
     :description "Python language support."
     :tags (:lang :python)
     :feature my/feature-lang-python
     :after (prog-core project-core)
     :require lang-python
     :init my/lang-python-init)

    (:name lang-go
     :description "Go language support."
     :tags (:lang :go)
     :feature my/feature-lang-go
     :after (prog-core project-core)
     :require lang-go
     :init my/lang-go-init)

    (:name lang-rust
     :description "Rust language support."
     :tags (:lang :rust)
     :feature my/feature-lang-rust
     :after (prog-core project-core)
     :require lang-rust
     :init my/lang-rust-init)

    (:name lang-tsjs
     :description "TypeScript/JavaScript language support."
     :tags (:lang :ts :js)
     :feature my/feature-lang-tsjs
     :after (prog-core project-core)
     :require lang-tsjs
     :init my/lang-tsjs-init)

    (:name lang-nix
     :description "Nix language support."
     :tags (:lang :nix)
     :feature my/feature-lang-nix
     :after (prog-core project-core)
     :require lang-nix
     :init my/lang-nix-init)

    (:name lang-web
     :description "Web development (HTML/CSS) support."
     :tags (:lang :web)
     :feature my/feature-lang-web
     :after (prog-core project-core)
     :require lang-web
     :init my/lang-web-init)

    (:name lang-markdown
     :description "Markdown editing support."
     :tags (:lang :markdown)
     :feature my/feature-lang-markdown
     :after project-core
     :require lang-markdown
     :init my/lang-markdown-init)

    (:name lang-org
     :description "Org mode configuration and enhancements."
     :tags (:lang :org)
     :feature my/feature-lang-org
     :after project-core
     :require lang-org
     :init my/lang-org-init)

    (:name lang-yaml-json-toml
     :description "YAML, JSON, and TOML data format support."
     :tags (:lang :data)
     :feature my/feature-lang-data
     :after (prog-core project-core)
     :require lang-yaml-json-toml
     :init my/lang-yaml-json-toml-init))
  "Declarative language module specifications.")

(provide 'manifest-lang)
;;; manifest-lang.el ends here
