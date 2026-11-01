# DialogueBox 分页机制专项验收 · 2026-11-01

> 基线：`51186c6`（`feat/ui-polish-round3`，第三轮 UI 已冻结）
> 验收分支：`feat/dialogue-pagination-acceptance`
> worktree：`/Users/elawang/Godot/rpg-studio-dialogue-pagination-acceptance`
> 未合并 main，未发布；未修改 Argon 预设系统/资源/接口。

## 一、调查结论

### 1. 原 `_visible_lines()` 不准确

原实现：

```gdscript
line_height = text_font_size + line_separation
visible = int(label.size.y / line_height)
```

实测偏差：

| 场景 | 原估算可见行 | 实际完整行 | 问题 |
| --- | ---: | ---: | --- |
| 普通中文，20px/8 | 4 | 3 | 页底多算一行 |
| 多段换行，20px/8 | 4 | 3 | 同上 |
| BBCode 40px/12px 混排 | 4 | 1 | 大字行被算小，跨页 |
| 主题 32px/8 | 3 | 2 | 页底裁行 |
| 主题 14px/4 | 7 | 6 | 页底裁行 |

实际行高约 **37px**（20px 字体 + 行距后由字体度量决定），不是 `20 + 8 = 28`。BBCode 的 `[font_size=40]` 行高约 65px，更无法用基础字号估算。

### 2. 修复方向

不再用固定像素估算，改为测量 RichTextLabel 的**真实行布局**：

1. 用 `scroll_to_line(i)` + `get_v_scroll_bar().value` 记录每行顶部偏移。
2. 用相邻行偏移差得到真实行高。
3. 当前页从 `_page_line` 开始，按真实行底部计算 `_page_end_line()`。
4. 翻页从“第一个未完整行”开始，避免漏行。
5. 窗口尺寸变化时重新测量并夹住当前页。

这能同时覆盖 BBCode 字号、字体度量、主题字号、自动换行和窗口变化。

## 二、分页对照：重叠 vs 不重叠

同一段 12 段中文对白，1152×648：

- 第 1 页：第 01～03 段。
- **不重叠**：第 2 页第 04～06 段。
- **保留一行重叠**：第 2 页第 03～05 段，重复第 03 段。

截图：

- [不重叠第 2 页](docs/images/dialogue-pagination-acceptance/overlap_off_page2_1152x648.png)
- [保留重叠第 2 页](docs/images/dialogue-pagination-acceptance/overlap_on_page2_1152x648.png)

### 推荐

**默认不重叠（`page_overlap=false`）**。

理由：
- 不会把上一页完整台词再读一遍。
- 页底如果有部分可见行，下一页会从该行重新完整显示；只重复“页底部分行”，不会漏字。
- 重叠模式会让读者产生“这段是不是重复了”的疑问，收益只有在页底半行时才体现。

当前实现默认不重叠；`page_overlap=true` 仅保留为对照/回退能力。

## 三、分页专项测试

新增 `tests/dialogue_pagination_test.gd`，共 **163 项检查**，覆盖：

1. 普通中文长文本。
2. 多段换行。
3. BBCode 粗体/斜体/40 号/12 号混排。
4. 自定义字体（`tests/fixtures/fonts/custom_serif.tres`）。
5. 主题 14/4、32/8 字号。
6. 超长连续文本、短文本。
7. 窗口 1152×648 → 960×600 → 1280×820 变化。
8. 打字机逐字状态。
9. 自动播放翻页与计时重置。
10. 最后一页、选项切换。

分页完整性检查：
- 页范围有效。
- 页内行底部不越出正文高度。
- 下一页从第一个未完整行开始。
- 翻页后 `_waiting_confirm` 保持。
- 最后一页 `_page_end_line() == 总行数`。
- 最后一页再次确认才关闭。
- 选项出现时 `_page_line=0`，不继承滚动状态。

## 四、真实输入链路

通过 `Input.parse_input_event()` 走实际 `InputService`/`InputMap`，不是直接调用 `_dismiss_text()`：

| 输入 | 结果 |
| --- | --- |
| 键盘 Space | 0→3 页，未误关闭 |
| 鼠标左键 | 3→6 页，未误关闭 |
| 手柄 A | 6→9 页，未误关闭 |
| 自动播放 | 到时翻页，`_auto_deadline` 重置，面板保持 |
| 打字机阶段按键 | 不抢翻页，页起始行保持；打字结束后才翻页 |

## 五、BBCode / 自定义字体截图

- [BBCode 第 1 页](docs/images/dialogue-pagination-acceptance/bbcode_mixed_1152x648.png)
- [BBCode 第 2 页：40 号大字完整显示](docs/images/dialogue-pagination-acceptance/bbcode_mixed_page2_1152x648.png)
- [自定义字体第 1 页](docs/images/dialogue-pagination-acceptance/custom_font_1152x648.png)
- [自定义字体第 2 页](docs/images/dialogue-pagination-acceptance/custom_font_page2_1152x648.png)

说明：BBCode 第 1 页页底可能露出下一行的部分像素；第 2 页会从该行开始完整显示。不重叠模式不会重复完整行，也不会漏掉该行的后半段。

## 六、i18n 口径修正

- CSV 共 **876 行**（含表头 `keys,zh_CN,en`）。
- 实际词条：**875 键**。
- `check_i18n.gd` 输出：`CSV 行数（不含表头）：875`。
- 已把报告、README、docs/25 统一为 **875 键**。

## 七、ALLOWED ERROR 逐条说明

测试日志现在会把原因标在行首：

- `EXPECTED[reason]`：测试主动触发的负向用例。
- `ENGINE_EXIT`：Godot 退出期引擎诊断。
- `SUITE_DIAG`：按套件列出的已知编辑器诊断。

| 日志 | 来源 | 性质 |
| --- | --- | --- |
| `EXPECTED[presenter-protocol] 自定义 presenter 缺少协议方法` | `tests/run.gd:1499` | **预期负向测试**：拒绝不满足协议的对象 |
| `EXPECTED[missing-common] Cannot open / Failed loading / 找不到公共事件 .godot/nope.tres` | `tests/runtime_trace_test.gd:527` | **预期负向测试**：缺失公共事件 |
| `ENGINE_EXIT resources still in use at exit` | 各套件退出 | **引擎退出诊断**，不是断言，不冒充负向测试 |
| `SUITE_DIAG UndoRedo history mismatch` | `gvl` 分组新建/删除 | **不是预期负向测试**；现有编辑器 Undo 诊断 |
| `SUITE_DIAG Child is not a child of this node` | `gvl` 删除/恢复分组 | **不是预期负向测试**；GraphFrame 清理诊断 |
| `SUITE_DIAG Required object "rp_child" is null` | `gvl` 节点视图清理 | **不是预期负向测试**；GraphNode 清理诊断 |

**结论：`gvl` 的三类 `SUITE_DIAG` 不是负向测试，不能作为“已解释通过”依据。** 本轮没有把它们伪装成负向测试；它们仍是待清理的编辑器诊断（P2），建议在最终整合前单独处理。分页专项测试本身不依赖这些诊断。

## 八、测试结果

```bash
GODOT_BIN=/Users/elawang/Godot/Godot.app/Contents/MacOS/Godot \
python3 tools/test_runner.py --all
```

| 门禁 | 结果 |
| --- | --- |
| headless 15 套 | **923 项，0 失败** |
| 编辑器 6 套 | **176 项，0 失败** |
| 故障注入 11 项 | **PASS** |
| i18n | **PASS，875 键**（876 行含表头） |
| Runner | **PASS**（gvl 的 9 条引擎诊断仍在日志中，见上表） |

分页专项：**163 项，0 失败**。

## 九、修改文件

- `addons/rpgeventstudio/runtime/ui/dialogue_box.gd`
- `tests/dialogue_pagination_test.gd`（新）
- `tests/fixtures/fonts/custom_serif.tres`（新）
- `tools/dialogue_pagination_shots.gd`（新）
- `tools/test_runner.py`（注册分页套件 + ALLOWED 原因标签）
- `tools/test_counts.json`
- `README.md`
- `docs/25-运行时剧情追踪.md`
- `docs/qa/2026-11-01/第三轮UI打磨.md`
- `docs/qa/2026-11-01/DialogueBox分页专项验收.md`
- `docs/images/dialogue-pagination-acceptance/`（10 张真实截图）

## 十、结论与冻结

- 分页机制：**通过**。
- 真实键鼠手柄/自动播放：**通过**。
- 不重叠模式推荐为默认：**已实现**。
- 第三轮 UI 分支冻结在 `51186c6`；本验收分支不合并 main。
- 待清理：`gvl` 的 9 条非预期编辑器诊断（P2），不影响分页验收，但影响“测试日志完全干净”的最终整合标准。
