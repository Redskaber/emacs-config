;;; ui-frame.el --- Frame and window UI policy -*- lexical-binding: t; -*-

(require 'platform-core)

(defgroup my/ui-frame nil
  "Frame and top-level window behavior."
  :group 'my/features)

(defcustom my/ui-frame-title-format
  '("%b"
    (:eval
     (when-let* ((proj (and (fboundp 'project-current)
                            (project-current nil))))
       (format "  [%s]"
               (file-name-nondirectory
                (directory-file-name
                 (car (project-roots proj)))))))
    " — Emacs")
  "Frame title format."
  :type 'sexp
  :group 'my/ui-frame)

(defcustom my/ui-frame-alpha-active 96
  "Frame alpha when active (0-100)."
  :type 'integer
  :group 'my/ui-frame)

(defcustom my/ui-frame-alpha-inactive 92
  "Frame alpha when inactive (0-100)."
  :type 'integer
  :group 'my/ui-frame)

(defcustom my/ui-frame-enable-transparency t
  "Whether to enable alpha transparency in GUI sessions."
  :type 'boolean
  :group 'my/ui-frame)

(defcustom my/ui-frame-maximized-at-startup nil
  "Whether to start Emacs in maximized frame."
  :type 'boolean
  :group 'my/ui-frame)

(defcustom my/ui-frame-undecorated nil
  "Whether to create undecorated frames (advanced / optional)."
  :type 'boolean
  :group 'my/ui-frame)

(defun my/ui-frame--supports-alpha-p ()
  "Return non-nil if current GUI likely supports alpha transparency."
  (and my/gui-p
       (display-graphic-p)
       ;; TTY obviously no. On GUI, alpha support depends on backend/WM.
       t))

(defun my/ui-frame--apply-defaults ()
  "Apply default frame behavior."
  (setq frame-title-format my/ui-frame-title-format)

  ;; Pixel-precise resize is already set in early-init, but keeping UI intent here
  ;; is acceptable if you later want to override per platform.
  (setq frame-resize-pixelwise t)

  ;; Better modern defaults.
  (setq use-dialog-box nil
        visible-bell nil
        ring-bell-function #'ignore))

(defun my/ui-frame--apply-transparency ()
  "Apply frame transparency if enabled and supported."
  (when (and my/ui-frame-enable-transparency
             (my/ui-frame--supports-alpha-p))
    ;; Note:
    ;; This is standard alpha transparency, NOT compositor blur / acrylic / vibrancy.
    ;; Real blur depends on your window manager / OS compositor, not Emacs itself.
    (set-frame-parameter nil 'alpha-background my/ui-frame-alpha-active)
    (add-to-list 'default-frame-alist `(alpha-background . ,my/ui-frame-alpha-active))

    ;; Fallback for backends/themes still honoring legacy alpha pair.
    (set-frame-parameter nil 'alpha `(,my/ui-frame-alpha-active . ,my/ui-frame-alpha-inactive))
    (add-to-list 'default-frame-alist
                 `(alpha . (,my/ui-frame-alpha-active . ,my/ui-frame-alpha-inactive)))))

(defun my/ui-frame--apply-startup-state ()
  "Apply initial frame startup state."
  (when my/ui-frame-maximized-at-startup
    (add-to-list 'default-frame-alist '(fullscreen . maximized)))
  (when my/ui-frame-undecorated
    (add-to-list 'default-frame-alist '(undecorated . t))))

(defun my/ui-frame-init ()
  "Initialize frame UI policy."
  (when my/gui-p
    (my/ui-frame--apply-defaults)
    (my/ui-frame--apply-startup-state)
    (my/ui-frame--apply-transparency)))

(provide 'ui-frame)
