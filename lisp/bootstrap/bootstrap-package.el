;;; bootstrap-package.el --- package.el setup -*- lexical-binding: t; -*-

(require 'package)

(defun my/bootstrap-package-init ()
  "Initialize package.el repositories."
  (setq package-archives
        '(("gnu"   . "https://elpa.gnu.org/packages/")
          ("nongnu" . "https://elpa.nongnu.org/nongnu/")
          ("melpa" . "https://melpa.org/packages/")))
  (setq package-archive-priorities
        '(("gnu" . 30)
          ("nongnu" . 20)
          ("melpa" . 10)))
  (unless package--initialized
    (package-initialize)))

(provide 'bootstrap-package)
