;;; editor-snippets.el --- Snippet infrastructure -*- lexical-binding: t; -*-
;;; Commentary:
;;; Snippet engine setup and policy.
;;; Code:
;;; global-set-key to kernel-keymap.el ?

(require 'cl-lib)

(require 'kernel-lib)
(require 'kernel-const)

(defgroup my/editor-snippets nil
  "Snippet infrastructure."
  :group 'editing)

(defcustom my/editor-enable-yasnippet t
  "Whether to enable yasnippet if installed."
  :type 'boolean
  :group 'my/editor-snippets)

(defcustom my/editor-enable-yasnippet-snippets t
  "Whether to load yasnippet-snippets if installed."
  :type 'boolean
  :group 'my/editor-snippets)

(defcustom my/editor-snippet-dirs nil
  "Additional snippet directories."
  :type '(repeat directory)
  :group 'my/editor-snippets)

(defun my/editor--yasnippet-init ()
  "Configure yasnippet."
  (when (and my/editor-enable-yasnippet
             (require 'yasnippet nil t))
    (let ((dirs (append
                 (when (boundp 'my/snippets-dir)
                   (list my/snippets-dir))
                 my/editor-snippet-dirs)))
      (setq yas-snippet-dirs
            (cl-remove-if-not #'file-directory-p dirs)))
    (yas-global-mode 1)

    (when (and my/editor-enable-yasnippet-snippets
               (require 'yasnippet-snippets nil t))
      t)))

(defun my/editor--bindings-init ()
  "Install snippet bindings."
  (when (featurep 'yasnippet)
    (global-set-key (kbd "C-c y i") #'yas-insert-snippet)
    (global-set-key (kbd "C-c y n") #'yas-new-snippet)
    (global-set-key (kbd "C-c y v") #'yas-visit-snippet-file)))

(defun my/editor-snippets-init ()
  "Initialize snippet infrastructure."
  (my/editor--yasnippet-init)
  (my/editor--bindings-init))

(provide 'editor-snippets)
;;; editor-snippets.el ends here
