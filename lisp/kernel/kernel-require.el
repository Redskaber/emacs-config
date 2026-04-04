;;; kernel-require.el --- Safe require helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;; Safe/optional require wrappers.
;;; Code:

(require 'kernel-lib)
(require 'kernel-logging)

(defun my/safe-require (feature &optional filename noerror)
  "Require FEATURE safely.
    Return non-nil when FEATURE loads, nil otherwise."
  (condition-case err
      (require feature filename noerror)
    (error
     (my/log "require failed: %S -> %S" feature err)
     nil)))

(defun my/require-if (predicate feature &optional filename)
  "Require FEATURE when PREDICATE passes."
  (when (cond
         ((functionp predicate) (funcall predicate))
         (t predicate))
    (my/safe-require feature filename t)))

(defun my/require-executable (cmd feature &optional filename)
  "Require FEATURE only when executable CMD exists."
  (when (my/executable-available-p cmd)
    (my/safe-require feature filename t)))

(defun my/kernel-require-init ()
  "Initialize require helpers."
  t)

(provide 'kernel-require)
;;; kernel-require.el ends here
