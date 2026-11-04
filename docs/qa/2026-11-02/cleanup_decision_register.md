# RPGEVENTSTUDIO 清理决策登记表（Cleanup Decision Register）

- **日期**：2026-11-02
- **依据**：《死代码与冗余专项审计报告》（docs/qa/dead_code_and_redundancy_audit.md，基线 `9fd3308`）+ 负责人审阅意见的 6 项分类校正
- **状态**：**待负责人确认，未实施任何源码修改**
- **动词约定**：DELETE＝真删除｜KEEP＝保留｜REWIRE＝保留并接线（修复半成品）｜DEPRECATE＝标记保留一个发布周期后再删｜ARCHIVE＝移入 archive/ 子目录（文件保留在 Git）｜MOVE＝迁出（仓库行数守恒）｜REFACTOR＝独立重构批次（行为不变）
- **本轮不重扫全仓**：全部新证据为针对 6 个复核点的定点取证，行号均可回源复核

---

## 〇、分类校正摘要（与原报告的差异）

| 原编号 | 原判定 | 修正判定 | 触发校正的证据 |
|---|---|---|---|
| A-3（EventPage.remove/move_command） | DELETE | **REWIRE**（并补充 insert_command 入组） | P1-1/P2-6 的撤销缺口正需要这组原子操作作基座；且原报告因同名碰撞漏判了 insert_command（event_page.gd:33-36 同样零调用） |
| A-4（EventCommand.set_param） | DELETE | **REWIRE** | 同上，参数编辑撤销统一基座 |
| A-5（EventDefinition.add/remove_page） | DELETE | **REWIRE** | P2-6 删页无撤销的直接修复基座（见 R3 依赖说明） |
| A-8（EventContext.has_state） | DELETE | **KEEP** | ctx 便捷层 CRUD 族（get/set/compare 在用）的缺失件；自定义指令作者的自然入口；保留成本 2 行 |
| A-10（is_cancelled） | DELETE | **KEEP**（误判） | **docs/04:86**"长循环的 handler 必须在循环内查 `ctx.is_cancelled()`"、**docs/04:102** ctx 契约图明列该方法——文档化 API，不是死代码 |
| A-10（take_logs） | DELETE | DELETE（维持，范围收窄） | docs/04 只承诺 `log(msg)` 打印行为，未承诺取回缓冲；删除时连带 `_logs` |
| A-12（DialogueBox.hide_text） | DELETE | **KEEP + 补文档** | 公开 Presenter 类方法，宿主可经 `runtime.default_presenter` 触达；与 close_all 语义不同（动画隐藏文本面板，不触碰选项与回调） |
| A-14（control_label + trace.control.* 7 键） | DELETE | **REWIRE** | 命令级控制流结果**当前有显示**：trace_debug_view.gd:508-513 `_result_label` 对 `trace.result.*` 未命中的值走 fallback 显示英文原始枚举；7 键 + 函数是为该处准备但从未接线的中文化 |
| A-15（L10n.EDITOR_SETTING） | DELETE | **REFACTOR**（二保一） | 更优解是 plugin.gd 改引 L10n 常量，净删除为零 |
| A-17（StudioRuntime.INTERACT_ACTION） | DELETE | **DEPRECATE** | Autoload 成员是插件最外层宿主可见面，按 2.3 原则降级观察一周期 |
| A-20（StoryDocument.collect_texts） | DELETE | **DEPRECATE** | 公开静态方法（宿主可达），虽未记载仍保守处理 |
| A-6（LevelNode.duplicate_node） | DELETE | **DEPRECATE** | 公开模型方法；节点复制属自然扩展点 |
| A-7（EventContext.locals） | DELETE | **DEPRECATE** | **docs/04:97 ctx 契约图明列 `locals: Dictionary`**——删除前须先修文档（图与实现二选一） |
| A-21（story.where.* 3 键） | DELETE | **REWIRE（可选）** | 与 control_label 同模式：预翻译键、现显示原始 where 值（story_editor_panel.gd:688-689 只用 story.where.page） |

未变动的原判定：A-1/A-2（见下文兼容性论证）、A-9、A-11、A-13、A-16、A-18、A-19、A-21 中 trace.empty、A-22、全部 B/C 类（除统计口径）。

---

## 一、可见性基线（复核点 6：A 类对象所属类型逐一核对）

| 类型分层 | 成员 | 宿主可达性 | 对原 A 类的影响 |
|---|---|---|---|
| Autoload（最强宿主可见面） | StudioRuntime（`RPGEventStudio`） | 运行时全局单例 | A-17 降级 DEPRECATE；get_graph_runner/state_dump 维持 KEEP |
| class_name 全局注册（编译期可达） | EventPage、EventCommand、EventDefinition、LevelNode、EventContext、StateStore、DialogueBox、RuntimeDisplayNames、L10n、StoryDocument、UiFonts、StateLibraryDialog（均已 grep 确认 `^class_name`） | 任何脚本可直接引用 | 下划线私有成员（_visible_lines、_pending_new）不属 API，DELETE 维持；公开成员逐项重判（见登记表） |
| 公开 Resource（可出现在宿主 .tres） | EventPage、EventCommand、EventDefinition、LevelNode、EventPage.conditions/commands 数组 | 序列化面 | @export 字段删除有数据兼容维度（见 D1/D2 论证） |
| EditorPlugin 入口脚本（**非 class_name**） | plugin.gd | 仅编辑器进程；宿主不可达；面板经 bind_plugin 持实例引用 | refresh_event_list/open_audit_tab 的 DELETE 维持（可达面仅限编辑器内部，且已证零调用） |
| 编辑器对话框 | StateLibraryDialog 等 pickers | 仅编辑器进程实例化 | rename_current 的 DELETE 维持 |
| 引擎回调（虚方法） | _has_main_screen 等 | 引擎隐式调用 | 原 2.2 节已排除，维持 KEEP |

**2.3 原则的落实方式**：对公开类型成员，本登记表不使用"仓库内零引用"单独判死；每一项 DELETE/REWIRE/DEPRECATE 均附带至少两类佐证——（a）两个现存宿主项目（School、GamePrototype）的定点 grep 零使用；（b）docs/ 契约文档未记载或明示相反；（c）被更优实现结构化取代。插件当前 v0.1.0、qa 报告载明"未发布、未合并 main"，外部未知使用集按空集处理，但每一项都标注了"若已外发则升级为 DEPRECATE"的条件。

---

## 二、决策登记表

### 2.1 REWIRE（保留并接线——半成品功能补完，行为增强）

#### R1 ｜ EventPage 指令原子操作族：insert_command / remove_command / move_command（原 A-3，扩展）
- **位置**：`core/model/event_page.gd:33-36`（insert）、`:38-42`（remove）、`:44-51`（move）
- **理由**：三者是带 `emit_changed()` 的小步变更 + 可被 `undo.add_do_method/add_undo_method` 直接调用的形状，正是 P2-6（event_editor_panel.gd:956-1002 删指令/加条件/页触发器/重复策略无撤销）需要的统一 UndoRedo 基座。原报告只判 remove/move 死、漏判 insert（与 StoryDocument.insert_command 同名碰撞所致），现整族一并处理。
- **依赖**：event_editor_panel 删/移/插指令路径改为 `undo.add_do_method(page, "remove_command", idx)` 模式；与 F5（面板助手下沉）联动时可减一份样板。
- **风险**：低。方法本身已存在且语义正确；接线只改编辑器内部路径。
- **对应测试**：tests/editor_selftest.gd（撤销/重做往返，现 19 项）+ tests/run.gd `_test_nested_serialization`（序列化回归）+ 建议在 editor_selftest 增补"删指令→Ctrl+Z→列表复原"断言。
- **补充依赖（P2-6 的条件编辑部分）**：EventPage 目前**没有**条件级原子操作（conditions 数组无 insert/remove_condition）——接线时需按同型补 2 个方法，属新增而非删除。

#### R2 ｜ EventCommand.set_param（原 A-4）
- **位置**：`core/model/event_command.gd:16-18`
- **理由**：参数编辑撤销（event_editor_panel.gd:918-926 `_apply_param` 模式）的标准变更入口；与 P1-1（level_graph_view 图参数撤销登记新值的缺陷）同型——统一走 set_param 可防止下一处 `_apply_param` 复制走样。
- **依赖**：event_editor_panel 参数编辑 do/undo 改调 `command.set_param`。
- **风险**：低（set_param 含 emit_changed，与现行为等价）。
- **对应测试**：editor_selftest.gd 撤销往返。

#### R3 ｜ EventDefinition.add_page / remove_page（原 A-5）
- **位置**：`core/model/event_definition.gd:31-35`、`:37-40`
- **理由**：P2-6"删页无撤销"（event_editor_panel.gd:956-974、story_editor_panel.gd:1136-1152）的修复基座。
- **依赖（重要）**：`add_page` 只能尾部追加，undo"恢复被删页"需要**任意位插入**——接线时须补 `insert_page(index, page)`（或 add_page 加 index 参数）。这是本项 REWIRE 的前置小改动。
- **风险**：低。
- **对应测试**：editor_selftest.gd + ui_smoke.gd（56 项面板冒烟）+ 建议增补"删页→Ctrl+Z→页数复原"断言。

#### R4 ｜ RuntimeDisplayNames.control_label + trace.control.* 7 词条（原 A-14）
- **位置**：`runtime/ui/display_names.gd:117-121`；`i18n/ui.csv:850-856`
- **理由（新证据，支持负责人判断）**：命令级控制流结果**已在 F2 时间线显示**，但走的是 `_result_label`（trace_debug_view.gd:508-513）的 fallback 分支——因为 `trace.result.continue/wait/…` 键不存在，实际显示英文原始枚举（"continue"/"wait"/…）。`trace.control.*` 7 键双语齐全、`control_label` 正确实现了"miss 即回退原文"语义——这是为该显示点准备但从未接线的中文化。接线点：`_result_label`/`:433 _result_text_for` 增加命令级记录分支（或 `RuntimeTrace._control_name` 值域路由）。
- **依赖**：RuntimeTrace._control_name 的值域（runtime_trace.gd:414-423：continue/wait/enter_block/call/halt/abort/unknown）与 7 键名完全一致，无数据改动。
- **风险**：低（纯显示层；miss 回退已内建）。
- **对应测试**：tests/trace_ui_test.gd（21 项）建议增补 1 条"命令行 result 为中文/回退原文"断言；tests/run.gd `_test_l10n` 保证键完整。

#### R5 ｜ L10n.EDITOR_SETTING 与 plugin.gd.EDITOR_LANGUAGE_SETTING 统一（原 A-15）
- **位置**：`core/i18n/l10n.gd:13`、`plugin.gd:20`（同一字符串 `"rpg_event_studio/editor_language"`）
- **理由**：统一优于删除——plugin.gd 改引 `L10n.EDITOR_SETTING`，删 plugin.gd 侧副本。魔串收敛到 core 单点。
- **依赖**：无。
- **风险**：极低。
- **对应测试**：编辑器自测启动即覆盖（plugin.gd 被任何 editor 套件加载）。

#### R6 ｜ story.where.choice_branch / then / else 3 词条（原 A-21 部分，可选）
- **位置**：`i18n/ui.csv:619-621`；现显示点 `editor/story/story_editor_panel.gd:688-689`
- **理由**：与 R4 完全同模式——插入位置标签对 choice_branch/then/else 三种取值显示原始英文 token，预翻译键已备好未接线。
- **依赖**：story_editor_panel 取 where 标签处改为查表。
- **风险**：极低。
- **对应测试**：story_editor_selftest（editor.story 20 项）。
- **备注**：优先级低于 R4（F2 面向玩家/验收，插入位置标签面向创作者）；若产品认为原始 token 可接受，可降级 DELETE（与 trace.empty 同批）。

### 2.2 DELETE（真删除——已按可见性原则重新核准）

#### D1 ｜ EventPage.priority（原 A-1）
- **位置**：`core/model/event_page.gd:12`
- **理由**：零引用 + 优先级语义由页序承担（README、event_runner 选页遍历）；**兼容性专项核实（复核点 3）**：基线全部 .tres 样本、School、GamePrototype 的全部 .tres 均无 `priority` 字段数据（grep 已验）；插件未发布。Godot 4 对 .tres 中未知属性行为＝加载时告警、下次编辑器保存丢弃该行，不会崩溃或损坏其余数据。
- **依赖**：无。
- **风险**：仅存在于"本工作区之外的手写 .tres"——若插件曾外发，升级为 DEPRECATE 一周期。
- **对应测试**：tests/run.gd `_test_nested_serialization` + `build_samples.gd` 重新生成冒烟（全样本加载）。

#### D2 ｜ EventPage.trigger_params（原 A-2）
- **位置**：`core/model/event_page.gd:8`
- **理由/依赖/风险/测试**：同 D1（同一序列化兼容论证，grep 零数据）。

#### D3 ｜ StateStore._pending_new（原 A-11）
- **位置**：`core/state/state_store.gd:26`。**私有成员**（下划线约定，不属 API 面），零读写；对照 `_pending_old`（:27）有完整读写。
- **风险**：无。**对应测试**：run.gd `_test_state_store`（123 项，事务路径全覆盖）。

#### D4 ｜ DialogueBox._visible_lines（原 A-13）
- **位置**：`runtime/ui/dialogue_box.gd:514-515`。**私有成员**，分页改造（70f974e）后的旧布局残留，被 `_page_line/_page_end_line` 机制取代。
- **风险**：无（测试反射调用的是新机制：dialogue_pagination_test.gd:58-62）。
- **对应测试**：dialogue_pagination_test.gd（163 项）+ dialogue_layout_test.gd（16 项）。

#### D5 ｜ EventContext.resolve_node（原 A-9）
- **位置**：`core/runtime/event_context.gd:150-157`
- **可见性论证**：EventContext 是 class_name（宿主可达），但 resolve_node **未列入 docs/04:94-107 的 ctx 契约图**；其职责已被同文件 `resolve_scene_object`（:130-146，结构化返回 + wrong_scene/not_found 诊断）取代——这是任务定义的"旧实现与新实现并存"。两个宿主零使用。
- **风险**：低；自定义指令若需节点解析应走 resolve_scene_object/resolve_player/resolve_camera。
- **对应测试**：run.gd `_test_give_key_flow`、`_test_map_event`、tests/interaction_test.gd（覆盖全部实际节点解析路径）。

#### D6 ｜ EventContext.take_logs + `_logs` 缓冲（原 A-10 收窄）
- **位置**：`core/runtime/event_context.gd:192-195`（take_logs）、`:24`（_logs 声明）、`:198`（log() 内 append）
- **理由**：docs/04 ctx 契约只承诺 `log(msg)`（:105），未承诺日志取回；take_logs 零调用使 `_logs` 成为只增不读缓冲（每个 ctx 生命周期内无界增长）。
- **依赖**：log() 保留打印行为（OS.is_debug_build 分支），仅删 append 与缓冲；**is_cancelled 保留**（见 K2）。
- **风险**：低。
- **对应测试**：run.gd `_test_event_diagnosis`（诊断路径不受影响）。

#### D7 ｜ plugin.gd.refresh_event_list / open_audit_tab（原 A-18）
- **位置**：`plugin.gd:238-240`、`:255-258`
- **可见性论证**：plugin.gd 是 EditorPlugin 脚本，**无 class_name，宿主不可达**；编辑器内可达面（bind_plugin 引用的面板）已证零调用（列表刷新走防抖直调 :233-236，审计页打开走面板内部路径）。
- **风险**：无。**对应测试**：editor_selftest（加载 plugin.gd）+ event_list_smoke（13 项）。

#### D8 ｜ StateLibraryDialog.rename_current（原 A-19）
- **位置**：`editor/pickers/state_library_dialog.gd:67-75`
- **可见性论证**：编辑器对话框，仅编辑器进程实例化；改名实际走行内 LineEdit → `_flush` 路径（:57-66）。
- **风险**：极低。**对应测试**：ui_smoke.gd + state 套件（对话框构建冒烟）。

#### D9 ｜ UiFonts.AUX / min_readable（原 A-16）
- **位置**：`editor/ui_fonts.gd:12`、`:17-18`
- **理由**：编辑器字号工具类上的零引用别名（面板全用 NOTE）；虽是 class_name，但成员与任何宿主场景无交集（编辑器排版常量）。
- **风险**：极低。**对应测试**：编辑器自测启动。

#### D10 ｜ 词条 trace.empty（原 A-21 部分）
- **位置**：`i18n/ui.csv:774`
- **理由**：全仓无构造点（2.2 节对全部 14 个动态前缀拼接点逐一排除）；F2 视图当前无空态文案显示逻辑。与 story.where.* 不同（后者有明确显示点等待接线），此键连显示场景都不存在。
- **风险**：无。**依赖**：check_i18n 键数快照同步（875→874，连同 R6 若删则 871）。
- **对应测试**：tools/check_i18n.gd。

### 2.3 DEPRECATE（标记保留一个发布周期，本轮不动代码）

#### P1 ｜ StudioRuntime.INTERACT_ACTION（原 A-17）
- **位置**：`runtime/autoload/studio_runtime.gd:11`
- **理由**：Autoload 成员是插件最强宿主可见面。两宿主零使用 + 动作权威在 `InputService.ACTIONS`（input_service.gd:34）+ 未记载 → 可删，但按 2.3 原则观察一周期（成本 1 行）。
- **依赖**：无。**风险**：极低。**对应测试**：run.gd `_test_input_service`/`_test_input_registry`。
- **升级条件**：发布宿主接入文档时直接改为 DELETE 并从文档中除名。

#### P2 ｜ StoryDocument.collect_texts（原 A-20）
- **位置**：`core/model/story_document.gd:531-546`
- **理由**：公开 class_name 上的静态工具（仅自递归、无调用者、无文档承诺）；宿主理论上可用于文本提取，观察一周期（16 行）。
- **对应测试**：run.gd `_test_story_document_*` 三件套。

#### P3 ｜ LevelNode.duplicate_node（原 A-6）
- **位置**：`core/model/level_node.gd:40-42`
- **理由**：公开模型方法；图节点复制是 docs/05 语义内的自然扩展点，零引用但保留成本低（3 行）。
- **对应测试**：graph_editor_gvl_selftest（64 项）。

#### P4 ｜ EventContext.locals（原 A-7）
- **位置**：`core/runtime/event_context.gd:16`
- **理由**：**docs/04:97 ctx 契约图明列 `locals: Dictionary`**——文档与实现冲突：实现侧 `@@self.X` 实际落 StateStore 的 `Local.<event_id>.X` 域（event_context.gd:49-52），字段零读写。处置：先修 docs/04（从图中删去或注明"未实现，走 StateStore Local 域"），下一周期删字段。
- **依赖**：docs/04 修订（属 B-17 文档批）。
- **对应测试**：run.gd `_test_state_store`（Local 域行为不依赖该字段）。

#### P5 ｜ 本地未跟踪产物（原 A-22，不计入 Git 收益）
- **清单**：A 副本 12 个 .bak（3.1 节比对表）、各 worktree `.godot/` 测试残留、基线工作区 `ui/` 空目录（git 不跟踪，主题保存时 dialogue_theme_view.gd:538 自动重建）。
- **处置**：工作区卫生操作，与 Git 仓库清理**解耦**，不进任何删除批次、不计入精简收益。若嫌 SafeFile 一代备份反复再生，调整 SafeFile 保留策略（工程决策，另行立项）。

### 2.4 KEEP（保留——含三处原 A 类改判）

| # | 项 | 位置 | 理由 | 对应测试 |
|---|---|---|---|---|
| K1 | EventContext.has_state（原 A-8） | event_context.gd:60-61 | ctx CRUD 便捷族（get_state/set_state/compare_state 在用）的第四件；docs/04 ctx 表未列，随 B-17 补文档；自定义指令作者的自然入口；成本 2 行 | 可在 run.gd 补 1 条存在性断言防回归 |
| K2 | EventContext.is_cancelled（原 A-10 部分，**原判死系误判**） | event_context.gd:179-180 | **docs/04:86 明文"长循环的 handler 必须在循环内查 ctx.is_cancelled()"、:102 契约图明列**。内置 handler 不调用是因为 runner 在调用前后统一检查；宿主自定义长循环指令必须使用它 | 无需 |
| K3 | DialogueBox.hide_text（原 A-12） | dialogue_box.gd:276-280 | 默认 Presenter 公开方法，宿主经 `runtime.default_presenter`/set_presenter 可触达；与 close_all（:399-411，杀 tween+隐藏面板与选项+清按钮）语义不同：hide_text 是**仅文本面板的动画隐藏**，不触碰选项区与回调。处置：保留并在 docs/18 可选方法清单（close_all/fade_to/clear_fade）补记 hide_text | dialogue_pagination_test（现有行为回归） |
| K4 | LevelNode.reentry | level_node.gd:11 | docs/13:44 明示"字段预留"；维持原 C-1 | 无 |
| K5 | EventBus.custom_signal/emit_custom | event_bus.gd:11,13 | docs/06:33,37 需求 §3.3 宿主信号落点；维持原 C-2 | 无 |
| K6 | 原报告全部 C 类（stop_graph、宿主 API 面、SELFTEST 钩子、双层测试、引擎回调、文档档案） | 见原报告第六节 | 维持 KEEP；其中 stop_graph 的接线属 P0-1 修复批，不属清理批 | 对应各套件 |
| K7 | InputService 查询族（B-5 六方法）+ remove_event/registered_action_ids | input_service.gd:119,137,151,174,181,288,339,579 | 公开 class_name API；School 实证消费同类面（rebind/extend_action_defaults/action_ids）；remove_event 是 README 已知限制 2 的单项解除实现。处置：保留 + 随宿主接入文档补 API 表 | runtime_trace_test/interaction_test/integration_demo 覆盖输入链路 |

### 2.5 ARCHIVE（文件保留在 Git，移入 archive/ 子目录）

| # | 项 | 数量（统一口径） | 说明 | 对应测试 |
|---|---|---|---|---|
| A-01 | tools 一次性截图脚本（B-2）：ui_round2_shots / dialogue_pagination_shots / capture_bbcode_editor / visual_docs / visual_check / round3_scroll_shots / hardening_shots | **7 脚本 + 7 .uid = 14 文件 / 683 行** → `tools/archive/` | 验收轮已冻结、对应截图已交付（deliverables/ 双 zip + sha256）；持续工具（check_i18n/check_theme_persist/build_samples/test_runner/test_counts/blank_install_check）**不入档** | 无（移位后跑一遍 test_runner --headless 确认无路径依赖） |
| A-02 | tests/trace_demo.gd + trace_demo.tscn（B-3） | **2 文件 / 73 行** → `tests/archive/` | 2026-10-30 硬化轮一次性截图脚本；其产物 runtime_trace_sample.json 在 qa 留档，脚本保留可追溯 | 无 |

**B-2/B-3 合计：16 文件 / 756 行**（修正原报告"-9 文件"的含混口径）。

### 2.6 MOVE（迁出，仓库行数守恒）

| # | 项 | 说明 |
|---|---|---|
| M1 | plugin.gd 截图脚手架 → `tools/editor_shots.gd`（B-1） | 范围：`plugin.gd:46-71` 的 8 个 SHOT 钩子（6 个 SELFTEST 钩子**留在原地**，它们是 test_runner editor 套件入口）+ `:488-798`/`:830-851` 的 14 个截图函数；合计约 **355 行**。plugin.gd 896 → 约 541 行，恢复纯插件入口职责。迁出后必须验证：docs/images 再生能力不变（任跑一个 SHOT 钩子冒烟） |

### 2.7 REFACTOR（独立重构批，行为不变，不与本轮清理混提）

| # | 项 | 内容 |
|---|---|---|
| F1 | float 判等 ×3（B-8） | story_document.gd:333 / event_editor_panel.gd:928 / state_store.gd:209 下沉共享；graph_validator._compare_for_satisfy 容差对齐（absf<0.0001 vs is_equal_approx） |
| F2 | OPS 表 ×3（B-9） | event_editor_panel.gd:26 / story_editor_panel.gd:898 / level_graph_view.gd:1591 下沉 |
| F3 | 选项块重建收敛（B-10） | story_document.gd:478 / story_editor_panel.gd:1027 / story_templates.gd:196 收敛到单点（P1-2/P1-3 修复的顺势前置） |
| F4 | @@level 前缀解析共享（B-11） | state_store ↔ state_usage_scanner 的 substr 硬编码统一 |
| F5 | 面板助手下沉 editor/shared（B-12） | 16 组（原报告第七节 A1-A16）；与 R1-R3 联动可减样板 |
| F6 | 主题加载回退下沉（B-13） | studio_runtime.gd:180-186 ↔ dialogue_theme_view.gd:568-573 合一；顺带归一 :541 的裸 ResourceSaver 写路径 |
| F7 | 字号常量表锚定（B-14） | ui_fonts ↔ runtime_fonts 数值互引或注释锚定（类边界保留） |
| F8 | 默认值强转合一（B-16） | state_catalog_bulk._coerce_default ↔ state_definition.default_of_type |
| F9 | EDITOR_SETTING 统一（＝R5，归入重构批执行） | plugin.gd 引 L10n 常量 |

### 2.8 待负责人单独拍板（不进默认批次）

| # | 项 | 决策点 |
|---|---|---|
| V1 | B-4 dialogue_layout_test.gd（16 项） | 删除（被 pagination 测试 163 项完整包含，删除不提高覆盖率、仅消除双计，counts 923→907）或保留并标注子集关系 |
| V2 | B-15 docs/images 历史轮约 115 个 png | 归档出库（deliverables 已有 zip 证据链）或维持现状 |
| V3 | B-17 文档修订批 | tools/README 重写、tests/README 更新、docs/02:167 / 07:17,64,130 / 09:115,133-139 / 23:24 失真句修订（P4 的 docs/04 locals 修订并入） |
| V4 | B-18 blank_install_check.gd | 纳入 test_runner 套件并回填 counts（工具本身保留） |

---

## 三、统计修正（区分 DELETE / MOVE / ARCHIVE；本地产物不计入）

| 处置 | Git 仓库效果 | 已核实的量 |
|---|---|---|
| **DELETE（本轮）** | 行级删除，行数真实减少 | GDScript **38 行**（D1 2 + D3 1 + D4 2 + D5 8 + D6 6 + D7 7 + D8 9 + D9 3）+ csv **2 行**（D10）。较原报告 97 行下调 61%——差额 59 行转入 REWIRE（13+3+9+5+3，其中 5 为 control_label）与 KEEP（2+2+5=9）/ REFACTOR（1）/ DEPRECATE（21） |
| **DEPRECATE（观察期保留）** | 本轮 0 删除；一周期后再删 | **21 行**（P1 1 + P2 16 + P3 3 + P4 1） |
| **REWIRE** | 本轮 0 删除，净增少量接线代码与新断言 | 保留 26 行既有代码 + 7+3 词条；新增：EventPage 条件级原子操作 ×2、EventDefinition.insert_page ×1 |
| **MOVE** | 行数守恒 | plugin.gd -355 行 / tools/editor_shots.gd +355 行 |
| **ARCHIVE** | 文件保留在 Git | **16 文件 / 756 行**（B-2 14 文件 683 行 + B-3 2 文件 73 行）移位 |
| **本地产物（P5）** | **不计入 Git 精简收益**（全部未跟踪） | 14 处：12 个 .bak + ui/ 空目录 + .godot 残留类 |
| **词条净变化** | i18n | 本轮 DELETE 仅 trace.empty（1 键/2 行）；story.where.*（3 键）与 trace.control.*（7 键）随 REWIRE 保留 |

---

## 四、执行顺序建议（批次隔离）

1. **批 1（纯删除）**：D1-D10——零行为变更，跑全量 test_runner（923+176 项）+ check_i18n 键数快照同步即可验收。
2. **批 2（MOVE + ARCHIVE）**：M1 + A-01 + A-02——位置变化，验收＝test_runner 全绿 + 一次 SHOT 钩子冒烟。
3. **批 3（REWIRE）**：R1-R6——**注意 R1-R3 与 P2-6 修复存在重叠**：若第一轮 P0/P1 修复批已按原样修复 P2-6，本批仅剩"把原子操作族设为唯一变更入口"的收敛动作；**建议与本轮 P1/P2 修复线合议执行顺序，避免两次改动同一路径**。R4/R5/R6 无此冲突。
4. **批 4（REFACTOR，F1-F9）**：行为不变重构，独立 PR。
5. **批 5（DEPRECATE 到期复评 + V1-V4 拍板项）**。
6. **批 0（随时可做，不属于清理批）**：P0/P1 修复线（含 stop_graph 接线）——与上述全部正交。

---

## 五、待确认清单（请负责人逐项勾选）

| # | 决策 | 默认建议 |
|---|---|---|
| 1 | R1-R3（原子操作族 REWIRE）是否采纳为统一 UndoRedo 基座 | 采纳；与 P2-6 修复合议顺序 |
| 2 | K2/K3 改判（is_cancelled、hide_text 保留）是否接受 | 接受 |
| 3 | R4/R6（trace.control.* 与 story.where.* 接线） | R4 采纳；R6 可选 |
| 4 | D1/D2 的发布状态前提（"插件未外发"）是否成立 | 成立则 DELETE，否则转 DEPRECATE |
| 5 | P1-P4 一周期观察 | 接受 |
| 6 | A-01/A-02 归档位置（tools/archive/、tests/archive/） | 接受 |
| 7 | V1（dialogue_layout_test）与 V2（png 归档） | 待拍板 |
| 8 | 批次顺序（尤其批 3 与修复线的先后） | 待拍板 |
