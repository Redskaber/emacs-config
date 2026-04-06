;;; runtime-graph.el --- Stage dependency graph -*- lexical-binding: t; -*-
;;; Commentary:
;;; Topological planning over stage registry.
;;; Code:

(require 'cl-lib)
(require 'runtime-registry)

(defun my/runtime-graph--validate-stage-deps ()
  "Validate all stage deps refer to declared stages."
  (let ((known (my/runtime-stage-names)))
    (dolist (stage known)
      (dolist (dep (my/runtime-stage-after stage))
        (unless (memq dep known)
          (error "Unknown stage dependency: %S depends on %S" stage dep))))))

(defun my/runtime-graph-stage-plan ()
  "Return topologically sorted stage plan.  Signals error on cycles."
  (my/runtime-graph--validate-stage-deps)
  (let* ((nodes    (my/runtime-stage-names))
         (incoming (make-hash-table :test #'eq))
         (outgoing (make-hash-table :test #'eq))
         (queue nil)
         (result nil))
    (dolist (n nodes)
      (puthash n 0 incoming)
      (puthash n nil outgoing))
    (dolist (stage nodes)
      (dolist (dep (my/runtime-stage-after stage))
        (puthash stage (1+ (gethash stage incoming 0)) incoming)
        (puthash dep (cons stage (gethash dep outgoing)) outgoing)))
    (dolist (n nodes)
      (when (= 0 (gethash n incoming 0))
        (push n queue)))
    (setq queue (nreverse queue))
    (while queue
      (let ((n (pop queue)))
        (push n result)
        (dolist (m (nreverse (gethash n outgoing)))
          (puthash m (1- (gethash m incoming)) incoming)
          (when (= 0 (gethash m incoming))
            (setq queue (append queue (list m)))))))
    (setq result (nreverse result))
    (unless (= (length result) (length nodes))
      (error "Cycle detected in stage registry"))
    result))

(provide 'runtime-graph)
;;; runtime-graph.el ends here
