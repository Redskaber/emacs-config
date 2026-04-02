;;; ui-modeline.el --- Modeline system -*- lexical-binding: t; -*-

(defgroup my/ui-modeline nil
  "Modeline system."
  :group 'my/features)

(defcustom my/ui-modeline-enable t
  "Whether to enable enhanced modeline."
  :type 'boolean
  :group 'my/ui-modeline)

(defun my/ui-modeline-init ()
  "Initialize modeline system."
  (when my/ui-modeline-enable
    (use-package doom-modeline
      :demand t
      :init
      (setq doom-modeline-height 28
            doom-modeline-bar-width 4
            doom-modeline-buffer-file-name-style 'truncate-upto-project
            doom-modeline-buffer-encoding nil
            doom-modeline-minor-modes nil
            doom-modeline-project-detection 'project
            doom-modeline-icon (display-graphic-p)
            doom-modeline-modal nil
            doom-modeline-time nil
            doom-modeline-vcs-max-length 18)
      :config
      (doom-modeline-mode 1)
      (message "[ui:modeline] doom-modeline enabled"))))

(provide 'ui-modeline)
