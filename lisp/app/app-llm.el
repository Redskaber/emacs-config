;;; app-llm.el --- General LLM application workflow -*- lexical-binding: t; -*-
;;; Commentary:
;;; Vendor-neutral LLM app entrypoints for chat, explain, and rewrite tasks.
;;; Code:

(defgroup my/app-llm nil
  "General LLM application workflow."
  :group 'applications)

(defcustom my/app-llm-preferred-backend 'gptel
  "Preferred general-purpose LLM backend."
  :type '(choice (const none)
                 (const gptel)
                 (const aider))
  :group 'my/app-llm)

(defun my/app-llm-chat ()
  "Open preferred LLM chat backend."
  (interactive)
  (pcase my/app-llm-preferred-backend
    ('gptel
     (if (fboundp 'gptel)
         (call-interactively #'gptel)
       (user-error "gptel is not available")))
    ('aider
     (if (fboundp 'aidermacs-transient-menu)
         (call-interactively #'aidermacs-transient-menu)
       (user-error "aidermacs is not available")))
    (_
     (user-error "No available LLM backend configured"))))

(defun my/app-llm-init ()
  "Initialize general LLM workflow."
  (use-package gptel
    :defer t
    :commands (gptel))
  (use-package aidermacs
    :defer t
    :commands (aidermacs-transient-menu))
  (global-set-key (kbd "C-c a c") #'my/app-llm-chat))

(provide 'app-llm)
;;; app-llm.el ends here
