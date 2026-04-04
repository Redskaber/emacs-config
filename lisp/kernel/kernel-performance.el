;;; kernel-performance.el --- Runtime performance policy -*- lexical-binding: t; -*-
;;; Commentary:
;;; Performance-oriented defaults for code-heavy workloads.
;;; Code:

(defun my/kernel-performance-init ()
  "Set runtime performance defaults."
  (setq auto-window-vscroll nil)

  (setq-default bidi-display-reordering 'left-to-right
                bidi-paragraph-direction 'left-to-right
                bidi-inhibit-bpa t)

  (global-so-long-mode 1))

(provide 'kernel-performance)
;;; kernel-performance.el ends here
