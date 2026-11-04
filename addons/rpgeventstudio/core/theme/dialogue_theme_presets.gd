@tool
class_name DialogueThemePresets
extends RefCounted
## ATELIER 运行时主题 v5：12 套预设注册表与工厂。
##
## 约定：
## - 预设是“工厂”，不是全局单例。每次 create() 都返回新的 RpgEventStudioTheme，
##   编辑器/运行时修改其中一套不会污染另一套。
## - 色值取自 design-system/palette.json 的染灰×强调配对（注释里标注色阶 hex）。
## - 旧 id 通过 LEGACY_ID_MAP 自动迁移到最近的 v5 预设，旧 .tres 不需要手写迁移。
## - 所有装饰均为几何绘制，字符串字段不允许 emoji/装饰字符（数字编号除外）。

const SERIES_5 := 5

# ── 内置字体（addons/rpgeventstudio/fonts/，全部为 OFL） ──
const FONT_SERIF := "res://addons/rpgeventstudio/fonts/NotoSerifSC-Regular.otf"
const FONT_SANS := "res://addons/rpgeventstudio/fonts/NotoSansSC-Regular.otf"
const FONT_KAI := "res://addons/rpgeventstudio/fonts/LXGWWenKai-Regular.ttf"
const FONT_KUAILE := "res://addons/rpgeventstudio/fonts/ZCOOLKuaiLe-Regular.ttf"
const FONT_QINGKE := "res://addons/rpgeventstudio/fonts/ZCOOLQingKeHuangYou-Regular.ttf"
const FONT_XIAOWEI := "res://addons/rpgeventstudio/fonts/ZCOOLXiaoWei-Regular.ttf"
const FONT_BRUSH := "res://addons/rpgeventstudio/fonts/MaShanZheng-Regular.ttf"
const FONT_MONO := "res://addons/rpgeventstudio/fonts/JetBrainsMono-Regular.ttf"
const FONT_PIXEL := "res://addons/rpgeventstudio/fonts/FusionPixel12px-zh_hans.woff2"

# ── 旧 id → v5 迁移表 ────────────────────────────────────
## 旧预设按视觉族谱归入最近的 v5 预设：视觉参数仍保留在旧 .tres 字段里，
## preset_id 迁移后“恢复出厂”与编辑器预设选择都落到有效的新预设。
const LEGACY_ID_MAP := {
	"sacred": "codex",
	"cute": "candy",
	"cool": "terminal",
	"minimal": "ember",
	"biscuit": "grove",
	"crimson": "ember",
	"astrolabe": "verse",
	"macaron": "candy",
	"morpho": "tide",
	"feather": "verse",
}

const PRESETS := [
	{
		"id": "verse",
		"series": SERIES_5,
		"title": "诗篇 · 居中诗行",
		"tab": "诗集·宽字距衬线",
		"tag": "v5·居中诗集",
		"description": "无框发丝线面板 + 居中诗集排版 + 宽字距说话人与称号副标；选项居中，选中时两端金线生长。",
		"bullets": [
			"无外框暗角面板：上下两端渐隐的发丝金线，文字浮于底部柔光。",
			"宽字距铭牌 + 称号副标：居中排版，菱形推进指示缓慢呼吸。",
			"居中丝线选项：选中时两端金线自文字向外生长 180ms。",
		],
		"colors": ["#090C10", "#C9A878", "#ECF4FE", "#868D96"],
		"stage_top": "#1E232B",
		"stage_bottom": "#090C10",
	},
	{
		"id": "codex",
		"series": SERIES_5,
		"title": "羊皮书 · 铜铭板手卷",
		"tab": "奇幻·羊皮卷轴",
		"tag": "v5·奇幻 RPG",
		"description": "羊皮纸底 + 双线框 + 四角括线；铜质铭板悬于上缘，选项是右上纸签，大立绘从左侧探入。",
		"bullets": [
			"羊皮纸双线框：深棕外框 + 铜色内缩细线，四角小括线收边。",
			"铜铭板铭牌：渐变铜底 + 内框线，称号以小字随行。",
			"纸签选项 + 键帽提示：右对齐纸签，三角光标，推进处是键帽样式。",
		],
		"colors": ["#FEF9F4", "#663722", "#C77D5C", "#3D3730"],
		"stage_top": "#DAD3CB",
		"stage_bottom": "#928B83",
	},
	{
		"id": "terminal",
		"series": SERIES_5,
		"title": "终端 · 石墨湖绿 HUD",
		"tab": "科幻·命令行 HUD",
		"tag": "v5·科幻终端",
		"description": "石墨面板 + 页签呼号铭牌 + 角框括线；选项收进面板右栏键帽索引，等宽字体提示行。",
		"bullets": [
			"分段顶条 + 角框：三段湖绿顶条依次点亮，四角描边括线。",
			"inside 右栏选项：选项与正文并排，键帽索引编号，辉光选中。",
			"光标块推进指示：1s 步进闪烁，提示行用等宽键帽。",
		],
		"colors": ["#121617", "#5DC2B6", "#EFF5F7", "#4E5355"],
		"stage_top": "#1F2425",
		"stage_bottom": "#0A0D0D",
	},
	{
		"id": "candy",
		"series": SERIES_5,
		"title": "糖果 · 柿红胶囊手账",
		"tab": "可爱·胶囊糖果",
		"tag": "v5·可爱 JRPG",
		"description": "奶白底 + 大圆角粗描边 + 柿红硬投影；胶囊铭牌与胶囊选项，选中胶囊弹跳，大立绘左侧探入。",
		"bullets": [
			"24px 圆角 + 2.5px 粗描边 + 右下柿红错位硬影。",
			"胶囊选项：实体胶囊 + 序号圆点，选中弹跳回落。",
			"圆点推进指示持续跳动，整体回弹缓动入场。",
		],
		"colors": ["#FFF8FA", "#D86983", "#5A4F53", "#F18AA0"],
		"stage_top": "#FED0D8",
		"stage_bottom": "#EFD4EC",
	},
	{
		"id": "tide",
		"series": SERIES_5,
		"title": "深潮 · 藏青斜切机能",
		"tab": "潮酷·深海斜切",
		"tag": "v5·潮酷机能",
		"description": "藏青底 + 顶部 2px 亮线 + 右下 18px 切角；选项左侧错落三行，斜切条带错位投影，大立绘右侧。",
		"bullets": [
			"顶部青色亮线 + 右下大切角，深海渐变底。",
			"错落选项：18/0/30 三行缩进，斜切条 + 白色错位投影。",
			"铭牌从左侧冲入带回弹，三角指示持续轻推。",
		],
		"colors": ["#0C1523", "#50BEDA", "#EDF4FF", "#485364"],
		"stage_top": "#2E3949",
		"stage_bottom": "#070C14",
	},
	{
		"id": "ember",
		"series": SERIES_5,
		"title": "余烬 · 暗红烛火哥特",
		"tab": "暗黑·双发丝切角",
		"tag": "v5·暗黑哥特",
		"description": "炭黑底 + 14px 切角 + 双发丝内框；选项居中无框细线，菱形指示如烛火不规则闪烁。",
		"bullets": [
			"切角面板 + 两条不同间距的发丝内框，血色点缀。",
			"居中无框选项：选中时横向暗红渐变底 + 双菱形标记。",
			"菱形推进指示 2.3s 不规则闪烁，整体慢速淡入。",
		],
		"colors": ["#1C1211", "#DB6976", "#FFEFEE", "#5C4F4D"],
		"stage_top": "#2B201E",
		"stage_bottom": "#110A0A",
	},
	{
		"id": "frost",
		"series": SERIES_5,
		"title": "霜原 · 靛青玻璃浮名",
		"tab": "清透·玻璃霜原",
		"tag": "v5·清透幻想",
		"description": "半透明玻璃面板 + 顶部靛青短线；名字悬浮在面板外缓慢浮动，玻璃行选项带左侧指示条。",
		"bullets": [
			"玻璃面板：圆角 8 + 顶部高光线 + 靛青短条。",
			"悬浮铭牌：无牌底，名字 3s 上下浮动 2px，称号随行。",
			"玻璃行选项：选中时左侧指示条由下往上长出。",
		],
		"colors": ["#DFE7F1", "#6474AE", "#1E232B", "#9AABE6"],
		"stage_top": "#DFE7F1",
		"stage_bottom": "#B7C5F6",
	},
	{
		"id": "ink",
		"series": SERIES_5,
		"title": "墨韵 · 朱印行草卷轴",
		"tab": "武侠·朱印墨迹",
		"tag": "v5·东方武侠",
		"description": "无边面板仅留上下 1px 横线；朱印铭牌斜压左上，选项是无框墨迹下划线，自左向右刷出。",
		"bullets": [
			"上下发丝横线承托正文，无左右边框，纸张暗纹。",
			"方形朱印铭牌旋转 -4°，如印章盖在面板左上。",
			"墨迹下划线选项：选中时墨线从左向右刷出 240ms。",
		],
		"colors": ["#FAF2EA", "#CC795D", "#27221C", "#928B83"],
		"stage_top": "#FAF2EA",
		"stage_bottom": "#DAD3CB",
	},
	{
		"id": "pixel",
		"series": SERIES_5,
		"title": "像素 · 琥珀阶梯描边",
		"tab": "复古·16-bit 像素",
		"tag": "v5·复古像素",
		"description": "4px 阶梯描边面板 + 像素字体；选项放进独立的像素窗口右对齐，步进展开、光标跳行选中。",
		"bullets": [
			"阶梯描边：4px 方块拼出像素边框，内圈 1px 暗线。",
			"独立选项窗口：separate 布局右上，步进动画四段展开。",
			"LED 方块推进指示步进闪烁，选中光标直接跳行。",
		],
		"colors": ["#151B32", "#D5A550", "#E6ECFF", "#4D5A8D"],
		"stage_top": "#4D5A8D",
		"stage_bottom": "#3F4A22",
	},
	{
		"id": "nocturne",
		"series": SERIES_5,
		"title": "夜行 · 都市手机聊天",
		"tab": "都市·聊天夜行",
		"tag": "v5·手机聊天",
		"description": "圆角 18 手机框 + 聊天头部铭牌；回复胶囊选项，三点推进指示依次跳动。",
		"bullets": [
			"手机框面板：深紫底 + 圆角 18，顶部聊天应用式头部。",
			"回复胶囊选项：chat 布局，选中琥珀描边 + 淡底。",
			"三点圆点推进指示依次跳动，气泡式淡入。",
		],
		"colors": ["#271626", "#D5A550", "#F7E7F5", "#754E72"],
		"stage_top": "#3C243A",
		"stage_bottom": "#1A0C19",
	},
	{
		"id": "grove",
		"series": SERIES_5,
		"title": "森语 · 苔绿叶形童话",
		"tab": "治愈·林间叶语",
		"tag": "v5·治愈童话",
		"description": "叶形圆角面板 + 苔绿配色；叶形标记选项轻微摆动，面板从左下角生长展开。",
		"bullets": [
			"不对称叶形圆角：28/6 圆角面板 + 苔绿描边。",
			"叶点标记选项：几何叶片标记 + 选中苔绿描边。",
			"铭牌与叶点 ±2° 缓慢摆动，入场从左下角生长。",
		],
		"colors": ["#15160E", "#899B5D", "#F4F4EA", "#6F7F46"],
		"stage_top": "#D9E3C5",
		"stage_bottom": "#8FB8AC",
	},
	{
		"id": "tactical",
		"series": SERIES_5,
		"title": "战术 · 军绿厚切角",
		"tab": "军事·末日战术",
		"tag": "v5·军事末日",
		"description": "厚切角面板 + 标签条呼号铭牌；选项左上间距 30，选中琥珀实底反色，LED 指示闪烁。",
		"bullets": [
			"厚切角 + 内圈强调折线：军绿面板配琥珀点缀。",
			"两段式呼号铭牌：实底名块 + 描边代号框。",
			"左对齐大间距选项：选中实底反色，LED 方块指示闪烁。",
		],
		"colors": ["#15160E", "#D5A550", "#F4F4EA", "#53534B"],
		"stage_top": "#383930",
		"stage_bottom": "#0C0D09",
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

## 旧 id 迁移：已是 v5 id 或未知 id 原样返回。
static func migrate_preset_id(id: String) -> String:
	return str(LEGACY_ID_MAP.get(id, id))

## 预设工厂。旧 id 自动走 LEGACY_ID_MAP 迁移；未知 id 返回插件默认外观
## （不是 null，调用方无需特判）。
static func create(id: String) -> RpgEventStudioTheme:
	var resolved := migrate_preset_id(id)
	var theme := RpgEventStudioTheme.new()
	theme.style_version = 3
	match resolved:
		"verse":
			_verse(theme)
		"codex":
			_codex(theme)
		"terminal":
			_terminal(theme)
		"candy":
			_candy(theme)
		"tide":
			_tide(theme)
		"ember":
			_ember(theme)
		"frost":
			_frost(theme)
		"ink":
			_ink(theme)
		"pixel":
			_pixel(theme)
		"nocturne":
			_nocturne(theme)
		"grove":
			_grove(theme)
		"tactical":
			_tactical(theme)
		_:
			return RpgEventStudioTheme.new()
	theme.preset_id = resolved
	var info := meta(resolved)
	theme.preset_title = str(info.get("title", ""))
	theme.preset_tag = str(info.get("tag", ""))
	theme.preset_description = str(info.get("description", ""))
	theme.preset_series = int(info.get("series", 0))
	return theme

## 恢复当前主题对应的出厂值：预设回到自己的工厂，旧主题回到插件默认外观。
static func factory_defaults(theme: RpgEventStudioTheme) -> RpgEventStudioTheme:
	if theme != null and theme.preset_id != "" and has_preset(migrate_preset_id(theme.preset_id)):
		return create(theme.preset_id)
	return RpgEventStudioTheme.new()

static func palette(id: String) -> PackedStringArray:
	var info := meta(id)
	var out := PackedStringArray()
	for color in info.get("colors", []):
		out.append(str(color))
	return out

# ── 公共基线 ─────────────────────────────────────────────

static func _hex(text: String) -> Color:
	return Color.from_string(text, Color.WHITE)

static func _base(theme: RpgEventStudioTheme) -> void:
	theme.style_version = 3
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
	theme.content_margin_left = 32
	theme.content_margin_right = 32
	theme.content_margin_top = 22
	theme.content_margin_bottom = 14
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
	theme.pattern_style = "none"
	theme.corner_ornament = "none"
	theme.corner_glyph = ""

# ── 1 · 诗篇 Verse（slate × brass）────────────────────────

static func _verse(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.48
	theme.panel_bg_color = Color(_hex("10151C"), 0.10)
	theme.panel_border_color = Color(0, 0, 0, 0)
	theme.panel_border_width = 0
	theme.panel_corner_radius = 0
	theme.panel_shadow_color = Color(0, 0, 0, 0)
	theme.panel_shadow_size = 0
	theme.panel_shape = "cinema"
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(_hex("10151C"), 0.0)
	theme.panel_gradient_bottom = Color(_hex("090C10"), 0.96)
	theme.frame_style = "tapered"
	theme.frame_inner_color = Color(_hex("C9A878"), 0.55)
	theme.accent_color = _hex("C9A878")
	theme.accent_secondary = _hex("868D96")
	theme.font_path = FONT_SERIF
	theme.font_path_body = FONT_KAI
	theme.font_path_choice = FONT_SERIF
	theme.text_color = _hex("ECF4FE")
	theme.speaker_color = _hex("DDC39C")
	theme.hint_color = Color(_hex("868D96"), 0.9)
	theme.text_align = "center"
	theme.text_min_height = 84
	theme.speaker_title = "白鸦诗人"
	theme.speaker_tracking = 0.32
	theme.nameplate_style = "floating"
	theme.nameplate_bg = Color(_hex("090C10"), 0.35)
	theme.nameplate_text_color = _hex("DDC39C")
	theme.nameplate_accent = _hex("C9A878")
	theme.nameplate_offset = Vector2(0, -34)
	theme.nameplate_width_ratio = 0.6
	theme.choice_layout = "top"
	theme.choice_align = "center"
	theme.choice_panel_style = "bare"
	theme.choice_style = "filament"
	theme.choice_separation = 30
	theme.choice_min_height = 40
	theme.choice_gap = 30
	theme.choice_normal_bg = Color(0, 0, 0, 0)
	theme.choice_selected_bg = Color(0, 0, 0, 0)
	theme.choice_text_color = _hex("AAB2BB")
	theme.choice_selected_color = _hex("F6EBDC")
	theme.choice_hover_bg = Color(0, 0, 0, 0)
	theme.choice_hover_text_color = _hex("ECF4FE")
	theme.choice_border_color = Color(0, 0, 0, 0)
	theme.choice_selected_border_color = _hex("C9A878")
	theme.choice_border_width = 0
	theme.choice_accent_color = _hex("C9A878")
	theme.choice_marker = "none"
	theme.advance_indicator = "diamond"
	theme.hint_style = "text"
	theme.panel_entrance = "fade"
	theme.panel_entrance_ms = 420
	theme.loop_anim = "pulse"
	theme.select_anim = "grow-line"
	theme.portrait_enabled = false
	theme.portrait_placement = "none"

# ── 2 · 羊皮书 Codex（sand × copper）──────────────────────

static func _codex(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.52
	theme.panel_bg_color = _hex("FEF9F4")
	theme.panel_border_color = _hex("663722")
	theme.panel_border_width = 2
	theme.panel_corner_radius = 6
	theme.panel_shadow_color = Color(_hex("27221C"), 0.35)
	theme.panel_shadow_size = 18
	theme.panel_shadow_offset = Vector2(0, 6)
	theme.panel_shape = "rect"
	theme.panel_gradient = true
	theme.panel_gradient_top = _hex("FEF9F4")
	theme.panel_gradient_bottom = _hex("FAF2EA")
	theme.frame_style = "double"
	theme.frame_inner_color = _hex("E09B7D")
	theme.frame_inner_gap = 7
	theme.frame_inner_width = 1
	theme.corner_ornament = "blade"
	theme.corner_ornament_color = _hex("A76345")
	theme.accent_color = _hex("C77D5C")
	theme.accent_secondary = _hex("A76345")
	theme.font_path = FONT_SERIF
	theme.font_path_body = FONT_SERIF
	theme.font_path_choice = FONT_SERIF
	theme.text_color = _hex("27221C")
	theme.speaker_color = _hex("FEF9F4")
	theme.hint_color = _hex("746D66")
	theme.speaker_title = "白鸦诗人"
	theme.nameplate_style = "plaque"
	theme.nameplate_bg = _hex("864C32")
	theme.nameplate_border = _hex("FCD4C4")
	theme.nameplate_border_width = 1
	theme.nameplate_text_color = _hex("FEF9F4")
	theme.nameplate_accent = _hex("FCD4C4")
	theme.nameplate_offset = Vector2(34, -19)
	theme.nameplate_shadow_color = Color(_hex("27221C"), 0.35)
	theme.nameplate_shadow_offset = Vector2(0, 3)
	theme.choice_layout = "top"
	theme.choice_align = "right"
	theme.choice_panel_style = "bare"
	theme.choice_style = "paper-sign"
	theme.choice_separation = 6
	theme.choice_min_height = 38
	theme.choice_gap = 18
	theme.choice_normal_bg = Color(_hex("FEF9F4"), 0.94)
	theme.choice_selected_bg = _hex("FFE7DD")
	theme.choice_text_color = _hex("3D3730")
	theme.choice_selected_color = _hex("663722")
	theme.choice_hover_bg = _hex("FCD4C4")
	theme.choice_hover_text_color = _hex("663722")
	theme.choice_border_color = _hex("B7B0A8")
	theme.choice_selected_border_color = _hex("A76345")
	theme.choice_border_width = 1
	theme.choice_accent_color = _hex("A76345")
	theme.choice_marker = "tri"
	theme.choice_marker_width = 24
	theme.select_anim = "shift"
	theme.advance_indicator = "tri-down"
	theme.hint_style = "keycap"
	theme.panel_entrance = "rise"
	theme.panel_entrance_ms = 240
	theme.loop_anim = "bob"
	theme.portrait_enabled = true
	theme.portrait_placement = "large-left"
	theme.portrait_bg = _hex("DAD3CB")

# ── 3 · 终端 Terminal（graphite × teal）───────────────────

static func _terminal(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.50
	theme.panel_bg_color = Color(_hex("121617"), 0.95)
	theme.panel_border_color = _hex("4E5355")
	theme.panel_border_width = 1
	theme.panel_corner_radius = 4
	theme.panel_shadow_color = Color(0, 0, 0, 0.5)
	theme.panel_shadow_size = 14
	theme.panel_shape = "rect"
	theme.frame_style = "plain"
	theme.corner_ornament = "blade"
	theme.corner_ornament_color = Color(_hex("28A79B"), 0.7)
	theme.top_blade_color = _hex("5DC2B6")
	theme.top_blade_width = 3
	theme.accent_color = _hex("5DC2B6")
	theme.accent_secondary = _hex("138A7F")
	theme.font_path = FONT_SANS
	theme.font_path_body = FONT_SANS
	theme.font_path_choice = FONT_MONO
	theme.font_style = "mono"
	theme.text_color = _hex("EFF5F7")
	theme.speaker_color = _hex("8CD8CE")
	theme.hint_color = _hex("888D8F")
	theme.speaker_title = "ID 0731 · 诗人"
	theme.nameplate_style = "callsign"
	theme.nameplate_bg = _hex("121617")
	theme.nameplate_border = _hex("4E5355")
	theme.nameplate_border_width = 1
	theme.nameplate_text_color = _hex("8CD8CE")
	theme.nameplate_accent = _hex("5DC2B6")
	theme.nameplate_tag = "ID 0731 · 诗人"
	theme.nameplate_offset = Vector2(0, -30)
	theme.choice_layout = "inside"
	theme.choice_align = "right"
	theme.choice_panel_style = "bare"
	theme.choice_style = "keycap-index"
	theme.choice_separation = 8
	theme.choice_min_height = 38
	theme.choice_normal_bg = Color(_hex("1F2425"), 0.6)
	theme.choice_selected_bg = Color(_hex("033631"), 0.9)
	theme.choice_text_color = _hex("CFD5D7")
	theme.choice_selected_color = _hex("8CD8CE")
	theme.choice_hover_bg = _hex("34393A")
	theme.choice_hover_text_color = _hex("8CD8CE")
	theme.choice_border_color = Color(_hex("4E5355"), 0.6)
	theme.choice_selected_border_color = _hex("5DC2B6")
	theme.choice_border_width = 1
	theme.choice_accent_color = _hex("5DC2B6")
	theme.choice_marker = "keycap"
	theme.choice_marker_size = 15
	theme.select_anim = "glow"
	theme.advance_indicator = "cursor-block"
	theme.hint_style = "keycap-mono"
	theme.panel_entrance = "wipe"
	theme.panel_entrance_ms = 220
	theme.loop_anim = "blink"
	theme.portrait_enabled = true
	theme.portrait_placement = "large-right"
	theme.portrait_bg = _hex("34393A")

# ── 4 · 糖果 Candy（mauve × persimmon）────────────────────

static func _candy(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.56
	theme.panel_bg_color = _hex("FFF8FA")
	theme.panel_border_color = _hex("5A4F53")
	theme.panel_border_width = 3
	theme.panel_corner_radius = 24
	theme.panel_shadow_color = Color(0, 0, 0, 0.16)
	theme.panel_shadow_size = 10
	theme.panel_shadow_offset = Vector2(0, 3)
	theme.panel_shape = "rect"
	theme.panel_gradient = true
	theme.panel_gradient_top = _hex("FFF8FA")
	theme.panel_gradient_bottom = _hex("FDEFF4")
	theme.hard_shadow_color = _hex("F18AA0")
	theme.hard_shadow_offset = Vector2(6, 7)
	theme.accent_color = _hex("D86983")
	theme.accent_secondary = _hex("FEADBD")
	theme.font_path = FONT_KUAILE
	theme.font_path_body = FONT_SANS
	theme.font_path_choice = FONT_SANS
	theme.text_color = _hex("3F3538")
	theme.speaker_color = _hex("FFF8FA")
	theme.hint_color = _hex("B7516A")
	theme.speaker_title = "甜食研究会"
	theme.nameplate_style = "capsule"
	theme.nameplate_bg = _hex("D86983")
	theme.nameplate_border = _hex("5A4F53")
	theme.nameplate_border_width = 3
	theme.nameplate_radius = 16
	theme.nameplate_text_color = Color(1, 1, 1, 1)
	theme.nameplate_accent = _hex("FEADBD")
	theme.nameplate_offset = Vector2(20, -28)
	theme.nameplate_rotation = -2
	theme.nameplate_shadow_color = _hex("5A4F53")
	theme.nameplate_shadow_offset = Vector2(3, 3)
	theme.choice_layout = "top"
	theme.choice_align = "right"
	theme.choice_panel_style = "bare"
	theme.choice_style = "pill-solid"
	theme.choice_separation = 10
	theme.choice_min_height = 50
	theme.choice_gap = 22
	theme.choice_normal_bg = _hex("FFF8FA")
	theme.choice_selected_bg = _hex("D86983")
	theme.choice_text_color = _hex("3F3538")
	theme.choice_selected_color = Color(1, 1, 1, 1)
	theme.choice_hover_bg = _hex("FED0D8")
	theme.choice_hover_text_color = _hex("70293C")
	theme.choice_border_color = _hex("5A4F53")
	theme.choice_selected_border_color = _hex("5A4F53")
	theme.choice_border_width = 3
	theme.choice_corner_radius = 22
	theme.choice_accent_color = _hex("F18AA0")
	theme.choice_marker = "index"
	theme.choice_marker_width = 28
	theme.choice_shadow_color = Color(_hex("5A4F53"), 0.35)
	theme.choice_shadow_offset = Vector2(3, 3)
	theme.select_anim = "pop"
	theme.advance_indicator = "dot"
	theme.hint_style = "text"
	theme.panel_entrance = "pop"
	theme.panel_entrance_ms = 280
	theme.loop_anim = "hop"
	theme.portrait_enabled = true
	theme.portrait_placement = "large-left"
	theme.portrait_bg = _hex("FED0D8")

# ── 5 · 深潮 Tide（navy × cyan）───────────────────────────

static func _tide(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.54
	theme.panel_bg_color = Color(_hex("0C1523"), 0.96)
	theme.panel_border_color = _hex("485364")
	theme.panel_border_width = 1
	theme.panel_corner_radius = 0
	theme.panel_shadow_color = Color(0, 0, 0, 0.55)
	theme.panel_shadow_size = 16
	theme.panel_shadow_offset = Vector2(0, 5)
	theme.panel_shape = "notched"
	theme.panel_notch_size = 18
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(_hex("192332"), 0.97)
	theme.panel_gradient_bottom = Color(_hex("0C1523"), 0.97)
	theme.top_blade_color = _hex("50BEDA")
	theme.top_blade_width = 2
	theme.accent_color = _hex("50BEDA")
	theme.accent_secondary = _hex("01859F")
	theme.font_path = FONT_QINGKE
	theme.font_path_body = FONT_SANS
	theme.font_path_choice = FONT_SANS
	theme.text_color = _hex("EDF4FF")
	theme.speaker_color = _hex("84D5EC")
	theme.hint_color = _hex("637082")
	theme.speaker_title = "潮间带向导"
	theme.nameplate_style = "parallelogram"
	theme.nameplate_bg = _hex("1CA2BF")
	theme.nameplate_border = Color(0, 0, 0, 0)
	theme.nameplate_border_width = 0
	theme.nameplate_text_color = _hex("070C14")
	theme.nameplate_accent = _hex("84D5EC")
	theme.nameplate_offset = Vector2(20, -26)
	theme.nameplate_shadow_color = _hex("50BEDA")
	theme.nameplate_shadow_offset = Vector2(3, 3)
	theme.choice_layout = "top"
	theme.choice_align = "left"
	theme.choice_stagger = true
	theme.choice_panel_style = "bare"
	theme.choice_style = "skew-strip"
	theme.choice_separation = 8
	theme.choice_min_height = 46
	theme.choice_gap = 18
	theme.choice_normal_bg = Color(_hex("192332"), 0.92)
	theme.choice_selected_bg = _hex("EDF4FF")
	theme.choice_text_color = _hex("A5B2C6")
	theme.choice_selected_color = _hex("0C1523")
	theme.choice_hover_bg = _hex("2E3949")
	theme.choice_hover_text_color = _hex("84D5EC")
	theme.choice_border_color = _hex("485364")
	theme.choice_selected_border_color = _hex("50BEDA")
	theme.choice_border_width = 1
	theme.choice_accent_color = _hex("50BEDA")
	theme.choice_marker = "tri"
	theme.choice_marker_width = 24
	theme.choice_shadow_color = Color(1, 1, 1, 0.6)
	theme.choice_shadow_offset = Vector2(4, 3)
	theme.select_anim = "shift"
	theme.advance_indicator = "tri"
	theme.hint_style = "keycap"
	theme.panel_entrance = "slide-left"
	theme.panel_entrance_ms = 260
	theme.loop_anim = "nudge"
	theme.portrait_enabled = true
	theme.portrait_placement = "large-right"
	theme.portrait_bg = _hex("2E3949")

# ── 6 · 余烬 Ember（char × oxblood）───────────────────────

static func _ember(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.52
	theme.panel_bg_color = Color(_hex("1C1211"), 0.96)
	theme.panel_border_color = Color(_hex("712933"), 0.75)
	theme.panel_border_width = 1
	theme.panel_corner_radius = 0
	theme.panel_shadow_color = Color(0, 0, 0, 0.7)
	theme.panel_shadow_size = 18
	theme.panel_shape = "double-inner-line"
	theme.panel_notch_size = 14
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(_hex("2B201E"), 0.97)
	theme.panel_gradient_bottom = Color(_hex("1C1211"), 0.97)
	theme.frame_style = "plain"
	theme.frame_inner_color = Color(_hex("B9515D"), 0.5)
	theme.frame_inner_gap = 6
	theme.accent_color = _hex("DB6976")
	theme.accent_secondary = _hex("712933")
	theme.font_path = FONT_SERIF
	theme.font_path_body = FONT_SERIF
	theme.font_path_choice = FONT_SERIF
	theme.text_color = _hex("FFEFEE")
	theme.speaker_color = _hex("F38B94")
	theme.hint_color = _hex("796B69")
	theme.speaker_title = "灰烬引路人"
	theme.nameplate_style = "poetic"
	theme.nameplate_bg = Color(0, 0, 0, 0)
	theme.nameplate_text_color = _hex("F38B94")
	theme.nameplate_accent = _hex("DB6976")
	theme.nameplate_width_ratio = 0.6
	theme.choice_layout = "top"
	theme.choice_align = "center"
	theme.choice_panel_style = "bare"
	theme.choice_style = "underline-list"
	theme.choice_separation = 30
	theme.choice_min_height = 40
	theme.choice_gap = 30
	theme.choice_normal_bg = Color(0, 0, 0, 0)
	theme.choice_selected_bg = Color(_hex("712933"), 0.7)
	theme.choice_text_color = _hex("978887")
	theme.choice_selected_color = _hex("FFEFEE")
	theme.choice_hover_bg = Color(0, 0, 0, 0)
	theme.choice_hover_text_color = _hex("FDAFB4")
	theme.choice_border_color = _hex("5C4F4D")
	theme.choice_selected_border_color = _hex("DB6976")
	theme.choice_border_width = 1
	theme.choice_accent_color = _hex("DB6976")
	theme.choice_marker = "diamond"
	theme.choice_marker_width = 22
	theme.select_anim = "glow"
	theme.advance_indicator = "diamond"
	theme.hint_style = "text"
	theme.panel_entrance = "fade"
	theme.panel_entrance_ms = 380
	theme.loop_anim = "flicker"
	theme.portrait_enabled = true
	theme.portrait_placement = "large-left"
	theme.portrait_bg = _hex("413433")

# ── 7 · 霜原 Frost（slate × indigo）───────────────────────

static func _frost(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.52
	theme.panel_bg_color = Color(_hex("DFE7F1"), 0.62)
	theme.panel_border_color = Color(_hex("9AABE6"), 0.55)
	theme.panel_border_width = 1
	theme.panel_corner_radius = 8
	theme.panel_shadow_color = Color(_hex("38426B"), 0.30)
	theme.panel_shadow_size = 16
	theme.panel_shape = "glass"
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(_hex("F7FAFF"), 0.55)
	theme.panel_gradient_bottom = Color(_hex("CDD5DF"), 0.62)
	theme.accent_color = _hex("6474AE")
	theme.accent_secondary = _hex("9AABE6")
	theme.font_path = FONT_XIAOWEI
	theme.font_path_body = FONT_SANS
	theme.font_path_choice = FONT_SANS
	theme.text_color = _hex("1E232B")
	theme.speaker_color = _hex("38426B")
	theme.hint_color = _hex("696F78")
	theme.speaker_title = "霜语者"
	theme.nameplate_style = "floating"
	theme.nameplate_bg = Color(_hex("DFE7F1"), 0.3)
	theme.nameplate_text_color = _hex("38426B")
	theme.nameplate_accent = _hex("6474AE")
	theme.nameplate_offset = Vector2(24, -40)
	theme.choice_layout = "top"
	theme.choice_align = "right"
	theme.choice_panel_style = "bare"
	theme.choice_style = "glass-row"
	theme.choice_separation = 8
	theme.choice_min_height = 44
	theme.choice_gap = 22
	theme.choice_corner_radius = 8
	theme.choice_normal_bg = Color(_hex("F7FAFF"), 0.55)
	theme.choice_selected_bg = Color(_hex("E6ECFF"), 0.9)
	theme.choice_text_color = _hex("4D535B")
	theme.choice_selected_color = _hex("242C4A")
	theme.choice_hover_bg = Color(_hex("ECF4FE"), 0.8)
	theme.choice_hover_text_color = _hex("38426B")
	theme.choice_border_color = Color(_hex("9AABE6"), 0.5)
	theme.choice_selected_border_color = _hex("6474AE")
	theme.choice_border_width = 1
	theme.choice_accent_color = _hex("6474AE")
	theme.choice_marker = "bar"
	theme.choice_marker_width = 20
	theme.select_anim = "bar-up"
	theme.advance_indicator = "tri-down"
	theme.hint_style = "keycap"
	theme.panel_entrance = "rise"
	theme.panel_entrance_ms = 260
	theme.loop_anim = "float"
	theme.portrait_enabled = true
	theme.portrait_placement = "large-left"
	theme.portrait_bg = _hex("CDD5DF")

# ── 8 · 墨韵 Ink（sand × clay）────────────────────────────

static func _ink(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.50
	theme.panel_bg_color = Color(_hex("FAF2EA"), 0.55)
	theme.panel_border_color = Color(0, 0, 0, 0)
	theme.panel_border_width = 0
	theme.panel_corner_radius = 0
	theme.panel_shadow_color = Color(0, 0, 0, 0.18)
	theme.panel_shadow_size = 12
	theme.panel_shape = "rect"
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(_hex("FAF2EA"), 0.0)
	theme.panel_gradient_bottom = Color(_hex("F4F4EA"), 0.62)
	theme.frame_style = "tapered"
	theme.frame_inner_color = Color(_hex("58514A"), 0.65)
	theme.accent_color = _hex("CC795D")
	theme.accent_secondary = _hex("8A4932")
	theme.font_path = FONT_KAI
	theme.font_path_body = FONT_KAI
	theme.font_path_choice = FONT_KAI
	theme.text_color = _hex("27221C")
	theme.speaker_color = _hex("FFF4F1")
	theme.hint_color = _hex("746D66")
	theme.speaker_title = "墨痕客"
	theme.nameplate_style = "seal"
	theme.nameplate_bg = _hex("AB6045")
	theme.nameplate_text_color = _hex("FFF4F1")
	theme.nameplate_accent = _hex("CC795D")
	theme.nameplate_rotation = -4
	theme.nameplate_offset = Vector2(22, -30)
	theme.choice_layout = "top"
	theme.choice_align = "left"
	theme.choice_panel_style = "bare"
	theme.choice_style = "ink-stroke"
	theme.choice_separation = 14
	theme.choice_min_height = 42
	theme.choice_gap = 20
	theme.choice_normal_bg = Color(0, 0, 0, 0)
	theme.choice_selected_bg = Color(0, 0, 0, 0)
	theme.choice_text_color = _hex("58514A")
	theme.choice_selected_color = _hex("27221C")
	theme.choice_hover_bg = Color(0, 0, 0, 0)
	theme.choice_hover_text_color = _hex("482113")
	theme.choice_border_color = _hex("8A4932")
	theme.choice_selected_border_color = _hex("CC795D")
	theme.choice_border_width = 0
	theme.choice_accent_color = _hex("CC795D")
	theme.choice_marker = "none"
	theme.select_anim = "stamp-line"
	theme.advance_indicator = "dot"
	theme.hint_style = "text"
	theme.panel_entrance = "stamp"
	theme.panel_entrance_ms = 200
	theme.loop_anim = "pulse"
	theme.portrait_enabled = true
	theme.portrait_placement = "large-right"
	theme.portrait_bg = _hex("DAD3CB")

# ── 9 · 像素 Pixel（indigo × amber）───────────────────────

static func _pixel(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.56
	theme.panel_bg_color = Color(_hex("151B32"), 0.97)
	theme.panel_border_color = _hex("D5A550")
	theme.panel_border_width = 2
	theme.panel_corner_radius = 0
	theme.panel_shadow_color = Color(0, 0, 0, 0.6)
	theme.panel_shadow_size = 0
	theme.panel_shape = "pixel-stepped"
	theme.panel_notch_size = 4
	theme.accent_color = _hex("D5A550")
	theme.accent_secondary = _hex("7D8ECE")
	theme.font_path = FONT_PIXEL
	theme.font_path_body = FONT_PIXEL
	theme.font_path_choice = FONT_PIXEL
	theme.text_font_size = 20
	theme.text_color = _hex("E6ECFF")
	theme.speaker_color = _hex("D5A550")
	theme.hint_color = _hex("7D8ECE")
	theme.speaker_title = "LV.12 旅人"
	theme.nameplate_style = "float"
	theme.nameplate_bg = _hex("242C4A")
	theme.nameplate_border = _hex("D5A550")
	theme.nameplate_border_width = 2
	theme.nameplate_text_color = _hex("D5A550")
	theme.nameplate_accent = _hex("7D8ECE")
	theme.nameplate_offset = Vector2(18, -24)
	theme.choice_layout = "separate"
	theme.choice_align = "right"
	theme.choice_left = 0.60
	theme.choice_right = 0.94
	theme.choice_top = 0.08
	theme.choice_bottom = 0.44
	theme.choice_panel_style = "panel"
	theme.choice_style = "pixel-box"
	theme.choice_separation = 6
	theme.choice_min_height = 40
	theme.choice_margin = 10
	theme.choice_normal_bg = Color(_hex("242C4A"), 0.95)
	theme.choice_selected_bg = _hex("D5A550")
	theme.choice_text_color = _hex("E6ECFF")
	theme.choice_selected_color = _hex("151B32")
	theme.choice_hover_bg = _hex("38426B")
	theme.choice_hover_text_color = _hex("FAEBD2")
	theme.choice_border_color = _hex("4D5A8D")
	theme.choice_selected_border_color = _hex("D5A550")
	theme.choice_border_width = 2
	theme.choice_accent_color = _hex("D5A550")
	theme.choice_marker = "index"
	theme.choice_marker_size = 15
	theme.select_anim = "step-cursor"
	theme.advance_indicator = "arrow-step"
	theme.hint_style = "keycap-mono"
	theme.panel_entrance = "step-open"
	theme.panel_entrance_ms = 400
	theme.loop_anim = "led"
	theme.portrait_enabled = false
	theme.portrait_placement = "none"

# ── 10 · 夜行 Nocturne（plum × amber）─────────────────────

static func _nocturne(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.50
	theme.panel_bg_color = Color(_hex("271626"), 0.97)
	theme.panel_border_color = _hex("754E72")
	theme.panel_border_width = 1
	theme.panel_corner_radius = 18
	theme.panel_shadow_color = Color(0, 0, 0, 0.55)
	theme.panel_shadow_size = 18
	theme.panel_shape = "rect"
	theme.panel_gradient = true
	theme.panel_gradient_top = Color(_hex("3C243A"), 0.97)
	theme.panel_gradient_bottom = Color(_hex("271626"), 0.97)
	theme.accent_color = _hex("D5A550")
	theme.accent_secondary = _hex("B17EAC")
	theme.font_path = FONT_SANS
	theme.font_path_body = FONT_SANS
	theme.font_path_choice = FONT_SANS
	theme.text_color = _hex("F7E7F5")
	theme.speaker_color = _hex("F4DAB0")
	theme.hint_color = _hex("93658F")
	theme.speaker_title = "在线"
	theme.nameplate_style = "phone"
	theme.nameplate_bg = _hex("3C243A")
	theme.nameplate_border = _hex("754E72")
	theme.nameplate_border_width = 1
	theme.nameplate_radius = 10
	theme.nameplate_text_color = _hex("F4DAB0")
	theme.nameplate_accent = _hex("D5A550")
	theme.nameplate_offset = Vector2(10, -34)
	theme.choice_layout = "chat"
	theme.choice_align = "right"
	theme.choice_panel_style = "bare"
	theme.choice_style = "chat-chip"
	theme.choice_separation = 8
	theme.choice_min_height = 40
	theme.choice_gap = 16
	theme.choice_normal_bg = Color(_hex("3C243A"), 0.9)
	theme.choice_selected_bg = Color(_hex("D5A550"), 0.16)
	theme.choice_text_color = _hex("E0B9DB")
	theme.choice_selected_color = _hex("FAEBD2")
	theme.choice_hover_bg = Color(_hex("583855"), 0.9)
	theme.choice_hover_text_color = _hex("FAEBD2")
	theme.choice_border_color = _hex("754E72")
	theme.choice_selected_border_color = _hex("D5A550")
	theme.choice_border_width = 1
	theme.choice_accent_color = _hex("D5A550")
	theme.choice_marker = "none"
	theme.select_anim = "glow"
	theme.advance_indicator = "dot"
	theme.hint_style = "text"
	theme.panel_entrance = "rise"
	theme.panel_entrance_ms = 320
	theme.loop_anim = "hop"
	theme.portrait_enabled = true
	theme.portrait_placement = "large-left"
	theme.portrait_bg = _hex("3C243A")

# ── 11 · 森语 Grove（olive × moss）────────────────────────

static func _grove(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.54
	theme.panel_bg_color = Color(_hex("F5F8EE"), 0.94)
	theme.panel_border_color = _hex("6F7F46")
	theme.panel_border_width = 2
	theme.panel_corner_radius = 24
	theme.panel_shadow_color = Color(_hex("2A3213"), 0.28)
	theme.panel_shadow_size = 14
	theme.panel_shape = "rect"
	theme.panel_gradient = true
	theme.panel_gradient_top = _hex("F5F8EE")
	theme.panel_gradient_bottom = _hex("EAF0DE")
	theme.accent_color = _hex("899B5D")
	theme.accent_secondary = _hex("576433")
	theme.font_path = FONT_KAI
	theme.font_path_body = FONT_KAI
	theme.font_path_choice = FONT_KAI
	theme.text_color = _hex("23231C")
	theme.speaker_color = _hex("F5F8EE")
	theme.hint_color = _hex("6F7F46")
	theme.speaker_title = "林间向导"
	theme.nameplate_style = "capsule"
	theme.nameplate_bg = _hex("6F7F46")
	theme.nameplate_border = _hex("F5F8EE")
	theme.nameplate_border_width = 2
	theme.nameplate_radius = 16
	theme.nameplate_text_color = _hex("F5F8EE")
	theme.nameplate_accent = _hex("C0CEA1")
	theme.nameplate_offset = Vector2(20, -26)
	theme.nameplate_shadow_color = Color(_hex("2A3213"), 0.4)
	theme.nameplate_shadow_offset = Vector2(0, 3)
	theme.choice_layout = "top"
	theme.choice_align = "right"
	theme.choice_panel_style = "bare"
	theme.choice_style = "leaf-row"
	theme.choice_separation = 10
	theme.choice_min_height = 46
	theme.choice_gap = 20
	theme.choice_corner_radius = 22
	theme.choice_normal_bg = Color(_hex("F5F8EE"), 0.95)
	theme.choice_selected_bg = _hex("D9E3C5")
	theme.choice_text_color = _hex("53534B")
	theme.choice_selected_color = _hex("2A3213")
	theme.choice_hover_bg = _hex("EAF0DE")
	theme.choice_hover_text_color = _hex("3F4A22")
	theme.choice_border_color = _hex("B1B2A8")
	theme.choice_selected_border_color = _hex("6F7F46")
	theme.choice_border_width = 2
	theme.choice_accent_color = _hex("899B5D")
	theme.choice_marker = "leaf"
	theme.choice_marker_width = 26
	theme.select_anim = "glow"
	theme.advance_indicator = "leaf"
	theme.hint_style = "text"
	theme.panel_entrance = "grow"
	theme.panel_entrance_ms = 300
	theme.loop_anim = "sway"
	theme.portrait_enabled = true
	theme.portrait_placement = "large-left"
	theme.portrait_bg = _hex("D4D5CB")

# ── 12 · 战术 Tactical（olive × amber）────────────────────

static func _tactical(theme: RpgEventStudioTheme) -> void:
	_base(theme)
	theme.panel_top = 0.54
	theme.panel_bg_color = Color(_hex("23231C"), 0.97)
	theme.panel_border_color = _hex("8C8D83")
	theme.panel_border_width = 3
	theme.panel_corner_radius = 0
	theme.panel_shadow_color = Color(0, 0, 0, 0.65)
	theme.panel_shadow_size = 14
	theme.panel_shape = "cut-corner-thick"
	theme.panel_notch_size = 10
	theme.accent_color = _hex("D5A550")
	theme.accent_secondary = _hex("6F7F46")
	theme.font_path = FONT_SANS
	theme.font_path_body = FONT_SANS
	theme.font_path_choice = FONT_MONO
	theme.text_color = _hex("F4F4EA")
	theme.speaker_color = _hex("15160E")
	theme.hint_color = _hex("8C8D83")
	theme.speaker_title = "哨站联络员"
	theme.nameplate_style = "callsign"
	theme.nameplate_bg = _hex("D5A550")
	theme.nameplate_text_color = _hex("15160E")
	theme.nameplate_accent = _hex("D5A550")
	theme.nameplate_tag = "UNIT-07"
	theme.nameplate_offset = Vector2(0, -32)
	theme.choice_layout = "top"
	theme.choice_align = "left"
	theme.choice_panel_style = "bare"
	theme.choice_style = "rect"
	theme.choice_separation = 30
	theme.choice_min_height = 44
	theme.choice_gap = 24
	theme.choice_normal_bg = Color(_hex("383930"), 0.9)
	theme.choice_selected_bg = _hex("D5A550")
	theme.choice_text_color = _hex("B1B2A8")
	theme.choice_selected_color = _hex("15160E")
	theme.choice_hover_bg = _hex("53534B")
	theme.choice_hover_text_color = _hex("FAEBD2")
	theme.choice_border_color = _hex("53534B")
	theme.choice_selected_border_color = _hex("D5A550")
	theme.choice_border_width = 1
	theme.choice_accent_color = _hex("D5A550")
	theme.choice_marker = "square"
	theme.choice_marker_width = 24
	theme.select_anim = "shift"
	theme.advance_indicator = "led"
	theme.hint_style = "keycap-mono"
	theme.panel_entrance = "wipe"
	theme.panel_entrance_ms = 240
	theme.loop_anim = "led"
	theme.portrait_enabled = true
	theme.portrait_placement = "large-right"
	theme.portrait_bg = _hex("383930")
