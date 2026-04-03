;;; app-terminal.el --- Unified terminal entrypoints -*- lexical-binding: t; -*-
;;; Commentary:
;;; User-facing terminal orchestration with backend preference and safe fallback.
;;; Code:

(defgroup my/app-terminal nil
  "Unified terminal entrypoints."
  :group 'tools)

(defcustom my/app-terminal-preferred-backend 'vterm
  "Preferred terminal backend.
Supported values: `vterm', `eat', `eshell', `ansi-term'."
  :type '(choice (const vterm)
                 (const eat)
                 (const eshell)
                 (const ansi-term))
  :group 'my/app-terminal)

(defcustom my/app-terminal-buffer-name "*terminal*"
  "Default terminal buffer name."
  :type 'string
  :group 'my/app-terminal)

(defun my/app-terminal-open ()
  "Open terminal using preferred backend with graceful fallback."
  (interactive)
  (pcase my/app-terminal-preferred-backend
    ('vterm
     (cond
      ((fboundp 'vterm) (vterm my/app-terminal-buffer-name))
      ((fboundp 'eat) (eat))
      ((fboundp 'eshell) (eshell t))
      (t (ansi-term (or (getenv "SHELL") "/bin/sh")))))
    ('eat
     (cond
      ((fboundp 'eat) (eat))
      ((fboundp 'vterm) (vterm my/app-terminal-buffer-name))
      ((fboundp 'eshell) (eshell t))
      (t (ansi-term (or (getenv "SHELL") "/bin/sh")))))
    ('eshell
     (if (fboundp 'eshell)
         (eshell t)
       (ansi-term (or (getenv "SHELL") "/bin/sh"))))
    (_
     (ansi-term (or (getenv "SHELL") "/bin/sh")))))

(defun my/app-terminal-init ()
  "Initialize terminal entrypoints."
  (global-set-key (kbd "C-c t") #'my/app-terminal-open))

(provide 'app-terminal)
;;; app-terminal.el ends here
