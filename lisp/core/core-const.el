;;; core-const.el --- Core constants -*- lexical-binding: t; -*-

(defconst my/cache-dir (expand-file-name "cache/" user-emacs-directory))
(defconst my/var-dir   (expand-file-name "var/" user-emacs-directory))
(defconst my/etc-dir   (expand-file-name "etc/" user-emacs-directory))
(defconst my/eln-dir   (expand-file-name "eln-cache/" user-emacs-directory))

(provide 'core-const)
