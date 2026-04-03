;;; lang-yaml-json-toml.el --- YAML/JSON/TOML adapter -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin glue for data/config file editing.
;;; Code:

(defgroup my/lang-data nil
  "Structured data language adapter."
  :group 'my/lang)

(defcustom my/lang-data-indent-level 2
  "Indentation width for structured data files."
  :type 'integer
  :group 'my/lang-data)

(defun my/lang-data--setup-json ()
  "Configure JSON indentation."
  (setq-local js-indent-level my/lang-data-indent-level))

(defun my/lang-data--setup-yaml ()
  "Configure YAML indentation."
  (when (boundp 'yaml-indent-offset)
    (setq-local yaml-indent-offset my/lang-data-indent-level)))

(defun my/lang-data--hook-json ()
  "Hook for JSON buffers."
  (my/lang-data--setup-json))

(defun my/lang-data--hook-yaml ()
  "Hook for YAML buffers."
  (my/lang-data--setup-yaml))

(defun my/lang-yaml-json-toml-init ()
  "Initialize YAML/JSON/TOML adapter."
  (dolist (hook '(json-mode-hook json-ts-mode-hook))
    (when (boundp hook)
      (add-hook hook #'my/lang-data--hook-json)))
  (dolist (hook '(yaml-mode-hook yaml-ts-mode-hook))
    (when (boundp hook)
      (add-hook hook #'my/lang-data--hook-yaml))))

(provide 'lang-yaml-json-toml)
;;; lang-yaml-json-toml.el ends here
