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
│   │   ├── bootstrap-profile.el
│   │   └── bootstrap-use-package.el
│   │
│   ├── platform/        ; 平台/能力探测（跨平台边界层）
│   │   ├── platform-core.el
│   │   ├── platform-gui.el
│   │   ├── platform-linux.el
│   │   ├── platform-macos.el
│   │   ├── platform-tty.el
│   │   └── platform-windows.el
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
│   │   ├── runtime-context.el
│   │   ├── runtime-deferred.el
│   │   ├── runtime-doctor.el
│   │   ├── runtime-feature.el
│   │   ├── runtime-graph.el
│   │   ├── runtime-lifecycle.el
│   │   ├── runtime-manifest.el
│   │   ├── runtime-module-runner.el
│   │   ├── runtime-module-state.el
│   │   ├── runtime-observer.el
│   │   ├── runtime-pipeline.el
│   │   ├── runtime-provider.el
│   │   ├── runtime-plan.el
│   │   ├── runtime-registry.el
│   │   ├── runtime-stage-state.el
│   │   ├── runtime-stage.el
│   │   └── runtime-types.el
│   │
│   ├── manifest/       ; 阶段注册表 / manifest 驱动
│   │   ├── manifest-app.el
│   │   ├── manifest-editor.el
│   │   ├── manifest-lang.el
│   │   ├── manifest-ops.el
│   │   ├── manifest-prog.el
│   │   ├── manifest-project.el
│   │   ├── manifest-registry.el
│   │   ├── manifest-ui.el
│   │   ├── manifest-ux.el
│   │   └── manifest-vcs.el
│   │
│   ├── ui/              ; 视觉层（theme/frame/font/modeline）
│   │   ├── ui-chrome.el
│   │   ├── ui-font.el
│   │   ├── ui-frame.el
│   │   ├── ui-icons.el
│   │   ├── ui-modeline.el
│   │   ├── ui-popup.el
│   │   └── ui-theme.el
│   │
│   ├── ux/              ; 交互层（minibuffer/commands/help）
│   │   ├── ux-actions.el
│   │   ├── ux-completion-at-point.el
│   │   ├── ux-completion-read.el
│   │   ├── ux-help.el
│   │   ├── ux-history.el
│   │   └── ux-search.el
│   │
│   ├── editor/          ; 通用编辑行为
│   │   ├── editor-basics.el
│   │   ├── editor-folding.el
│   │   ├── editor-format.el
│   │   ├── editor-indent.el
│   │   ├── editor-motion.el
│   │   ├── editor-pairs.el
│   │   ├── editor-selection.el
│   │   ├── editor-snippets.el
│   │   └── editor-whitespace.el
│   │
│   ├── project/         ; 项目工作流
│   │   ├── project-compile.el
│   │   ├── project-core.el
│   │   ├── project-search.el
│   │   ├── project-test.el
│   │   └── project-workspace.el
│   │
│   ├── vcs/             ; 版本控制工作流
│   │   ├── vcs-blame.el
│   │   ├── vcs-core.el
│   │   ├── vcs-diff.el
│   │   └── vcs-magit.el
│   │
│   ├── prog/            ; 编程基础设施（语言无关）
│   │   ├── prog-ai.el
│   │   ├── prog-build.el
│   │   ├── prog-core.el
│   │   ├── prog-debug.el
│   │   ├── prog-diagnostics.el
│   │   ├── prog-lsp.el
│   │   ├── prog-treesit.el
│   │   └── prog-xref.el
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


## TODO

**P0（必须先做）——架构定盘：建立 V2 的 SSOT 与边界**

1. [TODO-0.1][P0]: 明确 V2 的"唯一事实源（SSOT）"
   - 模块生命周期状态：runtime-lifecycle作为唯一事实源
   - 阶段执行状态：runtime-stage-state作为唯一事实源
   - 环境/能力事实：runtime-context中命名空间...
   - 执行计划：新增runtime-plan作为编译产物的唯一事实源
   - 禁止在module-runner/deferred/doctor内私自维护状态副本

2. [TODO-0.2][P0]: runtime-context降维重构
   - 保留核心事实：:fact/*（OS/GUI/treesit等）...、:state/phase、:state/session-id、:state/boot-id ...
   - 移出health-log：新建runtime-health.el独立管理健康日志
   - 限制:view/*为纯函数投影，禁止塞入module runtime data/stage result/metrics

3. [TODO-0.3][P0]: 定义V2 runtime"执行计划（Execution Plan）"对象
   - 新增runtime-plan.el定义plan struct（stages/modules/stage DAG/module DAG/compiled providers/feature gates/deferred jobs/validation report）
   - 启动流程升级：manifest collect → normalize → validate → compile(plan) → execute plan → finalize

**P1（核心重构）——Manifest从plist规范化升级为DSL+编译器**

4. [TODO-1.1][P1]: 定义统一Manifest Schema（强约束）
   - Stage spec schema：:name(required)、:manifest(required)、:after(list)、:feature(optional)、:critical(bool)、:policy(optional)
   - Module spec schema：:name(required,unique)、:feature、:when、:after、:before(new)、:require、:init、:teardown、:reload(new)、:healthcheck(new)、:defer、:priority(new)、:critical(new)、:provides(new)、:consumes(new)等

5. [TODO-1.2][P1]: 引入Manifest DSL宏
   - 新增my/defstage、my/defmodule、my/defmanifest宏
   - 用户层禁止直接写裸plist，宏展开产物可落到plist/struct
   - 所有manifest/*.el逐步迁移到DSL

6. [TODO-1.3][P1]: 新增runtime-manifest-validate.el
   - normalize只做格式标准化，validate负责完整校验（required keys/type checks/duplicate names/unknown deps/self-dependency/stage cross-reference/invalid gates/invalid defer schema/duplicate provides/missing capabilities）
   - 输出machine-readable report，doctor可复用

7. [TODO-1.4][P1]: 新增Manifest Compiler
   - provider从compiled spec构造而非raw spec
   - compile阶段完成：gate归一化、defer归一化、require归一化、tags canonicalize、lifecycle hooks attach
   - 生成immutable compiled module对象

**P2（执行内核）——统一Stage/Module/Deferred为任务调度系统**

8. [TODO-2.1][P2]: 统一runtime-stage+runtime-module-runner+runtime-deferred为Task Runtime
   - 新增runtime-task.el定义统一task类型（:stage、:module/load、:module/init、:module/defer、:module/teardown、:healthcheck）
   - 所有执行通过task dispatcher，deferred作为task scheduler

9. [TODO-2.2][P2]: Stage DAG与Module DAG统一为Execution Graph
   - 新增runtime-plan-graph.el构建全局execution graph（stage nodes/module nodes/implicit edge/explicit edge）
   - cross-stage module dependency明确策略：默认禁止或显式允许:cross-stage t
   - cycle report输出完整路径，graph可供doctor可视化

10. [TODO-2.3][P2]: Deferred升级为"策略化调度器"
    - 定义统一defer schema：(:trigger after-init)、(:trigger idle :secs 1.5)、(:trigger hook :hook after-init-hook :once t)、(:trigger feature :feature org)、(:trigger command :command magit-status)、(:trigger timer :secs 10 :repeat nil)
    - 增加:timeout、:retry、:cancel-on-failure-of、:coalesce
    - deferred执行后统一回写lifecycle

11. [TODO-2.4][P2]: 引入Teardown/Reload/Restart一等公民
    - 定义模块生命周期：plan→load→init→active→reload/teardown，failed→retry
    - 新增my/runtime-module-reload、my/runtime-stage-rerun、my/runtime-module-restart
    - teardown失败有独立状态，deferred未触发支持取消+清理

**P3（Kernel）——把Kernel真正收敛为"纯基础设施层"**

12. [TODO-3.1][P3]: runtime-observer从kernel初始化语义中剥离
    - 拆分my/init-kernel-stage为：my/init-kernel-stage（纯kernel）+ my/init-runtime-core-stage（observer/context/feature/lifecycle）
    - runtime-doctor-init移出kernel stage，进入runtime observe stage
    - runtime-observer重命名为core-eventbus.el或runtime-eventbus.el

13. [TODO-3.3][P3]: 修复kernel-require的API一致性（必须立即修）
    - 修正my/log-error调用：改为(my/log-error "require" "require failed: %S -> %S" feature err)
    - 全局grep检查所有my/log-{trace,debug,info,warn,error}调用符合(tag fmt ...)签名
    - 可新增lint helper：ops-lint-logging-calls.el

14. [TODO-3.2][P3]: kernel-logging升级为"结构化事件日志底座"
    - log entry增加:source（kernel/runtime/module）、:module、:stage、:boot-id、:thread
    - 定义统一事件/日志桥接层，重要lifecycle event映射为log
    - 增加file sink/structured json sink/ephemeral boot report sink

15. [TODO-3.4][P3]: early-init/startup收口为Startup Policy子系统
    - 新建kernel-startup-policy.el
    - 明确三阶段：pre-init policy（early-init）、boot policy（during init）、runtime restore policy（post-init）
    - startup-finalize只做orchestrate，不做具体策略

**P4（Model/State）——把状态模型彻底规范化**

16. [TODO-4.1][P4]: 统一Record Struct
    - 所有运行态记录用cl-defstruct：my/module-record、my/stage-record、my/task-record、my/plan-record
    - 不再用自由plist传状态，state access必须通过accessor API

17. [TODO-4.2][P4]: lifecycle FSM升级为"显式合法迁移表"
    - 新增状态迁移表常量
    - my/runtime-lifecycle-transition验证合法边，非法迁移log+signal
    - 支持terminal state/retryable state判定API

18. [TODO-4.3][P4]: Feature Gate模型化
    - gate支持：symbol/list(and/or/not)/predicate function/capability key/package availability/executable availability
    - 统一返回(:ok t :reason...)/(:ok nil :reason...)
    - stage/module skip reason标准化

**P5（Observability）——Doctor从"报告器"升级为"运行时诊断面板"**

19. [TODO-5.1][P5]: Doctor从订阅者升级为Projection Layer
    - runtime-doctor不碰执行逻辑，只订阅event bus、读取lifecycle/state snapshot、输出report/health/warnings
    - 新增多个projection：slow modules/failed modules/skipped-by-gate/deferred pending/dependency anomalies

20. [TODO-5.2][P5]: 增加Boot Report/Runtime Report/Debug Report三种视图
    - my/runtime-report-boot、my/runtime-report-failures、my/runtime-report-deferred、my/runtime-report-graph、my/runtime-report-health

21. [TODO-5.3][P5]: 增加"启动回归基线"
    - 启动耗时拆分：bootstrap/platform/kernel/runtime compile/runtime execute/deferred completion
    - 保存最近N次启动摘要到var/，检测异常抖动并告警

**P6（Manifest/Registry）——注册中心去"弱耦合适配器化"**

22. [TODO-6.1][P6]: manifest-registry升级为"声明注册层"
    - stage registry改为显式注册API：(my/register-stage...)、(my/register-manifest...)
    - 避免依赖boundp+symbol-value，registry返回typed records而非raw plist

23. [TODO-6.2][P6]: 支持Manifest分层组合
    - manifest支持overlay：base/platform overlay/profile overlay(dev/minimal/gui/tty)/host-local overlay/private overlay
    - 冲突策略：replace/merge/append/disable

24. [TODO-6.3][P6]: 模块命名空间规范
    - 模块名约定：ui/*/editor/*/lang/*/app/*/ops/*
    - :name用symbol但遵循namespaced symbol，统一:provides与:consumes命名规范

**P7（目录结构）——建议的V2物理重排**

25. [TODO-7.1][P7]: runtime/拆子目录
    - core/：runtime-types.el、runtime-events.el、runtime-contracts.el
    - model/：runtime-context.el、runtime-feature.el、runtime-lifecycle.el、runtime-stage-state.el、runtime-module-state.el、runtime-health.el、runtime-plan-state.el
    - manifest/：runtime-manifest-dsl.el、runtime-manifest-normalize.el、runtime-manifest-validate.el、runtime-manifest-compile.el、runtime-registry.el
    - exec/：runtime-plan.el、runtime-graph.el、runtime-task.el、runtime-provider.el、runtime-deferred.el、runtime-module-runner.el、runtime-stage-runner.el、runtime-pipeline.el
    - observe/：runtime-doctor.el、runtime-report.el、runtime-trace.el、runtime-benchmark.el

**P8（init-pipeline）——V2顶层流水线改造**

26. [TODO-8.1][P8]: init-pipeline升级为"两阶段runtime"
    - 新增显式函数：my/runtime-collect-manifests、my/runtime-build-plan、my/runtime-execute-plan
    - my/runtime-run-all-stages逐步废弃或仅作兼容入口
    - V2流水线：bootstrap→platform→kernel→runtime-core-init→manifest-collect→manifest-normalize→manifest-validate→runtime-plan-compile→runtime-plan-execute→post-init→deferred-runtime

27. [TODO-8.2][P8]: 增加boot-id/session-id
    - 启动时生成boot-id存入runtime-context
    - 所有log/event自动附带boot-id，支持多次my/init-force-rerun区分运行实例

**P9（质量保障）——为V2增加"架构防腐层"**

28. [TODO-9.1][P9]: 新增runtime lint/doctor静态检查
    - 检查manifest重名/stage DAG cycle/module DAG cycle/跨stage依赖/缺失init-require/非法defer spec/logging API误用/feature gate永远false的死模块

29. [TODO-9.2][P9]: 为runtime核心建立ERT测试矩阵
    - 优先测试：runtime-context、runtime-feature、runtime-lifecycle、runtime-graph、runtime-manifest-normalize、runtime-manifest-validate、runtime-plan、runtime-deferred


