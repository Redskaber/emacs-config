;;; prog-ai.el --- AI-assisted programming glue -*- lexical-binding: t; -*-
;;; Commentary:
;;; Thin integration layer for AI coding tools. Keep vendor-neutral.
;;; Code:

(defgroup my/prog-ai nil
  "AI-assisted programming."
  :group 'my/prog)

(defcustom my/prog-ai-enable t
  "Whether to enable AI coding integrations."
  :type 'boolean)

(defcustom my/prog-ai-preferred-backend 'none
  "Preferred AI backend."
  :type '(choice (const none)
                 (const copilot)
                 (const codeium)
                 (const aider)
                 (const gptel)))

(defun my/prog-ai-chat ()
  "Open preferred AI coding/chat backend."
  (interactive)
  (pcase my/prog-ai-preferred-backend
    ('gptel
     (if (fboundp 'gptel)
         (call-interactively #'gptel)
       (user-error "gptel is not available")))
    ('aider
     (if (fboundp 'aidermacs-transient-menu)
         (call-interactively #'aidermacs-transient-menu)
       (user-error "aidermacs is not available")))
    (_
     (user-error "No available AI backend configured"))))

(defun my/prog-ai--setup-gptel ()
  "Optional gptel integration."
  (use-package gptel
    :defer t
    :commands (gptel)))

(defun my/prog-ai--setup-aider ()
  "Optional aidermacs integration."
  (use-package aidermacs
    :defer t
    :commands (aidermacs-transient-menu)))

(defun my/prog-ai--setup-copilot ()
  "Optional copilot integration."
  (use-package copilot
    :defer t
    :commands (copilot-mode)
    :hook (prog-mode . copilot-mode)))

(defun my/prog-ai-init ()
  "Initialize AI-assisted programming glue."
  (when my/prog-ai-enable
    (my/prog-ai--setup-gptel)
    (my/prog-ai--setup-aider)
    (my/prog-ai--setup-copilot)
    (global-set-key (kbd "C-c a i") #'my/prog-ai-chat)))

(provide 'prog-ai)
;;; prog-ai.el ends here
