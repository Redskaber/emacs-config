;;; runtime-module-runner.el --- Manifest module executor -*- lexical-binding: t; -*-
;;; Commentary:
;;;   1. Uses `my/provider' structs (runtime-provider) instead of raw plists.
;;;   2. :feature gate and :when gate are evaluated separately.
;;;   3. load (require) and init are separate steps via my/provider-load /
;;;      my/provider-init.
;;;   4. Deferred scheduling delegated entirely to runtime-deferred.
;;;   5. Records are `my/module-record' structs (no free plists).
;;;   6. Idempotency guard unchanged in semantics; uses struct accessor.
;;;   7. Timestamps use float-time for consistency.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-feature)
(require 'runtime-manifest)
(require 'runtime-provider)
(require 'runtime-deferred)
(require 'runtime-module-state)

;; ---------------------------------------------------------------------------
;; Single module execution
;; ---------------------------------------------------------------------------

(defun my/runtime-module-run-spec (spec)
  "Evaluate a single manifest SPEC plist.
  Returns the module status symbol."
  (let* ((spec     (my/runtime-manifest-normalize-spec spec))
         (provider (my/provider-from-spec spec))
         (name     (my/provider-name     provider))
         (feature  (my/provider-feature  provider))
         (when-g   (my/provider-when-gate provider))
         (after    (my/provider-after    provider))
         (defer    (my/provider-defer    provider)))

    ;; ── Idempotency guard ──────────────────────────────────────────────
    (when (my/runtime-module-find-record name)
      (my/log-debug "runner" "idempotent skip: %s" name)
      (cl-return-from my/runtime-module-run-spec my/reason-idempotent-skip))

    (let ((feature-ok (my/feature-enabled-p feature))
          (when-ok    (my/gate-resolve when-g))
          (deps-ok    (my/runtime-module-deps-satisfied-p after)))

      (cond

       ;; ── :feature gate ───────────────────────────────────────────────
       ((not feature-ok)
        (my/runtime-module-record
         (my/make-module-record
          :name name :status my/module-status-skipped
          :reason my/reason-feature-disabled))
        (my/log-debug "runner" "skip(feature): %s" name)
        my/module-status-skipped)

       ;; ── :when gate ──────────────────────────────────────────────────
       ((not when-ok)
        (my/runtime-module-record
         (my/make-module-record
          :name name :status my/module-status-skipped
          :reason my/reason-predicate-failed))
        (my/log-debug "runner" "skip(when): %s" name)
        my/module-status-skipped)

       ;; ── :after dependency gate ──────────────────────────────────────
       ((not deps-ok)
        (my/runtime-module-record
         (my/make-module-record
          :name name :status my/module-status-skipped
          :reason my/reason-dependency-failed :after after))
        (my/log-debug "runner" "skip(dep): %s after=%S" name after)
        my/module-status-skipped)

       ;; ── load (require) gate ─────────────────────────────────────────
       ((not (my/provider-load provider))
        (my/runtime-module-record
         (my/make-module-record
          :name name :status my/module-status-failed
          :reason my/reason-require-failed))
        (my/log-warn "runner" "failed(load): %s" name)
        my/module-status-failed)

       ;; ── deferred ────────────────────────────────────────────────────
       (defer
        (let ((init-fn (my/provider-init-fn provider)))
          (my/deferred-schedule name init-fn defer)
          (my/runtime-module-register-deferred-job
           (my/make-deferred-job name defer))
          (my/runtime-module-record
           (my/make-module-record
            :name name :status my/module-status-deferred :defer defer))
          (my/log-debug "runner" "deferred: %s strategy=%S" name defer)
          my/module-status-deferred))

       ;; ── synchronous init ────────────────────────────────────────────
       (t
        (let* ((t0  (float-time))
               (ok  (my/provider-init provider))
               (t1  (float-time))
               (status (if ok my/module-status-ok my/module-status-failed)))
          (my/runtime-module-record
           (my/make-module-record
            :name name :status status
            :reason (unless ok my/reason-init-failed)
            :started-at t0 :ended-at t1))
          (my/log-debug "runner" "%s: %s (%.3fs)" status name (- t1 t0))
          status))))))

;; ---------------------------------------------------------------------------
;; Deferred completion callback
;; (Called by runtime-deferred after a deferred init fires)
;; ---------------------------------------------------------------------------

(defun my/runtime-module-on-deferred-complete (name ok t0 t1)
  "Update module state after deferred init for NAME completed.

  OK is non-nil on success.  T0/T1 are float-time start/end."
  (let ((status (if ok my/module-status-ok my/module-status-failed)))
    (my/runtime-module-record
     (my/make-module-record
      :name name :status status
      :reason (unless ok my/reason-init-failed)
      :started-at t0 :ended-at t1))
    (my/log-debug "runner" "deferred %s → %s (%.3fs)" name status (- t1 t0))))

;; ---------------------------------------------------------------------------
;; Manifest runner
;; ---------------------------------------------------------------------------

(defun my/runtime-module-run-manifest (manifest &optional label)
  "Run all specs in MANIFEST; return list of status symbols."
  (let ((manifest (my/runtime-manifest-normalize manifest))
        results)
    (when label (my/log-debug "runner" "manifest start: %s" label))
    (dolist (spec manifest)
      (push (my/runtime-module-run-spec spec) results))
    (when label (my/log-debug "runner" "manifest end: %s" label))
    (nreverse results)))

(provide 'runtime-module-runner)
;;; runtime-module-runner.el ends here
