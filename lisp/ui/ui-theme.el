;;; ui-theme.el --- Theme system -*- lexical-binding: t; -*-

(defgroup my/ui-theme nil
  "Theme system."
  :group 'my/features)

(defcustom my/ui-theme-variant 'modus-vivendi-tinted
  "Theme variant to load."
  :type '(choice
          (const :tag "Modus Operandi" modus-operandi)
          (const :tag "Modus Operandi Tinted" modus-operandi-tinted)
          (const :tag "Modus Vivendi" modus-vivendi)
          (const :tag "Modus Vivendi Tinted" modus-vivendi-tinted))
  :group 'my/ui-theme)

(defcustom my/ui-theme-fallback 'tango-dark
  "Fallback theme if preferred theme fails to load."
  :type 'symbol
  :group 'my/ui-theme)

(defun my/ui-theme--disable-all ()
  "Disable all currently enabled themes."
  (mapc #'disable-theme custom-enabled-themes))

(defun my/ui-theme--configure-modus ()
  "Configure Modus themes if the relevant variables are available."
  ;; 不强依赖 `(require 'modus-themes)`，避免不同发行版 / Nix 包布局差异。
  (when (boundp 'modus-themes-italic-constructs)
    (setq modus-themes-italic-constructs t
          modus-themes-bold-constructs t
          modus-themes-mixed-fonts t
          modus-themes-variable-pitch-ui t

          ;; More subtle, modern visual style
          modus-themes-prompts '(intense)
          modus-themes-completions '((matches . (extrabold))
                                     (selection . (semibold accented))
                                     (popup . (accented intense)))

          modus-themes-headings
          '((0 . (1.35))
            (1 . (1.25))
            (2 . (1.18))
            (3 . (1.12))
            (4 . (1.08))
            (t . (1.05)))

          modus-themes-org-blocks 'gray-background
          modus-themes-region '(bg-only no-extend)

          ;; Optional palette tweaks: minimal and conservative.
          modus-themes-common-palette-overrides
          '((fringe unspecified)
            (bg-tab-bar bg-main)
            (bg-tab-current bg-active)
            (bg-tab-other bg-dim)
            (bg-paren-match bg-magenta-subtle)
            (underline-err red-warmer)
            (underline-warning yellow-warmer)
            (underline-note cyan-warmer)))))

(defun my/ui-theme--load (theme)
  "Load THEME safely. Return non-nil on success."
  (condition-case err
      (progn
        (load-theme theme t)
        (message "[ui:theme] loaded -> %s" theme)
        t)
    (error
     (message "[ui:theme:error] failed to load %s -> %S" theme err)
     nil)))

(defun my/ui-theme-init ()
  "Initialize theme system."
  (my/ui-theme--disable-all)

  ;; 先配置（如果变量可用），再加载主题。
  (my/ui-theme--configure-modus)

  ;; 优先加载目标主题，失败则降级。
  (unless (my/ui-theme--load my/ui-theme-variant)
    (unless (my/ui-theme--load my/ui-theme-fallback)
      (message "[ui:theme:warn] no theme could be loaded"))))

(provide 'ui-theme)
