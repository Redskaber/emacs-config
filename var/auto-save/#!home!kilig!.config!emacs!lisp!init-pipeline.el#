;;; init-pipeline.el --- Top-level initialization pipeline -*- lexical-binding: t; -*-
;;; Commentary:
;;; Orchestrates startup in explicit stages via declarative manifests.
;;; Code:

(require 'bootstrap-profile)
(require 'bootstrap-core)
(require 'bootstrap-package)
(require 'bootstrap-use-package)

(require 'platform-core)

(require 'core-const)
(require 'core-lib)
(require 'core-paths)
(require 'core-feature-flags)
(require 'core-env)
(require 'core-encoding)
(require 'core-performance)
(require 'core-state)
(require 'core-hooks)
(require 'core-logging)
(require 'core-errors)
(require 'core-keymap)
(require 'core-startup)

(require 'manifest-ui)
(require 'manifest-ux)
(require 'manifest-editor)

(defvar my/project-modules nil
  "Declarative module specifications for project layer.")

(defvar my/vcs-modules nil
  "Declarative module specifications for VCS layer.")

(defvar my/prog-modules nil
  "Declarative module specifications for programming layer.")

(defvar my/lang-modules nil
  "Declarative module specifications for language layer.")

(defvar my/app-modules nil
  "Declarative module specifications for app layer.")

(defvar my/ops-modules nil
  "Declarative module specifications for ops layer.")

(defun my/module--feature-enabled-p (feature)
  "Return non-nil when FEATURE gate allows module activation.
FEATURE may be nil or a symbol bound to a boolean variable."
  (cond
   ((null feature) t)
   ((and (symbolp feature) (boundp feature))
    (symbol-value feature))
   (t nil)))

(defun my/module--predicate-p (predicate)
  "Return non-nil when PREDICATE passes.
PREDICATE may be nil, a symbol variable, or a function symbol / lambda."
  (cond
   ((null predicate) t)
   ((and (symbolp predicate)
         (boundp predicate)
         (not (fboundp predicate)))
    (symbol-value predicate))
   ((functionp predicate)
    (funcall predicate))
   ((and (symbolp predicate) (fboundp predicate))
    (funcall predicate))
   (t nil)))

(defun my/module-enabled-p (spec)
  "Return non-nil if module SPEC should be enabled."
  (let ((feature   (plist-get spec :feature))
        (predicate (plist-get spec :predicate)))
    (and (my/module--feature-enabled-p feature)
         (my/module--predicate-p predicate))))

(defun my/module-name (spec)
  "Return normalized module name string from SPEC."
  (let ((name (plist-get spec :name)))
    (cond
     ((symbolp name) (symbol-name name))
     ((stringp name) name)
     (t "unnamed-module"))))

(defun my/run-module (spec)
  "Load and initialize module SPEC safely.

  SPEC supports:
  :name       Symbol or string, human-readable module name.
  :feature    Optional feature flag variable symbol.
  :predicate  Optional extra gate, variable or callable.
  :require    Feature symbol to require.
  :init       Initialization function."
  (let ((name    (my/module-name spec))
        (req     (plist-get spec :require))
        (init-fn (plist-get spec :init)))
    (when (my/module-enabled-p spec)
      (my/with-safe-init name
        (when req
          (require req))
        (when init-fn
          (if (functionp init-fn)
              (funcall init-fn)
            (my/log-warn "Init function not callable for module: %s" name)))))))

(defun my/run-modules (stage modules)
  "Run MODULES within STAGE profiling boundary."
  (my/profile-stage stage
    (dolist (spec modules)
      (my/run-module spec))))

(defun my/init-run ()
  "Run the Emacs initialization pipeline."
  (interactive)

  (my/profile-stage "bootstrap"
    (my/bootstrap-core-init)
    (my/bootstrap-package-init)
    (my/bootstrap-use-package-init))

  (my/profile-stage "platform"
    (my/platform-init))

  (my/profile-stage "core"
    (my/core-paths-init)
    (my/core-feature-flags-init)
    (my/core-env-init)
    (my/core-encoding-init)
    (my/core-performance-init)
    (my/core-state-init)
    (my/core-hooks-init)
    (my/core-logging-init)
    (my/core-errors-init)
    (my/core-keymap-init)
    (my/core-startup-init))

  (my/run-modules "ui" my/ui-modules)
  (my/run-modules "ux" my/ux-modules)
  (my/run-modules "editor" my/editor-modules)

  ;; Reserved future stages (safe to keep empty for now).
  (my/run-modules "project" my/project-modules)
  (my/run-modules "vcs" my/vcs-modules)
  (my/run-modules "prog" my/prog-modules)
  (my/run-modules "lang" my/lang-modules)
  (my/run-modules "app" my/app-modules)
  (my/run-modules "ops" my/ops-modules)

  (my/profile-stage "post-init"
    (my/startup-finalize)))

(provide 'init-pipeline)
;;; init-pipeline.el ends here
