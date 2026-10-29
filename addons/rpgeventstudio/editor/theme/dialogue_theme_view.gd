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
	_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_label.add_theme_font_size_override("font_size", 11)
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
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.65, 0.82, 0.65))
	footer.add_child(_status)

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)

	var preview_side := VBoxContainer.new()
	preview_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_side.size_flags_vertical = Control.SIZE_FILL
	preview_side.custom_minimum_size = Vector2(0, 480)
	body.add_child(preview_side)

	var preview_title := Label.new()
	preview_title.text = L10n.ui("theme.preview")
	preview_title.add_theme_font_size_override("font_size", 12)
	preview_side.add_child(preview_title)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.custom_minimum_size = Vector2(480, 420)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.08, 0.09, 0.12)
	preview_style.set_corner_radius_all(4)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	preview_side.add_child(preview_panel)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(container)
	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(960, 540)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_preview_viewport)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.size = Vector2(960, 540)
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

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_controls_box = VBoxContainer.new()
	_controls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_controls_box)

	_build_controls()
	_play_preview.call_deferred()

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
	not_applied.add_theme_font_size_override("font_size", 11)
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
	for section in SECTIONS:
		var heading := Label.new()
		heading.text = L10n.ui(str(section.get("title", "")))
		heading.add_theme_font_size_override("font_size", 13)
		heading.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
		var spacing := Control.new()
		spacing.custom_minimum_size = Vector2(0, 4)
		_controls_box.add_child(spacing)
		_controls_box.add_child(heading)
		for field in section.get("fields", []):
			_controls_box.add_child(_make_field(field))
	_loading = false

func _make_field(field: Dictionary) -> Control:
	var prop := str(field.get("prop", ""))
	var kind := str(field.get("type", "text"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = L10n.ui(str(field.get("label", "")))
	label.custom_minimum_size = Vector2(190, 0)
	label.add_theme_font_size_override("font_size", 11)
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
