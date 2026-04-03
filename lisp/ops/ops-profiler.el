;;; ops-profiler.el --- Profiler workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin wrapper around built-in Emacs profiler.
;;; Code:

(require 'profiler)

(defgroup my/ops-profiler nil
  "Profiler workflow."
  :group 'my/features)

(defcustom my/ops-profiler-default-target '(cpu mem)
  "Default profiler target."
  :type '(set (const cpu) (const mem))
  :group 'my/ops-profiler)

(defun my/ops-profiler-start ()
  "Start profiler with default target."
  (interactive)
  (let ((cpu (memq 'cpu my/ops-profiler-default-target))
        (mem (memq 'mem my/ops-profiler-default-target)))
    (cond
     ((and cpu mem) (profiler-start 'cpu+mem))
     (cpu           (profiler-start 'cpu))
     (mem           (profiler-start 'mem))
     (t             (user-error "No profiler target selected")))))

(defun my/ops-profiler-stop-and-report ()
  "Stop profiler and show report."
  (interactive)
  (profiler-stop)
  (profiler-report))

(defun my/ops-profiler-init ()
  "Initialize profiler workflow."
  (global-set-key (kbd "C-c o p s") #'my/ops-profiler-start)
  (global-set-key (kbd "C-c o p r") #'my/ops-profiler-stop-and-report))

(provide 'ops-profiler)
;;; ops-profiler.el ends here
