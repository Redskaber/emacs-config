;;; app-rss.el --- RSS / feed reading workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Optional Elfeed integration as a lightweight reader app.
;;; Code:

(defgroup my/app-rss nil
  "RSS and feed reading."
  :group 'applications)

(defcustom my/app-rss-enable-elfeed t
  "Whether to enable Elfeed integration."
  :type 'boolean
  :group 'my/app-rss)

(defun my/app-rss-open ()
  "Open RSS reader."
  (interactive)
  (if (fboundp 'elfeed)
      (elfeed)
    (user-error "Elfeed is not available")))

(defun my/app-rss-init ()
  "Initialize RSS workflow."
  (when my/app-rss-enable-elfeed
    (use-package elfeed
      :defer t
      :commands (elfeed)))
  (global-set-key (kbd "C-c r") #'my/app-rss-open))

(provide 'app-rss)
;;; app-rss.el ends here
