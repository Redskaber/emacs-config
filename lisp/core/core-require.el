;;; core-require.el --- Safe require helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;; Safe/optional/capability-aware require helpers for manifest-driven startup.
;;; Code:

(require 'core-logging)
(require 'core-errors)

(defun my/safe-require (feature &optional filename noerror)
  "Require FEATURE safely.

Return non-nil when FEATURE is loaded successfully, nil otherwise.
FILENAME and NOERROR are passed through to `require'."
  (condition-case err
      (require feature filename noerror)
    (error
     (my/log "require failed: %s -> %S" feature err)
     nil)))

(defun my/require-if (predicate feature &optional filename)
  "Require FEATURE when PREDICATE is non-nil.

PREDICATE may be:
- a boolean value
- a function symbol
- a lambda/function object

Return non-nil only if predicate passes and FEATURE loads."
  (when (cond
         ((functionp predicate) (funcall predicate))
         (t predicate))
    (my/safe-require feature filename t)))

(defun my/require-executable (cmd feature &optional filename)
  "Require FEATURE only when executable CMD exists."
  (when (my/executable-ensure cmd)
    (my/safe-require feature filename t)))

(defun my/require-feature-flag (flag feature &optional filename)
  "Require FEATURE only when feature flag FLAG is enabled."
  (when (and (boundp flag) (symbol-value flag))
    (my/safe-require feature filename t)))

(defun my/core-require-init ()
  "Initialize require helpers."
  t)

(provide 'core-require)
;;; core-require.el ends here
