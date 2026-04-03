;;; manifest-ops.el --- Operations / diagnostics manifest -*- lexical-binding: t; -*-

(defconst my/ops-modules
  '((:name ops-startup
     :feature my/feature-ops-startup
     :predicate my/feature-ops
     :after prog-core
     :require ops-startup
     :init my/ops-startup-init)

    (:name ops-profiler
     :feature my/feature-ops-profiler
     :predicate my/feature-ops
     :require ops-profiler
     :init my/ops-profiler-init)

    (:name ops-healthcheck
     :feature my/feature-ops-healthcheck
     :predicate my/feature-ops
     :require ops-healthcheck
     :init my/ops-healthcheck-init)

    (:name ops-benchmark
     :feature my/feature-ops-benchmark
     :predicate my/feature-ops
     :require ops-benchmark
     :init my/ops-benchmark-init)

    (:name ops-sandbox
     :feature my/feature-ops-sandbox
     :predicate my/feature-ops
     :require ops-sandbox
     :init my/ops-sandbox-init))
  "Declarative operations module specifications.")

(provide 'manifest-ops)
;;; manifest-ops.el ends here
