;;; kernel-performance.el --- Runtime performance policy -*- lexical-binding: t; -*-
;;; Commentary:
;;;   bidi optimizations are gated behind my/perf-bidi-optimize defcustom.
;;;   Users who work with RTL text can disable the optimization safely.
;;;
;;; Code:

(require 'kernel-logging)

(defcustom my/perf-bidi-optimize t
  "When non-nil, apply bidi display reordering optimizations.

  Disable when working with right-to-left (Arabic, Hebrew, etc.) text.
  Defaults to t because most code-focused workflows are LTR-only."
  :type 'boolean
  :group 'my)

(defun my/kernel-performance-init ()
  "Set runtime performance defaults."
  (setq auto-window-vscroll nil)
  (when my/perf-bidi-optimize
    (setq-default bidi-display-reordering 'left-to-right
                  bidi-paragraph-direction 'left-to-right
                  bidi-inhibit-bpa t)
    (my/log-debug "perf" "bidi optimization enabled"))
  (global-so-long-mode 1))

(provide 'kernel-performance)
;;; kernel-performance.el ends here
