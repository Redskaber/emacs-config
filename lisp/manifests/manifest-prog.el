;;; manifest-prog.el --- Programming module manifest -*- lexical-binding: t; -*-

(defconst my/prog-modules
  '((:name prog-core
     :feature my/feature-prog
     :require prog-core
     :init my/prog-core-init)

    (:name prog-treesit
     :feature my/feature-prog-treesit
     :predicate my/feature-prog
     :after prog-core
     :require prog-treesit
     :init my/prog-treesit-init)

    (:name prog-lsp
     :feature my/feature-prog-lsp
     :predicate my/feature-prog
     :after prog-core
     :require prog-lsp
     :init my/prog-lsp-init)

    (:name prog-diagnostics
     :feature my/feature-prog-diagnostics
     :predicate my/feature-prog
     :after prog-core
     :require prog-diagnostics
     :init my/prog-diagnostics-init)

    (:name prog-xref
     :feature my/feature-prog-xref
     :predicate my/feature-prog
     :after prog-core
     :require prog-xref
     :init my/prog-xref-init)

    (:name prog-debug
     :feature my/feature-prog-debug
     :predicate my/feature-prog
     :after prog-core
     :require prog-debug
     :init my/prog-debug-init)

    (:name prog-build
     :feature my/feature-prog-build
     :predicate my/feature-prog
     :after prog-core
     :require prog-build
     :init my/prog-build-init)

    (:name prog-ai
     :feature my/feature-prog-ai
     :predicate my/feature-prog
     :after (prog-core prog-xref)
     :require prog-ai
     :init my/prog-ai-init
     :defer (:idle 2.0)))
  "Declarative programming module specifications.")

(provide 'manifest-prog)
;;; manifest-prog.el ends here
