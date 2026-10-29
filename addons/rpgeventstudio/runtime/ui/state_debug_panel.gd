class_name StateDebugPanel
extends CanvasLayer
## 游戏内状态调试面板（F2）：看当前状态、未登记状态、以及「事件为什么没执行」。
## 显示名与编辑器里完全一致——这里看到的「办公室日记已调查」就是编辑器里选的那条状态。

var runtime: Node

var _root: Control
var _body: VBoxContainer
var _refresh_left := 0.0

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	close_panel()

func _build() -> void:
	_root = Control.new()
	_root.name = "StateDebugRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 560)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.99)
	style.border_color = Color(0.55, 0.75, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
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
	column.add_child(header)

	var title := Label.new()
	title.text = L10n.game("debug.title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 19)
	header.add_child(title)

	var close := Button.new()
	close.text = L10n.game("debug.close")
	close.pressed.connect(close_panel)
	header.add_child(close)

	var hint := Label.new()
	hint.text = L10n.game("debug.hint")
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	column.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	scroll.add_child(_body)

func open() -> void:
	visible = true
	refresh()

func close_panel() -> void:
	visible = false

func is_open() -> bool:
	return visible

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.25
		refresh()

func refresh() -> void:
	if _body == null or runtime == null:
		return
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	var state: StateStore = runtime.get("state")
	if state == null:
		return

	# 关卡与阶段
	_add_line(L10n.game("debug.level", {"level": str(runtime.get("current_level"))}), Color(0.8, 0.85, 0.95), 13)
	var stage := str(runtime.call("current_stage")) if runtime.has_method("current_stage") else ""
	var stage_label := L10n.game("stage." + stage) if stage != "" else "—"
	if stage_label.begins_with("stage."):
		stage_label = stage
	_add_line(L10n.game("debug.stage", {"stage": stage_label}), Color(0.8, 0.85, 0.95), 13)

	# 已登记状态
	_add_section(L10n.game("debug.section.states"))
	var catalog := StateCatalogStore.catalog()
	var known := {}
	for group in catalog.grouped():
		_add_line(str(group["category"]), Color(0.75, 0.78, 0.86), 12)
		for item in group["items"]:
			var definition: StateDefinition = item
			known[definition.key] = true
			var value: Variant = state.get_value(definition.key, definition.default_of_type())
			_add_state_line(definition.label(), definition.key, value)

	# 未登记状态（旧资源里可能出现）
	var unknown_keys: Array[String] = []
	for key in state.snapshot().get("values", {}).keys():
		if not known.has(key):
			unknown_keys.append(String(key))
	if not unknown_keys.is_empty():
		_add_section(L10n.game("debug.section.unknown"))
		for key in unknown_keys:
			_add_state_line(key, key, state.get_value(key, null))

	# 最近没有执行的事件
	var rejections: Array = runtime.get("last_rejections") if runtime.get("last_rejections") != null else []
	if not rejections.is_empty():
		_add_section(L10n.game("debug.section.rejections"))
		for entry in rejections:
			_add_rejection(entry)

func _add_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.6))
	_body.add_child(label)

func _add_line(text: String, color: Color, font_size: int = 12) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_body.add_child(label)

func _add_state_line(label_text: String, key: String, value: Variant) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.tooltip_text = key
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = _value_text(value)
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color(0.62, 0.86, 0.66) if _is_truthy(value) else Color(0.72, 0.74, 0.8))
	row.add_child(value_label)

	_body.add_child(row)

func _add_rejection(entry: Dictionary) -> void:
	var event_id := str(entry.get("event_id", ""))
	_add_line("◆ " + event_id, Color(0.9, 0.9, 0.95), 12)
	var diagnosis: Dictionary = entry.get("diagnosis", {})
	var pages: Array = diagnosis.get("pages", [])
	if pages.is_empty():
		_add_line("   " + L10n.game("debug.rejection_no_pages"), Color(0.85, 0.7, 0.55), 11)
		return
	for page in pages:
		var trigger := _trigger_label(str(page.get("trigger", "")))
		_add_line("   " + L10n.game("debug.page", {"page": int(page.get("index", 0)) + 1, "trigger": trigger}), Color(0.75, 0.78, 0.86), 11)
		if not bool(page.get("trigger_ok", true)):
			_add_line("      " + L10n.game("debug.trigger_mismatch"), Color(0.9, 0.6, 0.5), 11)
		var conditions: Array = page.get("conditions", [])
		if conditions.is_empty():
			_add_line("      " + L10n.game("debug.no_conditions"), Color(0.7, 0.72, 0.78), 11)
		for condition in conditions:
			var name := StateCatalogStore.display(str(condition.get("key", "")))
			if bool(condition.get("ok", false)):
				_add_line("      ✓ " + name, Color(0.6, 0.85, 0.65), 11)
			else:
				var actual: Variant = condition.get("actual", null)
				_add_line("      ✗ " + L10n.game("debug.condition_fail", {
					"name": name,
					"value": _value_text(actual),
					"op": str(condition.get("op", "==")),
					"expected": _value_text(condition.get("value", null)),
				}), Color(0.9, 0.65, 0.55), 11)

func _trigger_label(trigger: String) -> String:
	if trigger == "interact":
		return L10n.game("input.action.interact")
	var text := L10n.game("trigger." + trigger)
	return trigger if text.begins_with("trigger.") else text

func _value_text(value: Variant) -> String:
	if value is bool:
		return L10n.game("debug.value_true") if value else L10n.game("debug.value_false")
	if value == null:
		return L10n.game("debug.value_none")
	return str(value)

func _is_truthy(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) != 0.0
	return value != null and str(value) != ""
