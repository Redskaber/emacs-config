;;; bootstrap-use-package.el --- Ensure use-package -*- lexical-binding: t; -*-

(defun my/bootstrap-use-package-init ()
  "Ensure and configure use-package."
  (unless (package-installed-p 'use-package)
    (unless package-archive-contents
      (package-refresh-contents))
    (package-install 'use-package))

  (require 'use-package)

  ;; Global defaults
  (setq use-package-always-ensure t
        use-package-always-defer t
        use-package-expand-minimally t
        use-package-compute-statistics t
        use-package-enable-imenu-support t))

(provide 'bootstrap-use-package)
