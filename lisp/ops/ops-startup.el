;;; ops-startup.el --- Startup observability -*- lexical-binding: t; -*-
;;; Commentary:
;;; Startup summary, timing visibility, and stage inspection.
;;; Code:

(defgroup my/ops-startup nil
  "Startup observability."
  :group 'my/features)

(defun my/ops-startup-summary ()
  "Display startup summary in echo area."
  (interactive)
  (let* ((mod (my/runtime-module-summary))
         (total (plist-get mod :total))
         (ok (plist-get mod :ok))
         (skipped (plist-get mod :skipped))
         (deferred (plist-get mod :deferred))
         (failed (plist-get mod :failed)))
    (message "[my] startup: total=%d ok=%d skipped=%d deferred=%d failed=%d"
             total ok skipped deferred failed)))

(defun my/ops-startup-stage-report ()
  "Show stage sentinel report in a temporary buffer."
  (interactive)
  (with-current-buffer (get-buffer-create "*my-stage-report*")
    (erase-buffer)
    (insert (format "%-12s %-14s %s\n" "Stage" "Status" "Detail"))
    (insert (make-string 72 ?-))
    (insert "\n")
    (maphash
     (lambda (stage data)
       (insert (format "%-12s %-14s %S\n"
                       stage
                       (plist-get data :status)
                       (plist-get data :detail))))
     my/stage-sentinels)
    (goto-char (point-min))
    (display-buffer (current-buffer))))

(defun my/ops-startup-init ()
  "Initialize startup observability."
  (add-hook 'emacs-startup-hook #'my/ops-startup-summary)
  (global-set-key (kbd "C-c o s") #'my/ops-startup-summary)
  (global-set-key (kbd "C-c o S") #'my/ops-startup-stage-report))

(provide 'ops-startup)
;;; ops-startup.el ends here
