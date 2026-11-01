@tool
class_name DialogueThemePresets
extends RefCounted
## 第二批 RPG 对话框主题预设注册表与工厂。
##
## 约定：
## - 预设是“工厂”，不是全局单例。每次 create() 都返回新的 RpgEventStudioTheme，
##   编辑器/运行时修改其中一套不会污染另一套。
## - 第一弹四套全部保留；第二弹按 Argon 的 v3 设计稿落地两套
##   （纯白神谕·琉璃彩窗、浮生水墨·朱砂方印按要求排除）。
## - Metadata 同时供主题编辑器展示（标题/标签/说明/色板），视觉参数全部落在
##   RpgEventStudioTheme 的字段里，由 DialoguePresenter + 可组合绘制组件消费。

const SERIES_1 := 1
const SERIES_2 := 2

const PRESETS := [
	{
		"id": "sacred",
		"series": SERIES_1,
		"title": "终焉圣堂 · 星辉银丝",
		"tab": "✨ 圣洁·星辉圣堂",
		"tag": "保留·暗夜圣堂",
		"description": "深邃夜空墨蓝渐变底 + 双层铂金细线内嵌框 + 四角星芒雕花；跨框圣徽铭牌与两端渐隐的羽翼选项。",
		"bullets": [
			"双层内嵌细框：外层暗金 + 内缩香槟金丝，四角嵌星芒。",
			"跨边框圣徽铭牌：顶部压线八角铭牌，两侧延伸金丝。",
			"无外框羽翼选项：两端渐隐的暗金光带，选中时星芒亮起。",
		],
		"colors": ["#0E131F", "#E5D1A7", "#7A6B4E", "#E2E6F0"],
		"stage_top": "#263147",
		"stage_bottom": "#080B12",
	},
	{
		"id": "cute",
		"series": SERIES_1,
		"title": "晴空波普 · 蜜桃苏打手账",
		"tab": "🍓 可爱·蜜桃波普",
		"tag": "保留·二次元波普",
		"description": "清爽奶白底 + 可可棕描边 + 蜜桃粉错位硬阴影；倾斜胶囊名字贴纸与独立药丸选项。",
		"bullets": [
			"错位贴纸硬投影：奶白底配可可棕实线边，右下偏移蜜桃粉投影。",
			"倾斜胶囊名字贴纸：左上角压线悬浮的蜜桃粉胶囊牌。",
			"独立胶囊药丸选项：每个选项是独立悬浮胶囊 + 序号圆章。",
		],
		"colors": ["#FFFDF9", "#FF6B93", "#4A3238", "#FFF07C"],
		"stage_top": "#CDEFFD",
		"stage_bottom": "#FFF3D6",
	},
	{
		"id": "cool",
		"series": SERIES_1,
		"title": "幻影过载 · 不对称斜切机能",
		"tab": "⚡ 超酷·绝区机能",
		"tag": "保留·赛博机能",
		"description": "左粗右隐的不对称装甲切边 + 平行四边形黑黄反色铭牌 + 带机能编号的斜切选项条。",
		"bullets": [
			"左装甲条 + 右侧消隐：赛博黄斜切亮条与品红副边。",
			"反色平行四边形铭牌：高饱和赛博黄底 + 纯黑粗斜体字。",
			"斜切反色高亮选项：平行四边形条，选中瞬间反色。",
		],
		"colors": ["#0B0D13", "#FCEE09", "#00F0FF", "#FF0055"],
		"stage_top": "#0B0D13",
		"stage_bottom": "#1D1128",
	},
	{
		"id": "minimal",
		"series": SERIES_1,
		"title": "寂静地平线 · 电影双栏留白",
		"tab": "🎬 极简·机械留白",
		"tag": "保留·科幻双栏",
		"description": "底部无边界电影柔光渐暗 + 顶部几何刻度线 + 左人名右台词双栏排版。",
		"bullets": [
			"无边框电影暗角：去掉左右封死边框，用底部柔光渐变承托文字。",
			"左人名 · 右台词双栏：黄金分割双栏 + 细竖线。",
			"左竖线光带选项：选中项仅在左侧亮起竖标与微光带。",
		],
		"colors": ["#121418", "#FFFFFF", "#9CA3AF", "#2B3038"],
		"stage_top": "#2B3038",
		"stage_bottom": "#121418",
	},
	{
		"id": "biscuit",
		"series": SERIES_2,
		"title": "焦糖曲奇 · 和纸胶带手账",
		"tab": "🧸 可爱·手账曲奇",
		"tag": "新增·温暖绘本",
		"description": "暖麦方格纸底 + 咖啡色虚线缝纫边 + 斜贴薄荷绿和纸胶带；拍立得相纸立绘框与便签纸选项。",
		"bullets": [
			"缝纫虚线 + 胶带角标：内圈烘焙棕虚线，左上斜贴薄荷胶带。",
			"拍立得相纸立绘框：立绘嵌在微倾的白边相纸框内。",
			"便签纸条选项：右侧便签纸造型，选中时浮起并出现小芽标记。",
		],
		"colors": ["#FDF8EE", "#5C3A21", "#78C2AD", "#F4A261"],
		"stage_top": "#4F6D5A",
		"stage_bottom": "#395144",
	},
	{
		"id": "crimson",
		"series": SERIES_2,
		"title": "猩红断头台 · 逆十字狂想",
		"tab": "🩸 超酷·猩红处决",
		"tag": "新增·暗黑怪谈",
		"description": "多边形斜切缺口黑框 + 猩红刀痕顶边 + 撕裂封条铭牌；纯黑斜切立绘框配猩红硬错位投影。",
		"bullets": [
			"多边形切角 + 猩红顶刃：左上与右下斜切缺口，顶部刺目猩红刀锋线。",
			"猩红残影立绘框：纯黑斜切框配右下角猩红硬错位投影。",
			"一闪贯穿选项：选中整条变为鲜血红底 + 纯白粗字 + 十字准星。",
		],
		"colors": ["#0B090C", "#E6002E", "#F8F9FA", "#590D22"],
		"stage_top": "#3B0813",
		"stage_bottom": "#070507",
	},
]

static func all_meta() -> Array:
	return PRESETS

static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for meta in PRESETS:
		out.append(str(meta.get("id", "")))
	return out

static func has_preset(id: String) -> bool:
	return ids().has(id)

static func meta(id: String) -> Dictionary:
	for item in PRESETS:
		if str(item.get("id", "")) == id:
			return item
	return {}

static func display_name(id: String) -> String:
	var item := meta(id)
	if item.is_empty():
		return "插件默认外观"
	return "%s · %s" % [str(item.get("tab", "")), str(item.get("title", ""))]

## 预设工厂。未知 id 返回插件默认外观（不是 null，调用方无需特判）。
static func create(id: String) -> RpgEventStudioTheme:
	var theme := RpgEventStudioTheme.new()
	theme.style_version = 2
	match id:
		"sacred":
			_sacred(theme)
		"cute":
			_cute(theme)
		"cool":
			_cool(theme)
		"minimal":
			_minimal(theme)
		"biscuit":
			_biscuit(theme)
		"crimson":
			_crimson(theme)
		_:
			return RpgEventStudioTheme.new()
	theme.preset_id = id
	var info := meta(id)
	theme.preset_title = str(info.get("title", ""))
	theme.preset_tag = str(info.get("tag", ""))
	theme.preset_description = str(info.get("description", ""))
	theme.preset_series = int(info.get("series", 0))
	return theme

## 恢复当前主题对应的出厂值：预设回到自己的工厂，旧主题回到插件默认外观。
static func factory_defaults(theme: RpgEventStudioTheme) -> RpgEventStudioTheme:
	if theme != null and theme.preset_id != "" and has_preset(theme.preset_id):
		return create(theme.preset_id)
	return RpgEventStudioTheme.new()

static func palette(id: String) -> PackedStringArray:
	var info := meta(id)
	var out := PackedStringArray()
	for color in info.get("colors", []):
		out.append(str(color))
	return out

# ── 公共基线 ─────────────────────────────────────────────

static func _base(theme: RpgEventStudioTheme) -> void:
	theme.style_version = 2
	theme.font_size = 18
	theme.text_font_size = 22
	theme.speaker_font_size = 22
	theme.hint_font_size = 13
	theme.choice_font_size = 19
	theme.line_separation = 8
	theme.text_speed = 42.0
	theme.appear_duration = 0.12
	theme.disappear_duration = 0.08
	theme.panel_left = 0.07
	theme.panel_right = 0.93
	theme.panel_bottom = 0.94
	theme.content_margin_left = 30
	theme.content_margin_right = 28
	theme.content_margin_top = 20
	theme.content_margin_bottom = 12
	theme.text_min_height = 76
	theme.choice_left = 0.58
	theme.choice_right = 0.93
	theme.choice_top = 0.28
	theme.choice_bottom = 0.64
	theme.choice_margin = 0
	theme.choice_separation = 12
	theme.choice_min_height = 48
	theme.choice_border_width = 1
	theme.choice_corner_radius = 8
	theme.choice_marker_width = 0
	theme.choice_marker_size = 17
	theme.nameplate_padding_x = 14
	theme.nameplate_padding_y = 5
	theme.nameplate_border_width = 1
	theme.nameplate_glyph = ""
	theme.nameplate_tag = ""
	theme.nameplate_shadow_color = Color(0, 0, 0, 0)
	theme.portrait_size = 100
	theme.portrait_aspect = 0.82
	theme.portrait_border_width = 1
	theme.portrait_corner_radius = 8
	theme.portrait_gap = 16
	theme.portrait_tint = Color(1, 1, 1, 1)

# ── 第一弹：终焉圣堂 ─────────────────────────────────────

static func _sacred(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.52
	theme.panel_bg_color = Color(0.043, 0.055, 0.090, 0.96)
	theme.panel_border_color = Color(0.620, 0.537, 0.376, 0.55)
	theme.panel_border_width = 1
	theme.panel_corner_radius = 0
	theme.panel_shadow_color = Color(0, 0, 0, 0.45)
	theme.panel_shadow_size = 14
	theme.panel_shadow_offset = Vector2(0, 4)
	theme.panel_shape = "rect"
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(0.067, 0.102, 0.169, 0.97)
	theme.panel_gradient_bottom = Color(0.031, 0.043, 0.071, 0.98)
	theme.frame_style = "ornament"
	theme.frame_inner_color = Color(0.898, 0.820, 0.655, 0.34)
	theme.frame_inner_gap = 5
	theme.frame_inner_width = 1
	theme.corner_ornament = "star"
	theme.corner_ornament_color = Color(0.898, 0.820, 0.655, 0.72)
	theme.corner_glyph = "✦"
	theme.corner_ornament_size = 13
	theme.pattern_style = "none"
	theme.accent_color = Color(0.898, 0.820, 0.655, 1)
	theme.accent_secondary = Color(0.478, 0.420, 0.306, 1)
	theme.content_margin_left = 30
	theme.content_margin_right = 28
	theme.content_margin_top = 22
	theme.font_style = "serif"
	theme.body_font_flavor = "serif"
	theme.text_color = Color(0.886, 0.902, 0.941, 1)
	theme.speaker_color = Color(0.953, 0.898, 0.753, 1)
	theme.hint_color = Color(0.788, 0.690, 0.478, 0.9)
	theme.nameplate_style = "float"
	theme.nameplate_bg = Color(0.051, 0.071, 0.114, 0.98)
	theme.nameplate_border = Color(0.831, 0.722, 0.478, 1)
	theme.nameplate_border_width = 1
	theme.nameplate_radius = 0
	theme.nameplate_text_color = Color(0.953, 0.898, 0.753, 1)
	theme.nameplate_accent = Color(0.898, 0.820, 0.655, 1)
	theme.nameplate_glyph = "❖"
	theme.nameplate_offset = Vector2(20, -26)
	theme.nameplate_shadow_color = Color(0, 0, 0, 0.5)
	theme.nameplate_shadow_offset = Vector2(0, 2)
	theme.nameplate_padding_x = 12
	theme.choice_panel_style = "bare"
	theme.choice_style = "wing"
	theme.choice_normal_bg = Color(0.043, 0.059, 0.098, 0.72)
	theme.choice_selected_bg = Color(0.130, 0.153, 0.212, 0.94)
	theme.choice_text_color = Color(0.788, 0.820, 0.875, 1)
	theme.choice_selected_color = Color(1.0, 0.973, 0.906, 1)
	theme.choice_hover_bg = Color(0.118, 0.145, 0.212, 0.94)
	theme.choice_hover_text_color = Color(0.953, 0.898, 0.753, 1)
	theme.choice_border_color = Color(0.898, 0.820, 0.655, 0.30)
	theme.choice_selected_border_color = Color(0.953, 0.898, 0.753, 0.95)
	theme.choice_accent_color = Color(0.898, 0.820, 0.655, 1)
	theme.choice_marker = "glyph"
	theme.choice_marker_glyph = "✦"
	theme.choice_marker_width = 24
	theme.choice_selected_shift = 8
	theme.choice_min_height = 48
	theme.portrait_enabled = true
	theme.portrait_style = "square"
	theme.portrait_ornament = "star"
	theme.portrait_size = 104
	theme.portrait_aspect = 0.78
	theme.portrait_bg = Color(0.078, 0.106, 0.176, 1)
	theme.portrait_border_color = Color(0.831, 0.722, 0.478, 1)
	theme.portrait_inner_border = 1
	theme.portrait_inner_color = Color(0.898, 0.820, 0.655, 0.35)
	theme.portrait_accent = Color(0.898, 0.820, 0.655, 1)
	theme.portrait_shadow_color = Color(0, 0, 0, 0.45)
	theme.portrait_shadow_offset = Vector2(0, 3)
	theme.portrait_glyph = "✦"
	theme.portrait_gap = 16

# ── 第一弹：晴空波普 ─────────────────────────────────────

static func _cute(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.56
	theme.panel_bg_color = Color(1.0, 0.992, 0.976, 0.98)
	theme.panel_border_color = Color(0.290, 0.196, 0.220, 1)
	theme.panel_border_width = 3
	theme.panel_corner_radius = 22
	theme.panel_shadow_color = Color(0, 0, 0, 0.16)
	theme.panel_shadow_size = 10
	theme.panel_shadow_offset = Vector2(0, 3)
	theme.panel_shape = "rect"
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(1.0, 0.992, 0.976, 1)
	theme.panel_gradient_bottom = Color(1.0, 0.969, 0.941, 1)
	theme.hard_shadow_color = Color(1.0, 0.553, 0.631, 1)
	theme.hard_shadow_offset = Vector2(6, 7)
	theme.frame_style = "plain"
	theme.pattern_style = "dots"
	theme.pattern_color = Color(1.0, 0.553, 0.631, 0.12)
	theme.pattern_spacing = 18
	theme.accent_color = Color(1.0, 0.420, 0.576, 1)
	theme.accent_secondary = Color(1.0, 0.941, 0.486, 1)
	theme.text_color = Color(0.290, 0.196, 0.220, 1)
	theme.speaker_color = Color(1.0, 1.0, 1.0, 1)
	theme.hint_color = Color(0.929, 0.420, 0.576, 1)
	theme.font_style = "sans"
	theme.body_font_flavor = "rounded"
	theme.nameplate_style = "capsule"
	theme.nameplate_bg = Color(1.0, 0.420, 0.576, 1)
	theme.nameplate_border = Color(0.290, 0.196, 0.220, 1)
	theme.nameplate_border_width = 3
	theme.nameplate_radius = 16
	theme.nameplate_text_color = Color(1, 1, 1, 1)
	theme.nameplate_accent = Color(1.0, 0.941, 0.486, 1)
	theme.nameplate_glyph = "🍓"
	theme.nameplate_offset = Vector2(20, -28)
	theme.nameplate_rotation = -2
	theme.nameplate_shadow_color = Color(0.290, 0.196, 0.220, 1)
	theme.nameplate_shadow_offset = Vector2(3, 3)
	theme.nameplate_padding_x = 14
	theme.choice_panel_style = "bare"
	theme.choice_style = "pill"
	theme.choice_normal_bg = Color(1.0, 0.992, 0.976, 1)
	theme.choice_selected_bg = Color(1.0, 0.459, 0.592, 1)
	theme.choice_text_color = Color(0.349, 0.227, 0.259, 1)
	theme.choice_selected_color = Color(1, 1, 1, 1)
	theme.choice_hover_bg = Color(1.0, 0.835, 0.886, 1)
	theme.choice_hover_text_color = Color(0.290, 0.196, 0.220, 1)
	theme.choice_border_color = Color(0.290, 0.196, 0.220, 1)
	theme.choice_selected_border_color = Color(0.290, 0.196, 0.220, 1)
	theme.choice_border_width = 3
	theme.choice_corner_radius = 22
	theme.choice_accent_color = Color(1.0, 0.941, 0.486, 1)
	theme.choice_marker = "number"
	theme.choice_marker_glyph = "★"
	theme.choice_marker_width = 28
	theme.choice_marker_size = 16
	theme.choice_selected_shift = 6
	theme.choice_min_height = 50
	theme.choice_shadow_color = Color(0.290, 0.196, 0.220, 0.35)
	theme.choice_shadow_offset = Vector2(3, 3)
	theme.portrait_enabled = true
	theme.portrait_style = "rounded"
	theme.portrait_ornament = "glyph"
	theme.portrait_size = 104
	theme.portrait_aspect = 0.90
	theme.portrait_bg = Color(1.0, 0.890, 0.925, 1)
	theme.portrait_border_color = Color(0.290, 0.196, 0.220, 1)
	theme.portrait_border_width = 3
	theme.portrait_corner_radius = 18
	theme.portrait_shadow_color = Color(1.0, 0.553, 0.631, 1)
	theme.portrait_shadow_offset = Vector2(3, 3)
	theme.portrait_glyph = "🎀"
	theme.portrait_gap = 14

# ── 第一弹：幻影过载 ─────────────────────────────────────

static func _cool(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.54
	theme.panel_bg_color = Color(0.039, 0.047, 0.071, 0.96)
	theme.panel_border_color = Color(0.988, 0.933, 0.035, 0.0)
	theme.panel_border_width = 0
	theme.panel_corner_radius = 0
	theme.panel_shadow_color = Color(0, 0, 0, 0.55)
	theme.panel_shadow_size = 16
	theme.panel_shadow_offset = Vector2(0, 5)
	theme.panel_shape = "slant"
	theme.panel_slant_size = 10
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(0.039, 0.047, 0.071, 0.97)
	theme.panel_gradient_bottom = Color(0.078, 0.094, 0.141, 0.97)
	theme.pattern_style = "grid"
	theme.pattern_color = Color(0.988, 0.933, 0.035, 0.08)
	theme.pattern_spacing = 16
	theme.hard_shadow_color = Color(1.0, 0.0, 0.333, 0.50)
	theme.hard_shadow_offset = Vector2(5, 5)
	theme.frame_style = "armor"
	theme.armor_bar_width = 5
	theme.top_blade_color = Color(0.0, 0.941, 1.0, 1)
	theme.top_blade_width = 0
	theme.accent_color = Color(0.988, 0.933, 0.035, 1)
	theme.accent_secondary = Color(0.0, 0.941, 1.0, 1)
	theme.text_color = Color(0.933, 0.965, 1.0, 1)
	theme.speaker_color = Color(0.090, 0.110, 0.157, 1)
	theme.hint_color = Color(0.0, 0.941, 1.0, 1)
	theme.font_style = "sans"
	theme.body_font_flavor = "sans"
	theme.nameplate_style = "parallelogram"
	theme.nameplate_bg = Color(0.988, 0.933, 0.035, 1)
	theme.nameplate_border = Color(0, 0, 0, 0)
	theme.nameplate_border_width = 0
	theme.nameplate_radius = 0
	theme.nameplate_text_color = Color(0.035, 0.043, 0.063, 1)
	theme.nameplate_accent = Color(0.0, 0.941, 1.0, 1)
	theme.nameplate_glyph = "▶"
	theme.nameplate_tag = "LV.99"
	theme.nameplate_offset = Vector2(20, -28)
	theme.nameplate_shadow_color = Color(1.0, 0.0, 0.333, 1)
	theme.nameplate_shadow_offset = Vector2(3, 3)
	theme.nameplate_padding_x = 14
	theme.choice_panel_style = "bare"
	theme.choice_style = "skew"
	theme.choice_skew_degrees = 12
	theme.choice_normal_bg = Color(0.047, 0.059, 0.094, 0.90)
	theme.choice_selected_bg = Color(0.988, 0.933, 0.035, 1)
	theme.choice_text_color = Color(0.784, 0.831, 0.902, 1)
	theme.choice_selected_color = Color(0.035, 0.043, 0.063, 1)
	theme.choice_hover_bg = Color(0.137, 0.169, 0.247, 1)
	theme.choice_hover_text_color = Color(0.988, 0.933, 0.035, 1)
	theme.choice_border_color = Color(0.0, 0.941, 1.0, 0.9)
	theme.choice_selected_border_color = Color(1.0, 0.0, 0.333, 1)
	theme.choice_border_width = 3
	theme.choice_accent_color = Color(1.0, 0.0, 0.333, 1)
	theme.choice_marker = "number"
	theme.choice_marker_glyph = "✖"
	theme.choice_marker_width = 26
	theme.choice_selected_shift = 8
	theme.choice_min_height = 48
	theme.portrait_enabled = true
	theme.portrait_style = "angular"
	theme.portrait_ornament = "glyph"
	theme.portrait_size = 100
	theme.portrait_aspect = 0.82
	theme.portrait_bg = Color(0.078, 0.102, 0.161, 1)
	theme.portrait_border_color = Color(0.0, 0.941, 1.0, 1)
	theme.portrait_border_width = 2
	theme.portrait_shadow_color = Color(0.988, 0.933, 0.035, 1)
	theme.portrait_shadow_offset = Vector2(3, 3)
	theme.portrait_glyph = "⚡"
	theme.portrait_gap = 14

# ── 第一弹：寂静地平线 ───────────────────────────────────

static func _minimal(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.52
	theme.panel_bg_color = Color(0.047, 0.055, 0.067, 0.10)
	theme.panel_border_color = Color(1, 1, 1, 0.0)
	theme.panel_border_width = 0
	theme.panel_corner_radius = 0
	theme.panel_shadow_color = Color(0, 0, 0, 0.0)
	theme.panel_shadow_size = 0
	theme.panel_shape = "cinema"
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(0.047, 0.055, 0.067, 0.02)
	theme.panel_gradient_bottom = Color(0.031, 0.039, 0.047, 0.97)
	theme.frame_style = "hairline"
	theme.frame_inner_color = Color(1, 1, 1, 0.38)
	theme.accent_color = Color(1, 1, 1, 0.92)
	theme.accent_secondary = Color(0.612, 0.639, 0.686, 1)
	theme.text_color = Color(0.929, 0.941, 0.965, 1)
	theme.speaker_color = Color(0.925, 0.937, 0.957, 1)
	theme.hint_color = Color(0.725, 0.749, 0.784, 0.9)
	theme.font_style = "sans"
	theme.body_font_flavor = "sans"
	theme.content_margin_left = 32
	theme.content_margin_right = 32
	theme.content_margin_top = 20
	theme.nameplate_style = "column"
	theme.nameplate_bg = Color(0, 0, 0, 0)
	theme.nameplate_border = Color(0, 0, 0, 0)
	theme.nameplate_border_width = 0
	theme.nameplate_text_color = Color(0.925, 0.937, 0.957, 1)
	theme.nameplate_accent = Color(0.612, 0.639, 0.686, 1)
	theme.nameplate_glyph = "◇"
	theme.nameplate_tag = "UNIT-02"
	theme.nameplate_column_width = 140
	theme.nameplate_divider = true
	theme.nameplate_divider_color = Color(1, 1, 1, 0.20)
	theme.nameplate_rotation = 0
	theme.choice_panel_style = "bare"
	theme.choice_style = "bar"
	theme.choice_normal_bg = Color(0, 0, 0, 0)
	theme.choice_selected_bg = Color(1, 1, 1, 0.13)
	theme.choice_text_color = Color(0.863, 0.882, 0.910, 0.82)
	theme.choice_selected_color = Color(1, 1, 1, 1)
	theme.choice_hover_bg = Color(1, 1, 1, 0.08)
	theme.choice_hover_text_color = Color(1, 1, 1, 1)
	theme.choice_border_color = Color(1, 1, 1, 0.16)
	theme.choice_selected_border_color = Color(1, 1, 1, 0.95)
	theme.choice_border_width = 2
	theme.choice_separation = 6
	theme.choice_min_height = 42
	theme.choice_font_size = 18
	theme.choice_selected_shift = 0
	theme.choice_marker = "none"
	theme.portrait_enabled = true
	theme.portrait_style = "square"
	theme.portrait_ornament = "none"
	theme.portrait_size = 78
	theme.portrait_aspect = 0.86
	theme.portrait_bg = Color(1, 1, 1, 0.05)
	theme.portrait_border_color = Color(1, 1, 1, 0.30)
	theme.portrait_border_width = 1
	theme.portrait_glyph = "◇"
	theme.portrait_gap = 12

# ── 第二弹：焦糖曲奇 ─────────────────────────────────────

static func _biscuit(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.54
	theme.panel_bg_color = Color(0.992, 0.973, 0.933, 1)
	theme.panel_border_color = Color(0.361, 0.227, 0.129, 1)
	theme.panel_border_width = 3
	theme.panel_corner_radius = 18
	theme.panel_shadow_color = Color(0, 0, 0, 0.22)
	theme.panel_shadow_size = 12
	theme.panel_shadow_offset = Vector2(0, 4)
	theme.panel_shape = "rect"
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(0.992, 0.973, 0.933, 1)
	theme.panel_gradient_bottom = Color(0.984, 0.953, 0.894, 1)
	theme.pattern_style = "notebook"
	theme.pattern_color = Color(0.651, 0.486, 0.322, 0.12)
	theme.pattern_spacing = 16
	theme.hard_shadow_color = Color(0.651, 0.431, 0.275, 1)
	theme.hard_shadow_offset = Vector2(5, 6)
	theme.frame_style = "stitch"
	theme.frame_inner_color = Color(0.690, 0.537, 0.408, 0.85)
	theme.frame_inner_gap = 7
	theme.frame_inner_width = 2
	theme.frame_inner_dash = true
	theme.corner_ornament = "tape"
	theme.corner_ornament_color = Color(0.471, 0.761, 0.678, 0.88)
	theme.accent_color = Color(0.471, 0.761, 0.678, 1)
	theme.accent_secondary = Color(0.957, 0.635, 0.380, 1)
	theme.text_color = Color(0.290, 0.180, 0.106, 1)
	theme.speaker_color = Color(0.992, 0.973, 0.933, 1)
	theme.hint_color = Color(0.651, 0.431, 0.275, 1)
	theme.font_style = "sans"
	theme.body_font_flavor = "rounded"
	theme.content_margin_left = 30
	theme.content_margin_right = 28
	theme.content_margin_top = 22
	theme.nameplate_style = "wood"
	theme.nameplate_bg = Color(0.361, 0.227, 0.129, 1)
	theme.nameplate_border = Color(0.992, 0.973, 0.933, 1)
	theme.nameplate_border_width = 2
	theme.nameplate_radius = 8
	theme.nameplate_text_color = Color(0.992, 0.973, 0.933, 1)
	theme.nameplate_accent = Color(0.471, 0.761, 0.678, 1)
	theme.nameplate_glyph = "🍪"
	theme.nameplate_offset = Vector2(18, -28)
	theme.nameplate_shadow_color = Color(0.361, 0.227, 0.129, 0.8)
	theme.nameplate_shadow_offset = Vector2(0, 2)
	theme.nameplate_padding_x = 12
	theme.choice_panel_style = "bare"
	theme.choice_style = "note"
	theme.choice_normal_bg = Color(0.992, 0.973, 0.933, 1)
	theme.choice_selected_bg = Color(1.0, 0.910, 0.714, 1)
	theme.choice_text_color = Color(0.290, 0.180, 0.106, 1)
	theme.choice_selected_color = Color(0.290, 0.180, 0.106, 1)
	theme.choice_hover_bg = Color(1.0, 0.929, 0.784, 1)
	theme.choice_hover_text_color = Color(0.290, 0.180, 0.106, 1)
	theme.choice_border_color = Color(0.361, 0.227, 0.129, 1)
	theme.choice_selected_border_color = Color(0.361, 0.227, 0.129, 1)
	theme.choice_border_width = 2
	theme.choice_corner_radius = 8
	theme.choice_accent_color = Color(0.471, 0.761, 0.678, 1)
	theme.choice_marker = "number"
	theme.choice_marker_glyph = "✿"
	theme.choice_marker_width = 28
	theme.choice_selected_shift = 6
	theme.choice_min_height = 50
	theme.choice_shadow_color = Color(0.361, 0.227, 0.129, 0.30)
	theme.choice_shadow_offset = Vector2(2, 2)
	theme.portrait_enabled = true
	theme.portrait_style = "polaroid"
	theme.portrait_ornament = "tape"
	theme.portrait_size = 106
	theme.portrait_aspect = 0.90
	theme.portrait_bg = Color(1, 1, 1, 1)
	theme.portrait_border_color = Color(0.361, 0.227, 0.129, 1)
	theme.portrait_border_width = 3
	theme.portrait_corner_radius = 2
	theme.portrait_padding = 5
	theme.portrait_shadow_color = Color(0.651, 0.431, 0.275, 1)
	theme.portrait_shadow_offset = Vector2(3, 3)
	theme.portrait_rotation = -3
	theme.portrait_glyph = "🧸"
	theme.portrait_gap = 14

# ── 第二弹：猩红断头台 ───────────────────────────────────

static func _crimson(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.54
	theme.panel_bg_color = Color(0.043, 0.035, 0.047, 0.97)
	theme.panel_border_color = Color(0.902, 0.0, 0.180, 0.75)
	theme.panel_border_width = 2
	theme.panel_corner_radius = 0
	theme.panel_shadow_color = Color(0, 0, 0, 0.80)
	theme.panel_shadow_size = 18
	theme.panel_shadow_offset = Vector2(0, 6)
	theme.panel_shape = "notched"
	theme.panel_notch_size = 12
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(0.043, 0.035, 0.047, 0.98)
	theme.panel_gradient_bottom = Color(0.094, 0.039, 0.059, 0.97)
	theme.pattern_style = "slash"
	theme.pattern_color = Color(0.902, 0.0, 0.180, 0.08)
	theme.pattern_spacing = 16
	theme.hard_shadow_color = Color(0.902, 0.0, 0.180, 0.45)
	theme.hard_shadow_offset = Vector2(4, 4)
	theme.frame_style = "blade"
	theme.top_blade_color = Color(0.902, 0.0, 0.180, 1)
	theme.top_blade_width = 3
	theme.accent_color = Color(0.902, 0.0, 0.180, 1)
	theme.accent_secondary = Color(0.349, 0.051, 0.133, 1)
	theme.text_color = Color(0.945, 0.914, 0.925, 1)
	theme.speaker_color = Color(1, 1, 1, 1)
	theme.hint_color = Color(0.902, 0.0, 0.180, 0.9)
	theme.font_style = "sans"
	theme.body_font_flavor = "sans"
	theme.content_margin_left = 32
	theme.content_margin_right = 30
	theme.content_margin_top = 22
	theme.nameplate_style = "blood"
	theme.nameplate_bg = Color(0.902, 0.0, 0.180, 1)
	theme.nameplate_border = Color(0, 0, 0, 0)
	theme.nameplate_border_width = 0
	theme.nameplate_radius = 0
	theme.nameplate_text_color = Color(1, 1, 1, 1)
	theme.nameplate_accent = Color(1, 1, 1, 1)
	theme.nameplate_glyph = "†"
	theme.nameplate_tag = "SIN:07"
	theme.nameplate_offset = Vector2(18, -28)
	theme.nameplate_shadow_color = Color(0.043, 0.035, 0.047, 1)
	theme.nameplate_shadow_offset = Vector2(3, 3)
	theme.nameplate_padding_x = 14
	theme.choice_panel_style = "bare"
	theme.choice_style = "notch"
	theme.choice_normal_bg = Color(0.055, 0.039, 0.055, 0.94)
	theme.choice_selected_bg = Color(0.902, 0.0, 0.180, 1)
	theme.choice_text_color = Color(0.796, 0.745, 0.769, 1)
	theme.choice_selected_color = Color(1, 1, 1, 1)
	theme.choice_hover_bg = Color(0.169, 0.059, 0.086, 1)
	theme.choice_hover_text_color = Color(1, 1, 1, 1)
	theme.choice_border_color = Color(0.902, 0.0, 0.180, 0.85)
	theme.choice_selected_border_color = Color(1, 1, 1, 1)
	theme.choice_border_width = 3
	theme.choice_accent_color = Color(0.902, 0.0, 0.180, 1)
	theme.choice_marker = "number"
	theme.choice_marker_glyph = "✖"
	theme.choice_marker_width = 30
	theme.choice_selected_shift = 7
	theme.choice_min_height = 50
	theme.portrait_enabled = true
	theme.portrait_style = "blood"
	theme.portrait_ornament = "cross"
	theme.portrait_size = 100
	theme.portrait_aspect = 0.82
	theme.portrait_bg = Color(0.086, 0.035, 0.051, 1)
	theme.portrait_border_color = Color(0.902, 0.0, 0.180, 1)
	theme.portrait_border_width = 2
	theme.portrait_shadow_color = Color(0.902, 0.0, 0.180, 1)
	theme.portrait_shadow_offset = Vector2(3, 3)
	theme.portrait_glyph = "†"
	theme.portrait_gap = 14
