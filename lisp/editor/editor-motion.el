;;; editor-motion.el --- Motion ergonomics -*- lexical-binding: t; -*-
;;; Commentary:
;;; Language-agnostic cursor movement enhancements.
;;; Code:
;;; global-set-key to core-keymap.el ?


(require 'core-lib)

(defgroup my/editor-motion nil
  "Motion ergonomics."
  :group 'editing)

(defcustom my/editor-enable-subword t
  "Whether to enable `subword-mode' in programming-like buffers."
  :type 'boolean
  :group 'my/editor-motion)

(defcustom my/editor-enable-avy t
  "Whether to enable avy if installed."
  :type 'boolean
  :group 'my/editor-motion)

(defun my/smarter-move-beginning-of-line (arg)
  "Move point back to indentation or beginning of line.
Move by ARG lines first if ARG is not nil."
  (interactive "^p")
  (setq arg (or arg 1))
  (when (/= arg 1)
    (forward-line (1- arg)))
  (let ((origin (point)))
    (back-to-indentation)
    (when (= origin (point))
      (move-beginning-of-line 1))))

(defun my/smarter-move-end-of-line ()
  "Move to end of code or real end of line."
  (interactive "^")
  (let ((origin (point)))
    (move-end-of-line 1)
    (skip-chars-backward " \t")
    (when (= origin (point))
      (move-end-of-line 1))))

(defun my/editor--core-bindings-init ()
  "Install core motion bindings."
  (global-set-key [remap move-beginning-of-line] #'my/smarter-move-beginning-of-line)
  (global-set-key (kbd "C-e") #'my/smarter-move-end-of-line))

(defun my/editor--subword-init ()
  "Enable subword navigation."
  (when my/editor-enable-subword
    (add-hook 'prog-mode-hook #'subword-mode)
    (add-hook 'text-mode-hook #'subword-mode)))

(defun my/editor--avy-init ()
  "Configure avy if available."
  (when my/editor-enable-avy
    (when (require 'avy nil t)
      (setq avy-timeout-seconds 0.25)
      (global-set-key (kbd "M-j") #'avy-goto-char-timer)
      (global-set-key (kbd "M-g l") #'avy-goto-line))))

(defun my/editor-motion-init ()
  "Initialize motion ergonomics."
  (my/editor--core-bindings-init)
  (my/editor--subword-init)
  (my/editor--avy-init))

(provide 'editor-motion)
;;; editor-motion.el ends here
