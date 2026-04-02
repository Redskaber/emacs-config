;;; core-feature-flags.el --- Feature flags and capability gates -*- lexical-binding: t; -*-

(defgroup my/features nil
  "Feature flags for my Emacs configuration."
  :group 'convenience)

(defcustom my/feature-ui t
  "Enable UI layer."
  :type 'boolean
  :group 'my/features)

(defcustom my/feature-ux t
  "Enable UX layer."
  :type 'boolean
  :group 'my/features)

(defcustom my/feature-editor t
  "Enable editor layer."
  :type 'boolean
  :group 'my/features)

(defcustom my/feature-project t
  "Enable project layer."
  :type 'boolean
  :group 'my/features)

(defcustom my/feature-vcs t
  "Enable VCS layer."
  :type 'boolean
  :group 'my/features)

(defcustom my/feature-prog t
  "Enable programming infrastructure layer."
  :type 'boolean
  :group 'my/features)

(defcustom my/feature-lang t
  "Enable language adapter layer."
  :type 'boolean
  :group 'my/features)

(defcustom my/feature-app t
  "Enable application layer."
  :type 'boolean
  :group 'my/features)

(defcustom my/feature-ops t
  "Enable operations/diagnostics layer."
  :type 'boolean
  :group 'my/features)

(defcustom my/feature-ai nil
  "Enable AI-related integrations."
  :type 'boolean
  :group 'my/features)

(defun my/core-feature-flags-init ()
  "Initialize feature flags."
  t)

(provide 'core-feature-flags)
