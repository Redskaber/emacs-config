;;; runtime-doctor.el --- Module explainability layer -*- lexical-binding: t; -*-
;;; Commentary:
;;; Answers Principle 6 from the README:
;;;    "Any module should be able to answer:
;;;     - Why did it run?
;;;     - Why didn't it run?
;;;     - Why was it deferred?
;;;     - Why did it fail?
;;;     - How long did it take?
;;;     - What is its dependency chain?"
;;;
;;;  Public API
;;;  ──────────
;;;   (my/doctor-explain NAME)           → formatted string
;;;   (my/doctor-explain-interactive)    → completing-read + *Messages*
;;;   (my/doctor-module-report)          → log all modules with status
;;;   (my/doctor-failed-modules)         → list of (name . record) for failures
;;;   (my/doctor-slow-modules &optional N) → top-N by init time
;;;
;;; Code:

(require 'cl-lib)
(require 'kernel-logging)
(require 'runtime-types)
(require 'runtime-module-state)
(require 'runtime-lifecycle)

;; ─────────────────────────────────────────────────────────────────────────────
;; Explain a single module
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/doctor--reason-string (reason)
  "Return human-readable string for REASON keyword."
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
  "Return duration in milliseconds for RECORD, or nil."
  (let ((t0 (my/module-record-started-at record))
        (t1 (my/module-record-ended-at   record)))
    (when (and t0 t1)
      (* 1000 (- t1 t0)))))

(defun my/doctor-explain (name)
  "Return formatted explanation string for module NAME.
  Includes full lifecycle history via :supersedes chain."
  (let* ((record  (my/runtime-module-find-record name))
         (history (my/runtime-module-history name)))
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
        ;; Show lifecycle transitions if there is a history
        (when (> (length history) 1)
          (princ "\nLifecycle transitions:\n")
          (dolist (rec history)
            (let ((ts (my/module-record-started-at rec)))
              (princ (format "  %s%s\n"
                             (my/module-record-status rec)
                             (if ts (format " (t=%.3f)" ts) ""))))))))))

(defun my/doctor-explain-interactive ()
  "Interactively explain a module's execution history."
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
  (let ((n (or n 10))
        timed)
    (dolist (pair (my/lifecycle-snapshot))
      (let ((dur (my/doctor--duration-ms (cdr pair))))
        (when dur (push (cons (car pair) dur) timed))))
    (setq timed (sort timed (lambda (a b) (> (cdr a) (cdr b)))))
    (seq-take timed n)))

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
                   name
                   status
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
  (my/log-info "doctor" "module doctor ready"))

(provide 'runtime-doctor)
;;; runtime-doctor.el ends here
