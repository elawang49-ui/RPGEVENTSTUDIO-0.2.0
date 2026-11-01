# 第二批 UI 主题预设 · 工程验收记录

- 日期：2026-11-01
- 分支：`feat/ui-theme-presets-v2`
- 独立 worktree：`/Users/elawang/Godot/rpg-studio-ui-themes-v2`
- 基线：`feat/ui-polish-round3`（`51186c6`，含长文翻页与窄窗口打磨）
- 实现提交：`b0d18e085057dc3e82a9ef09a3f9348128710e1a`（回填本记录的文档提交见分支 HEAD）
- 设计原型（只读）：`~/.gemini/antigravity/brain/f8470edc-973f-4584-bc55-83a63e7db800/rpgm_ui_presets_v3.html`
- 未修改 Argon 工作区 `/Users/elawang/Godot/RPGEVENTSTUDIO`，未合并 `main`，未发布版本。

## 1. 原型缺陷清单（先看设计稿，再写代码）

1. **固定舞台导致裁切**：300px 舞台 + 112px 固定对话框 + 绝对定位选项；窄窗口
   下左右区域互相挤压，长台词直接溢出。
2. **文字层级弱**：正文、说话人、选项、提示几乎都是 `text-xs`（12px）；说话人
   不突出，长篇中文阅读压力大。
3. **铭牌压内容**：`-top-3.5/-4` 的铭牌高度按 emoji 估算，长名字/真实立绘时
   会压住第一行或立绘。
4. **立绘框比例不成立**：所有立绘 56×56 方形，真实角色立绘多为 3:4/4:5；没有
   `cover` 裁切，也没有真实图片入口。
5. **只定义了选中态，没有 hover**：HTML 选项没有 `:hover`，鼠标经过没有反馈；
   选中只是“上次点击”，键盘/鼠标焦点不统一。
6. **装饰遮挡**：胶带、刀锋、双线、角花都用绝对定位估算，不同字号/长名字下会
   超出面板或压住边框。
7. **窄窗口无适配**：12 列网格 + 固定 256px 选项宽，无断点、无重排、无立绘让位。
8. **参数重复/不一致**：面板高度 112/114、内边距 5/6、选中位移 -6/-7/-8、
   圆角 0/6/20/pill 混用，缺少统一 token；部分主题仅靠颜色区分。

修复原则：保留每套的“轮廓、铭牌、选项形状、立绘框、底纹”特色；把固定像素
改为锚点 + 可组合绘制；补齐 hover；把 12px 统一提升为 22/22/19/13 的层级；
立绘框支持真实 `Texture2D` 裁切与退化。

## 2. HTML → Godot 对照

| 原型元素 | Godot 实现 |
| --- | --- |
| `linear-gradient` 底色 | `DialoguePanelDecor._draw_vertical_gradient` / 逐行多边形渐变 |
| `clip-path` 缺口/斜切 | `DialoguePanelDecor._shape_points` + `draw_colored_polygon/polyline` |
| 双层边框/角花 | `frame_style=double/ornament` + `DialoguePanelDecor` 内缩线/角标 |
| 缝线/方格纸/圆点/网格/斜线/放射 | `pattern_style` + `frame_style=stitch` 原生绘制 |
| 硬阴影 | `hard_shadow_color/offset` + `draw_style_box` / 偏移多边形 |
| 胶囊/平行四边形/木牌/血封条铭牌 | `DialogueNameplate` 的 `nameplate_style` |
| 左人名右台词双栏 | `nameplate_style=column` + `_speaker_spacer` 预留栏位 |
| 胶囊/斜切/便签/缺口/竖线/羽翼选项 | `ThemeChoiceRow.choice_style` + 内部 Button |
| 选项 hover | `ThemeChoiceRow` 悬停底色/文字/左侧强调线，独立于选中 |
| 拍立得/圆窗/八角/斜切立绘 | `DialoguePortraitSlot` + `portrait_mask.gdshader` + overlay |
| `skewX` 文本反向校正 | 面板/选项画多边形，文字保持正立；不做文字斜切 |
| `truncate` | Button `clip_text` + tooltip 全文 |
| 旋转胶带 | `DialoguePanelDecor._draw_tape` 的 `draw_set_transform` |
| 星芒旋转/光标浮动 | 保留静态角标与选中/悬停；未逐帧复刻纯装饰动画 |

## 3. 实现摘要

- 新增 `core/theme/dialogue_theme_presets.gd`：6 套预设 + 元信息 + 工厂。
- 扩展 `RpgEventStudioTheme`：布局/装饰/铭牌/选项形状/立绘框字段，全部兼容默认值。
- 新增 4 个可组合绘制组件：
  - `runtime/ui/theme/dialogue_panel_decor.gd`
  - `runtime/ui/theme/dialogue_nameplate.gd`
  - `runtime/ui/theme/theme_choice_row.gd`
  - `runtime/ui/theme/portrait_slot.gd` + `portrait_overlay.gd` + `portrait_mask.gdshader`
- `DialoguePresenter` 改为通用布局：面板 + 装饰层 + 内容行（立绘/左栏/正文/提示）
  + 跨框铭牌 + 选项行；保留原有 `show_text/show_choices/get_choice/close_all`、
  分页、打字机、自动播放、BBCode。
- `StudioRuntime` 新增：
  - `apply_dialogue_theme_preset(id)`
  - `set_dialogue_portrait(texture)` / `clear_dialogue_portrait()`
  - 主题加载改为 `duplicate(true)`，避免运行时改到缓存资源。
- 编辑器主题页：
  - 预设下拉 + 立绘框开关 + 标题/说明/色板。
  - 7 个参数分区（对话框/文字/选项/铭牌/立绘框/动画/交互提示）。
  - 固定虚拟分辨率预览（960×600 / 1280×820 / 1152×648），等比缩放。
  - 保存 / 重载 / 恢复预设默认值；预设工厂隔离。
- 示例立绘：`samples/ui/sample_portrait.png`（480×600，非角色资源系统，仅用于
  演示裁切/框体；真实项目通过 `set_dialogue_portrait` 注入自己的立绘）。

## 4. 测试

### 4.1 自动化

```bash
python3 tools/test_runner.py --headless   # 954 项，PASS
python3 tools/test_runner.py --editor     # 181 项，PASS
```

| 套件 | 检查项 | 结果 |
| --- | --- | --- |
| headless 全量 | 954 | PASS |
| 其中新增 `dialogue_theme_presets_test` | 194 | PASS |
| editor 全量 | 181 | PASS |
| 其中 `map`（含主题页预设/隔离） | 56 | PASS |

覆盖：

- 6 套预设注册、元信息、工厂新建实例、互不污染、恢复出厂值。
- 每套主题：装饰层、铭牌、立绘、3 选项、选中/悬停/点击、长文翻页、BBCode。
- 1280×820 与 1152×648：对话框/选项/立绘不越界。
- 旧主题资源保存/读取，新增字段默认值不改变旧外观。
- 立绘开启/关闭、长文不拉伸、无立绘正文左移、窄窗口立绘让位。
- 主题页：7 分区、预设切换、保存、重载保留 `preset_id` 与修改值、恢复预设默认、切换不继承临时修改。

### 4.2 真实截图

- 运行时 1280×820：19 张；1152×648：20 张。
- 六套主题 × 两种尺寸 ×（对白 + 选项）。
- 补充：无立绘退化、BBCode、长文第 1/2 页、EventRunner 事件链路。
- 真实编辑器主屏：1280×820（圣堂）、1152×648（曲奇）。
- 主题编辑器独立预览：1280 圣堂/曲奇、1152 预览模式。
- 目录：`docs/images/ui-theme-presets-v2/`。

截图工具：

```bash
godot --path . --script res://tools/theme_presets_shots.gd -- 1280 820
godot --path . --script res://tools/theme_presets_shots.gd -- 1152 648
```

`runtime_event_*.png` 由 `EventRunner → CmdShowText → DialoguePresenter` 产生，
不是直接摆拍 UI；日志输出实际 `last_text`。

## 5. 尚未解决 / 边界

- 按需求不实现“纯白神谕 · 琉璃彩窗”“浮生水墨 · 朱砂方印”。
- 没有角色立绘/表情资源注册表；本次只建立 `Texture2D` 显示接口与主题框体。
- 选项文字单行，超长文本省略号 + tooltip；未做多行选项排版。
- 编辑器预览为等比缩放，字体像素与 1:1 窗口有差异；以运行时截图为准。
- HTML 的星芒旋转、光标浮动未逐帧复刻；保留出现/消失与选中/悬停状态。
- 编辑器 1152×648 主屏受 Godot 左右 Dock 挤压，完整预览使用主题页「预览」模式。
- 系统 CJK 字体回退依赖平台；项目可用 `font_path` 指定字体。

## 6. 安全 / 兼容

- 未修改事件资源序列化格式、`EventCommand` 字段。
- 未改变 EventRunner/GraphRunner 执行语义；`tests/run.gd`、`integration_demo` 全绿。
- `plugin.gd` 仅增加 `THEME_SHOT_PRESET` 截图钩子；`ui.csv` 只追加新词条。
- 旧 `.tres` 缺省新字段时走旧 `StyleBox` 路径；`preset_id=""` 不启用装饰层。
- 与并行 worktree `rpg-studio-dialogue-pagination-acceptance` 的未提交
  `dialogue_box.gd` 修改没有合并/覆盖；本分支基于已提交的翻页基线。
