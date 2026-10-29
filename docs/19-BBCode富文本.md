# BBCode 富文本

事件文案直接写 Godot `RichTextLabel` 的 BBCode。编辑器只负责原样保存、实时预览和提示问题；
游戏运行时由 `RichTextLabel` 真正解析，插件不自己实现一套富文本渲染。

## 支持的标签

以 Godot 4.7 的 `RichTextLabel` 为准，常用：

| 写法 | 效果 |
| --- | --- |
| `[b]重点[/b]` | 粗体 |
| `[i]斜体[/i]` | 斜体 |
| `[u]下划线[/u]` / `[s]删除线[/s]` | 下划线 / 删除线 |
| `[color=red]警告[/color]` | 颜色 |
| `[color=#FFD700]关键线索[/color]` | 十六进制颜色 |
| `[font_size=24]大字[/font_size]` | 字号 |
| `[center]居中[/center]` | 对齐 |
| `[code]原样显示 [b] 标签[/b][/code]` | 代码块内不解析 |
| `[url=https://example.com]链接[/url]` | 链接 |
| `[table=2][cell]A[/cell][cell]B[/cell][/table]` | 表格 |

`Bbcode.SUPPORTED_TAGS` 维护当前识别范围；其它标签会在编辑器里提示“不支持或写法有误”，
并按 Godot 的实际行为原样显示，不会被静默删掉。

## 编辑器

「显示文字」的「内容」参数下方有：

- **原始文本编辑区**：仍然是普通 `TextEdit`，可以写多行、中文标点、换行和 BBCode。
- **BBCode 预览**：用同一个 `RichTextLabel` 渲染，输入时同步更新。
- **提示**：未闭合、闭合不匹配、闭合标签带参数、缺少必要参数、不支持的标签都会列出来。

原始文本不会被预览或保存流程改写；保存后重新打开，`params["text"]` 与输入完全一致。

## 游戏运行时

- 插件默认 UI（`DialoguePresenter`）与《做题家》原叙事 UI 都使用 `RichTextLabel`。
- 打字机按 `RichTextLabel.get_total_character_count()`（解析后的可见字符）推进，
  不会把 `[b]`、`[color=#...]` 逐字显示。
- 事件完成回调、选项、条件分支仍然走原来的指令/状态流程；BBCode 只影响显示。
- 未闭合或不支持的标签会记录到 `last_bbcode_issues`，运行时 `push_warning` 输出明确说明；
  原文仍然原样保留，不会损坏存档或事件资源。

## 已知边界

- 选项按钮（`Button`）显示的是纯文本；BBCode 支持范围是事件正文、选项提示和旁白。
- `[img]` 等依赖资源的标签能否显示取决于 Godot 能否加载对应路径。
- 预览与游戏使用同一套 `RichTextLabel` 解析，因此字体、换行和标签效果一致；
  但编辑器预览的宽度与游戏对话框宽度不同，自动换行位置可能略有差异。

## 验收 / 截图

```bash
# 编辑器预览（真实窗口；输出目录用 CAPTURE_DIR 指定）
CAPTURE_DIR=/path/to/output godot --path . --script res://tools/capture_bbcode_editor.gd

# 插件默认 UI 与游戏原叙事 UI 的同一段 BBCode
cd ../做题家小游戏/School
./tools/run_narrative_adapter_capture.sh
```
