;;; kernel-lib.el --- Shared kernel helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;; Small pure helpers used across kernel/runtime.
;;; Code:

(defun my/ensure-dir (dir)
  "Ensure DIR exists and return DIR."
  (unless (file-directory-p dir)
    (make-directory dir t))
  dir)

(defun my/buffer-file-or-default-directory ()
  "Return current buffer file path or `default-directory'."
  (or (buffer-file-name) default-directory))

(defun my/executable-available-p (cmd)
  "Return non-nil if CMD exists in PATH."
  (and (stringp cmd)
       (not (string-empty-p cmd))
       (executable-find cmd)))

(defun my/plist-get-required (plist prop)
  "Return PROP from PLIST or signal an error."
  (or (plist-get plist prop)
      (error "Missing required plist key %S in %S" prop plist)))

(defun my/listify (value)
  "Normalize VALUE to a list."
  (cond
   ((null value) nil)
   ((listp value) value)
   (t (list value))))

(provide 'kernel-lib)
;;; kernel-lib.el ends here
