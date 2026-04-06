;;; runtime-module-runner.el --- Manifest module executor -*- lexical-binding: t; -*-
;;; Commentary:
;;;  1. Deferred completion loop is closed via observer event (not direct callback).
;;;     my/runtime-module-on-deferred-complete is removed; lifecycle handles it.
;;;  2. Every step transitions through my/lifecycle-transition for the
;;;     authoritative state update.  runtime-module-state is still updated
;;;     (for backward compat reporting) but is derived, not authoritative.
;;;  3. Runner emits my/event-module-run directly for legacy subscribers.
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-feature)
(require 'runtime-manifest)
(require 'runtime-provider)
(require 'runtime-deferred)
(require 'runtime-lifecycle)
(require 'runtime-module-state)

;; ─────────────────────────────────────────────────────────────────────────────
;; Single module execution
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-module-run-spec (spec)
  "Evaluate a single manifest SPEC plist.  Returns module status symbol."
  (let* ((spec     (my/runtime-manifest-normalize-spec spec))
         (provider (my/provider-from-spec spec))
         (name     (my/provider-name      provider))
         (feature  (my/provider-feature   provider))
         (when-g   (my/provider-when-gate provider))
         (after    (my/provider-after     provider))
         (defer    (my/provider-defer     provider)))

    ;; ── Idempotency guard ───────────────────────────────────────────────
    (when (my/runtime-module-find-record name)
      (my/log-debug "runner" "idempotent skip: %s" name)
      (cl-return-from my/runtime-module-run-spec my/reason-idempotent-skip))

    ;; Register in lifecycle as planned
    (my/lifecycle-transition name my/module-status-planned)

    (let ((feature-ok (my/feature-enabled-p feature))
          (when-ok    (my/gate-resolve when-g))
          (deps-ok    (my/runtime-module-deps-satisfied-p after)))

      (cond

       ;; ── :feature gate ────────────────────────────────────────────────
       ((not feature-ok)
        (my/lifecycle-transition name my/module-status-skipped
                                 :reason my/reason-feature-disabled)
        (my/runtime-module-record
         (my/make-module-record
          :name name :status my/module-status-skipped
          :reason my/reason-feature-disabled))
        (my/log-debug "runner" "skip(feature): %s" name)
        my/module-status-skipped)

       ;; ── :when gate ───────────────────────────────────────────────────
       ((not when-ok)
        (my/lifecycle-transition name my/module-status-skipped
                                 :reason my/reason-predicate-failed)
        (my/runtime-module-record
         (my/make-module-record
          :name name :status my/module-status-skipped
          :reason my/reason-predicate-failed))
        (my/log-debug "runner" "skip(when): %s" name)
        my/module-status-skipped)

       ;; ── :after dependency gate ───────────────────────────────────────
       ((not deps-ok)
        (my/lifecycle-transition name my/module-status-skipped
                                 :reason my/reason-dependency-failed)
        (my/runtime-module-record
         (my/make-module-record
          :name name :status my/module-status-skipped
          :reason my/reason-dependency-failed :after after))
        (my/log-debug "runner" "skip(dep): %s after=%S" name after)
        my/module-status-skipped)

       ;; ── load (require) ───────────────────────────────────────────────
       (t
        (my/lifecycle-transition name my/module-status-loading)
        (if (not (my/provider-load provider))
            (progn
              (my/lifecycle-transition name my/module-status-failed
                                       :reason my/reason-require-failed)
              (my/runtime-module-record
               (my/make-module-record
                :name name :status my/module-status-failed
                :reason my/reason-require-failed))
              (my/log-warn "runner" "failed(load): %s" name)
              my/module-status-failed)

          ;; load succeeded
          (my/lifecycle-transition name my/module-status-loaded)

          (cond
           ;; ── deferred ────────────────────────────────────────────────
           (defer
            (let ((init-fn (my/provider-init-fn provider)))
              (my/lifecycle-transition name my/module-status-deferred
                                       :defer defer)
              (my/deferred-schedule name init-fn defer)
              (my/runtime-module-register-deferred-job
               (my/make-deferred-job name defer))
              (my/runtime-module-record
               (my/make-module-record
                :name name :status my/module-status-deferred :defer defer))
              (my/log-debug "runner" "deferred: %s strategy=%S" name defer)
              my/module-status-deferred))

           ;; ── synchronous init ────────────────────────────────────────
           (t
            (let* ((t0     (float-time))
                   (_      (my/lifecycle-transition name my/module-status-running
                                                    :started-at t0))
                   (ok     (my/provider-init provider))
                   (t1     (float-time))
                   (status (if ok my/module-status-ok my/module-status-failed)))
              (my/lifecycle-transition
               name status
               :reason     (unless ok my/reason-init-failed)
               :started-at t0
               :ended-at   t1)
              (my/runtime-module-record
               (my/make-module-record
                :name name :status status
                :reason     (unless ok my/reason-init-failed)
                :started-at t0 :ended-at t1))
              (my/log-debug "runner" "%s: %s (%.3fs)" status name (- t1 t0))
              status)))))))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Manifest runner
;; ─────────────────────────────────────────────────────────────────────────────

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
