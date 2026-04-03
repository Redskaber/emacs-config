;;; ops-benchmark.el --- Benchmark helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;; Simple benchmarking utilities for config development.
;;; Code:

(defgroup my/ops-benchmark nil
  "Benchmark helpers."
  :group 'my/features)

(defmacro my/benchmark (label &rest body)
  "Benchmark BODY and log LABEL."
  (declare (indent 1))
  `(let ((elapsed (benchmark-run 1 (progn ,@body))))
     (message "[my][bench] %s => %.6fs" ,label elapsed)
     elapsed))

(defun my/ops-benchmark-require-feature (feature)
  "Benchmark requiring FEATURE interactively."
  (interactive
   (list (intern (completing-read "Require feature: " obarray #'symbolp t))))
  (my/benchmark (format "require:%s" feature)
    (require feature)))

(defun my/ops-benchmark-init ()
  "Initialize benchmark helpers."
  (global-set-key (kbd "C-c o b r") #'my/ops-benchmark-require-feature))

(provide 'ops-benchmark)
;;; ops-benchmark.el ends here
