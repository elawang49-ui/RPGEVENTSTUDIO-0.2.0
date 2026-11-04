# ATELIER Design System

**Warm Editorial × Technical Instrument** — RPGEVENTSTUDIO 及 Cognition 系 Godot 项目的共享设计规范。
状态：**v0.1 草案（待审核）**。本阶段只做研究/设计/规划，不修改任何现有代码。

---

## 1. 开源项目研究报告

| 项目 | Stars（2026-11 核实） | 许可证 | 可迁移的核心思想 |
|---|---|---|---|
| shadcn/ui | ~127K | MIT | 语义化 Token 命名（`background/foreground/primary/muted/accent/border/ring`）；Token 与组件实现解耦；组件可复制而非黑盒 |
| Open Design | 105.7K ✔已核实 | Apache-2.0 | **最重要的参考**：`DESIGN.md`（规范散文）+ `manifest.json`（发现元数据）+ `tokens.css`（编译产物）的包结构；**A1/A2/B/C 四层 Token 契约**——A1 种子必填、A2 有兜底的必填、B 槽位可别名回退、C 扩展不跨品牌 |
| Ant Design | ~100K | MIT | 三层 Token 算法 `seedToken → mapToken → aliasToken`；状态规范（Hover/Active/Disabled/Loading/Error）在企业级密度下仍然一致 |
| Storybook | ~91K | MIT | 组件独立预览 + 状态枚举验收；每个组件按"状态矩阵"回归而非整页目检 |
| Dear ImGui | ~77K | MIT | 一个 `ImGuiStyle` 结构体承载全部样式；`PushStyleVar/Color` 局部覆盖、作用域恢复——正是主题继承/覆盖机制的极简模型 |
| godot-minimal-theme | ~3.8K | MIT | 克制哲学：少量语义色 + 一个中性灰阶梯 + 克制圆角；已并入 Godot 4.6 默认编辑器主题 |
| Dialogic | ~6.1K | MIT | **Theme = 可替换场景**（Layout Scene）而非一堆参数；每套布局是独立场景，继承靠复制布局目录 |
| Dialogue Manager | ~4.0K | MIT | 无状态运行时 + 单一 Balloon 场景引用；宿主只给场景路径，引擎不管内部结构 |

### 结论：不模仿任何一个，取四件东西

1. **Token 分层契约**（Open Design 的 A1/A2/B/C）→ ATELIER 的 `base → semantic → component → extension`
2. **语义命名而非色值命名**（shadcn）→ 编辑器写 `bg.surface` 不写 `#1A1916`
3. **Push/覆盖/弹栈**（ImGui + Ant 的 token override）→ 主题继承与 C 扩展机制
4. **Theme 即资源**（Dialogic）→ Runtime 主题继续用 `RpgEventStudioTheme` Resource，预设 = 资源工厂，宿主预设 = 用户注册资源

---

## 2. ATELIER 设计规范

### 2.1 方向词

- **温纸**：暖白纸面、赭墨正文、低饱和。编辑器是"工作台"不是"仪表盘"。
- **铜墨**：唯一品牌强调色 `copper #B56C4C`。功能性元素不用第二强调色。
- **精密**：4px 网格、单层边框、阴影克制（elevation ≤3）、动效 ≤280ms。
- **双生**：Editor 与 Runtime 共享种子层，但语义层、字号、密度各自独立。

### 2.2 Color System

三层结构（详见 `tokens/*.json`）：

- **A1 种子层** `base.json`：纸/墨/铜 + 功能色（ok/warn/err/info）+ 运行时强调色族（brass/persimmon/sage/oxblood/…，即已上线的 v2 统一色板，并入 ATELIER）。
- **A2 语义层** `editor.json` / `runtime.json`：只写角色名（`bg.surface`、`accent.default`），值用 `$ref` 引用种子层。
- **B 槽位**：组件级槽（`choice.selected.borderAlpha`），预设可覆盖；不覆盖时用默认值，保证组件总能渲染。
- **C 扩展**：预设/宿主私有（如 `morpho.crystalBorder`），通用组件禁止引用。

规则：

- 语义层**不允许出现裸色值**，必须 `$ref` 到种子层。
- 一个页面同时出现的强调色 ≤1（含功能色则 ≤2）。
- 暗色场景正文一律 `parchment #E9E2D4`，亮底一律 `ochre #3B322C`——与已上线的 runtime v2 一致。
- 状态色只允许出现在状态语义的组件上（校验器、通知），不得用于装饰。

### 2.3 Typography System

| 角色 | 编辑器 | 运行时 | 字重 |
|---|---|---|---|
| caption / hint | 13 | 13 | regular |
| body | 14 | 22 | regular |
| label / 选项 | 13 | 19 | medium |
| title / 说话人 | 18 | 22 | semibold |
| display / 分区标题 | 28 | — | semibold |

- 运行时字号整体放大（玩家视距 > 操作者视距）；**禁止**把编辑器字号规则套到运行时。
- 字重只开放 regular/medium/semibold 三档。
- 字体栈：编辑器 = 系统 UI 字体；运行时可由 `font_path` 覆盖，未指定时走 `font_style`（sans/serif/mono/rounded）回退链。行距 `line_separation` 默认 8（=space.2）。

### 2.4 Spacing System

4px 基准：`space.1..16` = 4..64。控件内边距只取 `space.2/3/4`；区块间距 `space.4/6/8`；页面边距 `space.8/10/12`。
运行时面板内容边距统一 `32/32/22/14`（已上线），结构性例外必须在 preset 工厂中显式写出（如 astrolabe 左侧星盘让位 96）。

### 2.5 Border & Radius

- 半径：`none/sm(4)/md(8)/lg(12)/xl(16)/xxl(22)/pill`。编辑器默认 sm，面板 md；运行时由预设决定但只允许取表中值。
- 边框宽度只允许 `0/1/2/3`；双层边框 = `border.default` + `frame_inner`（虚线/实线），不得超过两层。
- 分隔线透明度 ≤0.2，不画 1px 以下的线。

### 2.6 Shadow & Elevation

4 级：e0 无 / e1 悬浮控件（offset 0,2 size 6 α.16）/ e2 面板（0,4,12,.24）/ e3 模态与大面板（0,7,20,.45）。彩色硬投影（hard_shadow）只允许出现在运行时装饰性面板，编辑器禁用。

### 2.7 Iconography

- 编辑器用单色功能图标（Lucide 风格，stroke 1.5px），不用 emoji 作为 UI 图标。
- 运行时 glyph（❖✦☽ 等）属于预设层 C 扩展，不是 ATELIER 图标系统。
- 图标盒 16/20px，触控目标 ≥24px。

### 2.8 Component Guidelines（摘要）

- **Button**：primary = accent 底 + onAccent 字；secondary = surface 底 + 边框；ghost = 无框。高度 sm 24 / md 28 / lg 36。
- **Panel/Modal**：surface 底 + border.default + e2/e3 + radius.md；标题栏 paddingY = space.3。
- **Field（编辑器属性行）**：label 13px secondary + 控件 28px 高；行高 32；分组间距 16；同组字段垂直节奏 4px。
- **DialoguePanel**：语义结构 = `nameplate`（浮出 -28）+ `text` + `hint`；内容区只读 `layout.contentMargin`。
- **ChoiceRow**：高 48、间距 12、选中位移 +6、marker 位 24px；状态色只换 `bg/border/text` 三通道。
- **Tooltip**：surface 底 + e1 + radius.sm + caption 字号，延迟 400ms。

### 2.9 Interaction States

统一五态，任何可点控件必须全部定义：`normal / hover / pressed / focus / disabled`；另加 `loading / error / success` 于表单类组件。

| 状态 | 规范 |
|---|---|
| hover | 背景 +1 层（surface→hover）或文字 → accent.hover；只改一个通道 |
| pressed | accent.pressed 或背景 -1 层（pressed）；持续 motion.fast |
| focus | `border.focus` 1px 外描边（铜棕 hi），不改变内部填充 |
| disabled | 整体 alpha 0.4，禁止改变色相 |
| loading | 内容区 spinner + disabled；不闪烁 |
| error | `semantic.err` 仅用于边框/图标/文案，不填充整个控件 |
| success | `semantic.ok`，出现 ≤3s 后可自动消失 |

### 2.10 Motion Guidelines

- 时长：fast 120ms（hover/提示）、base 180ms（面板/展开）、slow 280ms（场景级转场）、exit 100ms。
- 缓动：入场 cubic-out、出场 quad-in（Godot `TRANS_CUBIC+EASE_OUT` / `TRANS_QUAD+EASE_IN`）。运行时对话框出场已符合。
- 只允许 tween 两类属性：透明度 + 几何位移（≤10px）；禁止缩放弹跳。
- `ornament_rotation_speed` 这类常驻微动画 ≤12°/s，且必须能被 `EditorSettings` 级别开关关掉。

### 2.11 Accessibility

- 正文对比度 ≥4.5:1（parchment/inkDeep、ochre/paper 均满足）。
- 交互状态不得仅靠色相传达：selected 同时有位移（+6px）或 marker 变化。
- Focus 永远可见（键盘导航场景）。
- 字号下限：编辑器 12，运行时 13（hint）；无上限（宿主可调）。

### 2.12 Responsive Layout

- 编辑器面板最小可用宽度 280px；窄于此折叠为单列 + 分段下拉（现状已有，保留）。
- 运行时面板以锚点比例布局（`panel_left/right/top/bottom`），禁止写死像素；极端矮窗口下优先保证正文最小行数，选项面板允许内部滚动（已有行为，写入规范）。

### 2.13 Visual QA

- 每个组件必须覆盖"状态矩阵"：5 个交互态 × 2 个长度（短/长文本）× 需要时 2 个分辨率。
- 回归方式沿用现有 headless 截图脚本：`tools/theme_presets_shots.gd` 扩展为 ATELIER QA 工具，输出按 组件/状态 命名。
- 验收以"像素对比 + 人审标注"两级：结构性变更必须附前后对比图。

---

## 3. Token 体系与双端架构

### 3.1 文件布局（已建）

```
design-system/
├── DESIGN.md               # 本文件：规范散文（A1 文档契约）
├── tokens/
│   ├── base.json           # A1 种子层（已建）
│   ├── editor.json         # A2 编辑器语义层（已建）
│   └── runtime.json        # A2 运行时语义层（已建）
├── components/             # 组件规范（实施期按需补）
└── godot/                  # 编译产物（实施期生成，不入源码评审）
```

评估：用户给的示例目录中 `components/*.md`、`godot/*.tres` 属于实施产物，不在本阶段创建；`dark.json/light.json` 暂不需要——editor 为 dark-warm 单一方向，runtime 明暗由预设决定，将来需要时按同层追加即可。

### 3.2 架构：一个源，两个编译目标

```
tokens/*.json ──(tools/atelier_build.py, 纯 stdlib)──┬─→ core/theme/atelier_tokens.gd   (生成, const Dictionary)
                                                    ├─→ studio_design.gd 改写为读 atelier token（API 签名不变）
                                                    └─→ runtime 语义默认值（RpgEventStudioTheme 工厂/_base 引用）
```

- 生成物是 `.gd` const 字典而非 `.tres`，避免序列化/加载路径问题；`.tres` 输出在确有需求时再加（DialogueTheme 本身是 Resource，不依赖 theme.tres）。
- `studio_design.gd` 改为 **atelier_tokens 的薄壳**：保留 `OBSIDIAN/SURFACE/...` 常量名作 alias 指向新 token 值，`box()/editor_theme()/primary_button()` 签名不动 → 现有调用点零改动。
- 编辑器色迁移：OBSIDIAN(#090B10)→`bg.base` inkDeep(#1A1916)、GOLD(#D2AE6E)→copper(#B56C4C) 等，色温从冷蓝转暖墨。这是一次有意的视觉变更，需配前后对比截图验收。

### 3.3 Editor/Runtime 隔离规则

- 语义层两份文件、两个命名空间（`editor.*` / `runtime.*`）；**禁止跨层 `$ref`**（runtime 不得 ref `editor.bg`）。
- 共享只发生在 A1 种子层（纸/墨/铜/功能色值相同，用途不同）。
- `studio_design.gd` 只服务编辑器；运行时着色只走 `RpgEventStudioTheme`/`dialogue_theme_presets.gd`。中间以 `atelier_tokens.gd` 作为唯一共享读点，任何文件不得反向依赖。

### 3.4 第三方扩展与主题继承

- 预设 = `DialogueThemePresets.create(id)` 工厂 + `PRESETS` 元信息（现状保留为兼容门面）。
- 扩展机制（下一阶段）：`register_preset(meta, overrides)`——overrides 为扁平字段字典打在 `_base()` 上；`based_on` 链式继承（深度 ≤4，防环）。
- 宿主私有字段走 C 扩展：写到 `RpgEventStudioTheme` 上未占用的新导出字段或 `meta` 字典，通用组件不读。
- B 槽位兜底：`choice.states` 等槽位预设不覆盖时使用 `runtime.json` 默认值，组件总能渲染。

---

## 4. Godot 4.7.2 技术实现方案

| 决策 | 方案 | 理由 |
|---|---|---|
| Token 源 | JSON（`tokens/*.json`） | 可被 Python/GDScript 双读；Diff 友好 |
| 编译器 | `tools/atelier_build.py`（标准库） | 仓库约定：脚本只用 stdlib |
| 编辑器消费 | 生成 `atelier_tokens.gd` const Dictionary；`studio_design.gd` 做别名层 | API 不变，调用点零改动 |
| 运行时消费 | `dialogue_theme_presets.gd` 的色板常量继续存在，但其**值**改为引用 `atelier_tokens` 语义名 | 与 v2 统一色板成果合并，不重复造轮 |
| Theme.tres | 暂不生成；`editor_theme()` 以代码构建 Theme 的现状保留 | 避免新增资源加载面 |
| 字体 | 编辑器沿用系统字体；运行时 `font_path`/`font_style` 回退链不变 | 跨平台 CJK 已可控 |
| 图标 | 编辑器功能图标后补（独立任务，非本批） | 当前无图标体系，不阻塞 |

## 5. 现有工程兼容性分析

- **`studio_design.gd`（238 行）**：保留全部公共 API（常量名 + 9 个 static func），仅常量取值迁移到 ATELIER。风险：编辑器全部面板视觉变化——需要一轮编辑器截图对比验收。
- **`RpgEventStudioTheme`**：字段不动、`.tres` 兼容不动、`style_version` 语义不变。ATELIER 只影响**预设工厂的取值**，不影响字段模型。
- **`DialogueThemePresets`**：已完成的 v2 统一色板（INK/PAPER/强调色族）正是 runtime.json 的 A1 取值——**本次工作是对齐而非推翻**。色板常量保留在本文件内作为运行时侧别名，语义层 JSON 为单一源。
- **`DialoguePresenter` 及组件**：不改。状态规范只约束未来组件行为；现有 hover/selected 表现已符合（choice_selected_shift、marker）。
- **旧 `.tres` 主题**：加载路径无任何变化。
- **两套体系不合并**：`studio_design`（编辑器）与 `RpgEventStudioTheme`（运行时）维持双轨，中间仅经 `atelier_tokens.gd` 只读桥接。

## 6. 组件清单与优先级

| 优先级 | 组件 | 端 | 现状 | 本系统下的动作 |
|---|---|---|---|---|
| P0 | Token 编译链 + atelier_tokens.gd | 共享 | 无 | 新建 |
| P0 | studio_design 迁移 | Editor | 可用 | 常量值迁移，API 不动 |
| P1 | 编辑器 Field/分组/滚动区规范 | Editor | 主题页 ~130 控件无结构 | 写 components/fields.md + 应用 |
| P1 | Button/Panel/Modal 规范 | Editor | 已用 primary_button/modal_style | 统一为 token 驱动 |
| P1 | 交互五态落地 | Editor | 部分有 hover | 补齐 pressed/focus/disabled |
| P2 | 预设注册 + 继承（registry） | Runtime | 硬编码 10 套 | 按既定 Phase 2 设计实施 |
| P2 | 编辑器主题页条件显示/搜索 | Editor | 无 | 按既定 Phase 3 设计实施 |
| P3 | Storybook 式组件预览页 | Editor | 截图脚本代替 | theme_presets_shots 扩展 |
| P3 | 图标体系 | Editor | 无 | 后置 |

## 7. 视觉验收标准

1. `tools/atelier_build.py` 输出与 `tokens/*.json` 逐字段一致（自动校验脚本，含 `$ref` 解析与裸色检测）。
2. 编辑器迁移后：主面板/事件图/主题页/弹窗各拍前后对比图；无功能性布局破坏（按钮不溢出、文字不被截断）。
3. 运行时 10 套预设：字段级 diff 应**零变化**（本次只改常量引用不改值）；若同时调整取值，按截图逐套确认。
4. `dialogue_theme_presets_test`（305）+ `dialogue_pagination_test`（282）+ `presenter_lifecycle_test`（48）+ `input_coexistence_test`（35）全绿。
5. 对比度抽查：每个预设正文/底面板组合满足 ≥4.5:1（写进 QA checklist，可脚本化）。

## 8. 分批实施计划（建议，待批准）

| 批 | 内容 | 风险 | 验收 |
|---|---|---|---|
| A0 | 本 DESIGN.md + tokens 审阅定稿 | 无 | 你确认 |
| A1 | `tools/atelier_build.py` + `atelier_tokens.gd` 生成 + 校验测试 | 低 | token 一致性测试 |
| A2 | `studio_design.gd` 迁移（API 不变的常量换值） | 中（编辑器观感变化） | 编辑器截图对比 |
| A3 | 编辑器五态 + Field 规范应用到主题页 | 中 | ui_smoke/editor 套件 + 截图 |
| A4 | 预设 registry（Phase 2 既定设计，overrides + based_on + register_preset） | 中高 | 新旧工厂字段等价测试 |
| A5 | 主题页条件显示/搜索/另存为（Phase 3 既定） | 中 | theme_editor 测试 |
| B+ | 组件库文档、图标、扩展 QA | 低 | checklist |

当前 `feat/theme-system-upgrade` 分支的合并基线工作（B0）已完成并全绿；色板统一 v2 已并入本方案作为 runtime A1 取值。A1 起的工作建议仍在本分支推进。

## 9. 预计文件修改范围与风险

**新增**：`tools/atelier_build.py`、`core/theme/atelier_tokens.gd`（生成）、`design-system/components/*.md`、`tests/atelier_tokens_test.gd`。
**修改**：`studio_design.gd`（常量取值→别名）、`dialogue_theme_presets.gd`（色板常量→token 引用）、主题页相关 editor 文件（A3/A5 阶段）。
**不碰**：`dialogue_box.gd`、`runtime/ui/theme/*`、`RpgEventStudioTheme` 字段定义、任何 `.tres`、main/release 分支与其他 worktree。
**最大风险点**：编辑器观感整体从冷蓝转暖墨（需你验收）；`register_preset` 落地时对 `PRESETS` 兼容门面的封装需要等价性测试兜底（沿用 Phase 2 既定的字段比对器方案）。

## 10. 待你拍板的开放点

1. **Editor 改暖墨方向**：`OBSIDIAN #090B10 → inkDeep #1A1916`、`GOLD → copper`。确认接受编辑器整体变"暖"？（备选：保持冷底仅换 token 结构）
2. **runtime 墨色**：现统一 INK `#14171D` 偏冷，ATELIER ink 偏暖 `#1A1916`。建议运行时保留冷墨作为 runtime 身份、种子层两者并存——当前文档即此方案，确认或要求统一。
3. **色板常量位置**：runtime 强调色族同时存在于 `base.json` 与 presets 常量——以 JSON 为唯一源、`.gd` 常量由构建器重写，还是允许两处手维护？（推荐前者）
4. **组件规范文档粒度**：A3 开始逐组件写 `components/*.md`，还是合并为一份 `components.md`？
