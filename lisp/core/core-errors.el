;;; core-errors.el --- Error boundary helpers -*- lexical-binding: t; -*-

(defmacro my/with-safe-init (label &rest body)
  "Execute BODY safely, reporting LABEL on failure."
  (declare (indent 1))
  `(condition-case err
       (progn ,@body)
     (error
      (message "[init:error] %s -> %S" ,label err)
      nil)))

(defun my/core-errors-init ()
  "Initialize error helpers."
  t)

(provide 'core-errors)
