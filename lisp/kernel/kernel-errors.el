;;; kernel-errors.el --- Error boundary helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;; Safe execution wrappers for startup/runtime boundaries.
;;; Code:

(require 'kernel-logging)

(defmacro my/with-safe-call (label &rest body)
  "Execute BODY safely, reporting LABEL on failure."
  (declare (indent 1))
  `(condition-case err
       (progn ,@body)
     (error
      (my/log "[error] %s -> %S" ,label err)
      nil)))

(defun my/kernel-errors-init ()
  "Initialize error helpers."
  t)

(provide 'kernel-errors)
;;; kernel-errors.el ends here
