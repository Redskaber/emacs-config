;;; core-feature-flags.el --- Feature flags and capability gates -*- lexical-binding: t; -*-

(defgroup my/features                   nil "Feature flags for my Emacs configuration." :group 'convenience)

(defcustom my/feature-ui                t "Enable UI layer."                          :type 'boolean :group 'my/features)

(defcustom my/feature-ux                t "Enable UX layer."                          :type 'boolean :group 'my/features)
(defcustom my/feature-ux-helpful        t "Enable helpful integration."               :type 'boolean :group 'my/features)
(defcustom my/feature-ux-embark         t "Enable embark integration."                :type 'boolean :group 'my/features)

(defcustom my/feature-editor            t "Enable editor layer."                      :type 'boolean :group 'my/features)

(defcustom my/feature-project           t "Whether to enable project layer."                  :type 'boolean :group 'my/features)
(defcustom my/feature-project-search    t "Whether to enable project search."                 :type 'boolean :group 'my/features)
(defcustom my/feature-project-compile   t "Whether to enable project compile workflow."       :type 'boolean :group 'my/features)
(defcustom my/feature-project-test      t "Whether to enable project test workflow."          :type 'boolean :group 'my/features)
(defcustom my/feature-project-workspace t "Whether to enable project workspace integration."  :type 'boolean :group 'my/features)

(defcustom my/feature-vcs               t "Enable VCS layer."                         :type 'boolean :group 'my/features)
(defcustom my/feature-vcs-magit         t "Enable Magit integration."                 :type 'boolean :group 'my/features)
(defcustom my/feature-vcs-diff          t "Enable VCS diff UX."                       :type 'boolean :group 'my/features)
(defcustom my/feature-vcs-blame         t "Enable VCS blame UX."                      :type 'boolean :group 'my/features)

(defcustom my/feature-prog              t "Enable programming infrastructure layer."  :type 'boolean :group 'my/features)
(defcustom my/feature-prog-ai           t "Enable AI-related integrations."           :type 'boolean :group 'my/features)
(defcustom my/feature-prog-treesit      t "Enable treesit integration."               :type 'boolean :group 'my/features)
(defcustom my/feature-prog-lsp          t "Enable LSP integration."                   :type 'boolean :group 'my/features)
(defcustom my/feature-prog-diagnostics  t "Enable diagnostics integration."           :type 'boolean :group 'my/features)
(defcustom my/feature-prog-xref         t "Enable xref enhancements."                 :type 'boolean :group 'my/features)
(defcustom my/feature-prog-debug        t "Enable debug integration."                 :type 'boolean :group 'my/features)
(defcustom my/feature-prog-build        t "Enable build integration."                 :type 'boolean :group 'my/features)

(defcustom my/feature-lang              t "Enable language adapter layer."            :type 'boolean :group 'my/features)
(defcustom my/feature-lang-python       t "Enable Python adapter."                    :type 'boolean :group 'my/features)
(defcustom my/feature-lang-rust         t "Enable Rust adapter."                      :type 'boolean :group 'my/features)
(defcustom my/feature-lang-tsjs         t "Enable TS/JS adapter."                     :type 'boolean :group 'my/features)
(defcustom my/feature-lang-nix          t "Enable Nix adapter."                       :type 'boolean :group 'my/features)
(defcustom my/feature-lang-elisp        t "Enable Emacs Lisp adapter."                :type 'boolean :group 'my/features)
(defcustom my/feature-lang-go           t "Enable Go adapter."                        :type 'boolean :group 'my/features)
(defcustom my/feature-lang-web          t "Enable Web adapter."                       :type 'boolean :group 'my/features)
(defcustom my/feature-lang-markdown     t "Enable Markdown adapter."                  :type 'boolean :group 'my/features)
(defcustom my/feature-lang-org          t "Enable Org adapter."                       :type 'boolean :group 'my/features)
(defcustom my/feature-lang-data         t "Enable YAML/JSON/TOML adapter."            :type 'boolean :group 'my/features)

(defcustom my/feature-app               t "Enable application layer."                 :type 'boolean :group 'my/features)
(defcustom my/feature-app-terminal      t "Enable terminal app glue."                 :type 'boolean :group 'my/features)
(defcustom my/feature-app-dired         t "Enable dired app glue."                    :type 'boolean :group 'my/features)
(defcustom my/feature-app-eshell        t "Enable eshell app glue."                   :type 'boolean :group 'my/features)
(defcustom my/feature-app-vterm         t "Enable vterm app glue."                    :type 'boolean :group 'my/features)
(defcustom my/feature-app-notes         t "Enable notes app glue."                    :type 'boolean :group 'my/features)
(defcustom my/feature-app-rss           t "Enable RSS app glue."                      :type 'boolean :group 'my/features)
(defcustom my/feature-app-llm           t "Enable LLM app glue."                      :type 'boolean :group 'my/features)

(defcustom my/feature-ops               t "Enable operations/diagnostics layer."      :type 'boolean :group 'my/features)
(defcustom my/feature-ops-startup       t "Enable startup ops."                       :type 'boolean :group 'my/features)
(defcustom my/feature-ops-profiler      t "Enable profiler ops."                      :type 'boolean :group 'my/features)
(defcustom my/feature-ops-healthcheck   t "Enable healthcheck ops."                   :type 'boolean :group 'my/features)
(defcustom my/feature-ops-benchmark     t "Enable benchmark ops."                     :type 'boolean :group 'my/features)
(defcustom my/feature-ops-sandbox       t "Enable sandbox ops."                       :type 'boolean :group 'my/features)

(defun my/core-feature-flags-init ()
  "Initialize feature flags subsystem."
  t)

(provide 'core-feature-flags)
;;; core-feature-flags.el ends here
