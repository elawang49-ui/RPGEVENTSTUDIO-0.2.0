# RPGEVENTSTUDIO 死代码与冗余专项审计报告

- **审计日期**：2026-11-02
- **审计基线**：commit `9fd3308`（worktree `rpg-studio-dialogue-pagination-acceptance`，分支 `feat/dialogue-pagination-acceptance`）。除第六节 F 类版本漂移外，所有行号均以该工作区文件为准。
- **审计性质**：只读审计。未修改、删除、重命名、移动任何文件；未触碰其他 worktree；本报告是本次任务唯一新增文件。
- **任务定位**：在 2026-11-01《插件全方位审计报告》基础上增加的独立代码精简专项，只提交报告，不实施删除；与第一轮 P0/P1 修复完全分离。
- **代码规模（基线）**：插件 GDScript 84 文件 / 18,399 行；tests 23 个 .gd / 6,830 行；tools 12 脚本 / 1,799 行；docs 34 个 .md；docs/images 138 个 png。

---

## 一、执行摘要

| 类别 | 数量 | 说明 |
|---|---|---|
| **A 类：高置信度可删除** | 代码 20 项（25 处声明，约 97 行 GDScript）+ 孤儿词条 11 个（22 个 csv 行）+ 本地未跟踪产物 14 处 | 全部零引用、非公开 API、非引擎回调、非设计预留，已逐一排除动态调用 |
| **B 类：疑似冗余，需验证** | 17 项 | 主要是：plugin.gd 截图脚手架（约 355 行）、tools 一次性截图脚本（7 个 / 683 行）、无文档引用的验收截图（约 115 个 png）、被完整覆盖的测试（1 个）、重复实现重构候选（6 组） |
| **C 类：应保留** | 12 项 | 公开/宿主 API、引擎回调、设计预留字段、正式测试入口、双层测试 |

三个最重要的结论：

1. **A 类死代码总量很小（约 97 行）**。这份代码库整体上没有大规模死代码——"看起来旧"的代码几乎都在被使用。真正的冗余集中在**工程脚手架层**（plugin.gd 的截图钩子、tools 的一次性截图脚本、未引用的验收截图），而不是运行时/编辑器功能层。
2. **story / map / graph 三个模块不存在可合并的重复实现**。它们是同一 model 层之上的三个职责不同的前端（剧情工作台 / 地图总览 / 关卡图编辑器）。重复的是 UI 助手层（16 组逐字或近似相同的私有函数/常量表），是**下沉共享**的重构候选，不是删除候选。
3. **文档失真比代码失真严重**：tools/README.md 记载的 6 个脚本中 5 个不存在、实际 14 项中 12 项未记载；tests/README.md 套件数过时；docs/02/07/09 把不存在的脚本当作已实现描述。**精简的第一收益在修文档，不在删代码。**

---

## 二、审计方法与置信度说明

### 2.1 方法

1. **符号级全量扫描**：用自建解析器提取全部 2,335 个类级声明（func/signal/const/enum/class/var，含 @export/@onready/static），在全部 .gd/.tscn/.tres/.py/.cfg/.csv/.md/.json 文本（含注释剥离后的字符串内容）中统计每个标识符的出现位置，得到：
   - 「完全零引用」（任何文件、任何行都没有第二次出现）：166 个原始候选；
   - 「仅本文件引用」（从未被跨文件使用）：1,051 个。
2. **人工逐条复核**：对每个零引用候选阅读定义处与上下文源码，按下述排除规则过滤。
3. **资源引用图**：解析全部 .tscn/.tres 的 ext_resource（path/uid）、.gd 的 preload()/load()/res:// 字符串、project.godot、plugin.cfg、tools/*.py，反查每个资源文件的引用者。
4. **跨副本核对**：14 个 worktree + School + GamePrototype 的版本漂移与 .bak 比对（见第六节 F）。
5. **宿主使用面核对**：在实际宿主项目（School、GamePrototype）中 grep 插件公开 API 的真实调用（InputService.rebind / extend_action_defaults / action_ids / L10n.game / runtime.get("input") 等），用于公开 API 分类。

### 2.2 假阳性排除记录（这些"零引用"项**不是**死代码，已从清单剔除）

| 候选 | 排除理由 |
|---|---|
| `plugin.gd:409 _has_main_screen` / `:412 _get_plugin_name` / `:415 _get_plugin_icon` | EditorPlugin 引擎回调，编辑器隐式调用 |
| `studio_debugger_plugin.gd:11 _has_capture`、`:14 _capture` | EditorDebuggerPlugin 引擎回调（capture 注册协议） |
| `tools/capture_bbcode_editor.gd:8 _initialize` | SceneTree 引擎回调 |
| `tests/fixtures/bulk_scan/legacy_script.gd` 全部符号 | 故意"死"的扫描夹具（StateUsageScanner 的测试输入），功能性使用 |
| `tests/mock_presenter.gd`（MockPresenter） | 经 class_name 全局注册被 run.gd×8、runtime_trace_test×2 使用 |
| `event_references.gd` | 被 story_audit.gd:65、event_list_panel.gd:82 实际调用 |
| `studio_runtime.DIALOGUE_THEME_PATH`（:10） | 同文件 :181/:182/:185 使用；`ui/rpgeventstudio_theme.tres` 文件本身不存在是"按需创建"设计（主题页保存时创建，dialogue_theme_view.gd:537-538 会 make_dir） |
| `graph.group.new` / `new_selection` 等 79 个 i18n 词条 | 经 `"前缀" + 变量` 动态拼接引用（共 14 个前缀拼接点，如 level_graph_view.gd:922 的 `["new_selection","new"]` 循环） |
| `story.template.*_hint` 7 词条 | story_templates.gd:17 `"story.template." + id + "_hint"` 构造 |
| 各类 `SAMEFILE` 私有函数（约 900 个） | 类内调用属于正常封装，不构成死代码 |

### 2.3 动态引用风险总评

- 本仓库内所有 `call("...")` / `Callable` / `connect("...")` 字符串参数都会被扫描器捕获（注释剥离保留字符串），因此"完全零引用"结论对**字符串式动态分发是稳健的**。
- 残余风险仅剩两类：① Godot class_name 全局类被**仓库外**工程（School / GamePrototype / 未来宿主）使用——凡 `class_name` 公开类型上的方法一律不因零引用判死；② 引擎按名字回调的虚方法——已逐一比对 Godot 4 文档级回调清单排除。

---

## 三、特别复核线索（任务第三节 7 项，逐一回答）

### 3.1 A 副本中的 .bak 文件：确认无独有内容 ✅（数量修正为 12 个，非 10 个）

A 副本（`/Users/elawang/Godot/RPGEVENTSTUDIO`，a5afc90）实际存在 **12 个 .bak**（全部未被 git 跟踪，`.gitignore:13` 的 `*.bak` 规则产物；前次审计计 10 个应为只数了 addons 下的部分）：

| 文件 | 比对结论 |
|---|---|
| `samples/audio/beep.tres.bak` | 与主文件**逐字节相同** |
| `samples/demo_theme.tres.bak`、`samples/events/`（basement_cutscene/classroom_board/key_pickup/librarian/locked_door/office 各 .bak）、`samples/graphs/school_graph.tres.bak`、`state/state_catalog.tres.bak`（共 9 个） | 行数一一对应，diff 全部为 Godot 重存时再生成的 ext/sub_resource ID 令牌，**非 ID 差异行数为 0**，命令/文本/结构内容一致 → 纯 ID 重排 |
| `samples/scenes/school_demo.tscn.bak` | 唯一有实质差异的：是**旧版本快照**（10-28），主文件（10-30）已改用外部主题 demo_theme.tres、交互提示加入「回车」（统一输入落地）。.bak 内容被现版本完全替代，无独有信息 |
| `.godot/test_state_catalog.tres.bak` | 测试运行残留（14 行测试夹具），.godot/ 本身 gitignored |
| （School）`project.godot.bak_pre_rpgeventstudio` | 安装插件前的配置备份，差异仅为当前已增加了 autoload / editor_plugins / [rpg_event_studio] 三段——备份本身无独有价值 |

**结论：12 个 .bak 全部无独有内容，可安全清理**（其中 11 个是 SafeFile「一代备份」设计的正常产物，删除后下次写盘还会再生；若嫌再生，应改 SafeFile 策略而不是反复手工清理）。

### 3.2 plugin.gd 约 55% 截图/自测脚手架：区分结论 ✅

- 实测占比：环境变量钩子块 `plugin.gd:46-71`（26 行，15 个 RPGEVENTSTUDIO_* 触发变量 + 9 个参数变量）+ 测试钩子节 `plugin.gd:488-896`（409 行）= **435/896 行 ≈ 48.5%**。
- **必须保留（正式测试入口，C 类）**：6 个 SELFTEST 钩子（`RPGEVENTSTUDIO_SELFTEST/MAP_SELFTEST/GVL_SELFTEST/STORY_SELFTEST/AUDIT_SELFTEST/TRACE_SELFTEST`）被 `tools/test_runner.py:74-79` 的 editor 套件逐一消费，对应 test_counts.json "editor" 节 6 个条目 / 176 项检查。对应 6 个 `_start_*_selftest` 函数（约 80 行）必须留在 plugin.gd。
- **疑似冗余（B 类）**：8 个 SHOT 截图钩子（`_SHOT`、`GVL_SHOT`、`MAP_SHOT`、`THEME_SHOT`、`BULK_SHOT`、`STORY_SHOT`、`MAIN_TAB_SHOT`、`DOCK_SHOT`）+ `_shot_target_size/_focus_main_screen/_apply_shot_window_size/_enforce_shot_size/_save_shot/_capture_viewport/_capture_graph_screen/_capture_dock_screen/_select_dock_tab/_capture_main_tab_screen/_capture_theme_screen/_capture_map_screen/_capture_bulk_screen/_capture_gvl_screen`（约 **355 行**）不被 test_runner.py 使用，唯一作用是再生成 docs/images 配图。**它们不是死代码**（docs/images 的图确实是它们生成的），但属于开发脚手架混入插件入口文件：建议整体迁出到 `tools/`（例如 EditorScript 或独立场景脚本），plugin.gd 恢复纯插件入口。

### 3.3 EventPage.priority / LevelNode.reentry 疑似死字段：结论相反 ✅

| 字段 | 位置 | 判定 | 依据 |
|---|---|---|---|
| `EventPage.priority` | `core/model/event_page.gd:12` | **A 类：死字段** | 全仓（含全部 .tres 样本、tests、tools、docs）零引用。README 的优先级语义是"页序号越大优先级越高"（README「事件多页」行），即由 pages 数组顺序决定，event_runner 的选页逻辑也只按数组序遍历。该 @export 字段既无运行时读取者、也无编辑器 UI、也无文档承诺，不属于设计预留 |
| `EventPage.trigger_params` | `core/model/event_page.gd:8` | **A 类：死字段** | 同上，全仓零引用（含所有 .tres）。触发参数实际走命令 params（如 region 的范围由场景碰撞体表达） |
| `LevelNode.reentry` | `core/model/level_node.gd:11` | **C 类：保留（设计预留）** | `docs/13-关卡总控图实现.md:44` 明文记载"`reentry` | drop / queue / restart（当前实现 drop 语义，**字段预留**）"；docs/05、docs/06 均按 QUEUE/RESTART 语义设计了风险与交互条款。这是有文档的设计预留，不得按死代码处理。运行时 trace 里的 "reentry" 字样（event_runner.gd:56）是事件重入保护，与该字段无关，勿混淆 |

### 3.4 StateStore._pending_new：确认死变量 ✅

`core/state/state_store.gd:26` `var _pending_new: Dictionary = {}`——全仓零引用（声明后从未读/写）。与之对照，`_pending_old`（:27）有实际读写。应为某次事务重构的残留。A 类。

### 3.5 被新缓存替代的旧缓存逻辑：未发现此类现场 ✅（结论：不存在）

全仓缓存字段共 4 处，全部是唯一实现、无新旧并存：
- `L10n._cache`（l10n.gd:16，翻译资源缓存）——在用；
- `StateUsageScanner._regex_cache`（state_usage_scanner.gd:43）——在用；
- `StateCatalogStore` 静态目录缓存（state_catalog_store.gd:60 提供 reset_cache，state_catalog_bulk.gd:83,119 与 state_library_dialog.gd:204 三个写路径均正确失效）——在用；
- `RuntimeDisplayNames._graph_cache`（display_names.gd:12）——在用，但**永不失效**（关卡图外改图后显示名过期）——这是前次审计 P3 已知缺陷，属"需要失效策略"，不是"旧实现残留"。

### 3.6 story / map / graph 重复实现：模块级无重复，助手级有 16 组 ✅

见第七节关系图与 B 类 B-12～B-14。核心结论：三个面板共享同一 model/undo/safe-file 基建，职责不同**不应合并**；重复的是 UI 层私有助手（节点解析、页签重建、保存、toast、BBCode 预览、OPS 表、float 判等、选项块重建），数量 16 组，建议下沉共享模块（重构候选，非删除候选）。

### 3.7 tools/README.md 与真实脚本差异：严重失真 ✅

`tools/README.md:5-12` 记载 6 项：`check_deps.gd`、`export_json.gd`、`import_json.gd`、`validate_all.gd`、`package.sh`、`test_runner.py`——**前 5 个不存在**（JSON 交换/依赖检查/打包是 docs/10 路线图 P3 项与 docs/07/09 的规划文案，从未实现）；实际存在的 14 项中 12 项只字未提（仅 test_runner.py 被记载）。tests/README.md 与 docs/07/09 的对应失真见 B-17。

---

## 四、A 类：高置信度可删除

判定标准：已证明无有效引用（含字符串动态调用）／不属于公开 API／不影响宿主兼容／无独有测试价值。每项 8 要素齐备。**本轮不删除，仅建议。**

### A-1 `EventPage.priority` 死导出字段
1. **位置**：`addons/rpgeventstudio/core/model/event_page.gd:12`
2. **用途**：@export int，名义上的页优先级。
3. **引用情况**：全仓零引用（含全部 .tres 样本、编辑器、运行时、测试、文档）。
4. **为何冗余**：优先级语义实际由页序决定（README「事件多页」行、event_runner 选页遍历顺序）。
5. **动态引用风险**：无。非协议字段；唯一残余风险是外部宿主的 .tres 手写了 `priority=` 值（样本与两份宿主副本均无）。
6. **删除影响**：无运行时影响；旧 .tres 若含该键会有一次"无法设置属性"警告。
7. **建议**：下一版本随 schema 收紧删除；如担心宿主数据，可先改为 @deprecated 注释保留一个周期。
8. **置信度**：高。

### A-2 `EventPage.trigger_params` 死导出字段
1. **位置**：`core/model/event_page.gd:8`
2. **用途**：@export Dictionary，名义上的触发参数。
3. **引用情况**：全仓零引用（含全部 .tres）。
4. **为何冗余**：触发行为（交互/区域/自动）由组件节点（EventInteractor2D 等）与场景表达，页面级触发参数从未接入。
5. **动态引用风险**：无（同 A-1）。
6. **删除影响**：无。
7. **建议**：删除；若未来要做"页面级触发参数"再按需设计。
8. **置信度**：高。

### A-3 `EventPage.remove_command` / `move_command` 未接线的"撤销原子操作"
1. **位置**：`core/model/event_page.gd:38-42`（remove_command，5 行）、`:44-51`（move_command，8 行）
2. **用途**：注释称"供编辑器撤销/重做调用的原子操作"。
3. **引用情况**：全仓零调用。事件编辑器删除/移动指令走 `_on_move_command`（event_editor_panel.gd:1103）直接操作数组 + 自建 undo；剧情线走 story_document 的 insert/remove。
4. **为何冗余**：注释承诺的接线从未发生，形成两套平行的命令操作路径（资源方法 vs 面板私有方法）。
5. **动态引用风险**：无（字符串参数扫描为 0）。
6. **删除影响**：无；若未来统一撤销路径反而应以本组方法为基座——**可与 B-12 重构二选一**。
7. **建议**：删除，或在 B-12 重构中真正接线。二选一，不要既保留又不用。
8. **置信度**：高（零引用事实）；处理方式建议项为中。

### A-4 `EventCommand.set_param` 死包装
1. **位置**：`core/model/event_command.gd:16-18`
2. **用途**：设置参数并 emit_changed 的便捷方法。
3. **引用情况**：全仓零调用；两个编辑器面板均直接写 `command.params[key]`。
4. **为何冗余**：未接线（同 A-3 模式）。
5. **动态引用风险**：无。
6. **删除影响**：无。
7. **建议**：删除，或随 B-12 统一参数编辑路径时启用。
8. **置信度**：高。

### A-5 `EventDefinition.add_page` / `remove_page` 死方法
1. **位置**：`core/model/event_definition.gd:31-35`（5 行）、`:37-40`（4 行）
2. **用途**：增删事件页的便捷方法。
3. **引用情况**：全仓零调用；两个面板的加/删页 handler（story_editor_panel.gd:1136-1152、event_editor_panel.gd:956-974）直接操作 `pages` 数组。
4. **为何冗余**：同 A-3 模式；且两个面板的删页都还没有撤销登记（前次审计 P2-6），这两个方法恰好是能补齐撤销的基座。
5. **动态引用风险**：无。
6. **删除影响**：无。
7. **建议**：删除，或随 B-12/P2-6 修复接线。
8. **置信度**：高。

### A-6 `LevelNode.duplicate_node` 死包装
1. **位置**：`core/model/level_node.gd:40-42`
2. **用途**：`duplicate(true)` 的类型化包装。
3. **引用情况**：全仓零调用（图节点复制尚未实现——README 未承诺节点复制）。
4. **为何冗余**：无调用者。
5. **动态引用风险**：无。
6. **删除影响**：无；若做"复制节点"功能再写。
7. **建议**：删除。
8. **置信度**：高。

### A-7 `EventContext.locals` 死字段
1. **位置**：`core/runtime/event_context.gd:16`
2. **用途**：名义上的事件局部变量域。
3. **引用情况**：全仓零读写。`@@self.X` 实际落入 StateStore 的 `Local.<event_id>.X` 域（event_context.gd:49-52）。
4. **为何冗余**：局部域方案已由 StateStore 承担，该字段是旧方案的残留。
5. **动态引用风险**：无。
6. **删除影响**：无。
7. **建议**：删除（与 docs/06 的 Local 域文档一致，无语义损失）。
8. **置信度**：高。

### A-8 `EventContext.has_state` 死方法
1. **位置**：`core/runtime/event_context.gd:60-61`
2. **用途**：判断状态键是否存在的上下文便捷方法。
3. **引用情况**：全仓零调用；指令处理器直接走 `state.has()`/`compare_state`。
4. **为何冗余**：未接线。注意：它是 ctx 便捷层的一部分（get_state/set_state/compare_state 均在用），属同族唯一孤儿。
5. **动态引用风险**：无；但 EventContext 是宿主可触达类型（指令处理器闭包内的 ctx）——宿主自定义指令理论上可调。风险低（便捷方法，语义明确，随时可重建）。
6. **删除影响**：极小。
7. **建议**：删除；若追求"ctx API 完整性"也可保留并在 docs/04 补一行——**倾向删除**（YAGNI）。
8. **置信度**：高（事实）/ 中（建议）。

### A-9 `EventContext.resolve_node` 死方法
1. **位置**：`core/runtime/event_context.gd:150-157`
2. **用途**：从当前场景根按路径解析节点。
3. **引用情况**：全仓零调用。场景对象解析实际走 `event_context.gd:130-146` 的 `resolve_scene_object`（带 wrong_scene 诊断的结构化返回）+ `resolve_player`/`resolve_camera`。
4. **为何冗余**：被结构化版本取代的旧签名（前次审计第七节安全扫描也只列了结构化路径）。
5. **动态引用风险**：无。
6. **删除影响**：无。
7. **建议**：删除。
8. **置信度**：高。

### A-10 `EventContext.is_cancelled` / `take_logs` 死方法（连带 `_logs` 无消费者）
1. **位置**：`core/runtime/event_context.gd:179-180`（is_cancelled，2 行）、`:192-195`（take_logs，4 行）
2. **用途**：取消查询便捷方法；取走日志缓冲。
3. **引用情况**：两者全仓零调用。runner 直接读 `ctx.cancelled` 字段；`log()`（:197-200）持续 append `_logs` 但无人取走（调试打印只在 OS.is_debug_build 分支）。
4. **为何冗余**：is_cancelled 是字段直读的重复封装；take_logs 使 `_logs` 成为"只写不读"缓冲（每个 ctx 生命周期内无界增长，事件结束随 ctx 释放）。
5. **动态引用风险**：无。
6. **删除影响**：无；删除 take_logs 应同时决定 `_logs` 的去留（建议一并删除 `_logs`/`log()` 中的 append，保留 print——见 B 类建议）。
7. **建议**：删除 is_cancelled；take_logs 与 `_logs` 缓冲一起删（保留 log() 的 print 行为）。
8. **置信度**：高。

### A-11 `StateStore._pending_new` 死变量
1. **位置**：`core/state/state_store.gd:26`
2. **用途**：无（从未读写）。
3. **引用情况**：全仓零引用。
4. **为何冗余**：事务重构残留；对照同文件 `_pending_old`（:27）有完整读写。
5. **动态引用风险**：无。
6. **删除影响**：无。
7. **建议**：删除。
8. **置信度**：高。

### A-12 `DialogueBox.hide_text` 死方法
1. **位置**：`runtime/ui/dialogue_box.gd:276-280`
2. **用途**：带动画隐藏对话框。
3. **引用情况**：全仓零调用。展示协议（docs/18:6-16）只有 show_text/is_text_finished/show_choices/get_choice/close_all/fade_to，**不含 hide_text**；面板收起走 close_all 路径。
4. **为何冗余**：协议外孤儿方法。
5. **动态引用风险**：低——DialogueBox 是默认 presenter，宿主若直接拿 `runtime.default_presenter` 当控件用可能调它；但未见于文档与两份宿主副本。
6. **删除影响**：极小。
7. **建议**：删除；若保留则应写入 docs/18 协议表（二选一）。
8. **置信度**：高。

### A-13 `DialogueBox._visible_lines` 分页改造残留
1. **位置**：`runtime/ui/dialogue_box.gd:514-515`
2. **用途**：旧布局的可见行数计算。
3. **引用情况**：零调用。分页改造（70f974e）引入 `_page_line/_page_end_line/_measure_line_tops` 新机制后遗留。
4. **为何冗余**：旧实现残留（这正是任务定义的"不再执行的旧逻辑"）。
5. **动态引用风险**：无（测试通过 `call("_page_end_line")` 反射调用新机制，dialogue_pagination_test.gd:62）。
6. **删除影响**：无。
7. **建议**：删除。
8. **置信度**：高。

### A-14 `RuntimeDisplayNames.control_label` 死函数（连带 7 个孤儿词条）
1. **位置**：`runtime/ui/display_names.gd:117-121`；词条 `i18n/ui.csv:850-856`（trace.control.continue/wait/enter_block/call/halt/abort/unknown）
2. **用途**：把 RuntimeTrace._control_name 的控制流枚举译成中文。
3. **引用情况**：函数全仓零调用；`"trace.control."` 前缀拼接**全仓仅此一处**（display_names.gd:120）；trace_debug_view 展示 result 用原始枚举串。词条因此成为孤儿。
4. **为何冗余**：功能被"直接显示英文枚举"取代（或从未接线）。
5. **动态引用风险**：无。
6. **删除影响**：无；删除函数则 7×2=14 个 csv 行一并删（保持 L10n 零空缺承诺由 check_i18n 复验）。
7. **建议**：函数与 7 词条一起删；或者反过来接线到 trace 时间线（产品决策）。
8. **置信度**：高。

### A-15 `L10n.EDITOR_SETTING` 死常量（重复字符串）
1. **位置**：`core/i18n/l10n.gd:13`
2. **用途**：编辑器语言设置键 `"rpg_event_studio/editor_language"`。
3. **引用情况**：零引用；plugin.gd:20 另有一份 `EDITOR_LANGUAGE_SETTING := "rpg_event_studio/editor_language"` 在用。
4. **为何冗余**：同一魔串两处定义，插件入口那份在用、core 这份无人用。
5. **动态引用风险**：无。
6. **删除影响**：无。
7. **建议**：删除 L10n.EDITOR_SETTING；或反向统一（plugin.gd 改用 L10n 常量）——统一更好，但至少删一份。
8. **置信度**：高。

### A-16 `UiFonts.AUX` / `UiFonts.min_readable` 死成员
1. **位置**：`editor/ui_fonts.gd:12`（常量，1 行）、`:17-18`（静态函数，2 行）
2. **用途**：与 NOTE 同值的别名常量；"最小可读字号"查询。
3. **引用情况**：全仓零引用（面板全部用 NOTE）。
4. **为何冗余**：别名无消费者。
5. **动态引用风险**：无。
6. **删除影响**：无。
7. **建议**：删除。runtime_fonts.gd 与 ui_fonts.gd 的常量表重复问题另见 B-15。
8. **置信度**：高。

### A-17 `StudioRuntime.INTERACT_ACTION` 死常量
1. **位置**：`runtime/autoload/studio_runtime.gd:11`
2. **用途**：`&"interact"` 动作名常量。
3. **引用情况**：零引用；动作表以 `InputService.ACTIONS`（input_service.gd:34）为唯一权威。
4. **为何冗余**：早期常量残留，动作名实际由 InputService 定义。
5. **动态引用风险**：无。
6. **删除影响**：无（若宿主曾引用该常量则会有编译错——两份宿主副本无引用）。
7. **建议**：删除。
8. **置信度**：高。

### A-18 `plugin.gd.refresh_event_list` / `open_audit_tab` 死方法
1. **位置**：`plugin.gd:238-240`、`:255-258`
2. **用途**：刷新事件列表 dock；打开审计主屏标签。
3. **引用情况**：零调用。列表刷新实际由防抖回调直接 `_list_panel.call("refresh")`（plugin.gd:233-236）；对称方法 `open_story_tab`（:249）与 `open_theme_page`（:284）在用，audit 页打开实际走审计面板内部跳转。
4. **为何冗余**：未接线的外部入口（曾计划供测试/其他面板调用）。
5. **动态引用风险**：无。
6. **删除影响**：无。
7. **建议**：删除（如后续需要"双击定位到审计页"再按需恢复）。
8. **置信度**：高。

### A-19 `StateLibraryDialog.rename_current` 死方法
1. **位置**：`editor/pickers/state_library_dialog.gd:67-75`
2. **用途**：对当前选中状态改名并落盘。
3. **引用情况**：零调用；改名实际由行内 LineEdit 编辑路径处理（:57-66 附近的 `_flush` 流程）。
4. **为何冗余**：未接线的第二套改名入口。
5. **动态引用风险**：无。
6. **删除影响**：无。
7. **建议**：删除。
8. **置信度**：高。

### A-20 `StoryDocument.collect_texts` 死函数
1. **位置**：`core/model/story_document.gd:531-546`
2. **用途**：递归收集视图内全部台词文本（疑似为字数统计/导出预留）。
3. **引用情况**：仅自递归（:542,544,545），无外部调用。
4. **为何冗余**：无调用者；也未见文档承诺。
5. **动态引用风险**：无。
6. **删除影响**：无；若做"剧情字数统计"功能需重写。
7. **建议**：删除。
8. **置信度**：高。

### A-21 孤儿 i18n 词条 11 个（22 csv 行）
1. **位置**：`addons/rpgeventstudio/i18n/ui.csv:619`（story.where.choice_branch）、`:620`（story.where.then）、`:621`（story.where.else）、`:774`（trace.empty）、`:850-856`（trace.control.* 7 个，随 A-14）
2. **用途**：见 A-14；story.where.* 三个是"插入位置"标签——代码实际显示 `where` 原始值（story_editor_panel.gd:688-689 只用 story.where.page）。
3. **引用情况**：静态拼接点逐一核实为零（2.2 节排除法覆盖全部 14 个动态前缀点）。
4. **为何冗余**：无构造路径即无显示路径。
5. **动态引用风险**：无。
6. **删除影响**：仅 i18n 完整性快照变化（check_i18n 的键数快照需同步，无 counts 依赖）。
7. **建议**：随 A-14 一并删除 11 个键。
8. **置信度**：高。

### A-22 本地未跟踪产物（不属版本库，列出仅为工作区卫生）
1. **位置**：A 副本 12 个 .bak（3.1 节清单）；各 worktree `.godot/` 下的 test_state_catalog.tres.bak / bulk_register_test/*.bak（测试运行残留，.godot 本身 gitignored）；基线工作区 `ui/` 空目录（git 不跟踪空目录，主题保存时 dialogue_theme_view.gd:538 会自动建目录）。
2. **用途**：SafeFile 一代备份 / 测试残留。
3. **引用情况**：无（gitignore 规则覆盖）。
4. **为何冗余**：见 3.1。
5. **动态引用风险**：无。
6. **删除影响**：无。
7. **建议**：可以清理；若不想反复再生，调整 SafeFile 备份保留策略（工程决策）。
8. **置信度**：高。

**A 类合计（已核实行数）**：GDScript 约 **97 行 / 25 处声明**（A-1～A-20 逐项实数：A-1 1 + A-2 1 + A-3 13 + A-4 3 + A-5 9 + A-6 3 + A-7 1 + A-8 2 + A-9 8 + A-10 6 + A-11 1 + A-12 5 + A-13 2 + A-14 5 + A-15 1 + A-16 3 + A-17 1 + A-18 7 + A-19 9 + A-20 16），csv 22 行（11 键 × 双语），涉及 0 个整文件删除。**没有任何一个 A 类项是整文件级死代码**——这本身是重要的审计结论。

---

## 五、B 类：疑似冗余，需要验证/决策

共同特征：有真实或历史价值，不能仅凭"当前无引用"处理。每项附验证路径。

### B-1 plugin.gd 截图脚手架（约 355 行可迁出）
- **位置**：`plugin.gd:46-71`（8 个 SHOT 触发钩子）+ `:488-798` 与 `:830-851` 的截图函数群（_shot_target_size/_focus_main_screen/_apply_shot_window_size/_enforce_shot_size/_save_shot/_capture_viewport/_capture_graph_screen/_capture_dock_screen/_select_dock_tab/_capture_main_tab_screen/_capture_theme_screen/_capture_map_screen/_capture_bulk_screen/_capture_gvl_screen）。
- **用途/引用**：生成 docs/images 全部验收配图；不被 test_runner.py 使用。
- **风险**：SHOT 函数依赖 plugin 内部状态（_main_tabs/_story_view 等）；迁出需保留等效访问路径（EditorInterface 可满足，工作量可控）。
- **删除影响**：不再影响插件运行时（ EditorPlugin 每次启动少加载 355 行逻辑）；但需保留 docs/images 再生能力。
- **建议**：迁出到 `tools/editor_shots.gd`（保留功能），而非删除。**待负责人确认迁出方案。**
- **置信度**：高（事实）；方案中。

### B-2 tools/ 一次性验收截图脚本（7 个 / 683 行 + 7 个 .uid）
- **位置与行数**：ui_round2_shots.gd（241）、dialogue_pagination_shots.gd（116）、capture_bbcode_editor.gd（80）、visual_docs.gd（83）、visual_check.gd（73）、round3_scroll_shots.gd（65）、hardening_shots.gd（25）。
- **引用**：全仓零引用或仅被对应 docs/qa 报告点名一次（round3_scroll_shots→第三轮UI打磨.md:88；dialogue_pagination_shots→DialogueBox分页专项验收.md:160；capture_bbcode_editor→docs/19:56）。
- **性质**：验收轮产物，轮次已冻结；对应验收截图已交付（deliverables/ 有 UI审计包与分页验收 zip + sha256）。
- **风险**：删除后无法原样再生成历史轮截图（但历史轮本就不需要再生成）。
- **建议**：整目录移入 `tools/archive/`（或删除）。**与持续工具严格区分**：check_i18n.gd（197 行，历轮验收都在跑）、check_theme_persist.gd（43）、build_samples.gd（462）、test_runner.py、test_counts.json、blank_install_check.gd 必须保留。
- **置信度**：高。

### B-3 tests/trace_demo.gd + trace_demo.tscn（73 行 + 场景）
- **引用**：除两文件互引外全仓零引用；无自动化入口（不在 test_runner.py 两张套件表、plugin.gd 无钩子、docs/26 与 qa 均未提及）。它是 2026-10-30 硬化轮的一次性截图脚本，产物 `docs/qa/2026-10-30/runtime_trace_sample.json` 与 `docs/images/hardening/runtime_trace.png` 已存在。
- **建议**：归档或删除；若保留，在 tests/README 补一行手动入口说明。
- **置信度**：高。

### B-4 tests/dialogue_layout_test.gd（16 项检查 / 99 行）被完整覆盖
- **证据**：dialogue_pagination_test.gd（163 项）是其严格超集——两文件逐条对应（dialogue_layout_test.gd:40-48 ↔ dialogue_pagination_test.gd:56-63）；《DialogueBox分页专项验收.md:69》自认分页测试是"新增超集"。
- **重要声明**：删除它**不提高**覆盖率（覆盖行为 100% 被 pagination 测试继承），只是消除 16 项双计。test_counts.json 需同步（headless 合计 923→907）。
- **风险**：低；但按任务纪律"不要因为看起来重复就删测试"——本项的超集关系已逐条核对，仍建议由负责人拍板。
- **置信度**：高（超集关系）；删除与否待决。

### B-5 InputService 零调用公开查询方法（6 个）
- **位置**：`core/input/input_service.gd:119`（all_action_entries）、`:137`（has_action）、`:151`（get_axis）、`:174`（device_of）、`:181`（describe_event）、`:579`（dict_to_event）、`:288`（registered_action_ids）。
- **引用**：仓内零调用（`save_bindings` 虽也在"仅本文件"名单，但被 rebind/clear_action 内部调用，非死代码）。宿主 School 实际使用的是 `rebind/same_event/event_to_dict/extend_action_defaults/action_ids/ACTION_*`（School/tools/test_game_input.gd:29-127），不涉及上述 6 个。
- **风险**：InputService 是公开 class_name，宿主可调；describe_event/device_of 是改键 UI 类的自然配套 API。
- **建议**：保留但**补文档**（在宿主接入文档中列明）或标注为内部；不建议删除。`registered_action_ids` 与 `remove_event` 见 C 类。
- **置信度**：高（零引用事实）；处理建议为"留 + 文档"。

### B-6 GraphRunner.node_activated 信号（发射无监听）
- **位置**：`core/graph/graph_runner.gd:7`（声明）、`:105`（发射）。
- **引用**：全仓无 connect；编辑器高亮走 `node_state_changed`（经调试器通道）。docs/06 的信号表也无此信号——它是超出文档承诺的额外可观察点。
- **风险**：公开信号，宿主可连；删掉会破坏潜在订阅。
- **建议**：保留并写入 docs/06 信号表（一分钟文档工作）；或者删除发射点。倾向保留+文档。
- **置信度**：高（事实）。

### B-7 GraphRunner.monitored_keys 查询方法
- **位置**：`core/graph/graph_runner.gd:335-339`。注释自称"编辑器高亮/调试用"，但编辑器实际经 trace/debugger 通道拿数据。
- **建议**：与 B-6 一起决定：作为图内省 API 补文档保留，或删除。
- **置信度**：高（事实）。

### B-8 重复的 float 判等 ×3
- **位置**：story_document.gd:333-336、event_editor_panel.gd:928-931、state_store.gd:209-212。
- **风险**：三份实现相同但独立演化；graph_validator.gd:398-424 的 `_compare_for_satisfy/_loose_eq` 与 state_store.compare 语义重叠且 float 容差不同（absf<0.0001 vs is_equal_approx）——存在语义漂移风险。
- **建议**：重构候选：抽 `core/util` 共享判等；graph_validator 保持静态镜像但容差对齐并注释关联。**不是删除**。
- **置信度**：高。

### B-9 OPS 运算符常量表 ×3
- **位置**：event_editor_panel.gd:26、story_editor_panel.gd:898（内联）、level_graph_view.gd:1591（内联）。
- **建议**：下沉共享（如 EventCondition.OP_CHOICES）。非删除项。
- **置信度**：高。

### B-10 show_choices 分支重建逻辑 ×3
- **位置**：story_document.gd:478-502（_rebuild_choice）、story_editor_panel.gd:1027-1041、story_templates.gd:196-204（_choice_branch）。
- **风险**：三处手写"show_choices + N 条 if @@self.choice"配对，P1-2/P1-3 的块级操作缺陷正源于多副本易漏改。
- **建议**：收敛到 story_document 单点。重构候选。
- **置信度**：高。

### B-11 `@@level.` 前缀解析 ×3
- **位置**：state_store.gd:32-36（权威）、event_context.gd:49-52（委托+@@self）、state_usage_scanner.gd:106-107（静态扫描不可用运行时实例，属合理第三份，但 substr 硬编码重复）。
- **建议**：scanner 侧抽静态纯函数与 store 共享。重构候选。
- **置信度**：高。

### B-12 两个编辑器面板的 16 组重复 UI 助手
- **证据**：见第七节关系图表（A1-A16），含逐字相同的 `_definition_of_node`、`_toast`、`_clear_children`、`_values_equal`、页签重建、保存流程等。
- **建议**：新建 `editor/shared/`（如 PanelKit）下沉；**不合并面板本身**（职责不同）。与 A-3/A-4/A-5 的"死原子方法"二选一联动：要么删方法、要么借重构接线。
- **置信度**：高（逐字对比）。

### B-13 主题加载回退逻辑 ×2
- **位置**：studio_runtime.gd:180-186（运行时）与 dialogue_theme_view.gd:568-573（编辑器）逐行相同。
- **建议**：下沉 `RpgEventStudioTheme.load_or_default(path)` 静态方法。另注意 dialogue_theme_view.gd:541 保存走裸 ResourceSaver（未过 SafeFile），与 SafeFile 写路径纪律不一致（前次审计第七节"两套写路径不一致"的同类项）。
- **置信度**：高。

### B-14 字号常量表双份
- **位置**：editor/ui_fonts.gd:8-14 与 runtime/runtime_fonts.gd:6-11 同名同值（TITLE/SECTION/BODY/BUTTON/NOTE/DEBUG）。
- **说明**：文件头注释声明编辑器/运行时有意隔离（ui_fonts.gd:4-5、runtime_fonts.gd:3-4），**职责切分保留**；但数值是手工同步拷贝，存在漂移风险。AUX/min_readable 已列 A-16。
- **建议**：保留两个类（边界文档化），但让其中一个引用另一个的常量，或以注释互相锚定。
- **置信度**：高。

### B-15 docs/images 约 115 个无文档引用的 png
- **证据**：138 个 png 中约 23 个被 .md 路径引用；零引用集中在 hardening/（16/16）、ui-polish-round1/（14/14）、ui-polish-round2/（27/27）、round3 大部分、rc-2026-10-31 大部分、dialogue-pagination-acceptance 的 1280x820 版本、顶层 4 个（cutscene/event_list/graph_editor_running/interaction_prompt——它们由 visual_check.gd/visual_docs.gd 生成但无 md 引用）。
- **性质**：验收证据链，且 deliverables/ 已有两份 zip 交付包（含 sha256）。
- **建议**：不删除工作区历史；若要精简仓库体积，归档到 release 包后在 .gitignore 排除历史轮目录。**待负责人决定**；本报告仅给出引用关系事实。
- **置信度**：高（逐文件 grep）；引用计数按 md 路径匹配，可能有相对路径写法的漏计，标"约"。

### B-16 StateCatalogBulk._coerce_default 与 StateDefinition.default_of_type 重复
- **位置**：state_catalog_bulk.gd:121-130、state_definition.gd:17-26——同一套 int/float/string/bool 强转两份实现。
- **建议**：bulk 改调 definition 侧静态化后的实现。重构候选。
- **置信度**：高。

### B-17 文档失真（修文档，不是删文档）
- **位置与证据**：
  - `tools/README.md:5-12`：5 个幽灵脚本（check_deps/export_json/import_json/validate_all/package.sh），12 个实际文件未记载；
  - `tests/README.md:64-65`：套件数 11/5，实际 15/6；`:10` MockAdapter/MockClock 不存在；`:27` tests/framework/assert.gd 不存在；`:11` fixtures 结构描述与实际三级目录不符；
  - `docs/07-插件目录结构.md:17`："plugin.gd 当前为占位"（实际 896 行）；目录树缺 core/audit、theme、trace 与 editor 五个面板目录；`:64`、`:130-134` 以现行口吻描述不存在的 check_deps.gd/package.sh；
  - `docs/02:167`："tools/ 提供 export_json/import_json"（不存在）；
  - `docs/09:115`：DoD 引用 check_deps.gd "通过"；`:133-139` 列出 5 个不存在的测试文件；
  - `docs/23:24`："干净环境安装未实现"与实际存在的 blank_install_check.gd 不同步（该脚本本身游离在 test_runner 之外、不在 test_counts.json——建议将其纳入 runner 并回填 counts，见 B-18）。
- **建议**：全部按"修订文档"处理；tools/README 重写为实际清单 + 持续工具/一次性脚本分组。
- **置信度**：高。

### B-18 tools/blank_install_check.gd 游离在标准入口之外
- **证据**：不在 test_runner.py 套件表、不在 test_counts.json、README/tests README/docs 均未提（tools/README 失真的一部分）。80 行，验证空白工程安装/Autoload/降级/最小剧情执行（自带 MiniPresenter）。
- **建议**：纳入 test_runner（新增套件或 --blank 开关）并回填 counts；这正是前次审计第八节"游离在标准入口外"的原话。保留，不删。
- **置信度**：高。

### B-19 School 的 project.godot.bak_pre_rpgeventstudio（独立项目，不修改）
- **性质**：安装插件前的手工备份（差异仅为当前已新增的 autoload/plugin/[rpg_event_studio] 三段）。属独立仓库工作区卫生，本审计不处理，仅记录。
- **置信度**：高。

---

## 六、C 类：应该保留（含"看起来死但必须留"）

| # | 项 | 位置 | 保留理由 |
|---|---|---|---|
| C-1 | `LevelNode.reentry` 字段 | core/model/level_node.gd:11 | docs/13:44 明示"字段预留"；docs/05/06 有完整 QUEUE/RESTART 设计条款。属设计预留，不是死代码 |
| C-2 | `EventBus.custom_signal` + `emit_custom` | core/runtime/event_bus.gd:11,13 | docs/06:33,37 明示为需求 §3.3"游戏信号触发"的宿主落点（游戏代码 emit、事件页订阅）。公开 API，零仓内调用不构成删除理由。注意：事件页 trigger 枚举尚无 "signal" 类型（event_page.gd:7），订阅侧未实现——这是**未完成的功能**而非死接口，删除会关闭需求落点 |
| C-3 | plugin.gd 六个 SELFTEST 钩子 + `_start_*_selftest` 六函数 | plugin.gd:46-67,604-616,800-896 | test_runner.py editor 套件的唯一入口（176 项检查） |
| C-4 | `LevelGraphRunner2D.stop_graph` | runtime/components/level_graph_runner.gd:40 | 前次审计 P0-1 的修复目标（"全仓无调用点，等于没修"）——**该做的是接线（_exit_tree 自动 stop）而不是删除** |
| C-5 | StudioRuntime 宿主 API：`get_graph_runner`(:272)、`state_dump`(:293)、`set_presenter/restore_default_presenter/is_using_default_presenter`、`register_graph`、`trace_*`、`open_input_settings`、`toggle_state_debug/toggle_input_settings` | runtime/autoload/studio_runtime.gd | Autoload `RPGEventStudio` 是宿主接入面；StateStore.dump() 链（:294）同属宿主调试面。宿主 School 已实证消费同类 API |
| C-6 | `InputService.remove_event`(:339)、`registered_action_ids`(:288) | core/input/input_service.gd | remove_event 是 README「已知限制 2」（解除只能按设备整组清理）的单项解除实现——属"等待 UI 接入的已设计 API"；registered_action_ids 是 register_action 配套查询 |
| C-7 | InputService 查询族（B-5 六个） | input_service.gd | 公开 class_name 上的查询 API，宿主可调；建议补文档而非删除 |
| C-8 | `L10n.add_runtime_message` 等词条注入面 | core/i18n/l10n.gd:84 | 注释明示"宿主游戏用"；l10n.gd:20-22 有设计说明 |
| C-9 | `StateStore.strict`(:17) + `SCOPE_*` 常量(:11-13) + `scope_of` | core/state/state_store.gd | strict 在 :202 被读取，是宿主可开启的严格模式开关（`RPGEventStudio.state.strict = true`）；SCOPE_* 是公开键域常量 |
| C-10 | 引擎回调：`_has_main_screen/_get_plugin_name/_get_plugin_icon`、`_has_capture/_capture`、`_initialize`、全部 `_on_*` 信号槽 | plugin.gd、studio_debugger_plugin.gd、capture_bbcode_editor.gd 等 | Godot 按名字隐式调用 |
| C-11 | headless↔editor 成对测试（graph_editor_smoke↔gvl_selftest、trace_ui_test↔trace_editor_selftest、story_audit_test↔story_audit_editor_selftest、ui_smoke↔editor_selftest、run.gd `_test_map_event`↔map_event_editor_selftest） | tests/ | 有意的双层覆盖（headless 对象级 vs 真编辑器环境），README:260 已声明总数含重复。**不合并**——环境不同，缺陷域不同（前次审计三个 P1 恰在编辑器层漏网，反证两层都需要） |
| C-12 | docs/qa 9 份验收报告 + docs/ 26 份设计文档 | docs/ | 历史档案与设计记录；失真处按 B-17 修订，不删除 |

---

## 七、重复实现关系图

```
                        ┌────────────────────────── model 层（唯一实现，无重复）──────────────────────────┐
                        │  EventDefinition/EventPage/EventCommand/EventCondition                         │
                        │  StoryDocument（剧情行视图）/ LevelGraph/LevelNode/LevelGroup                    │
                        │  StateStore（键域/事务/compare 权威）  StateCatalog(+Store/Bulk/Scanner)          │
                        └────────────────────────────────────────────────────────────────────────────────┘
                                ▲                        ▲                          ▲
              ┌─────────────────┴────────┐    ┌──────────┴───────────┐    ┌─────────────┴───────────┐
              │ 事件编辑面板 event_editor │    │ 剧情工作台 story      │    │ 关卡图 level_graph       │
              │ （页/条件/指令树）        │    │ （行视图/花名册/模板） │    │ （GraphEdit/分组/校验）   │
              └──────────────────────────┘    └──────────────────────┘    └─────────────────────────┘
               职责不同 → 不合并。重复的是下面 16 组 UI 助手（B-12，下沉 editor/shared 候选）：

  #   重复物                          位置（story 线 / event 线 / 第三处）
  A1  节点→EventDefinition 解析        story_editor_panel.gd:92-99   ↔ event_editor_panel.gd:108-115（逐字）
  A2  open_from_selection 选择流       story:73-81                   ↔ event:78-92
  A3  当前页 clamp                     story:405-409                 ↔ event:943-947
  A4  页签重建 + 加/删页               story:411-434,1136-1152       ↔ event:343-366,956-974
  A5  保存（ResourceSaver 自路径）      story:1174-1185               ↔ event:1229-1240
  A6  UndoRedo 获取                    story:1201-1204               ↔ event:1203-1206
  A7  _toast                           story:1421-1426（逐字）        ↔ event:1258-1263
  A8  _clear_children/_indent          story:1416-1419/1009-1013     ↔ event:1400-1403/1394-1398（逐字）
  A9  float 判等 ×3                    story_document.gd:333-336     ↔ event:928-931   ↔ state_store.gd:209-212
  A10 _apply_param 撤销回放            story_document.gd:326-331     ↔ event:918-926
  A11 insert/undo 样板 ×2             story_document.gd:207-303     ↔ event:1030-1065
  A12 delete/duplicate/move 命令      story_document.gd:256-303     ↔ event:1078-1131,1175-1201
  A13 选项块重建 ×3                   story_document.gd:478-502     ↔ story:1027-1041 ↔ story_templates.gd:196-204
  A14 条件编辑控件（bool 特判）        story:898-934                 ↔ event:406-446,671-684
  A15 OPS 表 ×3                       story:898（内联）             ↔ event:26      ↔ level_graph_view.gd:1591
  A16 BBCode 预览/警告 UI             story:322-358,781-809         ↔ event:746-798,885-892

  横切重复（各自独立成对）：
  · 主题加载回退 ×2        studio_runtime.gd:180-186 ↔ dialogue_theme_view.gd:568-573   → B-13
  · 条件求值镜像           state_store.compare ↔ graph_validator._compare_for_satisfy（容差不同！）→ B-8
  · 字号常量表 ×2          ui_fonts.gd ↔ runtime_fonts.gd（有意隔离，数值手工同步）            → B-14
  · CSV 校验 ×3            safe_csv.gd ↔ tools/check_i18n.gd:30-47,83-88 ↔ tests/run.gd:565-576
  · 默认值强转 ×2          state_catalog_bulk._coerce_default ↔ state_definition.default_of_type → B-16
  · @@level 前缀解析 ×3    state_store ↔ event_context ↔ state_usage_scanner                    → B-11
```

**明确不合并项**（职责不同，合并即违背任务"不强行合并"约束）：story/map/graph 三面板；StateStore 与 StateCatalog（运行时状态 vs 编辑器登记）；EventRunner 与 GraphRunner（事件流 vs 令牌流）；editor/ui_fonts 与 runtime/runtime_fonts 的类边界（仅同步数值）。

---

## 八、资源依赖关系概览

```
project.godot
 ├─ main_scene ──────────────► samples/scenes/school_demo.tscn
 │                              ├─ ext_resource: demo_theme.tres / demo_camera|demo_hint|demo_hud|player.gd
 │                              ├─ events/: librarian,key_pickup,locked_door,office_desk,classroom_board
 │                              └─ graphs/school_graph.tres（:252）
 ├─ autoload ─────────────────► runtime/autoload/studio_runtime.gd
 └─ editor_plugins ───────────► addons/rpgeventstudio/plugin.cfg → plugin.gd
                                 ├─ load(): event_editor/level_graph/event_list/theme/map/story/audit 七面板
                                 └─ editor/debugger/studio_debugger_plugin.gd
samples/scenes/map_events_demo.tscn ──► events/: map_region_demo,key_pickup,locked_door,office_desk,classroom_board + librarian
samples/events/basement_cutscene.tres ──► audio/beep.tres（sound_path）; school_graph.tres:103 ──► basement_cutscene（event_path）
core/theme/dialogue_theme.gd ◄── school_demo 场景主题; res://ui/rpgeventstudio_theme.tres（**当前不存在**，运行时回退默认，主题页保存时按需创建 ui/ 目录）
state/state_catalog.tres ◄── StateCatalogStore.DEFAULT_PATH; build_samples.gd:39 再生成
tests/fixtures/{audit,bulk_scan,fonts} ◄── story_audit_test / state_bulk_register_test / dialogue_pagination_test（目录扫描与显式路径）
tools/*.gd 截图脚本 ──► docs/images/**（单向写出；其中约 115 个 png 无任何 .md 反向引用 → B-15）

.gitkeep 占位目录 12 个：7 个纯空（core/adapters、core/save、editor/command_editors、editor/plugin、
editor/inspectors、editor/i18n、editor/themes）＋ 5 个已承载实文件（debugger、level_graph、pickers、graph、samples/graphs）
→ 纯占位 7 个对应 docs/07 规划结构位；docs/07 同时记载了从未实现的 tools 脚本，规划与现状已脱节 → 与 B-17 一并决策
```

孤儿资源结论：**addons/ 与 ui/、state/ 下没有零引用资源**；samples 全部被场景/图/测试/生成器引用；docs/images 是唯一成规模的"写出后无读者"资源集合。

---

## 九、目录精简方案（建议，未实施）

按风险从低到高，每步独立可回退：

| 步 | 内容 | 形式 | 预计收益（已核实） |
|---|---|---|---|
| 1 | 执行 A 类清单（A-1～A-21） | 行级删除 + 修订 test_counts 无关（i18n 键数快照若 check_i18n 有基线需同步） | -97 行 GDScript、-22 csv 行、-11 个词条 |
| 2 | plugin.gd 截图脚手架迁出（B-1） | 移动到 `tools/editor_shots.gd`（保留功能） | plugin.gd 896→约 540 行；插件入口恢复单一职责 |
| 3 | tools 一次性脚本归档（B-2）+ trace_demo（B-3） | 移入 `tools/archive/`（或删除，二选一由负责人定） | -7 文件 -7 .uid -683 行；tests -2 文件 -73 行 |
| 4 | 文档修订（B-17） | 重写 tools/README、更新 tests/README、修正 docs/02/07/09/23 失真句 | 消除 5 幽灵脚本记载与全部"已实现"假陈述 |
| 5 | blank_install_check 纳入 runner（B-18） | test_runner.py 增条目 + counts 回填 | 消除游离入口 |
| 6 | dialogue_layout_test 合并决策（B-4） | 删除或标注子集关系 | 若删：-16 项双计（923→907，需同步 counts 与 README） |
| 7 | B 类重构批（B-8～B-14、B-16） | 下沉共享，不改行为 | 独立批次，不与本审计混提 |
| 8 | docs/images 历史轮归档（B-15） | 归档至 release 包 + .gitignore（若负责人同意） | 仓库体积收益（png 为二进制，行数无意义） |

**明确不做**：合并任何职责不同的 Manager/Service/Store；删除任何公开 API（C-2/C-4～C-9）；删除 .gitkeep 规划目录（除非先修订 docs/07 结构承诺）；清理 School/GamePrototype（独立项目，仅记录漂移）。

---

## 十、预计精简收益（只统计已核实数据）

| 口径 | 数值 | 依据 |
|---|---|---|
| A 类代码删除 | **约 97 行 GDScript**（25 处声明）+ 22 行 csv（11 键×双语） | 第四节逐项行数 |
| A 类整文件删除 | **0 个** | 无整文件级死代码 |
| 本地未跟踪产物清理 | 14 处（A 副本 12 个 .bak + ui/ 空目录 + .godot 残留类） | 3.1 节逐项比对 |
| B-1 迁出（非删除） | plugin.gd **-355 行**（896→约 540） | 488-896 节 409 行 − 6 个 selftest 启动器 80 行 + 46-71 钩子 26 行 |
| B-2/B-3 归档 | **-9 文件**（7 工具 + 7 .uid 中成对的 7 个 uid + trace_demo×2 计 2 文件……准确为：tools 7 脚本 + 7 uid = 14 文件，tests 2 文件）与 **-756 行**（683+73） | wc -l 实测 |
| B-4 合并（待决） | -1 文件 -99 行 -16 项双计 | dialogue_layout_test.gd |
| B-15 归档（待决） | 最多 -115 个 png | 第八节引用清点 |
| 合计（不含待决项） | 代码行 **约 -1,208 行**（97+355+683+73），文件数最多 **-17**（14 tools + 2 tests + 1 tests uid 并入），词条 -11 | 上表合计；不含 png 与本地产物 |

说明：以上均为"已核实"口径——行数来自 wc -l 与源码逐项计数；"待验证/待决"项（B-4、B-15）单列不计入合计。**本审计没有把任何有效功能计入可删行数**；A 类 97 行全部是零引用声明。

---

## 十一、自检清单（对照任务"特别禁止"逐条）

| 禁止项 | 自检结果 |
|---|---|
| 为减少行数删除有效功能 | A 类 25 处全部为零引用声明；A-3/A-4/A-5 因"可作为重构基座"同时给出保留选项 |
| 为消除未使用警告删除公开 API | C-2/C-4～C-9 全部保留；B-5 六个公开方法建议"留+补文档" |
| 把设计预留误判为死代码 | LevelNode.reentry（C-1，docs/13 明示预留）、EventBus.custom_signal（C-2，docs/06 需求落点）均归 C；.gitkeep 规划目录不做删除建议 |
| 强行合并模块 | 第七节明确列出 5 组"明确不合并"边界；重复处理一律走"下沉共享"而非合并 |
| 删除测试后宣称覆盖率提高 | B-4 明确写"删除不提高覆盖率，仅消除 16 项双计"；C-11 双层测试全部保留 |
| 未经确认批量清理备份/历史文件 | .bak 仅列为 A-22"本地未跟踪产物"建议项；docs/images 历史轮归档列为待决（B-15）；本轮未删任何文件 |
| 影响宿主接入/插件扩展 | 宿主实际消费面（School/tools/test_game_input.gd、project.godot [rpg_event_studio] 段）逐一核对，无一在 A 类清单内 |
| 混合第一轮 P0/P1 修复 | 本报告为独立文档；A-22 与 C-4（stop_graph 接线）已显式标注属修复批事项 |

---

## 附：复核待办（负责人审阅时建议优先看的 5 个决策点）

1. **B-1**：plugin.gd 截图脚手架迁出方案（迁 tools/ 保留功能 vs 就地保留）。
2. **B-4**：dialogue_layout_test.gd 是否随 counts 同步合并删除。
3. **B-2/B-3**：tools 一次性脚本与 trace_demo 归档位置（tools/archive/ vs 直接删除）。
4. **B-15**：docs/images 历史轮 png 是否归档出库。
5. **A-3/A-4/A-5 × B-12**：死原子方法与面板助手下沉是"删旧"还是"接线统一"——影响 P2-6（页面级撤销缺口）的修复路径选择。
