class_name StateDebugPanel
extends CanvasLayer
const STUDIO_DESIGN := preload("res://addons/rpgeventstudio/core/theme/studio_design.gd")
## 游戏内状态调试面板（F2）：看当前状态、未登记状态、以及「事件为什么没执行」。
## 显示名与编辑器里完全一致——这里看到的「办公室日记已调查」就是编辑器里选的那条状态。

var runtime: Node

var _root: Control
var _panel: PanelContainer
var _body: VBoxContainer
var _state_scroll: ScrollContainer
var _trace_view: TraceDebugView
var _trace_button: Button
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
	_root.theme = STUDIO_DESIGN.runtime_theme()
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
	panel.add_theme_stylebox_override("panel", STUDIO_DESIGN.modal_style(STUDIO_DESIGN.BLUE))
	center.add_child(panel)
	_panel = panel
	_apply_bounds()

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

	_trace_button = Button.new()
	_trace_button.text = L10n.game("trace.title")
	_trace_button.toggle_mode = true
	_trace_button.toggled.connect(_show_trace)
	header.add_child(_trace_button)

	var close := Button.new()
	close.text = L10n.game("debug.close")
	close.pressed.connect(close_panel)
	header.add_child(close)

	var hint := Label.new()
	hint.text = L10n.game("debug.hint")
	hint.add_theme_font_size_override("font_size", RuntimeFonts.NOTE)
	hint.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	column.add_child(hint)

	_state_scroll = ScrollContainer.new()
	_state_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_state_scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	_state_scroll.add_child(_body)

	_trace_view = TraceDebugView.new()
	_trace_view.visible = false
	_trace_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_trace_view)

## 面板按窗口自适应：固定 1100×680 会超出 1152×648 这类小窗口，底部被裁掉。
func _apply_bounds() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(
		minf(1100.0, viewport_size.x - 32.0),
		minf(680.0, viewport_size.y - 32.0),
	)

func open() -> void:
	_apply_bounds()
	visible = true
	if _trace_view != null:
		_trace_view.setup(runtime)
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
		_apply_bounds()
		refresh()

func _show_trace(enabled: bool) -> void:
	if _state_scroll != null:
		_state_scroll.visible = not enabled
	if _trace_view != null:
		_trace_view.visible = enabled
		if enabled:
			_trace_view.setup(runtime)
	if not enabled and _body != null:
		refresh()

func refresh() -> void:
	if runtime == null:
		return
	if _trace_view != null and _trace_view.visible:
		_trace_view.refresh()
	if _body == null:
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
	_add_line(L10n.game("debug.stage", {"stage": RuntimeDisplayNames.stage_label(stage)}), Color(0.8, 0.85, 0.95), 13)

	# 已登记状态
	_add_section(L10n.game("debug.section.states"))
	var catalog := StateCatalogStore.catalog()
	var known := {}
	for group in catalog.grouped():
		_add_category(str(group["category"]), group["items"].size())
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
	label.add_theme_font_size_override("font_size", RuntimeFonts.SECTION)
	label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.6))
	_body.add_child(label)

## 分类子标题：竖向强调条 + 名称 + 条目数，与状态条目拉开视觉层级。
func _add_category(text: String, count: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var accent := ColorRect.new()
	accent.color = Color(0.55, 0.75, 1.0, 0.8)
	accent.custom_minimum_size = Vector2(3, 14)
	accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(accent)
	var label := Label.new()
	label.text = "%s · %d" % [text, count]
	label.add_theme_font_size_override("font_size", RuntimeFonts.DEBUG)
	label.add_theme_color_override("font_color", Color(0.68, 0.78, 0.92))
	row.add_child(label)
	_body.add_child(row)

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
	name_label.add_theme_font_size_override("font_size", RuntimeFonts.NOTE)
	name_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94))
	name_label.tooltip_text = key
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = RuntimeDisplayNames.value_text(value, key)
	value_label.add_theme_font_size_override("font_size", RuntimeFonts.NOTE)
	value_label.add_theme_color_override("font_color", Color(0.62, 0.86, 0.66) if _is_truthy(value) else Color(0.72, 0.74, 0.8))
	row.add_child(value_label)

	_body.add_child(row)

func _add_rejection(entry: Dictionary) -> void:
	var event_id := str(entry.get("event_id", ""))
	_add_line("◆ " + event_id, Color(0.9, 0.9, 0.95), RuntimeFonts.NOTE)
	var diagnosis: Dictionary = entry.get("diagnosis", {})
	var pages: Array = diagnosis.get("pages", [])
	if pages.is_empty():
		_add_line("   " + L10n.game("debug.rejection_no_pages"), Color(0.85, 0.7, 0.55), RuntimeFonts.NOTE)
		return
	for page in pages:
		var trigger := _trigger_label(str(page.get("trigger", "")))
		_add_line("   " + L10n.game("debug.page", {"page": int(page.get("index", 0)) + 1, "trigger": trigger}), Color(0.75, 0.78, 0.86), RuntimeFonts.NOTE)
		if not bool(page.get("trigger_ok", true)):
			_add_line("      " + L10n.game("debug.trigger_mismatch"), Color(0.9, 0.6, 0.5), RuntimeFonts.NOTE)
		var conditions: Array = page.get("conditions", [])
		if conditions.is_empty():
			_add_line("      " + L10n.game("debug.no_conditions"), Color(0.7, 0.72, 0.78), RuntimeFonts.NOTE)
		for condition in conditions:
			var key := str(condition.get("key", ""))
			var name := RuntimeDisplayNames.state_label(key)
			if bool(condition.get("ok", false)):
				_add_line("      ✓ " + name, Color(0.6, 0.85, 0.65), RuntimeFonts.NOTE)
			else:
				var actual: Variant = condition.get("actual", null)
				_add_line("      ✗ " + L10n.game("debug.condition_fail", {
					"name": name,
					"value": RuntimeDisplayNames.value_text(actual, key),
					"op": str(condition.get("op", "==")),
					"expected": RuntimeDisplayNames.value_text(condition.get("value", null), key),
				}), Color(0.9, 0.65, 0.55), RuntimeFonts.NOTE)

func _trigger_label(trigger: String) -> String:
	if trigger == "interact":
		return L10n.game("input.action.interact")
	var text := L10n.game("trigger." + trigger)
	return trigger if text.begins_with("trigger.") else text

func _is_truthy(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) != 0.0
	return value != null and str(value) != ""
