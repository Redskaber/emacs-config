;;; ui-chrome.el --- Editor chrome and visual ergonomics -*- lexical-binding: t; -*-

(require 'platform-core)

(defgroup my/ui-chrome nil
  "Visual ergonomics and editor chrome."
  :group 'my/features)

(defcustom my/ui-line-numbers t
  "Whether to enable line numbers in programming/text buffers."
  :type 'boolean
  :group 'my/ui-chrome)

(defcustom my/ui-line-numbers-type 'relative
  "Line number style."
  :type '(choice
          (const absolute)
          (const relative)
          (const visual))
  :group 'my/ui-chrome)

(defcustom my/ui-fringe-width 10
  "Fringe width on each side."
  :type 'integer
  :group 'my/ui-chrome)

(defcustom my/ui-enable-hl-line t
  "Whether to enable current line highlight."
  :type 'boolean
  :group 'my/ui-chrome)

(defcustom my/ui-enable-display-line-numbers-in-text-mode nil
  "Whether to enable line numbers in `text-mode'."
  :type 'boolean
  :group 'my/ui-chrome)

(defun my/ui-chrome--basic-visual-defaults ()
  "Apply basic visual defaults."
  ;; Cleaner redisplay / scrolling feel.
  (setq-default cursor-in-non-selected-windows nil
                fast-but-imprecise-scrolling t
                redisplay-skip-fontification-on-input t
                scroll-conservatively 101
                scroll-margin 2
                scroll-step 1
                hscroll-margin 2
                hscroll-step 1
                auto-hscroll-mode 'current-line
                truncate-partial-width-windows t
                sentence-end-double-space nil)

  ;; Fringe
  (when my/gui-p
    (set-fringe-mode my/ui-fringe-width))

  ;; Cursor
  (blink-cursor-mode -1)

  ;; Visible bell policy
  (setq visible-bell nil
        ring-bell-function #'ignore))

(defun my/ui-chrome--line-numbers-setup ()
  "Configure display line numbers."
  (when my/ui-line-numbers
    (setq display-line-numbers-type my/ui-line-numbers-type)

    (add-hook 'prog-mode-hook #'display-line-numbers-mode)

    (when my/ui-enable-display-line-numbers-in-text-mode
      (add-hook 'text-mode-hook #'display-line-numbers-mode))

    ;; Disable where line numbers are noisy or unhelpful.
    (dolist (hook '(term-mode-hook
                    shell-mode-hook
                    eshell-mode-hook
                    vterm-mode-hook
                    treemacs-mode-hook
                    dired-mode-hook
                    pdf-view-mode-hook
                    image-mode-hook
                    doc-view-mode-hook
                    minibuffer-setup-hook))
      (add-hook hook (lambda () (display-line-numbers-mode -1))))))

(defun my/ui-chrome--hl-line-setup ()
  "Configure current line highlighting."
  (when my/ui-enable-hl-line
    (global-hl-line-mode 1)))

(defun my/ui-chrome--paren-setup ()
  "Configure parenthesis matching."
  (show-paren-mode 1)
  (setq show-paren-delay 0
        show-paren-when-point-inside-paren t
        show-paren-when-point-in-periphery t))

(defun my/ui-chrome--misc-modes ()
  "Enable useful global visual modes."
  (column-number-mode 1)
  (size-indication-mode 1)
  (global-visual-line-mode -1)
  (global-auto-revert-mode 1)
  (setq global-auto-revert-non-file-buffers t
        auto-revert-verbose nil))

(defun my/ui-chrome-init ()
  "Initialize editor chrome."
  (my/ui-chrome--basic-visual-defaults)
  (my/ui-chrome--line-numbers-setup)
  (my/ui-chrome--hl-line-setup)
  (my/ui-chrome--paren-setup)
  (my/ui-chrome--misc-modes))

(provide 'ui-chrome)
