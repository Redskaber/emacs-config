;;; kernel-paths.el --- Path and directory policy -*- lexical-binding: t; -*-
;;; Commentary:
;;; Load-path registration and runtime directory creation.
;;; Code:

(require 'kernel-const)
(require 'kernel-lib)

(defun my/kernel-load-path-init ()
  "Register managed Lisp subdirectories into `load-path'."
  (dolist (subdir my/lisp-subdirs)
    (let ((dir (expand-file-name subdir my/lisp-dir)))
      (when (file-directory-p dir)
        (add-to-list 'load-path dir)))))

(defun my/kernel-runtime-dirs-init ()
  "Ensure required runtime directories exist."
  (dolist (dir (list my/cache-dir my/var-dir my/etc-dir my/eln-dir))
    (my/ensure-dir dir)))

(defun my/kernel-paths-init ()
  "Initialize path and directory policy."
  (my/kernel-runtime-dirs-init)
  (my/kernel-load-path-init))

(provide 'kernel-paths)
;;; kernel-paths.el ends here
