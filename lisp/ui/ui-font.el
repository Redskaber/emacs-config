;;; ui-font.el --- Font policy for GUI sessions -*- lexical-binding: t; -*-

(require 'platform-core)

(defgroup my/ui-font nil
  "Font configuration."
  :group 'my/features)

(defcustom my/ui-font-size 15
  "Default base font size."
  :type 'integer
  :group 'my/ui-font)

(defcustom my/ui-font-size-variable 15
  "Default variable-pitch font size."
  :type 'integer
  :group 'my/ui-font)

(defcustom my/ui-font-fixed-candidates
  '("Iosevka Comfy"
    "Iosevka Term"
    "JetBrainsMono Nerd Font"
    "JetBrains Mono"
    "Cascadia Code"
    "Sarasa Mono SC"
    "Maple Mono NF CN"
    "Maple Mono"
    "Fira Code"
    "Source Code Pro"
    "Monaco"
    "Consolas")
  "Candidate fixed-pitch fonts in priority order."
  :type '(repeat string)
  :group 'my/ui-font)

(defcustom my/ui-font-variable-candidates
  '("Inter"
    "SF Pro Text"
    "Segoe UI"
    "Noto Sans"
    "Source Sans 3"
    "Helvetica Neue")
  "Candidate variable-pitch fonts in priority order."
  :type '(repeat string)
  :group 'my/ui-font)

(defcustom my/ui-font-cjk-candidates
  '("Sarasa UI SC"
    "Sarasa Mono SC"
    "LXGW WenKai"
    "Maple Mono NF CN"
    "Noto Sans CJK SC"
    "Source Han Sans SC"
    "Microsoft YaHei UI"
    "PingFang SC"
    "WenQuanYi Micro Hei")
  "Candidate CJK fonts in priority order."
  :type '(repeat string)
  :group 'my/ui-font)

(defcustom my/ui-font-emoji-candidates
  '("Noto Color Emoji"
    "Apple Color Emoji"
    "Segoe UI Emoji")
  "Candidate emoji fonts in priority order."
  :type '(repeat string)
  :group 'my/ui-font)

(defun my/ui-font--installed-p (font-name)
  "Return non-nil if FONT-NAME is installed."
  (and (stringp font-name)
       (find-font (font-spec :name font-name))))

(defun my/ui-font--first-available (fonts)
  "Return first available font from FONTS."
  (seq-find #'my/ui-font--installed-p fonts))

(defun my/ui-font--set-default-font ()
  "Set default fixed-pitch font."
  (when-let* ((font (my/ui-font--first-available my/ui-font-fixed-candidates)))
    (set-face-attribute 'default nil :font font :height (* my/ui-font-size 10))
    (set-face-attribute 'fixed-pitch nil :font font :height (* my/ui-font-size 10))
    (message "[ui:font] fixed-pitch -> %s" font)))

(defun my/ui-font--set-variable-font ()
  "Set variable-pitch font."
  (when-let* ((font (my/ui-font--first-available my/ui-font-variable-candidates)))
    (set-face-attribute 'variable-pitch nil
                        :font font
                        :height (* my/ui-font-size-variable 10)
                        :weight 'regular)
    (message "[ui:font] variable-pitch -> %s" font)))

(defun my/ui-font--set-cjk-font ()
  "Set CJK fallback font."
  (when-let* ((font (my/ui-font--first-available my/ui-font-cjk-candidates)))
    ;; Common CJK charsets
    (dolist (charset '(han cjk-misc bopomofo kana symbol))
      (set-fontset-font t charset (font-spec :family font)))
    (message "[ui:font] cjk fallback -> %s" font)))

(defun my/ui-font--set-emoji-font ()
  "Set emoji fallback font."
  (when-let* ((font (my/ui-font--first-available my/ui-font-emoji-candidates)))
    (when (fboundp 'set-fontset-font)
      (set-fontset-font t 'emoji (font-spec :family font) nil 'prepend))
    (message "[ui:font] emoji fallback -> %s" font)))

(defun my/ui-font-init ()
  "Initialize GUI font policy."
  (when my/gui-p
    (my/ui-font--set-default-font)
    (my/ui-font--set-variable-font)
    (my/ui-font--set-cjk-font)
    (my/ui-font--set-emoji-font)))

(provide 'ui-font)
