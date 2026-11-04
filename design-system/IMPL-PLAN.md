# ATELIER v5 → Godot 实施计划

设计稿：`design-system/presets-v5.html`（浏览器近似，Godot 实机为准）。
色板源：`design-system/palette.json` 的染灰×强调配对（下表给出 hex）。

## 阶段划分

### Phase 1 · 地基（本批）
1. 字体：`addons/rpgeventstudio/fonts/` 内置 OFL 字体（见下表），`.import` 一并提交。fonttools 不在则用 `python3 -m pip install --user fontTools` 子集化到 GB2312 一级+二级（~6700 字）；子集化失败则保留全量并在报告里写体积。
   - serif=Noto Serif SC（思源宋体）、sans=Noto Sans SC（思源黑体）、kai=LXGW WenKai（文楷）、kuaile=ZCOOL KuaiLe（站酷快乐体）、qingke=ZCOOL QingKe HuangYou（庆科黄油体）、xiaowei=ZCOOL XiaoWei（小薇体）、brush=Ma Shan Zheng（马善政）、mono=JetBrains Mono、pixel=Fusion Pixel 12px（找不到则用 DotGothic16 并在报告注明）。
   - `dialogue_theme.gd` 新增：`font_path_body`、`font_path_choice`（缺省沿用 `font_path`，向后兼容）。字体取 res:// 内置路径。
2. 主题新字段（dialogue_theme.gd，全部有默认值，旧 .tres 兼容）：
   - `speaker_title: String = ""`（称号，铭牌内或下方小字）
   - `choice_layout: String = "top"`（top-right|top-center|top-left|inside|chat|separate）
   - `choice_align: String = "right"`（right|center|left）+ `choice_stagger: bool=false`（错落缩进）
   - `portrait_placement: String = "slot"`（slot|large-left|large-right|large-center|none）：大立绘=新 Control 位于 panel 之后、出框，`portrait_size` 为槽位小头像沿用
   - `advance_indicator: String = "none"`（none|tri|tri-down|diamond|dot|cursor-block|led|arrow-step|leaf）：几何绘制
   - `hint_style: String = "text"`（text|keycap|keycap-mono）：键帽=圆角矩形底+边框+字
   - `choice_marker` 增 enum 值：bar|tri|diamond|square|index|keycap|leaf|none（theme_choice_row 里几何绘制，禁止字符）
   - `panel_entrance: String = "fade"`（fade|rise|pop|slide-left|wipe|stamp|grow|step-open|none）+ `panel_entrance_ms: int`
   - `loop_anim: String = "none"`（none|pulse|bob|nudge|blink|flicker|float|hop|sway|led）：作用于推进指示/铭牌
   - `select_anim: String = "none"`（none|grow-line|bar-up|shift|glow|stamp-line|pop|step-cursor）
   - `speaker_tracking: float = 0.0`（铭牌字距，em→px 换算×字号）
   - 所有新增 enum 值都要进 `validate()`（若已实现）与 theme view 的 SECTIONS。
3. 渲染改造（runtime/ui/theme/*）：
   - `dialogue_nameplate.gd`：新增样式 plaque（金属铭板：底+内框线）、seal（方形朱印，rotate -4°）、floating（无底悬浮+称号）、callsign（两段式：实底名+描边代号）、phone（聊天头部）；支持 speaker_title 副标签。无 glyph 时不再画任何字符。
   - `theme_choice_row.gd`：marker 全部几何绘制（fill_rect/polygon），删除 "── ✦" 字符；新增样式：paper-sign（Codex 纸签）、keycap-index（Terminal 数字键帽）、pill-solid（Candy）、skew-strip（Tide）、underline-list（Ember/Ink）、glass-row（Frost）、ink-stroke（墨迹下划线）、pixel-box（像素阶梯描边：4 条 rect 拼阶梯）、chat-chip（回复胶囊）、leaf-row（Grove）。
   - `dialogue_panel_decor.gd`：新增 shape：double-inner-line（Ember 双发丝）、glass（Frost 半透明高光）、pixel-stepped（阶梯描边）、cut-corner-thick（Tactical 厚切角）；所有 pattern 保持 none。
   - `dialogue_box.gd`：`choice_layout` 五种落位；inside=选项进面板右栏（两栏 GridContainer）；chat/separate 结构。`portrait_placement=large-*` 时创建大立绘 Control（PanelContainer+TextureRect），在 panel 下层 z 序。`advance_indicator`/`hint_style` 渲染（keycap 用一个小的 _draw 控制）。入场/循环/选中动画用 Tween + `_process` 轻微摆动，遵循 420ms/4px/±2° 限制 + `reduced_motion` 主题开关（新增 bool `motion_reduced`）。
4. 预设重写：10 个工厂 → 12 个（id：verse codex terminal candy tide ember frost ink pixel nocturne grove tactical）。PRESETS meta 同步（title/tab/tag/description/bullets/colors/stage）。保留老 id 的兼容：`create("feather")`→verse、`create("sacred")`→codex 等映射表，旧 .tres 的 preset_id 自动迁移（函数 `migrate_preset_id`）。
   - 尺寸取 preview 数值近似；色值用下表。
5. 字体颜色/字体名按设计稿落实：`font_path`/`font_path_body`/`font_path_choice` 指向 res:// 内置字体；speaker/body/choice/hint 四色全部显式赋值。
6. 测试：`dialogue_theme_presets_test` 更新为 12 套；新增检查：字体路径存在（ResourceLoader.exists）、无 emoji/无装饰字符（沿用已写的 emoji 检查）、布局字段合法值、旧 preset_id 迁移表。`test_counts.json` 更新。
7. `tools/theme_presets_shots.gd`：12 套重拍 1280×820（含立绘占位用大色块 TextureRect 即可）。
8. `studio_design.gd` 不动。本阶段**不做**：编辑器主题页新字段分组（Phase 2）、减少动画设置入口（Phase 2）、Nocturne 的多气泡（先单条消息+回复行实现）。

### Phase 2（后续批）
主题页 UI 接入新字段、键帽提示随 InputService 切换、motion_reduced 设置、编辑器截图验收。

### Phase 3（后续批）
Night chat 多气泡历史、像素独立窗口滚动、霜原 blur 着色器评估、性能 profile。

## 12 套规格速查（gray×accent，形状，字体，布局，动画）

| id | 染灰 | 强调 | 形状 | 字体(名/正) | 布局要点 | 入场/循环/选中 |
|---|---|---|---|---|---|---|
| verse | slate | brass | 无框发丝线 | serif/kai | 居中；选项居中，间隔30；无立绘 | growX+pulse·菱形呼吸·两端线生长 |
| codex | sand | copper | 圆角6+双线框+角框 | serif/serif | 选项右上右对齐；大立绘左 | rise·三角bob·三角光标 |
| terminal | graphite | teal | 圆角4+页签+角框 | sans/mono | 选项在面板右栏 inside | wipe·光标块blink·辉光 |
| candy | mauve | persimmon | 圆角24粗描边2.5+硬影 | kuaile/sans500 | 选项右上；大立绘左 | pop·圆点hop·胶囊弹跳 |
| tide | navy | cyan | 顶部2px线+右下切18 | qingke/sans500 | 选项左错落18/0/30；立绘右 | slide+slam·三角nudge·错位投影 |
| ember | char | oxblood | 切角14双发丝内框 | serif/serif | 选项中上居中；立绘左 | 慢fade+生长线·diamond闪烁·双菱形 |
| frost | slate | indigo | 圆角8玻璃+顶短线 | xiaowei/sans | 选项右上；名悬浮；立绘左 | rise·名字float·指示条bar-up |
| ink | sand | clay | 无边横线上下1px | kai/kai | 选项左上无框墨迹线；立绘右 | stamp印章·圆点呼吸·下划线刷出 |
| pixel | indigo | amber | 阶梯4px描边 | pixel/pixel | 选项独立窗口右上 | step-open·步进闪烁·光标跳行 |
| nocturne | plum | amber | 圆角18手机框 | sans/sans | chat 布局；立绘左 | rise+气泡逐条·三点dot·芯片描边 |
| grove | olive | moss | 叶形圆角28/6 | kai/kai | 选项右上；立绘左 | grow·sway±2°·叶点摆动 |
| tactical | olive | amber | 厚切角+标签条 | sans/mono | 选项左上间距30；立绘右 | wipe+flash·led闪烁·实底反色 |

## 色值（hex，全部来自 palette.json）

sand: 50#FEF9F4 100#FAF2EA 200#ECE5DC 300#DAD3CB 400#B7B0A8 500#928B83 600#746D66 700#58514A 800#3D3730 900#27221C 950#19140E 975#0F0C08
mauve: 50#FFF8FA 100#FDEFF4 200#F0E2E7 300#DDD0D5 400#BAADB1 500#95888C 600#776B6F 700#5A4F53 800#3F3538 900#292023 950#1B1215 975#100B0C
slate: 50#F7FAFF 100#ECF4FE 200#DFE7F1 300#CDD5DF 400#AAB2BB 500#868D96 600#696F78 700#4D535B 800#323840 900#1E232B 950#10151C 975#090C10
navy: 50#F7FAFF 100#EDF4FF 200#D9E7FC 300#C8D5EA 400#A5B2C6 500#808DA0 600#637082 700#485364 800#2E3949 900#192332 950#0C1523 975#070C14
graphite: 50#F7FBFC 100#EFF5F7 200#E1E7E9 300#CFD5D7 400#ACB2B4 500#888D8F 600#6A7071 700#4E5355 800#34393A 900#1F2425 950#121617 975#0A0D0D
char: 50#FFF8F8 100#FFEFEE 200#F2E2E0 300#E0D0CE 400#BCADAB 500#978887 600#796B69 700#5C4F4D 800#413433 900#2B201E 950#1C1211 975#110A0A
olive: 50#FAFBF4 100#F4F4EA 200#E6E7DD 300#D4D5CB 400#B1B2A8 500#8C8D83 600#6F6F66 700#53534B 800#383930 900#23231C 950#15160E 975#0C0D09
plum: 50#FDF4FB 100#F7E7F5 200#EFD4EC 300#E0B9DB 400#CB9CC6 500#B17EAC 600#93658F 700#754E72 800#583855 900#3C243A 950#271626 975#1A0C19
indigo: 50#F4F7FF 100#E6ECFF 200#D3DDFE 300#B7C5F6 400#9AABE6 500#7D8ECE 600#6474AE 700#4D5A8D 800#38426B 900#242C4A 950#151B32 975#0C1022
copper: 50#FFF4F0 100#FFE7DD 200#FCD4C4 300#F2B8A0 400#E09B7D 500#C77D5C 600#A76345 700#864C32 800#663722 900#462313 950#2F1509 975#200B04
brass: 50#FCF6ED 100#F6EBDC 200#EDDBC1 300#DDC39C 400#C9A878 500#AF8C56 600#91713F 700#74582C 800#57411D 900#3B2A0F 950#271A06 975#191002
amber: 50#FEF6E8 100#FAEBD2 200#F4DAB0 300#E7C180 400#D5A550 500#BB881B 600#9B6E04 700#7B5600 800#5B3F01 900#3E2A01 950#281A01 975#1A0F00
persimmon: 50#FFF4F5 100#FEE6EA 200#FED0D8 300#FEADBD 400#F18AA0 500#D86983 600#B7516A 700#933B52 800#70293C 900#4E1827 950#350D18 975#24050D
oxblood: 50#FFF4F4 100#FEE6E7 200#FED1D3 300#FDAFB4 400#F38B94 500#DB6976 600#B9515D 700#953C47 800#712933 900#4F1820 950#350D13 975#24050A
cyan: 50#EAFAFF 100#D5F3FC 200#B4E8F7 300#84D5EC 400#50BEDA 500#1CA2BF 600#01859F 700#0E687C 800#004E5D 900#01343F 950#012129 975#00151B
teal: 50#EBFBF8 100#D8F4EF 200#B9EAE3 300#8CD8CE 400#5DC2B6 500#28A79B 600#138A7F 700#096C64 800#07504A 900#033631 950#00231F 975#001613
moss: 50#F5F8EE 100#EAF0DE 200#D9E3C5 300#C0CEA1 400#A6B67E 500#899B5D 600#6F7F46 700#576433 800#3F4A22 900#2A3213 950#1A2009 975#0F1404
clay: 50#FFF4F1 100#FFE7DF 200#FED3C4 300#F6B6A0 400#E5987D 500#CC795D 600#AB6045 700#8A4932 800#683422 900#482113 950#301309 975#210A04
sage: 50#F1F9F6 100#E3F0EC 200#CEE4DD 300#AFD0C5 400#8FB8AC 500#709D90 600#578175 700#42665C 800#2E4C44 900#1D332D 950#10211C 975#081511
rose: 50#FFF4F5 100#FCE7EA 200#F8D3D9 300#ECB7BF 400#D99AA4 500#C07C88 600#A1636E 700#814C56 800#61363F 900#432329 950#2C1519 975#1E0B0F
aegean: 50#EEF9FF 100#DBF1FD 200#BFE4F9 300#97D0EF 400#70B8DE 500#499DC5 600#3081A6 700#1E6586 800#0F4B65 900#043246 950#01202F 975#00141F
