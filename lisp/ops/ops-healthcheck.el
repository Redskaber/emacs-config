;;; ops-healthcheck.el --- Runtime health checks -*- lexical-binding: t; -*-
;;; Commentary:
;;; Environment, executable, and feature sanity checks.
;;; Code:

(defgroup my/ops-healthcheck nil
  "Runtime health checks."
  :group 'my/features)

(defcustom my/ops-healthcheck-executables
  '("git" "rg" "fd")
  "Common executables to verify."
  :type '(repeat string)
  :group 'my/ops-healthcheck)

(defun my/ops-healthcheck--insert-line (label status detail)
  "Insert a healthcheck line."
  (insert (format "%-18s %-8s %s\n" label status detail)))

(defun my/ops-healthcheck-run ()
  "Run basic health checks and show report."
  (interactive)
  (with-current-buffer (get-buffer-create "*my-healthcheck*")
    (erase-buffer)
    (insert "== Runtime ==\n")
    (my/ops-healthcheck--insert-line
     "emacs-version" "OK" emacs-version)
    (my/ops-healthcheck--insert-line
     "system-type" "OK" (symbol-name system-type))
    (my/ops-healthcheck--insert-line
     "native-comp" (if (fboundp 'native-comp-available-p)
                       (if (native-comp-available-p) "OK" "WARN")
                     "N/A")
     "")

    (insert "\n== Executables ==\n")
    (dolist (cmd my/ops-healthcheck-executables)
      (my/ops-healthcheck--insert-line
       cmd
       (if (executable-find cmd) "OK" "MISS")
       (or (executable-find cmd) "")))

    (insert "\n== Features ==\n")
    (dolist (flag '(my/feature-ui
                    my/feature-ux
                    my/feature-editor
                    my/feature-project
                    my/feature-vcs
                    my/feature-prog
                    my/feature-lang
                    my/feature-app
                    my/feature-ops))
      (my/ops-healthcheck--insert-line
       (symbol-name flag)
       (if (and (boundp flag) (symbol-value flag)) "ON" "OFF")
       ""))

    (goto-char (point-min))
    (display-buffer (current-buffer))))

(defun my/ops-healthcheck-init ()
  "Initialize healthcheck workflow."
  (global-set-key (kbd "C-c o h") #'my/ops-healthcheck-run))

(provide 'ops-healthcheck)
;;; ops-healthcheck.el ends here
