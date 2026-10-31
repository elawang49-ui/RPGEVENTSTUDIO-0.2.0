@tool
class_name DialogueThemeView
extends VBoxContainer
## UI 主题定制页（编辑器主屏内的一个标签页）。
##
## 只修改插件默认 DialoguePresenter / 交互提示的视觉；游戏注入自定义 presenter 时，
## 通过项目设置 rpg_event_studio/ui_mode="custom" 声明，本页只显示能力说明，不伪造配置。

const THEME_PATH := "res://ui/rpgeventstudio_theme.tres"
const UI_MODE_SETTING := "rpg_event_studio/ui_mode"
const CAPS_SETTING := "rpg_event_studio/custom_ui_capabilities"

const SAMPLE_PLAIN := "这是一段普通文本预览。\n可以检查颜色、字号、位置与内边距。"
const SAMPLE_BBCODE := "[b]重点文字[/b]\n[color=#FFD700]关键线索[/color] [font_size=26]大字号[/font_size]\n[center]居中文字[/center]"
const SAMPLE_MULTILINE := "第一行：多行文本。\n第二行：中文标点，换行。\n第三行：用于检查行距、内边距和位置。"
const SAMPLE_CHOICES := ["A. 删除异常记录，标记为已修复。", "B. 保留记录，申请进一步调查。", "C. 先完成修复，同时备份异常记录。"]

const SECTIONS := [
	{"title": "theme.section.panel", "fields": [
		{"prop": "panel_bg_color", "label": "theme.panel.bg", "type": "color"},
		{"prop": "panel_border_color", "label": "theme.panel.border", "type": "color"},
		{"prop": "panel_border_width", "label": "theme.panel.border_width", "type": "int", "min": 0, "max": 12, "step": 1},
		{"prop": "panel_corner_radius", "label": "theme.panel.corner", "type": "int", "min": 0, "max": 40, "step": 1},
		{"prop": "panel_shadow_color", "label": "theme.panel.shadow", "type": "color"},
		{"prop": "panel_shadow_size", "label": "theme.panel.shadow_size", "type": "int", "min": 0, "max": 40, "step": 1},
		{"prop": "panel_left", "label": "theme.panel.left", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "panel_right", "label": "theme.panel.right", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "panel_top", "label": "theme.panel.top", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "panel_bottom", "label": "theme.panel.bottom", "type": "float", "min": 0, "max": 1, "step": 0.01},
		{"prop": "content_margin_left", "label": "theme.panel.margin_left", "type": "int", "min": 0, "max": 80, "step": 1},
		{"prop": "content_margin_right", "label": "theme.panel.margin_right", "type": "int", "min": 0, "max": 80, "step": 1},
		{"prop": "content_margin_top", "label": "theme.panel.margin_top", "type": "int", "min": 0, "max": 80, "step": 1},
		{"prop": "content_margin_bottom", "label": "theme.panel.margin_bottom", "type": "int", "min": 0, "max": 80, "step": 1},
		{"prop": "text_min_height", "label": "theme.text.min_height", "type": "int", "min": 32, "max": 300, "step": 1},
	]},
	{"title": "theme.section.text", "fields": [
		{"prop": "font_path", "label": "theme.font", "type": "font"},
		{"prop": "font_size", "label": "theme.font_size", "type": "int", "min": 8, "max": 96, "step": 1},
		{"prop": "text_color", "label": "theme.text.color", "type": "color"},
		{"prop": "text_font_size", "label": "theme.text.size", "type": "int", "min": 8, "max": 96, "step": 1},
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
var _preview_container: SubViewportContainer
var _preview_panel: PanelContainer
var _preview_side: VBoxContainer
var _body: BoxContainer
var _settings_scroll: ScrollContainer
var _settings_box: VBoxContainer
var _section_jump: OptionButton
var _section_anchors: Array[Control] = []
var _last_preview_size := Vector2i.ZERO
var _preview_toggle: Button
var _preview_only := false
var _sample: OptionButton
var _controls_box: VBoxContainer
var _status: Label
var _path_label: Label
var _font_edit: LineEdit
var _font_dialog: FileDialog
var _loading := false
var _custom_mode := false

func _ready() -> void:
	_custom_mode = str(ProjectSettings.get_setting(UI_MODE_SETTING, "default")) == "custom"
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

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 固定预览高度：编辑器主屏本身可能很高，预览若跟着拉伸，对话框会落到可视区外。
	preview_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_panel.custom_minimum_size = Vector2(320, 480)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.08, 0.09, 0.12)
	preview_style.set_corner_radius_all(4)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	preview_side.add_child(preview_panel)
	_preview_panel = preview_panel
	var container := SubViewportContainer.new()
	container.stretch = false
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.resized.connect(_sync_preview_size)
	visibility_changed.connect(_sync_preview_size)
	preview_panel.add_child(container)
	_preview_container = container
	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(320, 180)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_preview_viewport)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_viewport.add_child(bg)
	_preview = DialoguePresenter.new()
	_preview.name = "ThemePreview"
	_preview.editor_preview = true
	_preview.input = null
	_preview.blocked = true
	_preview_viewport.add_child(_preview)

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
	var preview_h := clampf(available_h - 280.0, 240.0, 480.0)
	var compact := available_h < 700.0
	var side_by_side := available >= 540.0
	if _preview_toggle != null:
		_preview_toggle.visible = compact
	if _body.vertical == side_by_side:
		_body.vertical = not side_by_side
	if compact:
		# 低高度下预览/参数二选一，避免两者都被压扁；按钮可切换。
		if _preview_side != null:
			_preview_side.visible = _preview_only
		if _settings_box != null:
			_settings_box.visible = not _preview_only
		if _preview_only:
			if _preview_panel != null:
				_preview_panel.custom_minimum_size = Vector2(240, clampf(available_h - 230.0, 240.0, 620.0))
			_preview_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			_settings_scroll.custom_minimum_size = Vector2(0, 220)
	else:
		if _preview_side != null:
			_preview_side.visible = true
		if _settings_box != null:
			_settings_box.visible = true
		if side_by_side:
			_preview_side.custom_minimum_size = Vector2(260, 0)
			_preview_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_settings_scroll.custom_minimum_size = Vector2(240, 0)
			if _settings_box != null:
				_settings_box.custom_minimum_size = Vector2(260, 0)
			if _preview_panel != null:
				_preview_panel.custom_minimum_size = Vector2(240, preview_h)
		else:
			_preview_side.custom_minimum_size = Vector2(0, 300)
			_preview_side.size_flags_vertical = Control.SIZE_FILL
			_settings_scroll.custom_minimum_size = Vector2(0, 220)
			if _settings_box != null:
				_settings_box.custom_minimum_size = Vector2(0, 0)
			if _preview_panel != null:
				_preview_panel.custom_minimum_size = Vector2(320, 300)
	call_deferred("_sync_preview_size")

## 预览 SubViewport 跟随真实容器尺寸，避免固定 960×540 被拉伸成灰边/错比例。
func _sync_preview_size() -> void:
	if _preview_container == null or _preview_viewport == null:
		return
	var container_size := _preview_container.size
	if container_size.x < 1.0 or container_size.y < 1.0:
		return
	var target := Vector2i(maxi(1, int(container_size.x)), maxi(1, int(container_size.y)))
	if target == _last_preview_size:
		return
	_last_preview_size = target
	if container_size.x > 2.0 and container_size.y > 2.0:
		_preview_viewport.size = target
	if _preview != null and is_instance_valid(_preview):
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
	if _preview != null:
		_preview.set_dialogue_theme(_theme)
	_status.text = L10n.ui("theme.status.unsaved")

# ── 预览 / 保存 ───────────────────────────────────────────

func _play_preview() -> void:
	if _preview == null or _theme == null:
		return
	_preview.set_dialogue_theme(_theme)
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
	if _preview != null:
		_preview.set_dialogue_theme(_theme)
	_status.text = L10n.ui("theme.status.saved")
	_path_label.text = L10n.ui("theme.path", {"path": theme_path})

func _reload_theme() -> void:
	_theme = _load_theme()
	_build_controls()
	_play_preview()
	var runtime := get_node_or_null("/root/RPGEventStudio")
	if theme_path == THEME_PATH and runtime != null and runtime.has_method("apply_dialogue_theme"):
		runtime.call("apply_dialogue_theme", _theme)
	_status.text = L10n.ui("theme.status.reloaded")

func _restore_defaults() -> void:
	_theme = RpgEventStudioTheme.new()
	_build_controls()
	_save_theme()
	_status.text = L10n.ui("theme.status.restored")

func _load_theme() -> RpgEventStudioTheme:
	if ResourceLoader.exists(theme_path):
		var loaded := load(theme_path)
		if loaded is RpgEventStudioTheme:
			return loaded
	return RpgEventStudioTheme.new()
