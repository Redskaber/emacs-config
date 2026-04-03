;;; prog-debug.el --- Debugging integration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Built-in GUD with optional Dape integration.
;;; Code:

(require 'gud)

(defgroup my/prog-debug nil
  "Debugging integration."
  :group 'my/prog)

(defcustom my/prog-debug-enable-dape t
  "Whether to enable Dape when installed."
  :type 'boolean)

(defun my/prog-debug--setup-gud ()
  "Configure built-in GUD."
  (setq gud-tooltip-mode nil))

(defun my/prog-debug--setup-dape ()
  "Configure optional Dape."
  (when my/prog-debug-enable-dape
    (use-package dape
      :defer t
      :commands (dape dape-repl)
      :bind (("C-c d d" . dape)
             ("C-c d r" . dape-repl)))))

(defun my/prog-debug-init ()
  "Initialize debugging integration."
  (my/prog-debug--setup-gud)
  (my/prog-debug--setup-dape))

(provide 'prog-debug)
;;; prog-debug.el ends here
