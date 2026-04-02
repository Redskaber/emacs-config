;;; core-const.el --- Core constants -*- lexical-binding: t; -*-

(defconst my/lisp-dir  (expand-file-name "lisp/" user-emacs-directory)
  "Root directory for local Lisp modules.")

(defconst my/cache-dir (expand-file-name "cache/" user-emacs-directory)
  "Directory for transient caches.")

(defconst my/var-dir   (expand-file-name "var/" user-emacs-directory)
  "Directory for persistent runtime state.")

(defconst my/etc-dir   (expand-file-name "etc/" user-emacs-directory)
  "Directory for local templates, dictionaries, scripts, etc.")

(defconst my/eln-dir   (expand-file-name "eln-cache/" user-emacs-directory)
  "Directory for native compilation artifacts.")

(defconst my/lisp-subdirs
  '("bootstrap"
    "platform"
    "core"
    "ui"
    "ux"
    "editor"
    "project"
    "vcs"
    "prog"
    "lang"
    "app"
    "ops")
  "Managed subdirectories under `my/lisp-dir'.")

(provide 'core-const)
