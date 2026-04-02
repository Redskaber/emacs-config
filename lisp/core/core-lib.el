;;; core-lib.el --- Shared utility helpers -*- lexical-binding: t; -*-

(defun my/ensure-dir (dir)
  "Ensure DIR exists and return it."
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

(defun my/executable-ensure (cmd)
  "Return non-nil if CMD exists, otherwise log a warning."
  (if (my/executable-available-p cmd)
      t
    (message "[my:warn] missing executable: %s" cmd)
    nil))

(defun my/feature-enabled-p (value)
  "Return non-nil if feature flag VALUE is enabled."
  (eq value t))

(provide 'core-lib)
