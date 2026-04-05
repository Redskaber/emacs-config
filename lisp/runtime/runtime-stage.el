;;; runtime-stage.el --- Stage executor  -*- lexical-binding: t; -*-
;;; Commentary:
;;; my/runtime-stage-run now passes module results back to
;;; my/with-runtime-stage-state so it can compute ok vs degraded status.
;;; No other logic changes; the heavy lifting moved to runtime-stage-state.
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-registry)
(require 'runtime-stage-state)
(require 'runtime-module-runner)

(defun my/runtime-stage-deps-satisfied-p (stage)
  "Return non-nil when all stage dependencies of STAGE are satisfied."
  (cl-every #'my/runtime-stage-done-p
            (my/runtime-stage-after stage)))

(defun my/runtime-stage-run (stage)
  "Run the registered STAGE.
Returns the list of module status symbols, or a skip/error reason symbol."
  (let ((enabled-p (my/runtime-stage-enabled-p stage))
        (deps-ok-p (my/runtime-stage-deps-satisfied-p stage)))
    (cond
     ((not enabled-p)
      (my/runtime-stage-state-set stage my/stage-status-skipped)
      (my/log "[stage] skip(feature): %s" stage)
      my/stage-status-skipped)

     ((not deps-ok-p)
      (my/runtime-stage-state-set stage my/stage-status-skipped)
      (my/log "[stage] skip(dep): %s after=%S"
              stage (my/runtime-stage-after stage))
      my/stage-status-skipped)

     (t
      (my/with-runtime-stage-state stage
        (my/log "[stage] start: %s" stage)
        ;; Run manifest; returns list of module status symbols
        (let ((results (my/runtime-module-run-manifest
                        (my/runtime-stage-manifest stage)
                        (symbol-name stage))))
          (my/log "[stage] end: %s" stage)
          results))))))

(provide 'runtime-stage)
;;; runtime-stage.el ends here
