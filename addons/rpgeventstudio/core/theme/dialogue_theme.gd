@tool
class_name RpgEventStudioTheme
extends Resource
## 插件默认对话 UI 的可视化主题。只作用于 DialoguePresenter 和交互提示，
## 不作用于游戏注入的自定义 presenter（例如《做题家》原叙事 UI）。
##
## 默认值与未配置主题时的硬编码外观一致；缺省主题文件不会改变游戏表现。

@export_group("对话框")
@export var panel_bg_color: Color = Color(0.035, 0.045, 0.066, 0.97)
@export var panel_border_color: Color = Color(0.55, 0.46, 0.31, 0.72)
@export_range(0, 12, 1) var panel_border_width: int = 1
@export_range(0, 40, 1) var panel_corner_radius: int = 14
@export var panel_shadow_color: Color = Color(0, 0, 0, 0.58)
@export_range(0, 40, 1) var panel_shadow_size: int = 20
@export_range(0.0, 1.0, 0.01) var panel_left: float = 0.055
@export_range(0.0, 1.0, 0.01) var panel_right: float = 0.945
@export_range(0.0, 1.0, 0.01) var panel_top: float = 0.64
@export_range(0.0, 1.0, 0.01) var panel_bottom: float = 0.92
@export_range(0, 80, 1) var content_margin_left: int = 30
@export_range(0, 80, 1) var content_margin_right: int = 30
@export_range(0, 80, 1) var content_margin_top: int = 20
@export_range(0, 80, 1) var content_margin_bottom: int = 16
@export_range(32, 300, 1) var text_min_height: int = 76

@export_group("文字")
@export_file("*.ttf", "*.otf") var font_path: String = ""
@export_range(8, 96, 1) var font_size: int = 17
@export var text_color: Color = Color(0.90, 0.91, 0.94)
@export_range(8, 96, 1) var text_font_size: int = 21
@export var speaker_color: Color = Color(0.94, 0.81, 0.57)
@export_range(8, 96, 1) var speaker_font_size: int = 17
@export var hint_color: Color = Color(0.48, 0.53, 0.61)
@export_range(6, 48, 1) var hint_font_size: int = 12
@export_range(0, 32, 1) var line_separation: int = 7
@export_range(5.0, 200.0, 1.0) var text_speed: float = 42.0

@export_group("选项")
@export_range(0.0, 1.0, 0.01) var choice_left: float = 0.585
@export_range(0.0, 1.0, 0.01) var choice_right: float = 0.945
@export_range(0.0, 1.0, 0.01) var choice_top: float = 0.25
@export_range(0.0, 1.0, 0.01) var choice_bottom: float = 0.60
@export_range(0, 80, 1) var choice_margin: int = 16
@export_range(0, 32, 1) var choice_separation: int = 8
@export_range(24, 96, 1) var choice_min_height: int = 44
@export_range(8, 48, 1) var choice_font_size: int = 17
@export var choice_text_color: Color = Color(0.78, 0.81, 0.86)
@export var choice_selected_color: Color = Color(0.94, 0.81, 0.57)
@export var choice_normal_bg: Color = Color(0.060, 0.075, 0.105, 0.88)
@export var choice_selected_bg: Color = Color(0.16, 0.13, 0.085, 0.98)
@export var choice_border_color: Color = Color(0.19, 0.22, 0.28, 0.82)
@export_range(0, 12, 1) var choice_border_width: int = 1
@export_range(0, 20, 1) var choice_corner_radius: int = 8

@export_group("动画与转场")
@export_range(0.0, 2.0, 0.01) var appear_duration: float = 0.18
@export_range(0.0, 2.0, 0.01) var disappear_duration: float = 0.14
@export var fade_color: Color = Color(0, 0, 0, 1)

@export_group("交互提示")
@export_range(6, 48, 1) var prompt_font_size: int = 13
@export var prompt_color: Color = Color(0.94, 0.81, 0.57)
@export var prompt_outline_color: Color = Color(0.02, 0.025, 0.035, 0.96)
@export_range(0, 16, 1) var prompt_outline_size: int = 5
@export_range(-200.0, 0.0, 1.0) var prompt_offset_y: float = -56.0

func resolve_font() -> Font:
	if font_path.strip_edges() != "" and ResourceLoader.exists(font_path):
		var loaded := load(font_path)
		if loaded is Font:
			return loaded
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
		"Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "sans-serif",
	])
	return font

func make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = panel_bg_color
	style.border_color = panel_border_color
	style.set_border_width_all(panel_border_width)
	style.set_corner_radius_all(panel_corner_radius)
	style.shadow_color = panel_shadow_color
	style.shadow_size = panel_shadow_size
	style.shadow_offset = Vector2(0, 7)
	style.anti_aliasing = true
	return style

func make_choice_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = choice_selected_bg if selected else choice_normal_bg
	style.border_color = choice_selected_color if selected else choice_border_color
	style.set_border_width_all(choice_border_width)
	style.border_width_left = 3 if selected else choice_border_width
	style.set_corner_radius_all(choice_corner_radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.anti_aliasing = true
	if selected:
		style.shadow_color = Color(choice_selected_color, 0.10)
		style.shadow_size = 5
	return style
