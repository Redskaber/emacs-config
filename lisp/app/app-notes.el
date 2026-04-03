;;; app-notes.el --- Notes and knowledge entrypoints -*- lexical-binding: t; -*-
;;; Commentary:
;;; Org/Markdown oriented note capture and notebook access.
;;; Code:

(require 'core-const)

(defgroup my/app-notes nil
  "Notes and knowledge workflow."
  :group 'applications)

(defcustom my/app-notes-directory (expand-file-name "notes/" my/etc-dir)
  "Root directory for personal notes."
  :type 'directory
  :group 'my/app-notes)

(defcustom my/app-notes-default-file "inbox.org"
  "Default note file name under `my/app-notes-directory'."
  :type 'string
  :group 'my/app-notes)

(defun my/app-notes--ensure-root ()
  "Ensure notes root exists."
  (my/ensure-dir my/app-notes-directory))

(defun my/app-notes-open-inbox ()
  "Open default notes inbox."
  (interactive)
  (my/app-notes--ensure-root)
  (find-file (expand-file-name my/app-notes-default-file
                               my/app-notes-directory)))

(defun my/app-notes-open-root ()
  "Open notes root in Dired."
  (interactive)
  (my/app-notes--ensure-root)
  (dired my/app-notes-directory))

(defun my/app-notes-init ()
  "Initialize notes workflow."
  (global-set-key (kbd "C-c n i") #'my/app-notes-open-inbox)
  (global-set-key (kbd "C-c n d") #'my/app-notes-open-root))

(provide 'app-notes)
;;; app-notes.el ends here
