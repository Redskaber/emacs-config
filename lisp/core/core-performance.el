;;; core-performance.el --- Runtime performance policy -*- lexical-binding: t; -*-

(defun my/core-performance-init ()
  "Set runtime performance defaults."
  ;; Less frequent automatic redisplay churn.
  (setq auto-window-vscroll nil)

  ;; Faster bidi for mostly code workloads.
  (setq-default bidi-display-reordering 'left-to-right
                bidi-paragraph-direction 'left-to-right)

  ;; Better long-line behavior.
  (setq-default bidi-inhibit-bpa t)
  (global-so-long-mode 1))

(provide 'core-performance)
