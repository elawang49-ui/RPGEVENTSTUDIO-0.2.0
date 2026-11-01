@tool
class_name DialogueThemeView
extends VBoxContainer
## UI 主题定制页（编辑器主屏内的一个标签页）。
##
## 只修改插件默认 DialoguePresenter / 交互提示的视觉；游戏注入自定义 presenter 时，
## 通过项目设置 rpg_event_studio/ui_mode="custom" 声明，本页只显示能力说明，不伪造配置。
##
## 第二批主题：顶部预设切换 + 实时预览 + 参数区。
## 预设是工厂返回的独立实例，切换/修改不会污染其他预设；保存写回项目主题资源。

const THEME_PATH := "res://ui/rpgeventstudio_theme.tres"
const UI_MODE_SETTING := "rpg_event_studio/ui_mode"
const CAPS_SETTING := "rpg_event_studio/custom_ui_capabilities"
const SAMPLE_PORTRAIT_PATH := "res://addons/rpgeventstudio/samples/ui/sample_portrait.png"

const SAMPLE_PLAIN := "这是一段普通文本预览。\n可以检查颜色、字号、位置与内边距。"
const SAMPLE_BBCODE := "[b]重点文字[/b]\n[color=#FFD700]关键线索[/color] [font_size=26]大字号[/font_size]\n[center]居中文字[/center]"
const SAMPLE_MULTILINE := "第一行：多行文本。\n第二行：中文标点，换行。\n第三行：用于检查行距、内边距和位置。"
const SAMPLE_CHOICES := ["A. 删除异常记录，标记为已修复。", "B. 保留记录，申请进一步调查。", "C. 先完成修复，同时备份异常记录。"]

const PREVIEW_SIZE_LABELS := ["960×600", "1280×820", "1152×648"]
const PREVIEW_SIZES := [[960, 600], [1280, 820], [1152, 648]]

const SECTIONS := [
	{"title": "theme.section.panel", "fields": [
		{"prop": "panel_bg_color", "label": "theme.panel.bg", "type": "color"},
		{"prop": "panel_border_color", "label": "theme.panel.border", "type": "color"},
		{"prop": "panel_border_width", "label": "theme.panel.border_width", "type": "int", "min": 0, "max": 12, "step": 1},
		{"prop": "panel_corner_radius", "label": "theme.panel.corner", "type": "int", "min": 0, "max": 40, "step": 1},
		{"prop": "panel_shadow_color", "label": "theme.panel.shadow", "type": "color"},
		{"prop": "panel_shadow_size", "label": "theme.panel.shadow_size", "type": "int", "min": 0, "max": 40, "step": 1},
		{"prop": "panel_shadow_offset", "label": "theme.panel.shadow_offset", "type": "vec2"},
		{"prop": "panel_left", "label": "theme.panel.left", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "panel_right", "label": "theme.panel.right", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "panel_top", "label": "theme.panel.top", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "panel_bottom", "label": "theme.panel.bottom", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "content_margin_left", "label": "theme.panel.margin_left", "type": "int", "min": 0, "max": 160, "step": 1},
		{"prop": "content_margin_right", "label": "theme.panel.margin_right", "type": "int", "min": 0, "max": 160, "step": 1},
		{"prop": "content_margin_top", "label": "theme.panel.margin_top", "type": "int", "min": 0, "max": 160, "step": 1},
		{"prop": "content_margin_bottom", "label": "theme.panel.margin_bottom", "type": "int", "min": 0, "max": 160, "step": 1},
		{"prop": "text_min_height", "label": "theme.text.min_height", "type": "int", "min": 32, "max": 300, "step": 1},
		{"prop": "panel_shape", "label": "theme.panel.shape", "type": "option", "options": ["theme.opt.rect", "theme.opt.notched", "theme.opt.slant", "theme.opt.cinema", "theme.opt.octagon", "theme.opt.shard"], "values": ["rect", "notched", "slant", "cinema", "octagon", "shard"]},
		{"prop": "panel_notch_size", "label": "theme.panel.notch", "type": "int", "min": 0, "max": 32, "step": 1},
		{"prop": "panel_slant_size", "label": "theme.panel.slant", "type": "int", "min": 0, "max": 32, "step": 1},
		{"prop": "frame_style", "label": "theme.panel.frame", "type": "option", "options": ["theme.opt.frame_plain", "theme.opt.frame_double", "theme.opt.frame_ornament", "theme.opt.frame_stitch", "theme.opt.frame_blade", "theme.opt.frame_hairline", "theme.opt.frame_armor", "theme.opt.frame_lace", "theme.opt.frame_tapered"], "values": ["plain", "double", "ornament", "stitch", "blade", "hairline", "armor", "lace", "tapered"]},
		{"prop": "frame_inner_color", "label": "theme.panel.frame_color", "type": "color"},
		{"prop": "frame_inner_gap", "label": "theme.panel.frame_gap", "type": "int", "min": 0, "max": 24, "step": 1},
		{"prop": "frame_inner_width", "label": "theme.panel.frame_width", "type": "int", "min": 0, "max": 8, "step": 1},
		{"prop": "frame_inner_dash", "label": "theme.panel.frame_dash", "type": "bool"},
		{"prop": "corner_ornament", "label": "theme.panel.ornament", "type": "option", "options": ["theme.opt.none", "theme.opt.ornament_star", "theme.opt.ornament_cross", "theme.opt.ornament_tape", "theme.opt.ornament_seal", "theme.opt.ornament_blade", "theme.opt.ornament_astrolabe", "theme.opt.ornament_butterfly"], "values": ["none", "star", "cross", "tape", "seal", "blade", "astrolabe", "butterfly"]},
		{"prop": "corner_ornament_color", "label": "theme.panel.ornament_color", "type": "color"},
		{"prop": "corner_glyph", "label": "theme.panel.ornament_glyph", "type": "text"},
		{"prop": "corner_ornament_size", "label": "theme.panel.ornament_size", "type": "int", "min": 0, "max": 48, "step": 1},
		{"prop": "ornament_rotation_speed", "label": "theme.panel.ornament_speed", "type": "float", "min": 0, "max": 30, "step": 0.1},
		{"prop": "panel_gradient", "label": "theme.panel.gradient", "type": "bool"},
		{"prop": "panel_gradient_top", "label": "theme.panel.gradient_top", "type": "color"},
		{"prop": "panel_gradient_bottom", "label": "theme.panel.gradient_bottom", "type": "color"},
		{"prop": "pattern_style", "label": "theme.panel.pattern", "type": "option", "options": ["theme.opt.none", "theme.opt.pattern_notebook", "theme.opt.pattern_dots", "theme.opt.pattern_grid", "theme.opt.pattern_slash", "theme.opt.pattern_rays", "theme.opt.pattern_constellation"], "values": ["none", "notebook", "dots", "grid", "slash", "rays", "constellation"]},
		{"prop": "pattern_color", "label": "theme.panel.pattern_color", "type": "color"},
		{"prop": "pattern_spacing", "label": "theme.panel.pattern_spacing", "type": "int", "min": 4, "max": 64, "step": 1},
		{"prop": "hard_shadow_color", "label": "theme.panel.hard_shadow", "type": "color"},
		{"prop": "hard_shadow_offset", "label": "theme.panel.hard_shadow_offset", "type": "vec2"},
		{"prop": "accent_color", "label": "theme.panel.accent", "type": "color"},
		{"prop": "accent_secondary", "label": "theme.panel.accent2", "type": "color"},
		{"prop": "top_blade_color", "label": "theme.panel.blade_color", "type": "color"},
		{"prop": "top_blade_width", "label": "theme.panel.blade_width", "type": "int", "min": 0, "max": 16, "step": 1},
		{"prop": "armor_bar_width", "label": "theme.panel.armor_width", "type": "int", "min": 0, "max": 24, "step": 1},
	]},
	{"title": "theme.section.text", "fields": [
		{"prop": "font_path", "label": "theme.font", "type": "font"},
		{"prop": "font_style", "label": "theme.text.family", "type": "option", "options": ["theme.opt.sans", "theme.opt.serif", "theme.opt.mono"], "values": ["sans", "serif", "mono"]},
		{"prop": "body_font_flavor", "label": "theme.text.body_family", "type": "option", "options": ["theme.opt.sans", "theme.opt.serif", "theme.opt.font_rounded"], "values": ["sans", "serif", "rounded"]},
		{"prop": "text_align", "label": "theme.text.align", "type": "option", "options": ["theme.opt.text_left", "theme.opt.text_center"], "values": ["left", "center"]},
		{"prop": "font_size", "label": "theme.font_size", "type": "int", "min": 8, "max": 96, "step": 1},
		{"prop": "text_color", "label": "theme.text.color", "type": "color"},
		{"prop": "text_font_size", "label": "theme.text.size", "type": "int", "min": 8, "max": 96, "step": 1},
		{"prop": "text_outline_color", "label": "theme.text.outline", "type": "color"},
		{"prop": "text_outline_size", "label": "theme.text.outline_size", "type": "int", "min": 0, "max": 12, "step": 1},
		{"prop": "line_separation", "label": "theme.text.line", "type": "int", "min": 0, "max": 32, "step": 1},
		{"prop": "text_speed", "label": "theme.text.speed", "type": "float", "min": 5, "max": 200, "step": 1},
		{"prop": "speaker_color", "label": "theme.speaker.color", "type": "color"},
		{"prop": "speaker_font_size", "label": "theme.speaker.size", "type": "int", "min": 8, "max": 96, "step": 1},
		{"prop": "hint_color", "label": "theme.hint.color", "type": "color"},
		{"prop": "hint_font_size", "label": "theme.hint.size", "type": "int", "min": 6, "max": 48, "step": 1},
	]},
	{"title": "theme.section.choices", "fields": [
		{"prop": "choice_left", "label": "theme.choice.left", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "choice_right", "label": "theme.choice.right", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "choice_top", "label": "theme.choice.top", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "choice_bottom", "label": "theme.choice.bottom", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "choice_margin", "label": "theme.choice.margin", "type": "int", "min": 0, "max": 80, "step": 1},
		{"prop": "choice_separation", "label": "theme.choice.separation", "type": "int", "min": 0, "max": 32, "step": 1},
		{"prop": "choice_min_height", "label": "theme.choice.height", "type": "int", "min": 24, "max": 96, "step": 1},
		{"prop": "choice_font_size", "label": "theme.choice.font_size", "type": "int", "min": 8, "max": 48, "step": 1},
		{"prop": "choice_text_color", "label": "theme.choice.text", "type": "color"},
		{"prop": "choice_selected_color", "label": "theme.choice.selected_text", "type": "color"},
		{"prop": "choice_normal_bg", "label": "theme.choice.bg", "type": "color"},
		{"prop": "choice_selected_bg", "label": "theme.choice.selected_bg", "type": "color"},
		{"prop": "choice_border_color", "label": "theme.choice.border", "type": "color"},
		{"prop": "choice_border_width", "label": "theme.choice.border_width", "type": "int", "min": 0, "max": 12, "step": 1},
		{"prop": "choice_corner_radius", "label": "theme.choice.corner", "type": "int", "min": 0, "max": 20, "step": 1},
		{"prop": "choice_panel_style", "label": "theme.choice.panel_style", "type": "option", "options": ["theme.opt.choice_panel", "theme.opt.choice_bare"], "values": ["panel", "bare"]},
		{"prop": "choice_style", "label": "theme.choice.shape", "type": "option", "options": ["theme.opt.rect", "theme.opt.pill", "theme.opt.skew", "theme.opt.note", "theme.opt.bar", "theme.opt.notch", "theme.opt.wing", "theme.opt.spindle", "theme.opt.swallowtail", "theme.opt.crystal", "theme.opt.filament"], "values": ["rect", "pill", "skew", "note", "bar", "notch", "wing", "spindle", "swallowtail", "crystal", "filament"]},
		{"prop": "choice_skew_degrees", "label": "theme.choice.skew", "type": "int", "min": 0, "max": 20, "step": 1},
		{"prop": "choice_selected_shift", "label": "theme.choice.shift", "type": "int", "min": 0, "max": 20, "step": 1},
		{"prop": "choice_hover_bg", "label": "theme.choice.hover_bg", "type": "color"},
		{"prop": "choice_hover_text_color", "label": "theme.choice.hover_text", "type": "color"},
		{"prop": "choice_accent_color", "label": "theme.choice.accent", "type": "color"},
		{"prop": "choice_selected_border_color", "label": "theme.choice.selected_border", "type": "color"},
		{"prop": "choice_marker", "label": "theme.choice.marker", "type": "option", "options": ["theme.opt.none", "theme.opt.marker_number", "theme.opt.marker_glyph", "theme.opt.marker_crosshair", "theme.opt.marker_seal", "theme.opt.marker_heart"], "values": ["none", "number", "glyph", "crosshair", "seal", "heart"]},
		{"prop": "choice_marker_glyph", "label": "theme.choice.marker_glyph", "type": "text"},
		{"prop": "choice_marker_width", "label": "theme.choice.marker_width", "type": "int", "min": 0, "max": 32, "step": 1},
		{"prop": "choice_marker_size", "label": "theme.choice.marker_size", "type": "int", "min": 8, "max": 32, "step": 1},
		{"prop": "choice_shadow_color", "label": "theme.choice.shadow", "type": "color"},
		{"prop": "choice_shadow_offset", "label": "theme.choice.shadow_offset", "type": "vec2"},
		{"prop": "choice_gap", "label": "theme.choice.gap", "type": "int", "min": 0, "max": 40, "step": 1},
	]},
	{"title": "theme.section.nameplate", "fields": [
		{"prop": "nameplate_style", "label": "theme.nameplate.style", "type": "option", "options": ["theme.opt.inline", "theme.opt.float", "theme.opt.capsule", "theme.opt.parallelogram", "theme.opt.wood", "theme.opt.blood", "theme.opt.column", "theme.opt.ribbon", "theme.opt.header", "theme.opt.blade", "theme.opt.poetic"], "values": ["inline", "float", "capsule", "parallelogram", "wood", "blood", "column", "ribbon", "header", "blade", "poetic"]},
		{"prop": "nameplate_bg", "label": "theme.nameplate.bg", "type": "color"},
		{"prop": "nameplate_border", "label": "theme.nameplate.border", "type": "color"},
		{"prop": "nameplate_border_width", "label": "theme.nameplate.border_width", "type": "int", "min": 0, "max": 8, "step": 1},
		{"prop": "nameplate_radius", "label": "theme.nameplate.radius", "type": "int", "min": 0, "max": 32, "step": 1},
		{"prop": "nameplate_text_color", "label": "theme.nameplate.text", "type": "color"},
		{"prop": "nameplate_accent", "label": "theme.nameplate.accent", "type": "color"},
		{"prop": "nameplate_offset", "label": "theme.nameplate.offset", "type": "vec2"},
		{"prop": "nameplate_rotation", "label": "theme.nameplate.rotation", "type": "int", "min": -15, "max": 15, "step": 1},
		{"prop": "nameplate_glyph", "label": "theme.nameplate.glyph", "type": "text"},
		{"prop": "nameplate_tag", "label": "theme.nameplate.tag", "type": "text"},
		{"prop": "nameplate_shadow_color", "label": "theme.nameplate.shadow", "type": "color"},
		{"prop": "nameplate_shadow_offset", "label": "theme.nameplate.shadow_offset", "type": "vec2"},
		{"prop": "nameplate_padding_x", "label": "theme.nameplate.padding_x", "type": "int", "min": 0, "max": 32, "step": 1},
		{"prop": "nameplate_padding_y", "label": "theme.nameplate.padding_y", "type": "int", "min": 0, "max": 24, "step": 1},
		{"prop": "nameplate_column_width", "label": "theme.nameplate.column_width", "type": "int", "min": 40, "max": 180, "step": 1},
		{"prop": "nameplate_divider", "label": "theme.nameplate.divider", "type": "bool"},
		{"prop": "nameplate_divider_color", "label": "theme.nameplate.divider_color", "type": "color"},
		{"prop": "nameplate_width_ratio", "label": "theme.nameplate.width_ratio", "type": "float", "min": 0, "max": 1, "step": 0.01},
	]},
	{"title": "theme.section.portrait", "fields": [
		{"prop": "portrait_style", "label": "theme.portrait.style", "type": "option", "options": ["theme.opt.square", "theme.opt.rounded", "theme.opt.capsule", "theme.opt.circle", "theme.opt.octagon", "theme.opt.polaroid", "theme.opt.angular", "theme.opt.blood"], "values": ["square", "rounded", "capsule", "circle", "octagon", "polaroid", "angular", "blood"]},
		{"prop": "portrait_side", "label": "theme.portrait.side", "type": "option", "options": ["theme.opt.left", "theme.opt.right"], "values": ["left", "right"]},
		{"prop": "portrait_size", "label": "theme.portrait.size", "type": "int", "min": 36, "max": 180, "step": 1},
		{"prop": "portrait_aspect", "label": "theme.portrait.aspect", "type": "float", "min": 0.5, "max": 1.5, "step": 0.01},
		{"prop": "portrait_bg", "label": "theme.portrait.bg", "type": "color"},
		{"prop": "portrait_border_color", "label": "theme.portrait.border", "type": "color"},
		{"prop": "portrait_border_width", "label": "theme.portrait.border_width", "type": "int", "min": 0, "max": 8, "step": 1},
		{"prop": "portrait_corner_radius", "label": "theme.portrait.corner", "type": "int", "min": 0, "max": 48, "step": 1},
		{"prop": "portrait_padding", "label": "theme.portrait.padding", "type": "int", "min": 0, "max": 12, "step": 1},
		{"prop": "portrait_inner_border", "label": "theme.portrait.inner_border", "type": "int", "min": 0, "max": 8, "step": 1},
		{"prop": "portrait_inner_color", "label": "theme.portrait.inner_color", "type": "color"},
		{"prop": "portrait_accent", "label": "theme.portrait.accent", "type": "color"},
		{"prop": "portrait_shadow_color", "label": "theme.portrait.shadow", "type": "color"},
		{"prop": "portrait_shadow_offset", "label": "theme.portrait.shadow_offset", "type": "vec2"},
		{"prop": "portrait_rotation", "label": "theme.portrait.rotation", "type": "int", "min": -10, "max": 10, "step": 1},
		{"prop": "portrait_ornament", "label": "theme.portrait.ornament", "type": "option", "options": ["theme.opt.none", "theme.opt.ornament_star", "theme.opt.ornament_cross", "theme.opt.ornament_tape", "theme.opt.marker_glyph"], "values": ["none", "star", "cross", "tape", "glyph"]},
		{"prop": "portrait_glyph", "label": "theme.portrait.glyph", "type": "text"},
		{"prop": "portrait_gap", "label": "theme.portrait.gap", "type": "int", "min": 0, "max": 32, "step": 1},
		{"prop": "portrait_tint", "label": "theme.portrait.tint", "type": "color"},
		{"prop": "portrait_show_placeholder", "label": "theme.portrait.placeholder", "type": "bool"},
	]},
	{"title": "theme.section.effects", "fields": [
		{"prop": "appear_duration", "label": "theme.effects.appear", "type": "float", "min": 0, "max": 2, "step": 0.01},
		{"prop": "disappear_duration", "label": "theme.effects.disappear", "type": "float", "min": 0, "max": 2, "step": 0.01},
		{"prop": "fade_color", "label": "theme.effects.fade_color", "type": "color"},
	]},
	{"title": "theme.section.prompt", "fields": [
		{"prop": "prompt_font_size", "label": "theme.prompt.size", "type": "int", "min": 6, "max": 48, "step": 1},
		{"prop": "prompt_color", "label": "theme.prompt.color", "type": "color"},
		{"prop": "prompt_outline_color", "label": "theme.prompt.outline", "type": "color"},
		{"prop": "prompt_outline_size", "label": "theme.prompt.outline_size", "type": "int", "min": 0, "max": 16, "step": 1},
		{"prop": "prompt_offset_y", "label": "theme.prompt.offset", "type": "float", "min": -200, "max": 0, "step": 1},
	]},
]

## 可被测试覆盖；正常运行时就是项目主题路径。
var theme_path := THEME_PATH

var _theme: RpgEventStudioTheme
var _preview: DialoguePresenter
var _preview_viewport: SubViewport
var _preview_container: Control
var _preview_panel: PanelContainer
var _preview_side: VBoxContainer
var _preview_aspect: AspectRatioContainer
var _preview_backdrop: Control
var _body: BoxContainer
var _settings_scroll: ScrollContainer
var _settings_box: VBoxContainer
var _section_jump: OptionButton
var _section_anchors: Array[Control] = []
var _last_preview_size := Vector2i.ZERO
var _preview_toggle: Button
var _preview_only := false
var _sample: OptionButton
var _preview_size_select: OptionButton
var _preview_resolution := Vector2i(960, 600)
var _controls_box: VBoxContainer
var _status: Label
var _path_label: Label
var _font_edit: LineEdit
var _font_dialog: FileDialog
var _loading := false
var _custom_mode := false

var _preset_select: OptionButton
var _preset_info: Label
var _preset_palette: HBoxContainer
var _portrait_toggle: CheckButton
var _preset_syncing := false
var _sample_portrait: Texture2D

func _ready() -> void:
	_custom_mode = str(ProjectSettings.get_setting(UI_MODE_SETTING, "default")) == "custom"
	if ResourceLoader.exists(SAMPLE_PORTRAIT_PATH):
		_sample_portrait = load(SAMPLE_PORTRAIT_PATH)
	_theme = _load_theme()
	_build()
	set_process(true)

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_sync_preview_size()

func _build() -> void:
	add_theme_constant_override("separation", 8)
	var header := HBoxContainer.new()
	add_child(header)
	var title := Label.new()
	title.text = L10n.ui("theme.title")
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)
	_path_label = Label.new()
	_path_label.text = L10n.ui("theme.path", {"path": theme_path})
	_path_label.custom_minimum_size = Vector2(0, 0)
	_path_label.clip_text = true
	_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_path_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
	header.add_child(_path_label)

	if _custom_mode:
		_build_custom_mode()
		return

	_build_preset_row()

	var footer := HBoxContainer.new()
	add_child(footer)
	var save := Button.new()
	save.text = L10n.ui("theme.save")
	save.pressed.connect(_save_theme)
	footer.add_child(save)
	var reload := Button.new()
	reload.text = L10n.ui("theme.reload")
	reload.pressed.connect(_reload_theme)
	footer.add_child(reload)
	var restore := Button.new()
	restore.text = L10n.ui("theme.restore")
	restore.pressed.connect(_restore_defaults)
	footer.add_child(restore)
	_preview_toggle = Button.new()
	_preview_toggle.text = L10n.ui("theme.preview.toggle")
	_preview_toggle.tooltip_text = L10n.ui("theme.preview.toggle.tip")
	_preview_toggle.toggle_mode = true
	_preview_toggle.toggled.connect(func(pressed: bool) -> void:
		_preview_only = pressed
		_update_responsive_layout()
	)
	footer.add_child(_preview_toggle)
	_status = Label.new()
	_status.custom_minimum_size = Vector2(0, 0)
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_status.add_theme_color_override("font_color", Color(0.65, 0.82, 0.65))
	footer.add_child(_status)

	# 预览与参数左右分栏：1152×648 下设置区不再只剩三行高；
	# 窄窗口（编辑器停靠面板占位后）自动改为上下排列。
	var body := BoxContainer.new()
	body.vertical = false
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	add_child(body)
	_body = body

	var preview_side := VBoxContainer.new()
	preview_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_side.custom_minimum_size = Vector2(360, 0)
	body.add_child(preview_side)
	_preview_side = preview_side

	var preview_title := Label.new()
	preview_title.text = L10n.ui("theme.preview")
	preview_title.add_theme_font_size_override("font_size", 12)
	preview_side.add_child(preview_title)
	var sample_row := HBoxContainer.new()
	preview_side.add_child(sample_row)
	_sample = OptionButton.new()
	for key in ["theme.preview.text", "theme.preview.bbcode", "theme.preview.multiline", "theme.preview.choices"]:
		_sample.add_item(L10n.ui(key))
	_sample.item_selected.connect(func(_index: int) -> void: _play_preview())
	sample_row.add_child(_sample)
	var replay := Button.new()
	replay.text = L10n.ui("theme.preview.replay")
	replay.pressed.connect(_play_preview)
	sample_row.add_child(replay)
	_preview_size_select = OptionButton.new()
	for label in PREVIEW_SIZE_LABELS:
		_preview_size_select.add_item(label)
	_preview_size_select.tooltip_text = L10n.ui("theme.preview.size_tip")
	_preview_size_select.item_selected.connect(_on_preview_size_selected)
	sample_row.add_child(_preview_size_select)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.custom_minimum_size = Vector2(240, 240)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.08, 0.09, 0.12)
	preview_style.set_corner_radius_all(4)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	preview_side.add_child(preview_panel)
	_preview_panel = preview_panel
	var bottom_gap := Control.new()
	bottom_gap.custom_minimum_size = Vector2(0, 8)
	preview_side.add_child(bottom_gap)

	# 固定虚拟分辨率 + 等比缩放：预览布局与 1152/1280 运行时一致，
	# 不会因为编辑器面板只有 300px 高就把对话框挤成另一种布局。
	_preview_aspect = AspectRatioContainer.new()
	_preview_aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_preview_aspect.ratio = 960.0 / 600.0
	_preview_aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(_preview_aspect)
	# 固定虚拟分辨率离屏渲染，再用 TextureRect 等比缩放显示。
	# 不用 SubViewportContainer.stretch=true：它会把 SubViewport 改成容器尺寸，
	# 导致预览布局随编辑器面板大小漂移。
	_preview_viewport = SubViewport.new()
	_preview_viewport.size = _preview_resolution
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_viewport.disable_3d = true
	_preview_panel.add_child(_preview_viewport)
	var preview_texture := TextureRect.new()
	preview_texture.name = "PreviewTexture"
	preview_texture.texture = _preview_viewport.get_texture()
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_aspect.add_child(preview_texture)
	_preview_container = preview_texture
	_preview_backdrop = PreviewBackdrop.new()
	_preview_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_viewport.add_child(_preview_backdrop)
	_preview_backdrop.set("accent", _theme.accent_color)
	_preview = DialoguePresenter.new()
	_preview.name = "ThemePreview"
	_preview.editor_preview = true
	_preview.input = null
	_preview.blocked = true
	_preview_viewport.add_child(_preview)

	var settings := VBoxContainer.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", 6)
	body.add_child(settings)
	_settings_box = settings

	var settings_header := HBoxContainer.new()
	settings.add_child(settings_header)
	var settings_title := Label.new()
	settings_title.text = L10n.ui("theme.settings")
	settings_title.add_theme_font_size_override("font_size", 12)
	settings_title.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
	settings_header.add_child(settings_title)
	_section_jump = OptionButton.new()
	_section_jump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section_jump.item_selected.connect(_on_section_jump)
	settings_header.add_child(_section_jump)

	_settings_scroll = ScrollContainer.new()
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_scroll.custom_minimum_size = Vector2(360, 0)
	_settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings.add_child(_settings_scroll)
	_controls_box = VBoxContainer.new()
	_controls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_box.add_theme_constant_override("separation", 3)
	_settings_scroll.add_child(_controls_box)

	resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")
	call_deferred("_sync_preview_size")
	_build_controls()
	_play_preview.call_deferred()

# ── 预设选择 ─────────────────────────────────────────────

func _build_preset_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var label := Label.new()
	label.text = L10n.ui("theme.preset")
	label.add_theme_font_size_override("font_size", UiFonts.BODY)
	row.add_child(label)
	_preset_select = OptionButton.new()
	_preset_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_select.custom_minimum_size = Vector2(280, 0)
	_preset_select.add_item(L10n.ui("theme.preset.custom"))
	_preset_select.set_item_metadata(0, "")
	for meta in DialogueThemePresets.PRESETS:
		var series := int(meta.get("series", 1))
		var prefix := L10n.ui("theme.preset.series1")
		if series == 2:
			prefix = L10n.ui("theme.preset.series2")
		elif series == 4:
			prefix = L10n.ui("theme.preset.series4")
		_preset_select.add_item("%s · %s" % [prefix, str(meta.get("title", ""))])
		_preset_select.set_item_metadata(_preset_select.item_count - 1, str(meta.get("id", "")))
	_preset_select.item_selected.connect(_on_preset_selected)
	row.add_child(_preset_select)
	_portrait_toggle = CheckButton.new()
	_portrait_toggle.text = L10n.ui("theme.preset.portrait")
	_portrait_toggle.tooltip_text = L10n.ui("theme.preset.portrait_tip")
	_portrait_toggle.toggled.connect(_on_portrait_toggled)
	row.add_child(_portrait_toggle)

	_preset_info = Label.new()
	_preset_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preset_info.clip_text = true
	_preset_info.custom_minimum_size = Vector2(0, 34)
	_preset_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_info.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_preset_info.add_theme_color_override("font_color", Color(0.70, 0.76, 0.84))
	add_child(_preset_info)

	_preset_palette = HBoxContainer.new()
	_preset_palette.add_theme_constant_override("separation", 6)
	_preset_palette.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(_preset_palette)
	_sync_preset_selection()
	_update_preset_info()

func _sync_preset_selection() -> void:
	if _preset_select == null:
		return
	_preset_syncing = true
	var target := 0
	for index in _preset_select.item_count:
		if str(_preset_select.get_item_metadata(index)) == _theme.preset_id:
			target = index
			break
	_preset_select.select(target)
	if _portrait_toggle != null:
		_portrait_toggle.set_pressed_no_signal(_theme.portrait_enabled)
	_preset_syncing = false

func _update_preset_info() -> void:
	if _preset_info == null:
		return
	var info := DialogueThemePresets.meta(_theme.preset_id)
	if info.is_empty():
		_preset_info.text = L10n.ui("theme.preset.custom_desc")
	else:
		_preset_info.text = "%s · %s\n%s" % [str(info.get("tag", "")), str(info.get("title", "")), str(info.get("description", ""))]
	if _preset_palette != null:
		for child in _preset_palette.get_children():
			_preset_palette.remove_child(child)
			child.queue_free()
		var colors := DialogueThemePresets.palette(_theme.preset_id)
		if colors.is_empty():
			colors = PackedStringArray([
				_theme.panel_bg_color.to_html(false),
				_theme.accent_color.to_html(false),
				_theme.text_color.to_html(false),
			])
		for hex in colors:
			var chip := HBoxContainer.new()
			chip.add_theme_constant_override("separation", 4)
			var swatch := ColorRect.new()
			swatch.color = Color.from_string(hex, Color.WHITE)
			swatch.custom_minimum_size = Vector2(14, 14)
			chip.add_child(swatch)
			var hex_label := Label.new()
			hex_label.text = "#" + str(hex).trim_prefix("#")
			hex_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
			hex_label.add_theme_color_override("font_color", Color(0.68, 0.73, 0.80))
			chip.add_child(hex_label)
			_preset_palette.add_child(chip)

func _on_preset_selected(index: int) -> void:
	if _preset_syncing or _preset_select == null:
		return
	var id := str(_preset_select.get_item_metadata(index))
	if id == _theme.preset_id:
		return
	if id == "":
		_theme = RpgEventStudioTheme.new()
	else:
		_theme = DialogueThemePresets.create(id)
	_sync_preset_selection()
	_update_preset_info()
	_build_controls()
	_apply_to_preview()
	_status.text = L10n.ui("theme.status.preset_selected")
	_play_preview()

func _on_portrait_toggled(pressed: bool) -> void:
	if _preset_syncing or _theme == null:
		return
	_theme.portrait_enabled = pressed
	_apply_to_preview()
	_status.text = L10n.ui("theme.status.unsaved")

func _on_preview_size_selected(index: int) -> void:
	if index < 0 or index >= PREVIEW_SIZES.size():
		return
	var size_pair: Array = PREVIEW_SIZES[index]
	_preview_resolution = Vector2i(int(size_pair[0]), int(size_pair[1]))
	if _preview_viewport != null:
		_preview_viewport.size = _preview_resolution
	if _preview_aspect != null:
		_preview_aspect.ratio = float(_preview_resolution.x) / float(_preview_resolution.y)
	if _preview != null:
		_preview.call_deferred("_schedule_height_update")

## 宽窗口左右分栏，窄窗口上下排列；避免固定 480px 预览把参数区挤成三行。
func _update_responsive_layout() -> void:
	if _body == null:
		return
	var available := get_parent_area_size().x
	if available <= 1.0:
		available = size.x
	var available_h := get_parent_area_size().y
	if available_h <= 1.0:
		available_h = size.y
	var viewport_h := get_viewport_rect().size.y
	if viewport_h > 1.0:
		available_h = minf(available_h, viewport_h)
	var compact := available_h < 700.0
	var side_by_side := available >= 540.0
	if _preview_toggle != null:
		_preview_toggle.visible = true
	if _preset_palette != null:
		_preset_palette.visible = available >= 860.0
	if _body.vertical == side_by_side:
		_body.vertical = not side_by_side
	if _preview_only:
		if _preview_side != null:
			_preview_side.visible = true
			_preview_side.custom_minimum_size = Vector2(0, 0)
			_preview_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if _settings_box != null:
			_settings_box.visible = false
		if _preview_panel != null:
			_preview_panel.custom_minimum_size = Vector2(240, 240)
	elif compact:
		if _preview_side != null:
			_preview_side.visible = false
		if _settings_box != null:
			_settings_box.visible = true
		_settings_scroll.custom_minimum_size = Vector2(0, 220)
	else:
		if _preview_side != null:
			_preview_side.visible = true
		if _settings_box != null:
			_settings_box.visible = true
		if side_by_side:
			_preview_side.custom_minimum_size = Vector2(300, 0)
			_preview_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_settings_scroll.custom_minimum_size = Vector2(260, 0)
			if _settings_box != null:
				_settings_box.custom_minimum_size = Vector2(280, 0)
			if _preview_panel != null:
				_preview_panel.custom_minimum_size = Vector2(280, 240)
		else:
			_preview_side.custom_minimum_size = Vector2(0, 300)
			_preview_side.size_flags_vertical = Control.SIZE_FILL
			_settings_scroll.custom_minimum_size = Vector2(0, 220)
			if _settings_box != null:
				_settings_box.custom_minimum_size = Vector2(0, 0)
			if _preview_panel != null:
				_preview_panel.custom_minimum_size = Vector2(240, 240)
	call_deferred("_sync_preview_size")

## 预览 SubViewport 使用固定虚拟分辨率，由 AspectRatioContainer 等比缩放。
func _sync_preview_size() -> void:
	if _preview == null or not is_instance_valid(_preview):
		return
	_preview.call("_schedule_height_update")

func _on_section_jump(index: int) -> void:
	if index < 0 or index >= _section_anchors.size():
		return
	_settings_scroll.ensure_control_visible(_section_anchors[index])

func _build_custom_mode() -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.95)
	style.border_color = Color(0.35, 0.40, 0.50, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	var heading := Label.new()
	heading.text = L10n.ui("theme.custom.title")
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(0.96, 0.85, 0.55))
	box.add_child(heading)

	var hint := Label.new()
	hint.text = L10n.ui("theme.custom.hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
	box.add_child(hint)

	var caps_text := _custom_capabilities_text()
	var caps := Label.new()
	caps.text = L10n.ui("theme.custom.caps", {"caps": caps_text})
	caps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caps.add_theme_font_size_override("font_size", 12)
	box.add_child(caps)

	var not_applied := Label.new()
	not_applied.text = L10n.ui("theme.custom.plugin_only")
	not_applied.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	not_applied.add_theme_font_size_override("font_size", UiFonts.NOTE)
	not_applied.add_theme_color_override("font_color", Color(0.75, 0.62, 0.50))
	box.add_child(not_applied)

func _custom_capabilities_text() -> String:
	var raw = ProjectSettings.get_setting(CAPS_SETTING, PackedStringArray())
	var caps: Array = []
	if raw is Array:
		caps = raw
	elif raw is PackedStringArray:
		for cap in raw:
			caps.append(cap)
	if caps.is_empty():
		return L10n.ui("theme.custom.no_caps")
	var parts: PackedStringArray = []
	for cap in caps:
		var key := "theme.cap." + str(cap)
		parts.append(L10n.ui(key) if L10n.has_key(key) else str(cap))
	return " / ".join(parts)

# ── 控件 ──────────────────────────────────────────────────

func _build_controls() -> void:
	_loading = true
	for child in _controls_box.get_children():
		_controls_box.remove_child(child)
		child.queue_free()
	_section_anchors.clear()
	if _section_jump != null:
		_section_jump.clear()
	for section_index in SECTIONS.size():
		var section: Dictionary = SECTIONS[section_index]
		if section_index > 0:
			_controls_box.add_child(HSeparator.new())
		var section_box := VBoxContainer.new()
		section_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_box.add_theme_constant_override("separation", 2)
		_controls_box.add_child(section_box)
		var heading := Label.new()
		heading.text = L10n.ui(str(section.get("title", "")))
		heading.add_theme_font_size_override("font_size", 13)
		heading.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
		section_box.add_child(heading)
		for field in section.get("fields", []):
			section_box.add_child(_make_field(field))
		_section_anchors.append(section_box)
		if _section_jump != null:
			_section_jump.add_item(heading.text, section_index)
	if _section_jump != null and _section_jump.item_count > 0:
		_section_jump.select(0)
	_loading = false

func _make_field(field: Dictionary) -> Control:
	var prop := str(field.get("prop", ""))
	var kind := str(field.get("type", "text"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = L10n.ui(str(field.get("label", "")))
	label.custom_minimum_size = Vector2(190, 0)
	label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	row.add_child(label)

	match kind:
		"color":
			var picker := ColorPickerButton.new()
			picker.edit_alpha = true
			picker.color = _theme.get(prop)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			picker.color_changed.connect(func(value: Color) -> void:
				_set_prop(prop, value)
			)
			row.add_child(picker)
		"int", "float":
			var spin := SpinBox.new()
			spin.min_value = float(field.get("min", 0))
			spin.max_value = float(field.get("max", 100))
			spin.step = float(field.get("step", 1))
			spin.allow_greater = false
			spin.allow_lesser = false
			spin.value = float(_theme.get(prop))
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(func(value: float) -> void:
				_set_prop(prop, int(value) if kind == "int" else value)
			)
			row.add_child(spin)
		"bool":
			var check := CheckButton.new()
			check.button_pressed = bool(_theme.get(prop))
			check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			check.toggled.connect(func(value: bool) -> void:
				_set_prop(prop, value)
			)
			row.add_child(check)
		"option":
			var opt := OptionButton.new()
			opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var values: Array = field.get("values", [])
			var labels: Array = field.get("options", values)
			for i in values.size():
				var text := str(labels[i]) if i < labels.size() else str(values[i])
				opt.add_item(L10n.ui(text) if L10n.has_key(text) else text)
				opt.set_item_metadata(i, str(values[i]))
			var current := str(_theme.get(prop))
			for i in values.size():
				if str(values[i]) == current:
					opt.select(i)
					break
			opt.item_selected.connect(func(index: int) -> void:
				_set_prop(prop, str(opt.get_item_metadata(index)))
			)
			row.add_child(opt)
		"vec2":
			var vec := _theme.get(prop) as Vector2
			var spin_x := SpinBox.new()
			spin_x.min_value = -200.0
			spin_x.max_value = 200.0
			spin_x.step = 1.0
			spin_x.value = vec.x
			spin_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var spin_y := SpinBox.new()
			spin_y.min_value = -200.0
			spin_y.max_value = 200.0
			spin_y.step = 1.0
			spin_y.value = vec.y
			spin_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var apply := func(_v: float) -> void:
				_set_prop(prop, Vector2(spin_x.value, spin_y.value))
			spin_x.value_changed.connect(apply)
			spin_y.value_changed.connect(apply)
			row.add_child(spin_x)
			row.add_child(spin_y)
		"font":
			_font_edit = LineEdit.new()
			_font_edit.text = str(_theme.get(prop))
			_font_edit.placeholder_text = L10n.ui("theme.font.default")
			_font_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_font_edit.text_changed.connect(func(value: String) -> void:
				_set_prop(prop, value)
			)
			row.add_child(_font_edit)
			var pick := Button.new()
			pick.text = L10n.ui("theme.font.pick")
			pick.pressed.connect(_open_font_dialog)
			row.add_child(pick)
		_:
			var edit := LineEdit.new()
			edit.text = str(_theme.get(prop))
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text_changed.connect(func(value: String) -> void:
				_set_prop(prop, value)
			)
			row.add_child(edit)
	return row

func _open_font_dialog() -> void:
	if _font_dialog == null:
		_font_dialog = FileDialog.new()
		_font_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_font_dialog.access = FileDialog.ACCESS_RESOURCES
		_font_dialog.filters = PackedStringArray(["*.ttf, *.otf ; Fonts"])
		_font_dialog.file_selected.connect(func(path: String) -> void:
			if _font_edit != null:
				_font_edit.text = path
			_set_prop("font_path", path)
		)
		get_tree().root.add_child(_font_dialog)
	_font_dialog.popup_centered_ratio(0.55)

func _set_prop(prop: String, value: Variant) -> void:
	if _loading or _theme == null:
		return
	_theme.set(prop, value)
	if prop == "font_path" or prop == "font_style" or prop == "body_font_flavor":
		_theme.invalidate_font_cache()
	_apply_to_preview()
	_status.text = L10n.ui("theme.status.unsaved")
	if prop == "portrait_enabled":
		_sync_preset_selection()

# ── 预览 / 保存 ───────────────────────────────────────────

func _apply_to_preview() -> void:
	if _preview == null or _theme == null:
		return
	if _preview_backdrop != null:
		_preview_backdrop.set("accent", _theme.accent_color)
		_preview_backdrop.queue_redraw()
	_preview.set_dialogue_theme(_theme)
	if _theme.portrait_enabled and _sample_portrait != null:
		_preview.set_dialogue_portrait(_sample_portrait)
	else:
		_preview.clear_dialogue_portrait()

func _play_preview() -> void:
	if _preview == null or _theme == null:
		return
	_apply_to_preview()
	_preview.close_all()
	var sample_index := _sample.selected if _sample != null else 0
	match sample_index:
		0:
			_preview.show_text("旁白", SAMPLE_PLAIN)
		1:
			_preview.show_text("旁白", SAMPLE_BBCODE)
		2:
			_preview.show_text("旁白", SAMPLE_MULTILINE)
		3:
			_preview.show_choices("请选择处理方式", SAMPLE_CHOICES)

func _save_theme() -> void:
	if _theme == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui"))
	var error := ResourceSaver.save(_theme, theme_path)
	if error != OK:
		_status.text = L10n.ui("theme.status.save_failed", {"code": error})
		return
	var runtime := get_node_or_null("/root/RPGEventStudio")
	if theme_path == THEME_PATH and runtime != null and runtime.has_method("reload_dialogue_theme"):
		_theme = runtime.call("reload_dialogue_theme")
	_sync_preset_selection()
	_update_preset_info()
	_apply_to_preview()
	_status.text = L10n.ui("theme.status.saved")
	_path_label.text = L10n.ui("theme.path", {"path": theme_path})

func _reload_theme() -> void:
	_theme = _load_theme()
	_sync_preset_selection()
	_update_preset_info()
	_build_controls()
	_play_preview()
	var runtime := get_node_or_null("/root/RPGEventStudio")
	if theme_path == THEME_PATH and runtime != null and runtime.has_method("apply_dialogue_theme"):
		runtime.call("apply_dialogue_theme", _theme)
	_status.text = L10n.ui("theme.status.reloaded")

func _restore_defaults() -> void:
	_theme = DialogueThemePresets.factory_defaults(_theme)
	_sync_preset_selection()
	_update_preset_info()
	_build_controls()
	_save_theme()
	_play_preview()
	_status.text = L10n.ui("theme.status.restored")

func _load_theme() -> RpgEventStudioTheme:
	if ResourceLoader.exists(theme_path):
		var loaded := load(theme_path)
		if loaded is RpgEventStudioTheme:
			return (loaded as RpgEventStudioTheme).duplicate(true)
	return RpgEventStudioTheme.new()


## 预览背景：只属于编辑器预览，不参与运行时绘制。给对话框一个可读的
## 场景底色，避免主题页里只有黑底 + UI，看不出边框和阴影的层次。
class PreviewBackdrop extends Control:
	var accent := Color(0.85, 0.75, 0.55)

	func _draw() -> void:
		var steps := 64
		for i in steps:
			var t := float(i) / float(steps - 1)
			var c := Color(0.12, 0.13, 0.17).lerp(Color(0.035, 0.04, 0.055), t)
			draw_rect(Rect2(0, size.y * t, size.x, size.y / float(steps) + 1.0), c, true)
		var cx := size.x * 0.18
		var cy := size.y * 0.12
		for i in 8:
			var r := size.x * (0.08 + i * 0.035)
			draw_circle(Vector2(cx, cy), r, Color(accent, 0.012 + i * 0.004))
		for i in 8:
			draw_rect(Rect2(i * 6, i * 6, size.x - i * 12, size.y - i * 12), Color(0, 0, 0, 0.025), false, 12.0)
