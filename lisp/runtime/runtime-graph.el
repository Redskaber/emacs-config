;;; runtime-graph.el --- Stage and module dependency graphs -*- lexical-binding: t; -*-
;;; Commentary:
;;;     Split into two clearly separated DAG layers within this file.
;;;     (Full file split into runtime-stage-graph.el / runtime-module-graph.el
;;;      is tracked as a future refactor; this version provides the logical
;;;      separation as the first step.)
;;;
;;;   ─ Part A: Stage graph (coarse — startup stage DAG, Kahn topo-sort)
;;;   ─ Part B: Module graph (fine-grained — per-manifest :after dependency DAG)
;;;             Currently provides validation and cycle detection for modules.
;;;             Full topo-sort of modules within a stage is available via
;;;             my/runtime-module-graph-sort.
;;;
;;; Code:

(require 'cl-lib)
(require 'runtime-registry)

;; ═════════════════════════════════════════════════════════════════════════════
;; Part A — Stage graph
;; ═════════════════════════════════════════════════════════════════════════════

;; ─────────────────────────────────────────────────────────────────────────────
;; Validation
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/stage-graph--validate-deps ()
  "Validate stage deps: no unknown refs, no self-deps."
  (let ((known (my/runtime-stage-names)))
    (dolist (stage known)
      (dolist (dep (my/runtime-stage-after stage))
        (when (eq dep stage)
          (error "Stage %S depends on itself" stage))
        (unless (memq dep known)
          (error "Unknown stage dependency: %S depends on %S" stage dep))))))

;; ─────────────────────────────────────────────────────────────────────────────
;; Cycle finder  (DFS, path-based)
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/graph--find-cycle (nodes after-fn)
  "Return a cycle path (list of nodes) in the DAG, or nil.
  AFTER-FN maps node → list of predecessors (dependencies)."
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
                 (let ((loop-start (memq dep (reverse path))))
                   (setq cycle (append (reverse loop-start) (list dep)))))
                ((not (gethash dep visited))
                 (dfs dep (cons node path)))))
             (remhash node in-stack)
             (puthash node t visited))))
      (dolist (n nodes) (dfs n (list))))
    cycle))

;; ─────────────────────────────────────────────────────────────────────────────
;; Topological sort — Kahn's algorithm
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/stage-graph--topo-sort (nodes after-fn)
  "Kahn's topo-sort over NODES where AFTER-FN gives predecessors.
  Signals error on cycle (pre-checked by caller)."
  (let ((incoming (make-hash-table :test #'eq))
        (outgoing (make-hash-table :test #'eq))
        queue result)
    (dolist (n nodes)
      (puthash n 0   incoming)
      (puthash n nil outgoing))
    (dolist (node nodes)
      (dolist (dep (funcall after-fn node))
        (puthash node (1+ (gethash node incoming 0)) incoming)
        (puthash dep  (cons node (gethash dep outgoing)) outgoing)))
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
    (nreverse result)))

;; ─────────────────────────────────────────────────────────────────────────────
;; Public: Stage plan
;; ─────────────────────────────────────────────────────────────────────────────

(defun my/runtime-graph-stage-plan ()
  "Return topologically sorted stage list.  Signals on cycle."
  (my/stage-graph--validate-deps)
  (let* ((nodes (my/runtime-stage-names))
         (cycle (my/graph--find-cycle nodes #'my/runtime-stage-after)))
    (when cycle
      (error "Cycle detected in stage registry: %s"
             (mapconcat #'symbol-name cycle " → ")))
    (let ((result (my/stage-graph--topo-sort nodes #'my/runtime-stage-after)))
      (unless (= (length result) (length nodes))
        (error "Cycle detected in stage registry (topo sort incomplete)"))
      result)))

;; ═════════════════════════════════════════════════════════════════════════════
;; Part B — Module graph  (fine-grained per-manifest :after DAG)
;; ═════════════════════════════════════════════════════════════════════════════
;;
;; Usage:
;;   (my/runtime-module-graph-validate specs)
;;     → signals on unknown :after refs or cycles within a spec list
;;   (my/runtime-module-graph-sort specs)
;;     → returns specs in dependency order (topo-sorted)
;;
;; specs is a list of normalised manifest spec plists.

(defun my/module-graph--spec-name (spec)
  (plist-get spec :name))

(defun my/module-graph--spec-after (spec all-names)
  "Return :after deps of SPEC that are present in ALL-NAMES.
  Filters out cross-stage deps (not in current spec list)."
  (let ((deps (plist-get spec :after)))
    (cl-remove-if-not (lambda (d) (memq d all-names))
                      (if (listp deps) deps (when deps (list deps))))))

(defun my/runtime-module-graph-validate (specs)
  "Validate :after deps within SPECS (intra-manifest).
  Signals on self-dependency or cycle."
  (let ((all-names (mapcar #'my/module-graph--spec-name specs)))
    ;; Self-dep check
    (dolist (spec specs)
      (let ((name  (my/module-graph--spec-name spec))
            (after (plist-get spec :after)))
        (when (memq name (if (listp after) after (when after (list after))))
          (error "Module %S depends on itself" name))))
    ;; Cycle check
    (let ((cycle (my/graph--find-cycle
                  all-names
                  (lambda (name)
                    (let ((spec (cl-find name specs
                                         :key #'my/module-graph--spec-name)))
                      (when spec
                        (my/module-graph--spec-after spec all-names)))))))
      (when cycle
        (error "Cycle detected in module :after deps: %s"
               (mapconcat #'symbol-name cycle " → "))))))

(defun my/runtime-module-graph-sort (specs)
  "Return SPECS sorted in :after dependency order (topo-sort).
  Only intra-list deps are considered; cross-stage deps are ignored."
  (my/runtime-module-graph-validate specs)
  (let* ((all-names (mapcar #'my/module-graph--spec-name specs))
         (name->spec (let ((h (make-hash-table :test #'eq)))
                       (dolist (s specs) (puthash (my/module-graph--spec-name s) s h))
                       h))
         (sorted-names
          (my/stage-graph--topo-sort
           all-names
           (lambda (name)
             (let ((spec (gethash name name->spec)))
               (when spec (my/module-graph--spec-after spec all-names)))))))
    (mapcar (lambda (n) (gethash n name->spec)) sorted-names)))

(provide 'runtime-graph)
;;; runtime-graph.el ends here
