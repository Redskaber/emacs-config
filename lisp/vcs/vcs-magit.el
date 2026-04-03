;;; vcs-magit.el --- Magit integration -*- lexical-binding: t; -*-
;;; Commentary:
;;; Optional Magit/Forge integration with safe degradation.
;;; Code:

(defgroup my/vcs-magit nil
  "Magit integration."
  :group 'my/vcs)

(defcustom my/vcs-magit-enable-forge nil
  "Whether to enable Forge integration."
  :type 'boolean)

(defcustom my/vcs-magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1
  "Display strategy for Magit buffers."
  :type 'function)

(defun my/vcs-magit-init ()
  "Initialize Magit integration."
  (use-package magit
    :defer t
    :commands (magit-status magit-file-dispatch magit-blame-addition)
    :bind (("C-x g" . magit-status)
           ("C-c v g" . magit-status)
           ("C-c v ." . magit-file-dispatch))
    :init
    (setq magit-display-buffer-function my/vcs-magit-display-buffer-function
          magit-save-repository-buffers 'dontask
          magit-diff-refine-hunk t
          magit-bury-buffer-function #'magit-restore-window-configuration)
    :config
    (when my/vcs-magit-enable-forge
      (use-package forge
        :after magit
        :defer t))))

(provide 'vcs-magit)
;;; vcs-magit.el ends here
