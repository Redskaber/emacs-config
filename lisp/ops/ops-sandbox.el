;;; ops-sandbox.el --- Development sandbox helpers -*- lexical-binding: t; -*-
;;; Commentary:
;;; Safe reset and iterative development helpers for config hacking.
;;; Code:

(defgroup my/ops-sandbox nil
  "Development sandbox helpers."
  :group 'my/features)

(defun my/ops-sandbox-clear-stages ()
  "Clear all stage sentinels."
  (interactive)
  (my/stage-sentinel-clear)
  (message "[my] cleared all stage sentinels"))

(defun my/ops-sandbox-rerun-init ()
  "Force rerun complete init pipeline."
  (interactive)
  (if (fboundp 'my/init-force-rerun)
      (my/init-force-rerun)
    (user-error "my/init-force-rerun is not available")))

(defun my/ops-sandbox-reload-feature (feature)
  "Unload and require FEATURE again."
  (interactive
   (list (intern (completing-read "Reload feature: " obarray #'featurep t))))
  (when (featurep feature)
    (ignore-errors (unload-feature feature t)))
  (require feature)
  (message "[my] reloaded feature: %s" feature))

(defun my/ops-sandbox-init ()
  "Initialize sandbox helpers."
  (global-set-key (kbd "C-c o x c") #'my/ops-sandbox-clear-stages)
  (global-set-key (kbd "C-c o x r") #'my/ops-sandbox-rerun-init)
  (global-set-key (kbd "C-c o x l") #'my/ops-sandbox-reload-feature))

(provide 'ops-sandbox)
;;; ops-sandbox.el ends here
