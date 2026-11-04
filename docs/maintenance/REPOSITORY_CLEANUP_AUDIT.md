# RPGEVENTSTUDIO 仓库清理审计报告（Phase 0）

- **日期**：2026-11-05
- **执行基线**：`release/0.2.0`（= `feat/theme-system-upgrade` tip `b352223` + cherry-pick `2fc4fbf` `register_host_command`，提交于 `3970939`；清理提交 `6913300`）
- **性质**：已执行的清理 + 审计记录。所有删除均在提交前完成零引用/已合并验证；未触碰存档 schema、GameState 兼容层、事件数据格式与公开 API。

---

## 一、清理前原始结构

单仓库 + git worktree 并行开发：

| 指标 | 清理前 | 清理后 |
|---|---|---|
| worktree | 28（+1 本阶段新建 release worktree = 29） | **3** |
| 本地分支 | 32（+1 release/0.2.0 = 33） | **3** |
| tag | 1（v0.2.0-rc2） | 1（不变） |
| 跟踪文件数（release 基线口径） | 1009 | **910** |
| 工作区顶层 rpg-*/rpgeventstudio-* 目录 | 27 | **3**（+1 空快照目录已删） |
| .git 体积 | 102M | 102M（历史保留，未 gc） |
| 磁盘释放 | — | 26 个 worktree 约 **700M+**（含各自 .godot 导入缓存） |

清理后三个分支：

| 分支 | worktree | HEAD | 作用 |
|---|---|---|---|
| `main` | `RPGEVENTSTUDIO`（主工程） | `3970939`→`6913300` | 正式工程入口，已快进到 release 内容 |
| `release/0.2.0` | `rpg-studio-release-0.2.0` | `6913300` | 0.2.0 发布工程线 |
| `feat/theme-system-upgrade` | `rpg-studio-theme-upgrade` | `b352223` | ACTIVE：含未提交 WIP（见七.4） |

---

## 二、Worktree 盘点与分类（28→3）

测量口径：`git rev-list --count release/0.2.0..<branch>` 为独有提交数；`git status --porcelain` 为未提交文件数。**全部分支均经提交级祖先验证，不按名称/日期判废弃。**

### 已清理（26 个 worktree，全部 unique=0、无未提交开发成果）

| worktree | 分支 | 分类 | 处理 |
|---|---|---|---|
| rpg-studio-audit | feat/story-resource-audit | MERGED | 移除 + 删分支 |
| rpg-studio-dialogue-pagination-acceptance | feat/dialogue-pagination-acceptance | MERGED（2 个未提交 QA 文档已抢救） | 移除 + 删分支 |
| rpg-studio-fix-b2-credibility | fix/test-credibility | MERGED | 移除 + 删分支 |
| rpg-studio-fix-b2-editorux | fix/p1-story-insert-theme-reload | MERGED | 移除 + 删分支 |
| rpg-studio-fix-b2-integration | fix/audit-remediation-batch2 | MERGED | 移除 + 删分支 |
| rpg-studio-fix-b2-mouse | fix/p0-mouse-hit-test | MERGED | 移除 + 删分支 |
| rpg-studio-fix-b2-nested | fix/p1-nested-wait-semantics | MERGED | 移除 + 删分支 |
| rpg-studio-fix-b2-tree-utf8 | fix/p2-bulk-tree-utf8 | MERGED | 移除 + 删分支 |
| rpg-studio-fix-batch1 | fix/audit-remediation-batch1 | MERGED | 移除 + 删分支 |
| rpg-studio-fix-p01-graph-runner | fix/p0-level-graph-lifecycle | MERGED | 移除 + 删分支 |
| rpg-studio-fix-p02-presenter | fix/p0-presenter-dangling | MERGED | 移除 + 删分支 |
| rpg-studio-fix-p15-input | fix/p1-inputmap-coexistence | MERGED | 移除 + 删分支 |
| rpg-studio-gvl | feat/graph-validation-layout | MERGED | 移除 + 删分支 |
| rpg-studio-integration | integration/tasks-2026-10-30 | MERGED | 移除 + 删分支 |
| rpg-studio-release-0.2.0-rc1 | release/0.2.0-rc1 | MERGED（rc 线被 release/0.2.0 取代，tag v0.2.0-rc2 保留其 tip） | 移除 + 删分支 |
| rpg-studio-release-hardening | feat/release-hardening | MERGED（未提交截图已归档） | 移除 + 删分支 |
| rpg-studio-runtime-trace | feat/runtime-trace | MERGED | 移除 + 删分支 |
| rpg-studio-stage2 | integration/stage2-2026-10-30 | MERGED | 移除 + 删分支 |
| rpg-studio-task-integration | feat/task-system-integration | **内容已合并**（独有提交 2fc4fbf 经 cherry-pick 进入 release/0.2.0；patch-id 因 test_counts 冲突解决不同，`git diff` 逐文件核对为等价） | 移除 + `branch -D` |
| rpg-studio-ui-appearance-verify | feat/ui-appearance-runtime-acceptance | MERGED | 移除 + 删分支 |
| rpg-studio-ui-polish-glm53 | feat/ui-polish-glm53 | MERGED（未提交截图已归档） | 移除 + 删分支 |
| rpg-studio-ui-polish-round2 | feat/ui-polish-round2 | MERGED | 移除 + 删分支 |
| rpg-studio-ui-polish-round3 | feat/ui-polish-round3 | MERGED | 移除 + 删分支 |
| rpg-studio-ui-themes-v2 | feat/ui-theme-presets-v2 | MERGED | 移除 + 删分支 |
| rpgeventstudio-workbench | feat/event-authoring-workbench | MERGED | 移除 + 删分支 |
| rpgeventstudio-worktrees/state-catalog-bulk-register | feat/state-catalog-bulk-register | MERGED | 移除 + 删分支（空容器目录一并删除） |

### 无 worktree 的已合并分支（4 个，直接删除）

`feat/map-event-placement`、`feat/presenter-injection`、`integration/2026-10-30`、`feat/unified-input`（主 worktree 切走后）。

### 非 worktree 顶层产物

| 项 | 判定 | 处理 |
|---|---|---|
| `rpg-studio-ui-themes-v2-snapshot-2026-11-02/` | ABANDONED：非 git 仓库，0 字节 patch + 空 tgz + 空目录，是失败的快照操作残留 | 已删除 |
| `rpgeventstudio-worktrees/`（空容器） | DUPLICATE 容器 | 已删除 |

### 保留（3 个 worktree）

| worktree | 分类 | 原因 |
|---|---|---|
| `RPGEVENTSTUDIO`（main） | RELEASE | 主工程入口，已切到 main@release tip |
| `rpg-studio-release-0.2.0` | RELEASE | 0.2.0 发布工程线 |
| `rpg-studio-theme-upgrade` | **ACTIVE（含未提交 WIP）** | 4 个未提交项：`theme_presets_shots.gd --anim` 录制模式改动、`design-system/anim-preview.html`、`qa-screenshots.html`、`docs/images/ui-theme-anim/`（21M 动画帧）。按规则不删未提交开发成果；建议 WIP 提交后该 worktree 亦可移除 |

---

## 三、工程垃圾清理（release/0.2.0，提交 `6913300`）

### 已删除

| 项 | 数量 | 依据 |
|---|---|---|
| `未命名-待删除/` 整目录 | 16 文件（6 个 _debug_*.gd + uid、截图、README） | 目录自述"确认无用后可整目录删除"；6 个脚本逐一 grep 零外部引用 |
| `deliverables/rpg-studio-0.2.0-rc2-ui-patch-r2.zip` | 1 | 构建产物入库；交付物应出仓管理（顶层 deliverables/） |
| docs/images 无引用截图 | **85 张 png**（+ .import sidecar） | 全路径 + basename 双重引用扫描确认为孤儿：ui-polish-round2(27)、round3(24)、rc-2026-10-31(26)、dialogue-pagination-acceptance(8)；对应 md 报告已出仓在 deliverables zip，证据未丢 |
| i18n `trace.empty` 词条 | 1 键 | 无任何构造点/显示逻辑（沿用登记表 D10 复核结论，check_i18n 无计数断言） |

### 已归档（位置移动，Git 内保留）

| 项 | 去向 | 依据 |
|---|---|---|
| 一次性截图工具×7：capture_bbcode_editor / dialogue_pagination_shots / hardening_shots / round3_scroll_shots / ui_round2_shots / visual_check / visual_docs | `tools/archive/` | 对应验收轮已冻结、产物已交付；test_runner/CI 无引用（登记表 A-01） |
| `trace_demo.gd` + `.tscn` | `tests/archive/` | 一次性 trace 截图 demo（登记表 A-02）；已修正 tscn 内 ext_resource 路径 |

### 出仓抢救的 QA 证据（不丢）

- `deliverables/qa-evidence-archive/`：`dead_code_and_redundancy_audit.md`、`cleanup_decision_register.md`（同时入 Git `docs/qa/2026-11-02/`）、`release-final-{hardening,glm53}/` 截图 7.7M、`docs-images-orphaned/` 85 张。

---

## 四、死代码审计结果

以 2026-11-02《死代码与冗余专项审计报告》+《清理决策登记表》为输入，逐项在 `release/0.2.0` 基线复核（基线已漂移，行号全部重验）。

### 本轮已执行（零 API 面风险，全部复核零引用）

| 项 | 位置 | 说明 |
|---|---|---|
| `plugin.gd refresh_event_list()` / `open_audit_tab()` | plugin.gd | 零调用；刷新走防抖直调、审计页走面板内部（D7） |
| `DialogueBox._visible_lines()` | dialogue_box.gd | 分页改造后的孤儿函数（旧 var 已在分页重构中消除，func 零调用） |
| `StateLibraryDialog.rename_current()` | state_library_dialog.gd | 改名实际走行内 LineEdit→_flush 路径（D8） |
| `UiFonts.AUX` / `min_readable()` | ui_fonts.gd | 与 NOTE 同值的零引用别名/工具（D9） |
| i18n `trace.empty` | ui.csv | 无构造点（D10） |

### 登记表中已失效的条目（基线演进自然消除）

- `StateStore._pending_new`（D3）：会话重构后已不存在，仓库零匹配。
- `DialogueBox._visible_lines` 旧 *var*（D4）：分页重构已消除；残留 func 本轮已删。

### 复核确认仍存在、但**本轮不动**（报告项，待负责人拍板）

| 项 | 位置 | 不删原因 |
|---|---|---|
| `EventPage.priority` / `trigger_params`（D1/D2） | event_page.gd:8,12 | **@export 序列化字段＝事件数据格式面**，属硬性约束保护范围；登记表自己的前提也是"插件未外发"，0.2.0 即将外发，建议转 DEPRECATE 而非 DELETE |
| `EventContext.resolve_node()`（D5） | event_context.gd:176 | class_name 公开方法，宿主 API 面；建议 DEPRECATE 一周期 |
| `EventContext.take_logs()` + `_logs`（D6） | event_context.gd:45,214-220 | 同上；注意 `_logs` 每 ctx 生命周期无界增长，建议下批处理 |
| `StudioRuntime.INTERACT_ACTION`（P1） | studio_runtime.gd | Autoload 宿主可见面，按登记表已列 DEPRECATE 观察期 |
| `StoryDocument.collect_texts`（P2）/`LevelNode.duplicate_node`（P3）/`EventContext.locals`（P4） | 各模型/ctx | 登记表 DEPRECATE 观察期；locals 还涉及 docs/04 契约图修订 |

### 登记表 REWIRE / REFACTOR / MOVE（功能/重构批，不属清理批，未动）

- REWIRE R1-R6：原子操作族作 UndoRedo 基座、trace.control.*/story.where.* 词条接线、EDITOR_SETTING 统一。
- MOVE M1：`plugin.gd` 内 SHOT 截图脚手架（8 钩子 + 14 函数，约 350 行）→ `tools/editor_shots.gd`，当前仍在 plugin.gd（925 行），建议独立批次迁出并做 SHOT 冒烟验证。
- REFACTOR F1-F9：面板助手下沉等 9 项，建议独立 PR。
- KEEP 复核：`is_cancelled`/`hide_text`/`has_state`/`EventBus.custom_*`/`LevelNode.reentry`/InputService 查询族——确认有文档或宿主面依据，保留正确。
- V1 `dialogue_layout_test.gd`（19 项，pagination 282 项覆盖其子集）保留现状待拍板。

---

## 五、文档整理

### 本轮已修

| 项 | 处理 |
|---|---|
| **docs/22 编号冲突**：`22-状态持久化边界`（旧，README/INSTALL 引用）与 `22-对话主题预设`（新）同号 | 后者重编号 `docs/27-对话主题预设.md`，更新 docs/21 ×2、README ×3 引用 |
| `tools/README.md` | 全文重写：22→24 headless 套件、归档工具表、release/0.2.0 分支名 |
| `tools/release_check.py` | `--fresh` 硬编码分支 release/0.2.0-rc1 → release/0.2.0 |
| `tests/README.md` | 22→24 headless 套件数 |
| 登记表 + 审计报告 | 入 Git `docs/qa/2026-11-02/` 留档 |

### 仍失真/待处理（报告项）

- `README.md` 顶部仍标"0.2.0-rc2 发布候选"——属发布批次的版本号更新，随 0.2.0 版本 bump 一并处理。
- `docs/02/07/09` 登记表 B-17 指出的失真句（把不存在脚本当已实现）、`docs/04` locals 契约图——需文档修订批。
- `tests/README.md` 套件名单未逐套列出（仅总数已修）。
- `design-system/`（11 文件）：ATELIER v5 设计工件，被 `dialogue_theme_presets.gd`、IMPL-PLAN 引用，**保留**；presets-v3/v4 为历史迭代原型，保留作设计溯源。
- `docs/theme-palette-preview.html`：被 dialogue_theme_presets.gd 注释引用，保留。

---

## 六、验证

- `tools/test_runner.py --all`：**PASS**（headless 24 套件 2109 项 + editor 6 套件 233 项 + 故障注入 12/12）。
- 归档后 `test_counts.json` 与实际一致；`host_command_test`（cherry-pick 带入）19 项通过。
- CI：`.github/workflows/quality.yml` 存在并跑同一 runner + release_check --package（发布阶段使用）。
- 未触碰：`state/state_catalog.tres`、存档 schema、GameState 兼容层、事件数据格式、公开 API、`.github/`、`design-system/`、`state/`、`tests/fixtures/`。

## 七、遗留与建议

1. **theme-upgrade WIP**（4 个未提交项）建议提交或丢弃后移除该 worktree，分支也可删（已全量并入 release/0.2.0）。
2. **发布批次待办**：plugin.cfg 版本 bump 0.2.0-rc2→0.2.0、README rc2 横幅、INSTALL/RELEASE_NOTES 更新、export_presets.cfg（Windows 交付物）、导出模板安装。
3. **下一批清理候选**（已复核可执行，待拍板）：D5/D6 公开 API 转 DEPRECATE 注释标记、M1 plugin.gd 脚手架迁出、REWIRE R1-R6 接线、REFACTOR F1-F9。
4. **工作区级（仓库外，未动）**：`.backup_*`、`.task-backups`、`.release-check`、`.godot-home`、`school-*`、`GamePrototype`、`Tower`、`museum-hall`、`做题家小游戏`、`deliverables/`——分别为外部宿主工程、历史备份与交付物仓，建议负责人按需处置，本报告不做删除。
5. `.git` 102M：含全部已删分支历史（分支删除不丢历史，tag + reflog 可回溯）；如需瘦身可另行 `gc`。
