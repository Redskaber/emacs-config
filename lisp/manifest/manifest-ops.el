;;; manifest-ops.el --- Operations / diagnostics manifest  -*- lexical-binding: t; -*-
;;; Code:

(defconst my/ops-modules
  '((:name ops-startup
     :description "Startup time measurement and reporting."
     :tags (:ops :startup)
     :feature my/feature-ops-startup
     :after prog-core
     :require ops-startup
     :init my/ops-startup-init)

    (:name ops-profiler
     :description "Runtime profiler integration."
     :tags (:ops :profiler)
     :feature my/feature-ops-profiler
     :require ops-profiler
     :init my/ops-profiler-init)

    (:name ops-healthcheck
     :description "System health and configuration status checks."
     :tags (:ops :health)
     :feature my/feature-ops-healthcheck
     :require ops-healthcheck
     :init my/ops-healthcheck-init)

    (:name ops-benchmark
     :description "Performance benchmarking tools."
     :tags (:ops :benchmark)
     :feature my/feature-ops-benchmark
     :require ops-benchmark
     :init my/ops-benchmark-init)

    (:name ops-sandbox
     :description "Sandboxed evaluation environment."
     :tags (:ops :sandbox)
     :feature my/feature-ops-sandbox
     :require ops-sandbox
     :init my/ops-sandbox-init))
  "Declarative operations module specifications.")

(provide 'manifest-ops)
;;; manifest-ops.el ends here
