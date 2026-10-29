class_name DialoguePresenter
extends CanvasLayer
## 运行期对话界面：底部对话框 + 选项列表。
## 键盘 / 鼠标 / 手柄都通过 InputService 的动作触发，可在按键设置里改键。

var input: InputService
var blocked: bool = false

var _root: Control
var _fade_rect: ColorRect
var _fade_tween: Tween
var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _hint_label: Label
var _choices_panel: PanelContainer
var _choices_box: VBoxContainer

var _typing := false
var _waiting_confirm := false
var _text_done := true
var _reveal := 0.0
var _reveal_total := 0
var _speed := 42.0
var _auto_deadline := 0
var _input_cooldown := 0
var _mouse_click := false
var _choice_result := -1
var _choice_index := -1
var _choice_buttons: Array[Button] = []

## 调试用：最近显示过的文字（集成测试与问题排查会读它）
var last_text := ""
var shown_texts: PackedStringArray = []

func _ready() -> void:
	layer = 20
	_build_ui()
	_panel.hide()
	_choices_panel.hide()

func _build_ui() -> void:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
		"Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "sans-serif",
	])
	theme.default_font = font
	theme.default_font_size = 18

	_root = Control.new()
	_root.name = "RPGEventStudioUI"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.modulate.a = 0.0
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade_rect)

	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.anchor_left = 0.06
	_panel.anchor_right = 0.94
	_panel.anchor_top = 0.60
	_panel.anchor_bottom = 0.93
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 21)
	_name_label.add_theme_color_override("font_color", Color(0.96, 0.85, 0.55))
	column.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = false
	_text_label.scroll_active = false
	_text_label.custom_minimum_size = Vector2(0, 96)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	_text_label.add_theme_color_override("default_color", Color(0.94, 0.94, 0.96))
	column.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
	column.add_child(_hint_label)

	_choices_panel = PanelContainer.new()
	_choices_panel.name = "ChoicePanel"
	_choices_panel.anchor_left = 0.60
	_choices_panel.anchor_right = 0.94
	_choices_panel.anchor_top = 0.26
	_choices_panel.anchor_bottom = 0.58
	_choices_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(_choices_panel)

	var choice_margin := MarginContainer.new()
	choice_margin.add_theme_constant_override("margin_left", 14)
	choice_margin.add_theme_constant_override("margin_right", 14)
	choice_margin.add_theme_constant_override("margin_top", 14)
	choice_margin.add_theme_constant_override("margin_bottom", 14)
	_choices_panel.add_child(choice_margin)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 8)
	choice_margin.add_child(_choices_box)

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.10, 0.93)
	style.border_color = Color(0.80, 0.70, 0.42, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	return style

# ── 显示文字 ─────────────────────────────────────────────

func show_text(speaker: String, text: String, auto_advance: float = 0.0) -> void:
	last_text = text
	shown_texts.append(text)
	_name_label.text = speaker
	_name_label.visible = speaker.strip_edges() != ""
	_text_label.text = text
	_text_label.visible_characters = 0
	_hint_label.visible = false

	_reveal = 0.0
	_reveal_total = text.length()
	_typing = _reveal_total > 0
	_waiting_confirm = false
	_text_done = false
	_auto_deadline = 0
	_input_cooldown = Time.get_ticks_msec() + 160
	_clear_choices()

	_panel.show()
	if not _typing:
		_finish_typing()
	elif auto_advance > 0.0:
		_auto_deadline = Time.get_ticks_msec() + int(auto_advance * 1000.0)

func is_text_finished() -> bool:
	return _text_done

## 淡入淡出：返回 tween（duration 为 0 时返回 null）。
func fade_to(alpha: float, duration: float) -> Tween:
	if _fade_rect == null:
		return null
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if duration <= 0.01:
		_fade_rect.modulate.a = alpha
		return null
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "modulate:a", alpha, duration)
	return _fade_tween

func clear_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _fade_rect != null:
		_fade_rect.modulate.a = 0.0

func hide_text() -> void:
	_panel.hide()
	_text_done = true
	_waiting_confirm = false
	_typing = false

# ── 显示选项 ─────────────────────────────────────────────

func show_choices(prompt: String, options: Array) -> void:
	show_text("", prompt, 0.0)
	_typing = false
	_text_label.visible_characters = -1
	_waiting_confirm = false
	_text_done = false
	_choice_result = -1

	_clear_choice_buttons()
	for index in options.size():
		var button := Button.new()
		button.text = str(options[index])
		button.custom_minimum_size = Vector2(0, 40)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# 自己管理选中项：不依赖 ui_up/ui_down，这样改键后依然有效
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.pressed.connect(_on_choice_pressed.bind(index))
		_choices_box.add_child(button)
		_choice_buttons.append(button)

	_choices_panel.show()
	_hint_label.visible = true
	_hint_label.text = L10n.game("game.choice_hint")
	_choice_index = 0
	_update_choice_highlight()

func get_choice() -> int:
	return _choice_result

func _on_choice_pressed(index: int) -> void:
	_choice_result = index
	_choices_panel.hide()
	_clear_choice_buttons()
	_text_done = true

func _move_choice(delta: int) -> void:
	if _choice_buttons.is_empty():
		return
	_choice_index = wrapi(_choice_index + delta, 0, _choice_buttons.size())
	_update_choice_highlight()

func _update_choice_highlight() -> void:
	for index in _choice_buttons.size():
		_choice_buttons[index].button_pressed = index == _choice_index

# ── 关闭 ─────────────────────────────────────────────────

func close_all() -> void:
	if _panel != null:
		_panel.hide()
	if _choices_panel != null:
		_choices_panel.hide()
	_clear_choice_buttons()
	_typing = false
	_waiting_confirm = false
	_text_done = true
	_choice_result = -1
	_choice_index = -1

# ── 每帧 ─────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		_mouse_click = false
		return

	var now := Time.get_ticks_msec()

	if _typing:
		_reveal += _speed * delta
		_text_label.visible_characters = int(_reveal)
		if _reveal >= float(_reveal_total):
			_finish_typing()
		_mouse_click = false
		return

	if blocked:
		_mouse_click = false
		return

	if _choices_panel.visible:
		if _pressed(InputService.ACTION_CHOICE_UP):
			_move_choice(-1)
		elif _pressed(InputService.ACTION_CHOICE_DOWN):
			_move_choice(1)
		elif now >= _input_cooldown and _pressed(InputService.ACTION_CONFIRM) and not _mouse_click:
			# 鼠标点击由按钮自己处理，这里只处理键盘与手柄
			_on_choice_pressed(_choice_index)
	elif _waiting_confirm:
		if _auto_deadline > 0 and now >= _auto_deadline:
			_dismiss_text()
		elif now >= _input_cooldown and (_pressed(InputService.ACTION_CONFIRM) or _mouse_click):
			_dismiss_text()

	_mouse_click = false

func _finish_typing() -> void:
	_typing = false
	_text_label.visible_characters = -1
	_waiting_confirm = true
	_hint_label.visible = true
	_hint_label.text = L10n.game("game.advance_hint")

func _dismiss_text() -> void:
	_waiting_confirm = false
	_text_done = true
	_panel.hide()

func _pressed(action: StringName) -> bool:
	if input == null:
		return false
	return input.is_action_just_pressed(action)

func _input(event: InputEvent) -> void:
	# 记录鼠标左键按下沿（即使点在 UI 上也算），供对话推进判断
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_mouse_click = true

# ── 内部 ─────────────────────────────────────────────────

func _clear_choices() -> void:
	_choices_panel.hide()
	_clear_choice_buttons()
	_choice_result = -1
	_choice_index = -1

func _clear_choice_buttons() -> void:
	if _choices_box == null:
		return
	for child in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()
	_choice_buttons.clear()
