;;; runtime-doctor.el --- Module explainability layer -*- lexical-binding: t; -*-
;;; Commentary:
;;;     - Evidence-based diagnosis: gate-evidence, when-evidence, etc.
;;;       Record enrichment happens via domain event subscriptions.
;;;     - Subscribes to runtime domain events to build evidence chains
;;;     - reason-code + reason-data structure (partial — kept minimal
;;;       to avoid bloating the module; evidence is stored in :data plist)
;;;
;;;  Public API
;;;  ──────────
;;;   (my/doctor-explain NAME)
;;;   (my/doctor-explain-interactive)
;;;   (my/doctor-module-report)
;;;   (my/doctor-failed-modules)
;;;   (my/doctor-slow-modules &optional N)
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-module-state)
(require 'runtime-lifecycle)
(require 'runtime-observer)

;; ─────────────────────────────────────────────────────────────────────────────
;; Evidence store
;; ─────────────────────────────────────────────────────────────────────────────
;; Keyed by module-name-symbol.  Each entry is a plist of evidence fields:
;;   :gate-evidence        — feature gate value at evaluation time
;;   :when-evidence        — :when predicate result
;;   :dependency-evidence  — list of (dep . satisfied?) pairs
;;   :require-evidence     — require result / error
;;   :trigger-evidence     — deferred trigger kind + data

(defvar my/doctor--evidence (make-hash-table :test #'eq)
  "Map module-name → evidence plist.")

(defun my/doctor--evidence-get (name)
  (gethash name my/doctor--evidence))

(defun my/doctor--evidence-put (name key value)
  "Set evidence KEY to VALUE for module NAME."
  (let ((ev (or (gethash name my/doctor--evidence) nil)))
    (puthash name (plist-put ev key value) my/doctor--evidence)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Domain event subscriptions for evidence collection
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/doctor--on-module-skipped (payload)
  (let ((name   (plist-get payload :name))
        (reason (plist-get payload :reason)))
    (my/doctor--evidence-put name :skip-reason reason)))

(defun my/doctor--on-module-started (payload)
  (let ((name (plist-get payload :name)))
    (my/doctor--evidence-put name :started-at (plist-get payload :started-at))))

(defun my/doctor--on-module-failed (payload)
  (let ((name   (plist-get payload :name))
        (reason (plist-get payload :reason)))
    (my/doctor--evidence-put name :fail-reason reason)))

(defun my/doctor--on-module-deferred (payload)
  (let ((name  (plist-get payload :name))
        (defer (plist-get payload :defer)))
    (my/doctor--evidence-put name :trigger-evidence defer)))

(defun my/doctor--on-deferred-complete (payload)
  (let ((name    (plist-get payload :name))
        (trigger (plist-get payload :trigger))
        (tdata   (plist-get payload :trigger-data)))
    (my/doctor--evidence-put name :trigger-kind trigger)
    (my/doctor--evidence-put name :trigger-data tdata)))

(defun my/doctor--install-subscriptions ()
  "Subscribe to domain events to build evidence chains."
  (my/observer-subscribe my/event-runtime-module-skipped
                         'my/doctor--skipped
                         #'my/doctor--on-module-skipped
                         :priority 80)
  (my/observer-subscribe my/event-runtime-module-started
                         'my/doctor--started
                         #'my/doctor--on-module-started
                         :priority 80)
  (my/observer-subscribe my/event-runtime-module-failed
                         'my/doctor--failed
                         #'my/doctor--on-module-failed
                         :priority 80)
  (my/observer-subscribe my/event-runtime-module-deferred
                         'my/doctor--deferred
                         #'my/doctor--on-module-deferred
                         :priority 80)
  (my/observer-subscribe my/event-runtime-deferred-complete
                         'my/doctor--deferred-complete
                         #'my/doctor--on-deferred-complete
                         :priority 80))

;; ─────────────────────────────────────────────────────────────────────────────
;; Explain helpers
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/doctor--reason-string (reason)
  (pcase reason
    (:feature-disabled  "feature flag was nil")
    (:predicate-failed  ":when condition evaluated nil")
    (:dependency-failed ":after dependency not satisfied")
    (:require-failed    "(require …) signalled an error")
    (:init-failed       ":init function signalled an error")
    (:already-done      "stage already completed in this session")
    (:idempotent-skip   "record already exists (idempotency guard)")
    (:cancelled         "deferred init was explicitly cancelled")
    (_                  (if reason (format "%S" reason) "none"))))

(defun my/doctor--duration-ms (record)
  (let ((t0 (my/module-record-started-at record))
        (t1 (my/module-record-ended-at   record)))
    (when (and t0 t1)
      (* 1000 (- t1 t0)))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Explain a single module
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/doctor-explain (name)
  "Return formatted explanation string for module NAME."
  (let* ((record   (my/runtime-module-find-record name))
         (history  (my/runtime-module-history name))
         (evidence (my/doctor--evidence-get name)))
    (if (null record)
        (format "Module %S: no record found (never evaluated or unknown name)" name)
      (with-output-to-string
        (princ (format "Module: %s\n" name))
        (princ (format "Status: %s\n" (my/module-record-status record)))
        (let ((reason (my/module-record-reason record)))
          (when reason
            (princ (format "Reason: %s\n" (my/doctor--reason-string reason)))))
        (let ((dur (my/doctor--duration-ms record)))
          (when dur
            (princ (format "Duration: %.1f ms\n" dur))))
        (let ((after (my/module-record-after record)))
          (when after
            (princ (format "Dependencies (:after): %S\n" after))))
        (let ((defer (my/module-record-defer record)))
          (when defer
            (princ (format "Defer strategy: %S\n" defer))))
        ;; Evidence section
        (when evidence
          (princ "\nEvidence:\n")
          (when-let ((tr (plist-get evidence :trigger-kind)))
            (princ (format "  trigger:      %s  data=%S\n"
                           tr (plist-get evidence :trigger-data))))
          (when-let ((sr (plist-get evidence :skip-reason)))
            (princ (format "  skip-reason:  %s\n" (my/doctor--reason-string sr))))
          (when-let ((fr (plist-get evidence :fail-reason)))
            (princ (format "  fail-reason:  %s\n" (my/doctor--reason-string fr)))))
        ;; Lifecycle transitions
        (when (> (length history) 1)
          (princ "\nLifecycle transitions:\n")
          (dolist (rec history)
            (let ((ts (my/module-record-started-at rec)))
              (princ (format "  %s%s\n"
                             (my/module-record-status rec)
                             (if ts (format " (t=%.3f)" ts) ""))))))))))

(defun my/doctor-explain-interactive ()
  "Interactively explain a module."
  (interactive)
  (let* ((names (mapcar (lambda (pair) (symbol-name (car pair)))
                        (my/lifecycle-snapshot)))
         (choice (completing-read "Explain module: " names nil t))
         (sym    (intern choice))
         (explanation (my/doctor-explain sym)))
    (message "%s" explanation)
    (with-current-buffer (get-buffer-create "*module-doctor*")
      (erase-buffer)
      (insert explanation)
      (display-buffer (current-buffer)))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Aggregate reports
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/doctor-failed-modules ()
  "Return alist of (name . record) for all failed modules."
  (let (failed)
    (dolist (pair (my/lifecycle-snapshot))
      (when (eq (my/module-record-status (cdr pair)) my/module-status-failed)
        (push pair failed)))
    (nreverse failed)))

(defun my/doctor-slow-modules (&optional n)
  "Return top N (default 10) modules sorted by init time descending."
  (let ((n (or n 10)) timed)
    (dolist (pair (my/lifecycle-snapshot))
      (let ((dur (my/doctor--duration-ms (cdr pair))))
        (when dur (push (cons (car pair) dur) timed))))
    (seq-take (sort timed (lambda (a b) (> (cdr a) (cdr b)))) n)))

(defun my/doctor-module-report ()
  "Log a one-liner status for every known module."
  (my/log-info "doctor" "=== module status report ===")
  (dolist (pair (my/lifecycle-snapshot))
    (let* ((name   (car pair))
           (rec    (cdr pair))
           (status (my/module-record-status rec))
           (dur    (my/doctor--duration-ms  rec))
           (reason (my/module-record-reason rec)))
      (my/log-info "doctor"
                   "  %-40s %-10s %s%s"
                   name status
                   (if dur (format "(%.1fms)" dur) "")
                   (if reason (format " [%s]" (my/doctor--reason-string reason)) "")))))

(defun my/doctor-print-slow-modules (&optional n)
  "Log top N slowest modules."
  (let ((slow (my/doctor-slow-modules n)))
    (my/log-info "doctor" "=== top %d slowest modules ===" (length slow))
    (dolist (pair slow)
      (my/log-info "doctor" "  %-40s %.1fms" (car pair) (cdr pair)))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Init
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-doctor-init ()
  "Initialise doctor/explainability layer."
  (clrhash my/doctor--evidence)
  (my/doctor--install-subscriptions)
  (my/log-info "doctor" "module doctor ready (evidence-based diagnostics active)"))

(provide 'runtime-doctor)
;;; runtime-doctor.el ends here
