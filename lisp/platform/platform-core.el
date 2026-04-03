;;; platform-core.el --- Platform and capability detection -*- lexical-binding: t; -*-

(defconst my/os-linux-p   (eq system-type 'gnu/linux))
(defconst my/os-macos-p   (eq system-type 'darwin))
(defconst my/os-windows-p (memq system-type '(windows-nt ms-dos cygwin)))

(defconst my/gui-p (display-graphic-p))
(defconst my/tty-p (not my/gui-p))

;; Session layer (desktop environment session)
(defconst my/session-wayland-p
  (and my/os-linux-p
       (string= (or (getenv "XDG_SESSION_TYPE") "") "wayland")))

(defconst my/session-x11-p
  (and my/os-linux-p
       (string= (or (getenv "XDG_SESSION_TYPE") "") "x11")))

;; Emacs display backend layer
(defconst my/backend-x-p
  (eq window-system 'x))

(defconst my/backend-pgtk-p
  ;; pgtk builds on GNU/Linux often report 'pgtk.
  (eq window-system 'pgtk))

(defconst my/backend-ns-p
  (eq window-system 'ns))

(defconst my/backend-w32-p
  (eq window-system 'w32))

(defun my/platform-summary ()
  "Return a plist describing current platform capabilities."
  (list :system-type system-type
        :window-system window-system
        :gui my/gui-p
        :tty my/tty-p
        :session-wayland my/session-wayland-p
        :session-x11 my/session-x11-p
        :backend-x my/backend-x-p
        :backend-pgtk my/backend-pgtk-p
        :backend-ns my/backend-ns-p
        :backend-w32 my/backend-w32-p
        :native-comp (featurep 'native-compile)
        :treesit (and (fboundp 'treesit-available-p)
                      (treesit-available-p))))

(defun my/platform-core-init ()
  "Initialize platform layer."
  (when my/os-linux-p
    (require 'platform-linux)
    (my/platform-linux-init))

  (when my/os-macos-p
    (require 'platform-macos)
    (my/platform-macos-init))

  (when my/os-windows-p
    (require 'platform-windows)
    (my/platform-windows-init))

  (if my/gui-p
      (progn
        (require 'platform-gui)
        (my/platform-gui-init))
    (require 'platform-tty)
    (my/platform-tty-init))

  (message "[platform] %S" (my/platform-summary)))

(provide 'platform-core)
