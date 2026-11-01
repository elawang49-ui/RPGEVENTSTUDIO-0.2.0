@tool
class_name RpgEventStudioTheme
extends Resource
## 插件默认对话 UI 的可视化主题。
##
## 设计约束：
## - 只作用于 DialoguePresenter 和交互提示，不作用于游戏注入的自定义 presenter。
## - 老主题资源不需要迁移：新增字段的默认值等价于旧外观。
## - 预设不是“只有颜色不同”的换肤。面板/铭牌/选项/立绘框各自有独立的可组合
##   参数，由 DialoguePresenter 中的少量绘制组件消费；预设工厂每次都返回新实例，
##   避免两套主题共享可变配置。

# ── 预设元信息 ───────────────────────────────────────────

@export_group("预设")
## 为空表示插件默认外观（旧主题资源也会是空）。
@export var preset_id: String = ""
@export var preset_title: String = ""
@export var preset_tag: String = ""
@export_multiline var preset_description: String = ""
## 1 = 第一弹，2 = 第二弹。
@export_range(0, 3, 1) var preset_series: int = 0
## 数据模型版本；老资源为 0，保存后写 2。
@export_range(0, 9, 1) var style_version: int = 0

# ── 对话框 ───────────────────────────────────────────────

@export_group("对话框")
@export var panel_bg_color: Color = Color(0.06, 0.07, 0.10, 0.93)
@export var panel_border_color: Color = Color(0.80, 0.70, 0.42, 0.85)
@export_range(0, 12, 1) var panel_border_width: int = 2
@export_range(0, 40, 1) var panel_corner_radius: int = 10
@export var panel_shadow_color: Color = Color(0, 0, 0, 0.45)
@export_range(0, 40, 1) var panel_shadow_size: int = 8
@export var panel_shadow_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var panel_left: float = 0.06
@export_range(0.0, 1.0, 0.01) var panel_right: float = 0.94
@export_range(0.0, 1.0, 0.01) var panel_top: float = 0.60
@export_range(0.0, 1.0, 0.01) var panel_bottom: float = 0.93
@export_range(0, 80, 1) var content_margin_left: int = 22
@export_range(0, 80, 1) var content_margin_right: int = 22
@export_range(0, 80, 1) var content_margin_top: int = 16
@export_range(0, 80, 1) var content_margin_bottom: int = 12
@export_range(32, 300, 1) var text_min_height: int = 96

## 面板轮廓：rect 传统矩形；notched 斜切缺口；slant 平行四边形；cinema 无边框电影暗角。
@export_enum("rect", "notched", "slant", "cinema") var panel_shape: String = "rect"
@export_range(0, 32, 1) var panel_notch_size: int = 10
@export_range(0, 32, 1) var panel_slant_size: int = 12
## 双层/装饰边框：plain 单层；double 内缩细线；ornament 细线+角花；
## stitch 手账缝线；blade 顶部刀锋；hairline 顶部刻度线；armor 左侧装甲条。
@export_enum("plain", "double", "ornament", "stitch", "blade", "hairline", "armor") var frame_style: String = "plain"
@export var frame_inner_color: Color = Color(0.85, 0.75, 0.55, 0.35)
@export_range(0, 24, 1) var frame_inner_gap: int = 4
@export_range(0, 8, 1) var frame_inner_width: int = 1
@export var frame_inner_dash: bool = false
@export var corner_ornament: String = "none"
@export var corner_ornament_color: Color = Color(0.85, 0.75, 0.55, 0.8)
@export var corner_glyph: String = "✦"
@export_range(0, 48, 1) var corner_ornament_size: int = 13
## 面板底色是否使用上下渐变（由绘制组件实现）。
@export var panel_gradient: bool = false
@export var panel_gradient_top: Color = Color(0.08, 0.10, 0.16, 0.96)
@export var panel_gradient_bottom: Color = Color(0.04, 0.05, 0.08, 0.96)
## 面板底纹：none / notebook / dots / grid / slash / rays。
@export_enum("none", "notebook", "dots", "grid", "slash", "rays") var pattern_style: String = "none"
@export var pattern_color: Color = Color(1, 1, 1, 0.05)
@export_range(4, 64, 1) var pattern_spacing: int = 16
## 贴纸式硬阴影（0 alpha 表示不使用）。
@export var hard_shadow_color: Color = Color(0, 0, 0, 0)
@export var hard_shadow_offset: Vector2 = Vector2.ZERO
## 主题主色 / 副色，供装饰组件取用。
@export var accent_color: Color = Color(0.85, 0.75, 0.55)
@export var accent_secondary: Color = Color(0.55, 0.65, 0.85)
@export var top_blade_color: Color = Color(0, 0, 0, 0)
@export_range(0, 16, 1) var top_blade_width: int = 0
@export_range(0, 24, 1) var armor_bar_width: int = 0

# ── 文字 ─────────────────────────────────────────────────

@export_group("文字")
@export_file("*.ttf", "*.otf") var font_path: String = ""
@export_enum("sans", "serif", "mono") var font_style: String = "sans"
@export_range(8, 96, 1) var font_size: int = 18
@export var text_color: Color = Color(0.94, 0.94, 0.96)
@export_range(8, 96, 1) var text_font_size: int = 20
@export var speaker_color: Color = Color(0.96, 0.85, 0.55)
@export_range(8, 96, 1) var speaker_font_size: int = 21
@export var hint_color: Color = Color(0.72, 0.72, 0.78)
@export_range(6, 48, 1) var hint_font_size: int = 12
@export_range(0, 32, 1) var line_separation: int = 8
@export_range(5.0, 200.0, 1.0) var text_speed: float = 42.0
## 正文描边可提高复杂底纹上的可读性；0 表示不描边。
@export var text_outline_color: Color = Color(0, 0, 0, 0)
@export_range(0, 12, 1) var text_outline_size: int = 0
## 正文/选项的字体样式（预设可给“手账”用圆体、圣堂用水宋）。
@export_enum("sans", "serif", "rounded") var body_font_flavor: String = "sans"

# ── 选项 ─────────────────────────────────────────────────

@export_group("选项")
@export_range(0.0, 1.0, 0.01) var choice_left: float = 0.60
@export_range(0.0, 1.0, 0.01) var choice_right: float = 0.94
@export_range(0.0, 1.0, 0.01) var choice_top: float = 0.26
@export_range(0.0, 1.0, 0.01) var choice_bottom: float = 0.58
@export_range(0, 80, 1) var choice_margin: int = 14
@export_range(0, 32, 1) var choice_separation: int = 8
@export_range(24, 96, 1) var choice_min_height: int = 40
@export_range(8, 48, 1) var choice_font_size: int = 18
@export var choice_text_color: Color = Color(0.90, 0.91, 0.95)
@export var choice_selected_color: Color = Color(0.96, 0.85, 0.55)
@export var choice_normal_bg: Color = Color(0.08, 0.10, 0.15, 0.55)
@export var choice_selected_bg: Color = Color(0.18, 0.16, 0.10, 0.88)
@export var choice_border_color: Color = Color(0.30, 0.35, 0.44, 0.70)
@export_range(0, 12, 1) var choice_border_width: int = 1
@export_range(0, 20, 1) var choice_corner_radius: int = 6
## panel：沿用原来的选项面板；bare：每个选项自己成形（胶囊/斜切/纸条等）。
@export_enum("panel", "bare") var choice_panel_style: String = "panel"
## rect / pill / skew / note / bar / notch / wing
@export_enum("rect", "pill", "skew", "note", "bar", "notch", "wing") var choice_style: String = "rect"
@export_range(0, 20, 1) var choice_skew_degrees: int = 0
@export_range(0, 20, 1) var choice_selected_shift: int = 0
@export var choice_hover_bg: Color = Color(0.16, 0.19, 0.26, 0.72)
@export var choice_hover_text_color: Color = Color(1, 0.95, 0.78)
@export var choice_accent_color: Color = Color(0.85, 0.75, 0.55)
@export var choice_selected_border_color: Color = Color(0.85, 0.75, 0.55)
## none / number / glyph / crosshair / seal
@export_enum("none", "number", "glyph", "crosshair", "seal") var choice_marker: String = "none"
@export var choice_marker_glyph: String = "✦"
@export_range(0, 32, 1) var choice_marker_width: int = 0
@export_range(0, 8, 1) var choice_marker_size: int = 18
@export var choice_shadow_color: Color = Color(0, 0, 0, 0)
@export var choice_shadow_offset: Vector2 = Vector2.ZERO

# ── 铭牌 ─────────────────────────────────────────────────

@export_group("铭牌")
## inline 旧版标题；float 压线矩形；capsule 胶囊；parallelogram 平行四边形；
## wood 印章木牌；blood 血封条；column 左栏式（不是压在正文上）。
@export_enum("inline", "float", "capsule", "parallelogram", "wood", "blood", "column") var nameplate_style: String = "inline"
@export var nameplate_bg: Color = Color(0.06, 0.07, 0.10, 0.95)
@export var nameplate_border: Color = Color(0.80, 0.70, 0.42, 0.85)
@export_range(0, 8, 1) var nameplate_border_width: int = 1
@export_range(0, 32, 1) var nameplate_radius: int = 0
@export var nameplate_text_color: Color = Color(0.96, 0.85, 0.55)
@export var nameplate_accent: Color = Color(0.85, 0.75, 0.55)
@export var nameplate_offset: Vector2 = Vector2(20, -18)
@export_range(-15, 15, 1) var nameplate_rotation: int = 0
@export var nameplate_glyph: String = ""
@export var nameplate_tag: String = ""
@export var nameplate_shadow_color: Color = Color(0, 0, 0, 0)
@export var nameplate_shadow_offset: Vector2 = Vector2.ZERO
@export_range(0, 32, 1) var nameplate_padding_x: int = 12
@export_range(0, 24, 1) var nameplate_padding_y: int = 4
## column 模式给正文让出的左栏宽度。
@export_range(40, 180, 1) var nameplate_column_width: int = 92
@export var nameplate_divider: bool = false
@export var nameplate_divider_color: Color = Color(1, 1, 1, 0.18)

# ── 立绘框 ───────────────────────────────────────────────

@export_group("立绘框")
@export var portrait_enabled: bool = false
@export_enum("square", "rounded", "capsule", "circle", "octagon", "polaroid", "angular", "blood") var portrait_style: String = "rounded"
@export_enum("left", "right") var portrait_side: String = "left"
## 立绘框高度（px）；宽度 = 高度 × portrait_aspect。
@export_range(36, 180, 1) var portrait_size: int = 78
@export_range(0.5, 1.5, 0.01) var portrait_aspect: float = 0.82
@export var portrait_bg: Color = Color(0.08, 0.10, 0.15, 0.9)
@export var portrait_border_color: Color = Color(0.80, 0.70, 0.42, 0.85)
@export_range(0, 8, 1) var portrait_border_width: int = 1
@export_range(0, 48, 1) var portrait_corner_radius: int = 6
@export_range(0, 12, 1) var portrait_padding: int = 0
@export_range(0, 8, 1) var portrait_inner_border: int = 0
@export var portrait_inner_color: Color = Color(1, 1, 1, 0.35)
@export var portrait_accent: Color = Color(0.85, 0.75, 0.55)
@export var portrait_shadow_color: Color = Color(0, 0, 0, 0)
@export var portrait_shadow_offset: Vector2 = Vector2.ZERO
@export_range(-10, 10, 1) var portrait_rotation: int = 0
@export var portrait_glyph: String = ""
## 框体角标：none / star / glyph / tape / cross（不同主题用不同角标）。
@export_enum("none", "star", "glyph", "tape", "cross") var portrait_ornament: String = "none"
@export_range(0, 32, 1) var portrait_gap: int = 12
@export var portrait_tint: Color = Color(1, 1, 1, 1)
## 无立绘时是否保留占位框（默认 false：布局完整退化）。
@export var portrait_show_placeholder: bool = false

# ── 动画与转场 ───────────────────────────────────────────

@export_group("动画与转场")
@export_range(0.0, 2.0, 0.01) var appear_duration: float = 0.0
@export_range(0.0, 2.0, 0.01) var disappear_duration: float = 0.0
@export var fade_color: Color = Color(0, 0, 0, 1)

# ── 交互提示 ─────────────────────────────────────────────

@export_group("交互提示")
@export_range(6, 48, 1) var prompt_font_size: int = 13
@export var prompt_color: Color = Color(1.0, 0.95, 0.72)
@export var prompt_outline_color: Color = Color(0, 0, 0, 0.9)
@export_range(0, 16, 1) var prompt_outline_size: int = 4
@export_range(-200.0, 0.0, 1.0) var prompt_offset_y: float = -52.0

# ── 字体与样式 ───────────────────────────────────────────

const SANS_FONTS := [
	"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
	"Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "sans-serif",
]
const SERIF_FONTS := [
	"Songti SC", "STSong", "Noto Serif CJK SC", "Source Han Serif SC",
	"SimSun", "serif",
]
const ROUNDED_FONTS := [
	"PingFang SC", "Hiragino Sans GB", "Yuanti SC", "YouYuan",
	"Microsoft YaHei", "Noto Sans CJK SC", "sans-serif",
]
const MONO_FONTS := [
	"SF Mono", "Menlo", "Consolas", "Noto Sans Mono CJK SC", "monospace",
]

var _font_cache: Font
var _font_cache_key := ""
var _body_font_cache: Font
var _body_font_cache_key := ""

## 主题参数变化后调用，避免编辑器里换字体仍拿到旧缓存。
func invalidate_font_cache() -> void:
	_font_cache = null
	_font_cache_key = ""
	_body_font_cache = null
	_body_font_cache_key = ""

func resolve_font() -> Font:
	var key := "%s|%s" % [font_path, font_style]
	if _font_cache != null and _font_cache_key == key:
		return _font_cache
	var font: Font = null
	if font_path.strip_edges() != "" and ResourceLoader.exists(font_path):
		var loaded := load(font_path)
		if loaded is Font:
			font = loaded
	if font == null:
		var system := SystemFont.new()
		var names := SANS_FONTS
		match font_style:
			"serif":
				names = SERIF_FONTS
			"mono":
				names = MONO_FONTS
		system.font_names = PackedStringArray(names)
		font = system
	_font_cache = font
	_font_cache_key = key
	return font

func resolve_body_font() -> Font:
	var key := "%s|%s" % [font_path, body_font_flavor]
	if _body_font_cache != null and _body_font_cache_key == key:
		return _body_font_cache
	var font: Font = null
	if font_path.strip_edges() != "" and ResourceLoader.exists(font_path):
		var loaded := load(font_path)
		if loaded is Font:
			font = loaded
	if font == null:
		var system := SystemFont.new()
		match body_font_flavor:
			"serif":
				system.font_names = PackedStringArray(SERIF_FONTS)
			"rounded":
				system.font_names = PackedStringArray(ROUNDED_FONTS)
			_:
				system.font_names = PackedStringArray(SANS_FONTS)
		font = system
	_body_font_cache = font
	_body_font_cache_key = key
	return font

## 绘制组件是否接管面板底色。预设主题使用绘制组件，以支持渐变、底纹、
## 斜切缺口和硬阴影；旧默认主题继续走 StyleBox，保持旧资源完全一致。
func uses_decor_base() -> bool:
	if preset_id != "":
		return true
	if panel_gradient or pattern_style != "none":
		return true
	if hard_shadow_color.a > 0.0:
		return true
	if panel_shape != "rect":
		return true
	if frame_style != "plain" or corner_ornament != "none":
		return true
	return top_blade_width > 0 or armor_bar_width > 0

func uses_bare_choices() -> bool:
	return choice_panel_style == "bare"

func is_shaped_choice() -> bool:
	return choice_style != "rect" or choice_marker != "none"

## 面板主体 StyleBox。预设主题会把底/边/阴影交给绘制组件，
## 这里只保留兼容旧默认主题的最小形状信息。
func make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if uses_decor_base():
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color(0, 0, 0, 0)
		style.set_border_width_all(0)
		style.shadow_color = Color(0, 0, 0, 0)
		style.shadow_size = 0
	else:
		style.bg_color = panel_bg_color
		style.border_color = panel_border_color
		style.set_border_width_all(panel_border_width)
		style.shadow_color = panel_shadow_color
		style.shadow_size = panel_shadow_size
		style.shadow_offset = panel_shadow_offset
	style.set_corner_radius_all(panel_corner_radius)
	return style

func make_choice_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if uses_bare_choices():
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color(0, 0, 0, 0)
		style.set_border_width_all(0)
		style.shadow_color = Color(0, 0, 0, 0)
		style.shadow_size = 0
	else:
		style = make_panel_style()
		# 选项面板背景不透明，地图元素不允许透过面板影响选项文字。
		style.bg_color.a = 1.0
	style.set_corner_radius_all(panel_corner_radius)
	return style

func make_choice_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = choice_selected_bg if selected else choice_normal_bg
	style.border_color = choice_selected_border_color if selected else choice_border_color
	style.set_border_width_all(choice_border_width)
	style.set_corner_radius_all(choice_corner_radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style
