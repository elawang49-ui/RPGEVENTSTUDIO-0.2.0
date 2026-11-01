# 第三轮 UI 打磨 · 2026-11-01

> 基线：`fe70846`（第二轮 RC）
> 分支：`feat/ui-polish-round3`
> worktree：`/Users/elawang/Godot/rpg-studio-ui-polish-round3`
> 未修改 `RPGEVENTSTUDIO`、`rpg-studio-release-hardening`、`rpg-studio-ui-polish-glm53`；未合并 main。

## 一、滚动条调查结论

### 1. 用户看到的是哪一个

**游戏运行时对话框**里的滚动条，来自 `DialogueBox` 的正文 `RichTextLabel`。

RC 截图证据：`docs/images/rc-2026-10-31/game/c_dialogue_long_1152x648.png` 右侧有一条细滚动条，正文底部被截断。

实际节点路径（headless 探针）：

```text
/root/RPGEventStudio/Presenter/RPGEventStudioUI/DialoguePanel/
  @MarginContainer@2/@VBoxContainer@3/@RichTextLabel@7
滚动条：.../@RichTextLabel@7/@VScrollBar@5
```

脚本：`addons/rpgeventstudio/runtime/ui/dialogue_box.gd`

### 2. 为什么会出现

第二轮 C 修复为了让超长正文不被裁掉，在 `_update_heights()` 里做了：

```gdscript
needs_scroll = text_content > panel_max
_text_label.scroll_active = needs_scroll
```

- 短文本：`scroll_active=false`，无滚动条。
- 长文本：内容高度超过面板上限，`scroll_active=true`，出现玩家可见滚动条。
- 选项很多时：`_choices_scroll` 是 `SCROLL_MODE_AUTO`，也会出现滚动条，这是选项列表的正常设计。

### 3. 其他界面的滚动条

| 界面 | 控件 | 结论 |
| --- | --- | --- |
| 游戏运行时对话框正文 | `RichTextLabel` + 内部 VScrollBar | **问题**；已改为翻页，不再显示 |
| 游戏运行时选项列表 | `ScrollContainer`（AUTO） | 正常；选项过多时保留 |
| 编辑器 · 剧情工作台 | 多个 `ScrollContainer`、预览 `RichTextLabel` | 正常；编辑区长文本应可滚动 |
| 编辑器 · 事件编辑器 | 参数区 `ScrollContainer`、文本 `TextEdit`、BBCode 预览 | 正常；输入/预览区滚动合理 |
| 编辑器 · 主题页 | 参数 `ScrollContainer`；预览用的 `DialoguePresenter` | 参数滚动正常；预览正文原先继承运行时滚动条，现已随翻页修复 |
| 编辑器 · 资源审计 | 详情 `RichTextLabel.scroll_active=true` | 正常；详情区滚动合理 |

因此：
- 运行时长台词滚动条**不是正常设计**，已改为 RPG 式翻页。
- 编辑器里的长文本滚动条**是正常设计**，保留。
- 主题预览的滚动条是运行时 `DialoguePresenter` 的副作用，已随翻页去除。

## 二、实际修复

### 1. 游戏内长台词翻页（P1）

- `RichTextLabel` 始终保持 `scroll_active=false`，玩家不可见滚动条。
- 正文高度按整行对齐；超过可见行数时，推进键/鼠标/手柄翻到下一页。
- 翻页按行对齐并保留一行重叠，不会出现半行被切掉。
- 提示改为 `空格 / 鼠标左键继续 / 手柄 A ▼`。
- 最后一页再推进才结束对话；自动播放翻页后重置倒计时。
- 短文本、单页文本行为不变。
- 选项列表的滚动保留（选项过多时需要）。

### 2. 主题预览布局

- 示例选择/重播移到预览上方，预览区不再被下方控件挤压。
- 「预览」按钮在 1280 和 1152 都可用；可切到全高预览。
- 预览 SubViewport 跟随预览面板宽度，长句正常换行。
- 预览模式隐藏运行时推进提示，为样本文案留高度。
- 1280 全高预览可完整显示两行示例文本；1152 低高度下缩略预览仍偏紧（P2）。

### 3. 剧情审计列宽

- 窄窗口（<700）收窄「类别 / 位置」列，把宽度让给问题描述。
- 宽窗口恢复 64 / 84 / 自适应 / 自适应。

## 三、修改文件

- `addons/rpgeventstudio/runtime/ui/dialogue_box.gd`
- `addons/rpgeventstudio/editor/theme/dialogue_theme_view.gd`
- `addons/rpgeventstudio/editor/audit/story_audit_panel.gd`
- `addons/rpgeventstudio/i18n/ui.csv`（`game.advance_more`）
- `tests/dialogue_layout_test.gd`
- `tools/test_counts.json`
- `tools/round3_scroll_shots.gd`
- `README.md`、`docs/25-运行时剧情追踪.md`
- `docs/qa/2026-11-01/第三轮UI打磨.md`
- `docs/images/round3/`

## 四、测试结果

```bash
GODOT_BIN=/Users/elawang/Godot/Godot.app/Contents/MacOS/Godot \
python3 tools/test_runner.py --all
```

| 门禁 | 结果 |
| --- | --- |
| headless 14 套 | **760 项，0 失败**（对话布局 11→16） |
| 编辑器 6 套 | **176 项，0 失败** |
| 故障注入 11 项 | **PASS** |
| i18n | **PASS，876 键** |
| Runner | **RUNNER RESULT: PASS** |

`dialogue_layout_test` 新增：长文无玩家可见滚动条、滚动条不可见、可翻页、翻页后仍等待、面板保持显示。

## 五、截图

- `docs/images/round3/scroll-fix/before/`：第二轮 RC 长对话（有滚动条）
- `docs/images/round3/scroll-fix/after/`
  - `dialogue_long_page1_1152x648.png` / 1280：第一页，无滚动条
  - `dialogue_long_page2_1152x648.png` / 1280：翻页后
  - `dialogue_short_1152x648.png` / 1280：短文本
- `docs/images/round3/editor/after/`
  - `tab1_*`：主题默认分栏
  - `tab1_preview_1280x820.png`：1280 全高预览，示例文本完整
  - `tab1_preview_1152x648.png`：1152 全高预览（仍偏紧）
  - `tab3_*`：审计页窄/宽列宽
  - `event_dock_*` / `list_dock_*`：事件编辑器/列表回归

全部为真实 Godot 4.7.2 游戏/编辑器窗口截图。

## 六、遗留

| 优先级 | 问题 | 状态 |
| --- | --- | --- |
| P2 | 1152×648 主题全高预览文字仍偏紧 | 设置页不受影响；1280 全高预览可用；缩略图受面板高度限制 |
| P2 | 1152×648 关卡图节点文字偏小 | 沿用第二轮 70% 最小缩放 + 左对齐；可横向滚动 |
| P2 | 剧情工作台窄屏默认收起侧栏 | 沿用 `面板` 菜单 |
| P2 | 审计页窄窗口列宽仍有限 | 已让宽度给问题列；更长文本仍可能截断 |
| P3 | 旧编辑器布局残留旧 Dock 宽度 | 建议重置编辑器布局 |

无 P1 阻塞；未合并 main，未发布。
