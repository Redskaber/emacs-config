;;; runtime-stage.el --- Stage executor -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - Optionally applies my/runtime-module-graph-sort to the manifest
;;;       before running, enabling intra-stage :after dependency ordering.
;;;       Controlled by my/stage-sort-modules (default t).
;;;     - Dep check and feature gate logic unchanged.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-registry)
(require 'runtime-stage-state)
(require 'runtime-module-runner)
(require 'runtime-graph)

(defcustom my/stage-sort-modules t
  "When non-nil, sort manifest specs within each stage by :after deps.
  This gives intra-stage dependency ordering without relying on declaration
  order.  Set nil to preserve V1 behavior (declaration order)."
  :type 'boolean
  :group 'my)

;; ─────────────────────────────────────────────────────────────────────────────
;; Helpers
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-stage-deps-satisfied-p (stage)
  "Return non-nil when all stage :after deps are done."
  (cl-every #'my/runtime-stage-done-p
            (my/runtime-stage-after stage)))

(defun my/runtime-stage--sorted-manifest (manifest)
  "Return MANIFEST (list of normalised specs) sorted by intra-stage :after deps.
  Falls back to original order if sorting signals an error (e.g. cross-stage refs)."
  (if (not my/stage-sort-modules)
      manifest
    (condition-case err
        (my/runtime-module-graph-sort manifest)
      (error
       (my/log-warn "stage" "module-graph sort failed (%S); using declaration order" err)
       manifest))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Stage runner
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-stage-run (stage)
  "Run the registered STAGE.
  Returns list of module status symbols, or a skip/error reason symbol."
  (let ((enabled-p (my/runtime-stage-enabled-p stage))
        (deps-ok-p (my/runtime-stage-deps-satisfied-p stage)))
    (cond
     ((not enabled-p)
      (my/runtime-stage-state-set stage my/stage-status-skipped
                                  :feature-disabled)
      (my/log-debug "stage" "skip(feature): %s" stage)
      my/stage-status-skipped)

     ((not deps-ok-p)
      (my/runtime-stage-state-set stage my/stage-status-skipped
                                  :dependency-failed)
      (my/log-debug "stage" "skip(dep): %s after=%S"
                    stage (my/runtime-stage-after stage))
      my/stage-status-skipped)

     (t
      (my/with-runtime-stage-state stage
        (my/log-info "stage" "start: %s" stage)
        (let* ((raw-manifest    (my/runtime-stage-manifest stage))
               (norm-manifest   (my/runtime-manifest-normalize raw-manifest))
               (sorted-manifest (my/runtime-stage--sorted-manifest norm-manifest))
               (results         (my/runtime-module-run-manifest
                                 sorted-manifest
                                 (symbol-name stage))))
          (my/log-info "stage" "end: %s" stage)
          results))))))

(provide 'runtime-stage)
;;; runtime-stage.el ends here
