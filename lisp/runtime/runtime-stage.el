;;; runtime-stage.el --- Stage executor -*- lexical-binding: t; -*-
;;; Commentary:
;;; Execute declared runtime stages.
;;; Code:

(require 'kernel-logging)
(require 'runtime-registry)
(require 'runtime-stage-state)
(require 'runtime-module-runner)

(defun my/runtime-stage-deps-satisfied-p (stage)
  "Return non-nil when all stage dependencies of STAGE are satisfied."
  (let ((deps (my/runtime-stage-after stage)))
    (cl-every #'my/runtime-stage-done-p deps)))

(defun my/runtime-stage-run (stage)
  "Run registered STAGE."
  (let ((enabled-p (my/runtime-stage-enabled-p stage))
        (deps-ok-p (my/runtime-stage-deps-satisfied-p stage)))
    (cond
     ((not enabled-p)
      (my/log "stage skipped (feature): %s" stage)
      'skipped)

     ((not deps-ok-p)
      (my/log "stage skipped (dependency): %s after=%S"
              stage (my/runtime-stage-after stage))
      'skipped)

     (t
      (my/with-runtime-stage-state stage
        (my/log "stage start: %s" stage)
        (let ((records (my/runtime-module-run-manifest
                        (my/runtime-stage-manifest stage)
                        (symbol-name stage))))
          (my/log "stage end: %s" stage)
          records))))))

(provide 'runtime-stage)
;;; runtime-stage.el ends here
