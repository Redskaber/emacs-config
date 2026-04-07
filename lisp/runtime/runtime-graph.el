;;; runtime-graph.el --- Stage dependency graph -*- lexical-binding: t; -*-
;;; Code:

(require 'cl-lib)
(require 'runtime-registry)

;; ─────────────────────────────────────────────────────────────────────────────
;; Validation
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-graph--validate-stage-deps ()
  "Validate that all stage deps refer to declared stages and no self-deps."
  (let ((known (my/runtime-stage-names)))
    (dolist (stage known)
      (dolist (dep (my/runtime-stage-after stage))
        (when (eq dep stage)
          (error "Stage %S depends on itself" stage))
        (unless (memq dep known)
          (error "Unknown stage dependency: %S depends on %S" stage dep))))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Cycle finder  (DFS path-based, returns cycle list or nil)
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-graph--find-cycle (nodes after-fn)
  "Return a cycle path (list of nodes) in the DAG defined by AFTER-FN, or nil.
  NODES is the full node list; AFTER-FN maps node → list of predecessors."
  (let ((visited  (make-hash-table :test #'eq))
        (in-stack (make-hash-table :test #'eq))
        cycle)
    (cl-labels
        ((dfs (node path)
           (unless (or cycle (gethash node visited))
             (puthash node t in-stack)
             (dolist (dep (funcall after-fn node))
               (cond
                ((gethash dep in-stack)
                 ;; Found cycle: extract the loop from path
                 (let ((loop-start (memq dep (reverse path))))
                   (setq cycle (append (reverse loop-start) (list dep)))))
                ((not (gethash dep visited))
                 (dfs dep (cons node path)))))
             (remhash node in-stack)
             (puthash node t visited))))
      (dolist (n nodes) (dfs n (list))))
    cycle))

;; ─────────────────────────────────────────────────────────────────────────────
;; Topological sort  (Kahn's algorithm)
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-graph-stage-plan ()
  "Return topologically sorted stage plan.
  Signals a descriptive error if a cycle exists."
  (my/runtime-graph--validate-stage-deps)
  (let* ((nodes    (my/runtime-stage-names))
         ;; Pre-check cycle with path-aware finder for better error message
         (cycle    (my/runtime-graph--find-cycle
                    nodes #'my/runtime-stage-after))
         (_        (when cycle
                     (error "Cycle detected in stage registry: %s"
                            (mapconcat #'symbol-name cycle " → "))))
         ;; Kahn's
         (incoming (make-hash-table :test #'eq))
         (outgoing (make-hash-table :test #'eq))
         (queue    nil)
         (result   nil))
    (dolist (n nodes)
      (puthash n 0   incoming)
      (puthash n nil outgoing))
    (dolist (stage nodes)
      (dolist (dep (my/runtime-stage-after stage))
        (puthash stage (1+ (gethash stage incoming 0)) incoming)
        (puthash dep   (cons stage (gethash dep outgoing)) outgoing)))
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
      ;; Fallback: should have been caught by cycle pre-check
      (error "Cycle detected in stage registry (topo sort incomplete)"))
    result))

(provide 'runtime-graph)
;;; runtime-graph.el ends here
