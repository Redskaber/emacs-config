;;; core-paths.el --- Path and directory policy -*- lexical-binding: t; -*-

(require 'core-const)
(require 'core-lib)

(defun my/core-load-path-init ()
  "Register managed Lisp subdirectories into `load-path'."
  (dolist (subdir my/lisp-subdirs)
    (let ((dir (expand-file-name subdir my/lisp-dir)))
      (when (file-directory-p dir)
        (add-to-list 'load-path dir)))))

(defun my/core-runtime-dirs-init ()
  "Ensure required runtime directories exist."
  (dolist (dir (list my/cache-dir my/var-dir my/etc-dir my/eln-dir))
    (my/ensure-dir dir)))

(defun my/core-paths-init ()
  "Initialize path and directory policy."
  (my/core-runtime-dirs-init)
  (my/core-load-path-init))

(provide 'core-paths)
