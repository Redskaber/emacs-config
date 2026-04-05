;;; runtime-context.el --- Centralised runtime context -*- lexical-binding: t; -*-
;;; Commentary:
;;; A single plist that accumulates runtime-wide facts:
;;; - resolved capabilities (gui, os, native-comp …)
;;; - active profile name
;;; - phase (bootstrap / kernel / stages / post-init / ready)
;;; - user-visible health summary
;;;
;;; All runtime subsystems read/write through my/ctx-get / my/ctx-set.
;;; This replaces the pattern of querying my/gui-p, my/os-linux-p etc. at
;;; arbitrary call sites – instead callers read :gui from the context.
;;; Code:

(require 'kernel-logging)

(defvar my/runtime-context (make-hash-table :test #'eq)
  "Centralised runtime context table.
Keys are keyword symbols, values are arbitrary Lisp objects.")

;; ---------------------------------------------------------------------------
;; Accessors
;; ---------------------------------------------------------------------------

(defun my/ctx-get (key &optional default)
  "Return KEY from runtime context, or DEFAULT."
  (let ((v (gethash key my/runtime-context :__missing__)))
    (if (eq v :__missing__) default v)))

(defun my/ctx-set (key value)
  "Set KEY to VALUE in runtime context.  Return VALUE."
  (puthash key value my/runtime-context)
  value)

(defun my/ctx-update (key fn &optional default)
  "Apply FN to current value of KEY (or DEFAULT) and store result."
  (my/ctx-set key (funcall fn (my/ctx-get key default))))

(defun my/ctx-snapshot ()
  "Return a snapshot of the context as an alist."
  (let (pairs)
    (maphash (lambda (k v) (push (cons k v) pairs))
             my/runtime-context)
    (sort pairs (lambda (a b) (string< (symbol-name (car a))
                                       (symbol-name (car b)))))))

;; ---------------------------------------------------------------------------
;; Phase management
;; ---------------------------------------------------------------------------

(defconst my/ctx-phases
  '(bootstrap platform kernel stages post-init ready)
  "Ordered list of startup phases.")

(defun my/ctx-phase ()
  "Return current startup phase keyword."
  (my/ctx-get :phase 'bootstrap))

(defun my/ctx-set-phase (phase)
  "Advance startup to PHASE.  Emits a log line."
  (my/log "[ctx] phase: %s → %s" (my/ctx-phase) phase)
  (my/ctx-set :phase phase))

;; ---------------------------------------------------------------------------
;; Capability helpers
;; ---------------------------------------------------------------------------

(defun my/ctx-capability-p (cap)
  "Return non-nil when runtime capability CAP is set."
  (my/ctx-get cap nil))

(defun my/ctx-declare-capabilities ()
  "Populate capability keys from current Emacs environment.
Called once during kernel init after platform detection."
  (my/ctx-set :gui           (display-graphic-p))
  (my/ctx-set :tty           (not (display-graphic-p)))
  (my/ctx-set :os-linux      (eq system-type 'gnu/linux))
  (my/ctx-set :os-macos      (eq system-type 'darwin))
  (my/ctx-set :os-windows    (memq system-type '(windows-nt ms-dos cygwin)))
  (my/ctx-set :native-comp   (featurep 'native-compile))
  (my/ctx-set :treesit       (and (fboundp 'treesit-available-p)
                                  (treesit-available-p)))
  (my/ctx-set :wayland       (and (eq system-type 'gnu/linux)
                                  (string= (or (getenv "XDG_SESSION_TYPE") "")
                                           "wayland")))
  (my/log "[ctx] capabilities declared"))

;; ---------------------------------------------------------------------------
;; Health summary
;; ---------------------------------------------------------------------------

(defun my/ctx-record-health (stage status)
  "Append STAGE STATUS pair to :health-log in context."
  (my/ctx-update :health-log
                 (lambda (log) (append log (list (cons stage status))))
                 nil))

(defun my/ctx-health-summary ()
  "Return alist of (stage . status) pairs."
  (my/ctx-get :health-log nil))

;; ---------------------------------------------------------------------------
;; Init
;; ---------------------------------------------------------------------------

(defun my/runtime-context-init ()
  "Initialise runtime context subsystem."
  (clrhash my/runtime-context)
  (my/ctx-set :phase 'bootstrap)
  (my/log "[ctx] context initialised"))

(provide 'runtime-context)
;;; runtime-context.el ends here
