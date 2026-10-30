class_name InputSettingsPanel
extends CanvasLayer
## 轻量级按键设置面板：键盘 / 鼠标 / 手柄分开显示、分别改键、冲突提示、恢复默认、切换语言。
## 打开方式：F1（可改键），或调用 RPGEventStudio.open_input_settings()。

signal locale_changed(locale: String)

var input: InputService
## 当前展示层：默认是 DialoguePresenter，也可能是游戏注入的展示层。
## 只有实现了 blocked 属性的实现才会被暂停。
var presenter

var _root: Control
var _title: Label
var _hint: Label
var _status: Label
var _rows: VBoxContainer
var _close_button: Button
var _restore_button: Button
var _lang_label: Label
var _lang_option: OptionButton
var _conflict_row: HBoxContainer
var _conflict_label: Label
var _conflict_bind: Button
var _conflict_cancel: Button

var _listening := false
var _listen_action := ""
var _listen_device := ""
var _guard_until := 0
var _pending_event: InputEvent = null
var _pending_action := ""

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.99)
	style.border_color = Color(0.80, 0.70, 0.42, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	return style

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	close()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "InputSettingsRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 560)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 20)
	header.add_child(_title)

	_lang_label = Label.new()
	header.add_child(_lang_label)

	_lang_option = OptionButton.new()
	_lang_option.add_item("简体中文")
	_lang_option.add_item("English")
	_lang_option.item_selected.connect(_on_language_selected)
	header.add_child(_lang_option)

	_close_button = Button.new()
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", RuntimeFonts.NOTE)
	_hint.add_theme_color_override("font_color", Color(0.78, 0.80, 0.86))
	column.add_child(_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	column.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)

	_conflict_row = HBoxContainer.new()
	_conflict_row.add_theme_constant_override("separation", 8)
	_conflict_row.visible = false
	column.add_child(_conflict_row)

	_conflict_label = Label.new()
	_conflict_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conflict_row.add_child(_conflict_label)

	_conflict_bind = Button.new()
	_conflict_bind.pressed.connect(_on_conflict_bind_anyway)
	_conflict_row.add_child(_conflict_bind)

	_conflict_cancel = Button.new()
	_conflict_cancel.pressed.connect(_on_conflict_cancel)
	_conflict_row.add_child(_conflict_cancel)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)

	_restore_button = Button.new()
	_restore_button.pressed.connect(_on_restore_defaults)
	footer.add_child(_restore_button)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_font_size_override("font_size", RuntimeFonts.NOTE)
	_status.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))
	footer.add_child(_status)

# ── 开关 ─────────────────────────────────────────────────

func open() -> void:
	visible = true
	_listening = false
	_hint.text = L10n.game("input.press_hint")
	_status.text = ""
	_conflict_row.visible = false
	_set_presenter_blocked(true)
	_sync_language_option()
	_refresh_texts()
	_rebuild_rows()
	_lang_option.grab_focus()

func close() -> void:
	visible = false
	_listening = false
	_listen_action = ""
	_conflict_row.visible = false
	_status.text = ""
	_set_presenter_blocked(false)

## 自定义展示层不一定实现 blocked；没有这个属性时保持原样即可。
func _set_presenter_blocked(value: bool) -> void:
	if presenter == null or not is_instance_valid(presenter):
		return
	if "blocked" in presenter:
		presenter.set("blocked", value)

func is_open() -> bool:
	return visible

func is_listening() -> bool:
	return _listening

# ── 文本 ─────────────────────────────────────────────────

func _refresh_texts() -> void:
	_title.text = L10n.game("input.title")
	_close_button.text = L10n.game("input.close")
	_restore_button.text = L10n.game("input.restore_defaults")
	_lang_label.text = L10n.game("input.language")
	_conflict_bind.text = L10n.game("input.bind_anyway")
	_conflict_cancel.text = L10n.game("input.cancel")
	_lang_option.set_item_text(0, "简体中文")
	_lang_option.set_item_text(1, "English")

func _sync_language_option() -> void:
	_lang_option.selected = 0 if L10n.get_game_locale() == "zh_CN" else 1

func _on_language_selected(index: int) -> void:
	var locale := "zh_CN" if index == 0 else "en"
	L10n.set_game_locale(locale)
	_refresh_texts()
	_rebuild_rows()
	locale_changed.emit(locale)

# ── 列表 ─────────────────────────────────────────────────

func _rebuild_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	for action in InputService.action_ids():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		_rows.add_child(box)

		var title := Label.new()
		title.text = L10n.game(InputService.action_label_key(action))
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66))
		box.add_child(title)

		for device in ["keyboard", "mouse", "gamepad"]:
			box.add_child(_make_device_row(action, device))

func _make_device_row(action: String, device: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var device_label := Label.new()
	device_label.text = L10n.game("input.device." + device)
	device_label.custom_minimum_size = Vector2(48, 0)
	device_label.add_theme_font_size_override("font_size", RuntimeFonts.NOTE)
	device_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.8))
	row.add_child(device_label)

	var value_label := Label.new()
	value_label.text = _describe(action, device)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.add_theme_font_size_override("font_size", RuntimeFonts.BODY)
	row.add_child(value_label)

	var change := Button.new()
	change.text = L10n.game("input.rebind")
	change.disabled = _listening
	change.pressed.connect(_start_listen.bind(action, device))
	row.add_child(change)

	var remove := Button.new()
	remove.text = L10n.game("input.remove_binding")
	remove.disabled = _listening or _describe(action, device) == L10n.game("input.unbound")
	remove.pressed.connect(_on_remove_binding.bind(action, device))
	row.add_child(remove)

	return row

func _describe(action: String, device: String) -> String:
	var described: Dictionary = input.describe(action)
	var items: Array = described.get(device, [])
	if items.is_empty():
		return L10n.game("input.unbound")
	var texts := PackedStringArray()
	for item in items:
		texts.append(str(item))
	return " / ".join(texts)

# ── 改键 ─────────────────────────────────────────────────

func _start_listen(action: String, device: String) -> void:
	_listen_action = action
	_listen_device = device
	_listening = true
	_guard_until = Time.get_ticks_msec() + 250
	_conflict_row.visible = false
	_status.text = ""
	_hint.text = L10n.game("input.press_hint")
	_rebuild_rows()

func _stop_listen() -> void:
	_listening = false
	_listen_action = ""
	_listen_device = ""
	_pending_event = null
	_pending_action = ""
	_conflict_row.visible = false
	_hint.text = L10n.game("input.press_hint")
	_rebuild_rows()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if not _listening:
		if event.is_action_pressed(InputService.ACTION_CANCEL) and not _confirm_visible():
			close()
			_consume()
		return

	if Time.get_ticks_msec() < _guard_until:
		return

	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
			_stop_listen()
			_consume()
			return
		_try_bind(key)
		return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			_try_bind(mouse)
		return

	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.pressed:
			_try_bind(button)
		return

	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) > 0.6:
			var axis := InputEventJoypadMotion.new()
			axis.axis = motion.axis
			axis.axis_value = signf(motion.axis_value)
			_try_bind(axis)

func _try_bind(event: InputEvent) -> void:
	if _listen_action == "":
		return
	var conflict := input.find_conflict(_listen_action, event)
	if conflict != "":
		_pending_event = event.duplicate()
		_pending_action = _listen_action
		_conflict_label.text = L10n.game("input.conflict", {
			"action": L10n.game(InputService.action_label_key(conflict)),
		})
		_conflict_row.visible = true
		_hint.text = L10n.game("input.status.conflict_hint")
		_consume()
		return
	_apply_bind(_listen_action, event)
	_consume()

func _apply_bind(action: String, event: InputEvent, allow_share: bool = false) -> void:
	var result := input.rebind(action, event, allow_share)
	if bool(result.get("ok", false)):
		_stop_listen()
		_status.text = L10n.game("input.saved")
	else:
		var conflict := str(result.get("conflict", ""))
		_conflict_label.text = L10n.game("input.conflict", {
			"action": L10n.game(InputService.action_label_key(conflict)),
		})
		_conflict_row.visible = true

func _on_conflict_bind_anyway() -> void:
	if _pending_event == null or _pending_action == "":
		return
	_apply_bind(_pending_action, _pending_event, true)

func _on_conflict_cancel() -> void:
	_pending_event = null
	_pending_action = ""
	_conflict_row.visible = false
	_stop_listen()

func _on_remove_binding(action: String, device: String) -> void:
	input.clear_device(action, device)
	_status.text = L10n.game("input.saved")
	_rebuild_rows()

func _on_restore_defaults() -> void:
	input.restore_defaults()
	_status.text = L10n.game("input.saved")
	_rebuild_rows()

func _confirm_visible() -> bool:
	return _conflict_row != null and _conflict_row.visible

func _consume() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
