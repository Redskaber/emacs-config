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
│   │   ├── runtime-deferred.el
│   │   ├── runtime-feature.el
│   │   ├── runtime-graph.el
│   │   ├── runtime-manifest.el
│   │   ├── runtime-module-runner.el
│   │   ├── runtime-module-state.el
│   │   ├── runtime-pipeline.el
│   │   ├── runtime-provider.el
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

## 原则

原则 1：Manifest 是声明，不是执行计划
  - manifest 不负责顺序正确
  - runtime 负责生成 plan
原则 2：Provider 是唯一执行适配层
  - runner 不再直接理解 plist 细节
  - 一切执行相关语义都通过 provider 暴露
原则 3：Deferred 是调度器，不是真实状态
  - deferred 只描述“未来会执行”
  - 模块最终状态必须回写到 module-state
原则 4：State 与 Event 分离
  - latest state 用于决策
  - append-only event 用于审计/debug
原则 5：Feature 是 policy，When 是 fact
  - profile 只改 policy
  - fact 永不被 profile 覆盖
原则 6：所有可观察行为必须可解释
  任何模块都应该能回答：
  - 为什么执行了？
  - 为什么没执行？
  - 为什么 deferred？
  - 为什么失败？
  - 耗时多少？
  - 依赖链是什么？

## TODO

1. 抽象层已经够多，但契约还没完全闭合
2. 数据模型开始结构化，但状态流转仍有断裂
3. 模块生命周期已分层，但异步/延迟执行路径还未完全接通
4. 有 observability 雏形，但缺少统一事件语义与最终一致性
5. runtime-deferred 与 runtime-module-runner 没有真正闭环 
  - 事件驱动
  - runtime-deferred 不直接依赖 runner，而是发 observer event
6. runtime-module-state 注释说有 supersedes，但实现并没有
  - latest table + append-only log
  - 状态模型与事件模型分离
7. runtime-deferred 当前“状态”与“模块状态”是两套并行系统，缺少统一生命周期模型
  模块状态应该是“业务真相”
  建议模块状态枚举统一为：
    - planned
    - skipped
    - loading
    - loaded
    - deferred
    - running
    - ok
    - failed
    - cancelled
  而 deferred-obj.state 只描述 调度器内部状态：
    - scheduled
    - fired
    - cancelled
  然后通过 event 或 callback，把调度器状态映射到模块状态迁移。
8. runtime-context 目前仍偏“弱类型 KV”，缺少“系统事实 vs 派生视图”分层
  - facts
  - state
  - derived / report
  - 多层模型 ...
9. runtime-feature 的 ancestor 解析存在“循环 parent”静默风险
  - 显式 cycle detection
  - fail-fast
10. kernel-logging 的 ring 实现是 O(n) 尾删，规模大了会不必要地慢
  - Emacs 自带 ring 
11. kernel-errors 与 kernel-logging 的 backtrace 语义重复且不一致
  统一成：
  - 错误边界负责“捕获上下文异常”
  - logger 负责“输出结构化日志”
  - backtrace capture 只在 error boundary / exception site 发生
12. runtime-manifest 目前是“normalize-only”，还缺少“spec validation contract”
  - 验证
  - ...
13. runtime-graph 只做 stage graph，module graph 仍是“线性 manifest 顺序 + after satisfied”
  - module 也做成 plan
14. runtime-module-runner
  - deferred completion 未接通（最大）
  - 语义问题

--- 
- deferred 闭环
- module state/event 模型
- module graph/multi-pass
- manifest contract
- doctor/explain
- ...


