;;; core-paths.el --- Path and directory policy -*- lexical-binding: t; -*-

(defun my/core-paths-init ()
  "Ensure required runtime directories exist."
  (dolist (dir (list my/cache-dir my/var-dir my/etc-dir my/eln-dir))
    (unless (file-directory-p dir)
      (make-directory dir t))))

(provide 'core-paths)
