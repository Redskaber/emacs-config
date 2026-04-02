;;; bootstrap-profile.el --- Startup profiling helpers -*- lexical-binding: t; -*-

(defvar my/profile-enabled t
  "Whether startup stage profiling is enabled.")

(defvar my/profile-records nil
  "Collected startup stage timing records.")

(defmacro my/profile-stage (name &rest body)
  "Measure execution time of BODY and record it under NAME."
  (declare (indent 1))
  `(let ((start (current-time)))
     (prog1
         (progn ,@body)
       (when my/profile-enabled
         (push (cons ,name (float-time (time-subtract (current-time) start)))
               my/profile-records)))))

(defun my/report-startup ()
  "Report startup timing in *Messages*."
  (let ((elapsed (float-time (time-subtract (current-time) my/emacs-start-time))))
    (message "[init] startup completed in %.3fs | GC=%d"
             elapsed gcs-done)
    (dolist (it (nreverse my/profile-records))
      (message "[init] stage %-12s %.3fs" (car it) (cdr it)))))

(provide 'bootstrap-profile)
