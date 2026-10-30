# 第二阶段整合验收 · 2026-10-30

> 整合分支：`integration/stage2-2026-10-30`
> 基线：`be04593`（`integration/tasks-2026-10-30`）
> 原始主工作区：`RPGEVENTSTUDIO`（`feat/unified-input` @ `a5afc90`），本轮未改动、未合并 main。

## 1. 整合方式

| 来源 | 提交 | 方式 | 结果 |
| --- | --- | --- | --- |
| 全工程审计器 | `41c6fcb`（基于 `be04593`） | `git merge --no-ff` | `ad3f70e`，无冲突 |
| 统一输入系统 | `3669476`、`a5afc90`（基于 `2c18d67`） | `git merge --no-ff` | `94a98f0`，仅 `ui.csv` 冲突 |
| 整合期测试补强 | — | 直接提交 | `6f51bcf`（手柄事件）、`3a7b813`（恢复被跳过用例） |

输入分支的共同祖先是 `2c18d67`；`be04593` 是 `2c18d67` 的后代，因此采用三方合并，
没有改写、重置或覆盖 `feat/unified-input` 原分支。

## 2. 冲突解决记录

### ui.csv

输入分支把整个文件从 CRLF 改成了 LF，直接合并会产生整文件冲突。处理方式：

1. 以整合侧 754 条词条（含审计 `audit.*`）为基准；
2. 只套用输入分支的**内容差异**：
   - 改值 3 条：`game.prompt.hint`、`input.action.confirm`、`sample.hint`；
   - 新增 4 条：`input.action.dialogue_advance`、`input.device.gamepad`、`input.device.keyboard`、`input.device.mouse`；
3. 保留原文件混合换行与既有顺序；最终 758 键，0 重复、0 空翻译。

### tests/run.gd / tools/check_i18n.gd

Git 自动合并成功，人工复核确认双方新增均保留：

- 审计：`_test_story_audit()`、审计夹具用例、`audit.` 前缀与问题码白名单；
- 输入：`_test_input_registry()`、`dialogue_advance`、旧存档兼容、`add_runtime_message()` 注入、宿主注册动作；
- i18n 工具：同时识别 `audit.*` 与 `add_runtime_message` 注入键。

### plugin.gd / InputService / 运行时

- `plugin.gd`：审计第 4 个标签、定位回调、自测钩子均存在；输入分支未改此文件。
- `InputService`：输入分支新增的动作注册、默认键补充、`[meta] customized`、旧存档迁移完整保留。
- `dialogue_box` 改用 `dialogue_advance`；`event_interactor` 提示跟随绑定；样例场景提示更新为“空格 / 回车”。

## 3. 整合期发现的问题

### 3.1 输入分支自测存在“假全绿”（已修）

`tests/run.gd` 的 `_test_input_registry()` 里：

```gdscript
var described: Dictionary = service.describe("dialogue_advance")["keyboard"]
```

`describe()` 的 `keyboard` 值是 `Array`，不是 `Dictionary`。运行时抛类型错误后函数中断，
后面 **11 项**旧存档兼容、补键、动作拆分用例从未执行；输入分支与初次合并都显示“通过”。

修复：类型改为 `Array`；同时把中文环境下用英文 `"Space"` 判断标签的本地化敏感断言，
改成按真实按键事件（`KEY_SPACE`）断言。

### 3.2 手柄事件覆盖不足（已补）

原测试只断言“存在手柄绑定”。新增 6 项真实事件通道用例：

- `Input.parse_input_event` 手柄 A 按下/松开 → `interact` 按下/释放；
- 左摇杆 `-1.0` / 回中 → `move_left` 按下/释放；
- 改键到手柄 X（避开取消键 B）→ 保存 → 重新加载仍生效。

### 3.3 EventReferences 迁移

审计器把 `EventReferences` 从 `editor/event_list/` 下沉到 `core/audit/`。全仓库搜索确认
没有旧路径引用；`event_list_smoke` 13/13、`ui_smoke` 56/56 通过。

## 4. 测试数量对照

| 套件 | 整合前 `be04593` | 审计器分支 `41c6fcb` | 本整合分支 |
| --- | --- | --- | --- |
| `tests/run.gd` | 317 | 323 | **348** |
| `story_audit_test.gd` | — | 24 | **24** |
| `state_bulk_register_test.gd` | 96 | 96 | **96** |
| `graph_editor_smoke.gd` | 19 | 19 | **19** |
| `ui_smoke.gd` | 56 | 56 | **56** |
| `integration_demo.gd` | 37 | 37 | **37** |
| `safe_write_test.gd` | 17 | 17 | **17** |
| `event_list_smoke.gd` | 13 | 13 | **13** |
| `tutorial_flow.gd` | 14 | 14 | **14** |
| `interaction_test.gd` | 19 | 19 | **19** |
| `node_ref_test.gd` | 12 | 12 | **12** |
| **headless 合计** | **600** | **630** | **655** |

| 编辑器套件 | 整合前 | 本整合分支 |
| --- | --- | --- |
| `RPGEVENTSTUDIO_SELFTEST`（撤销/重做） | 19 | **19** |
| `RPGEVENTSTUDIO_MAP_SELFTEST`（地图 + 主题） | 50 | **50** |
| `RPGEVENTSTUDIO_GVL_SELFTEST`（关卡图） | 59 | **59** |
| `RPGEVENTSTUDIO_STORY_SELFTEST`（剧情） | 20 | **20** |
| `RPGEVENTSTUDIO_AUDIT_SELFTEST`（审计） | — | **14** |
| **编辑器合计** | **148** | **162** |

`run.gd` 的增量为：审计 6 项 + 输入注册/旧存档 16 项 + L10n 注入 3 项 + 手柄 6 项 = +31（317 → 348）。

## 5. 最终执行记录

| 命令 | 结果 |
| --- | --- |
| `tests/run.gd` | **348，0 失败** |
| 其余 10 个 headless 脚本 | **307，0 失败**（24+96+19+56+37+17+13+14+19+12） |
| 5 个编辑器自测 | **162，0 失败** |
| 真实窗口 `RPGEVENTSTUDIO_AUDIT_SELFTEST=1` | **14/14 PASS** |
| 真实窗口 `RPGEVENTSTUDIO_SELFTEST=1` | **19/19** |
| `tools/check_i18n.gd` | **PASS（758 键）** |
| 改键/冲突/持久化 | 主套件 + `integration_demo` 通过 |
| 旧存档兼容 | 4 项迁移断言通过 |
| 手柄按键/摇杆 | 6 项真实事件断言通过 |
| 审计器 | 24 + 6 + 14 通过 |

## 6. 已知限制

- 手柄测试是 `Input.parse_input_event` 模拟，未接真实物理手柄硬件。
- 审计器仍是磁盘静态扫描：不展开场景实例、脚本动态 `load()` 视为未引用。
- 没有做导出构建/干净工程安装验证（仍是后续任务）。
- 输入增强的宿主注册能力已进入整合基线，但宿主项目仍需自行调用
  `register_action()` / `extend_action_defaults()` 并提供运行时文案。
- 未合并 `main`；原始主工作区保持 `feat/unified-input` @ `a5afc90`，无未提交改动。
