;;; runtime-types.el --- Shared runtime type contracts -*- lexical-binding: t; -*-
;;; Commentary:
;;; Defines the canonical status symbols and plist shapes used by
;;; runtime-module-state, runtime-stage-state, and the observer bus.
;;; All runtime code must use these constants instead of bare symbols.
;;; Code:

;; ---------------------------------------------------------------------------
;; Module status symbols
;; ---------------------------------------------------------------------------

(defconst my/module-status-pending   'pending
  "Module registered but not yet evaluated.")

(defconst my/module-status-ok        'ok
  "Module initialised successfully.")

(defconst my/module-status-deferred  'deferred
  "Module scheduled for deferred initialisation.")

(defconst my/module-status-failed    'failed
  "Module initialisation failed.")

(defconst my/module-status-skipped   'skipped
  "Module was skipped (feature gate / predicate / dependency).")

;; ---------------------------------------------------------------------------
;; Stage status symbols
;; ---------------------------------------------------------------------------

(defconst my/stage-status-pending   'pending
  "Stage not yet started.")

(defconst my/stage-status-running   'running
  "Stage currently executing.")

(defconst my/stage-status-ok        'ok
  "Stage completed; all modules ok or deferred.")

(defconst my/stage-status-degraded  'degraded
  "Stage completed but one or more modules failed.")

(defconst my/stage-status-failed    'failed
  "Stage could not complete (dependency failure or internal error).")

(defconst my/stage-status-skipped   'skipped
  "Stage was skipped by feature gate or dependency.")

;; ---------------------------------------------------------------------------
;; Reason symbols for skip/fail
;; ---------------------------------------------------------------------------

(defconst my/reason-feature-disabled    :feature-disabled)
(defconst my/reason-predicate-failed    :predicate-failed)
(defconst my/reason-dependency-failed   :dependency-failed)
(defconst my/reason-require-failed      :require-failed)
(defconst my/reason-init-failed         :init-failed)
(defconst my/reason-already-done        :already-done)

;; ---------------------------------------------------------------------------
;; Module record shape (documentation only – Elisp has no types)
;;
;; (:name     SYMBOL
;;  :status   STATUS-SYMBOL
;;  :reason   REASON-SYMBOL | nil
;;  :after    LIST | nil
;;  :defer    DEFER-SPEC | nil
;;  :started-at TIME | nil
;;  :ended-at   TIME | nil)
;;
;; Stage record shape:
;; (:status    STATUS-SYMBOL
;;  :started-at TIME | nil
;;  :ended-at   TIME | nil
;;  :detail     ANY | nil)
;; ---------------------------------------------------------------------------

(defun my/runtime-types-init ()
  "No-op; types are constants loaded at require time."
  t)

(provide 'runtime-types)
;;; runtime-types.el ends here
