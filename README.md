# emacs

> 现代, 高效，敏捷，科学，美观、跨平台
> 层级划分，层级功能性细分，管道式流水线，插件加载，依赖倒置，边界明确，策略选择,生命周期明确 

## Design Principles

- **Thin entrypoints**: `early-init.el` and `init.el` remain minimal.
- **Explicit pipeline**: startup is organized into deterministic stages.
- **Layered architecture**: each directory represents a strict responsibility boundary.
- **Dependency inversion**: language modules are adapters, not logic containers.
- **Capability-driven behavior**: GUI/TTY/OS/package availability are treated as runtime capabilities.
- **Composable modules**: every module exposes a predictable lifecycle contract.
- **Safe degradation**: failures in optional modules must not break startup.
- **Operational visibility**: profiling, diagnostics, health checks, and benchmarks are first-class.


## Arch

```bash
~/.config/emacs/
├── early-init.el        ; 极薄启动前入口
├── init.el              ; 极薄主入口
├── custom.el            ; Custom UI 写入隔离（禁止污染 init）
│
├── lisp/
│   ├── bootstrap/       ; 包管理与启动基础设施
│   │   ├── bootstrap-core.el
│   │   ├── bootstrap-package.el
│   │   ├── bootstrap-use-package.el
│   │   └── bootstrap-profile.el
│   │
│   ├── platform/        ; 平台/能力探测（跨平台边界层）
│   │   ├── platform-core.el
│   │   ├── platform-linux.el
│   │   ├── platform-macos.el
│   │   ├── platform-windows.el
│   │   ├── platform-gui.el
│   │   └── platform-tty.el
│   │
│   ├── kernel/          ; 核心基础设施
│   │   ├── kernel-const.el
│   │   ├── kernel-encoding.el
│   │   ├── kernel-env.el
│   │   ├── kernel-errors.el
│   │   ├── kernel-hooks.el
│   │   ├── kernel-keymap.el
│   │   ├── kernel-lib.el
│   │   ├── kernel-logging.el
│   │   ├── kernel-paths.el
│   │   ├── kernel-performance.el
│   │   ├── kernel-require.el
│   │   ├── kernel-startup.el
│   │   └── kernel-state.el
│   │
│   ├── runtime/         ; 运行时系统
│   │   ├── runtime-types.el
│   │   ├── runtime-context.el
│   │   ├── runtime-feature.el
│   │   ├── runtime-graph.el
│   │   ├── runtime-manifest.el
│   │   ├── runtime-module-runner.el
│   │   ├── runtime-module-state.el
│   │   ├── runtime-pipeline.el
│   │   ├── runtime-registry.el
│   │   ├── runtime-stage-state.el
│   │   ├── runtime-stage.el
│   │   ├── runtime-plan.el
│   │   └── runtime-observer.el
│   │
│   ├── manifest/       ; 阶段注册表 / manifest 驱动
│   │   ├── manifest-registry.el
│   │   ├── manifest-ui.el
│   │   ├── manifest-ux.el
│   │   ├── manifest-editor.el
│   │   ├── manifest-project.el
│   │   ├── manifest-vcs.el
│   │   ├── manifest-prog.el
│   │   ├── manifest-lang.el
│   │   ├── manifest-app.el
│   │   └── manifest-ops.el
│   │
│   ├── ui/              ; 视觉层（theme/frame/font/modeline）
│   │   ├── ui-frame.el
│   │   ├── ui-font.el
│   │   ├── ui-theme.el
│   │   ├── ui-chrome.el
│   │   ├── ui-modeline.el
│   │   ├── ui-icons.el
│   │   └── ui-popup.el
│   │
│   ├── ux/              ; 交互层（minibuffer/commands/help）
│   │   ├── ux-completion-read.el
│   │   ├── ux-completion-at-point.el
│   │   ├── ux-actions.el
│   │   ├── ux-search.el
│   │   ├── ux-help.el
│   │   └── ux-history.el
│   │
│   ├── editor/          ; 通用编辑行为
│   │   ├── editor-basics.el
│   │   ├── editor-motion.el
│   │   ├── editor-selection.el
│   │   ├── editor-pairs.el
│   │   ├── editor-indent.el
│   │   ├── editor-format.el
│   │   ├── editor-whitespace.el
│   │   ├── editor-snippets.el
│   │   └── editor-folding.el
│   │
│   ├── project/         ; 项目工作流
│   │   ├── project-core.el
│   │   ├── project-search.el
│   │   ├── project-compile.el
│   │   ├── project-test.el
│   │   └── project-workspace.el
│   │
│   ├── vcs/             ; 版本控制工作流
│   │   ├── vcs-core.el
│   │   ├── vcs-magit.el
│   │   ├── vcs-diff.el
│   │   └── vcs-blame.el
│   │
│   ├── prog/            ; 编程基础设施（语言无关）
│   │   ├── prog-core.el
│   │   ├── prog-treesit.el
│   │   ├── prog-lsp.el
│   │   ├── prog-diagnostics.el
│   │   ├── prog-xref.el
│   │   ├── prog-debug.el
│   │   ├── prog-build.el
│   │   └── prog-ai.el
│   │
│   ├── lang/            ; 语言适配层（仅做 glue，不堆通用逻辑）
│   │   ├── lang-elisp.el
│   │   ├── lang-python.el
│   │   ├── lang-go.el
│   │   ├── lang-rust.el
│   │   ├── lang-tsjs.el
│   │   ├── lang-nix.el
│   │   ├── lang-web.el
│   │   ├── lang-markdown.el
│   │   ├── lang-org.el
│   │   └── lang-yaml-json-toml.el
│   │
│   ├── app/             ; "应用化"能力
│   │   ├── app-terminal.el
│   │   ├── app-dired.el
│   │   ├── app-eshell.el
│   │   ├── app-vterm.el
│   │   ├── app-notes.el
│   │   ├── app-rss.el
│   │   └── app-llm.el
│   │
│   ├── ops/             ; 运维/诊断/性能/实验
│   │   ├── ops-startup.el
│   │   ├── ops-profiler.el
│   │   ├── ops-healthcheck.el
│   │   ├── ops-benchmark.el
│   │   └── ops-sandbox.el
│   │
│   └── init-pipeline.el ; 顶层 orchestration（统一装配）
│
├── var/                 ; 状态数据（session/history）
├── cache/               ; cache / transient / url / etc
├── eln-cache/           ; native-comp 输出（可选重定向）
├── snippets/            ; yasnippet（可选）
├── tree-sitter/         ; grammar 管理（可选）
└── etc/                 ; 本地模板、脚本、字典等
```


## Depand

```bash
bootstrap
   ↓
platform
   ↓
kernel
   ↓
runtime
   ↓
policy (optional)
   ↓
ui / ux / editor
   ↓      ↓      ↓
project  vcs    prog
   ↓       ↘     ↓
   └──────→ app  lang
            ↓
           ops (observe-all, depend-on-none by policy)

```

- lang: 主要依赖 prog，可选依赖 project
- app: 主要依赖 project / vcs / prog / ux 的部分能力（不是强依赖全部）
- ops: 原则上只依赖 core，但可观察所有层；不要强耦合业务层

核心原则: 
- ops 是“观测层”，不是“业务层附庸”；
- app 是“面向用户工作流的应用聚合层”，不是语言层的一部分。


## Template

```elisp
;;; xxx.el --- One-line summary -*- lexical-binding: t; -*-
;;; Commentary:
;;; Short description.
;;; Code:

(require 'kernel-lib)      ;; if needed
(require 'kernel-const)    ;; if needed
(require 'kernel-require)  ;; if needed

(defgroup my/xxx nil
  "Description."
  :group 'my)

(defcustom my/xxx-foo ...
  "..."
  :type '...
  :group 'my/xxx)

(defun my/xxx--hook ()
  "Hook entry."
  ...)

(defun my/xxx-init ()
  "Initialize xxx module."
  ...)

(provide 'xxx)
;;; xxx.el ends here

```


