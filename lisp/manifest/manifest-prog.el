;;; manifest-prog.el --- Programming module manifest  -*- lexical-binding: t; -*-
;;; Code:

(defconst my/prog-modules
  '((:name prog-core
     :description "Programming fundamentals: prog-mode hooks, fill-column, compile."
     :tags (:prog :core)
     :feature my/feature-prog
     :require prog-core
     :init my/prog-core-init)

    (:name prog-treesit
     :description "Tree-sitter integration: grammar auto-install, mode remapping."
     :tags (:prog :treesit)
     :feature my/feature-prog-treesit
     :predicate my/feature-prog
     :after prog-core
     :require prog-treesit
     :init my/prog-treesit-init)

    (:name prog-lsp
     :description "LSP client via eglot or lsp-mode, project-aware server launch."
     :tags (:prog :lsp)
     :feature my/feature-prog-lsp
     :predicate my/feature-prog
     :after prog-core
     :require prog-lsp
     :init my/prog-lsp-init)

    (:name prog-diagnostics
     :description "Inline diagnostics via flymake / flycheck."
     :tags (:prog :diagnostics)
     :feature my/feature-prog-diagnostics
     :predicate my/feature-prog
     :after prog-core
     :require prog-diagnostics
     :init my/prog-diagnostics-init)

    (:name prog-xref
     :description "Cross-reference navigation enhancements."
     :tags (:prog :navigation)
     :feature my/feature-prog-xref
     :predicate my/feature-prog
     :after prog-core
     :require prog-xref
     :init my/prog-xref-init)

    (:name prog-debug
     :description "Debug adapter (dap-mode / realgud) integration."
     :tags (:prog :debug)
     :feature my/feature-prog-debug
     :predicate my/feature-prog
     :after prog-core
     :require prog-debug
     :init my/prog-debug-init)

    (:name prog-build
     :description "Build system glue: compilation commands, error parsers."
     :tags (:prog :build)
     :feature my/feature-prog-build
     :predicate my/feature-prog
     :after prog-core
     :require prog-build
     :init my/prog-build-init)

    (:name prog-ai
     :description "AI coding assistants (copilot, gptel, codeium…)."
     :tags (:prog :ai)
     :feature my/feature-prog-ai
     :predicate my/feature-prog
     :after (prog-core prog-xref)
     :require prog-ai
     :init my/prog-ai-init
     :defer (:idle 2.0)))
  "Declarative programming module specifications.")

(provide 'manifest-prog)
;;; manifest-prog.el ends here
