class_name TraceDebugView
extends VBoxContainer
## F2 面板内的「运行追踪」视图。复用 StateDebugPanel，不新建调试器。
## 只看 RuntimeTrace 已经记录的真实数据；没有的记录项显示为空，不推断。

var runtime: Node
var _trace: RuntimeTrace

var _enable: CheckBox
var _event_filter: LineEdit
var _state_filter: LineEdit
var _result_filter: OptionButton
var _tree: Tree
var _details: RichTextLabel
var _status: Label
var _current: Label

var _visible: Array = []
var _signature := ""

func setup(p_runtime: Node) -> void:
	runtime = p_runtime
	_trace = runtime.get("trace") if runtime != null else null
	if _tree == null:
		_build()
	refresh(true)

func _build() -> void:
	add_theme_constant_override("separation", 6)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	add_child(toolbar)

	_enable = CheckBox.new()
	_enable.text = L10n.game("trace.enable")
	_enable.toggled.connect(func(pressed: bool) -> void:
		if runtime != null:
			runtime.call("set_trace_enabled", pressed)
		refresh(true)
	)
	toolbar.add_child(_enable)

	_event_filter = LineEdit.new()
	_event_filter.placeholder_text = L10n.game("trace.filter.event")
	_event_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_filter.text_changed.connect(func(_text: String) -> void: refresh(true))
	toolbar.add_child(_event_filter)

	_state_filter = LineEdit.new()
	_state_filter.placeholder_text = L10n.game("trace.filter.state")
	_state_filter.custom_minimum_size = Vector2(160, 0)
	_state_filter.text_changed.connect(func(_text: String) -> void: refresh(true))
	toolbar.add_child(_state_filter)

	_result_filter = OptionButton.new()
	_result_filter.add_item(L10n.game("trace.result.all"), 0)
	_result_filter.add_item(L10n.game("trace.result.completed"), 1)
	_result_filter.add_item(L10n.game("trace.result.cancelled"), 2)
	_result_filter.add_item(L10n.game("trace.result.failed"), 3)
	_result_filter.item_selected.connect(func(_index: int) -> void: refresh(true))
	toolbar.add_child(_result_filter)

	var clear_button := Button.new()
	clear_button.text = L10n.game("trace.clear")
	clear_button.pressed.connect(func() -> void:
		if runtime != null:
			runtime.call("clear_trace")
		refresh(true)
	)
	toolbar.add_child(clear_button)

	var export_button := Button.new()
	export_button.text = L10n.game("trace.export")
	export_button.pressed.connect(_export)
	toolbar.add_child(export_button)

	_current = Label.new()
	_current.add_theme_font_size_override("font_size", 11)
	_current.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	add_child(_current)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.set_column_title(0, L10n.game("trace.col.time"))
	_tree.set_column_title(1, L10n.game("trace.col.kind"))
	_tree.set_column_title(2, L10n.game("trace.col.summary"))
	_tree.set_column_title(3, L10n.game("trace.col.result"))
	_tree.set_column_expand(0, false)
	_tree.set_column_expand(1, false)
	_tree.set_column_expand(2, true)
	_tree.set_column_expand(3, false)
	_tree.set_column_custom_minimum_width(0, 58)
	_tree.set_column_custom_minimum_width(1, 92)
	_tree.set_column_custom_minimum_width(3, 90)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_selected)
	_tree.item_activated.connect(_on_activated)
	add_child(_tree)

	_details = RichTextLabel.new()
	_details.custom_minimum_size = Vector2(0, 130)
	_details.scroll_active = true
	_details.add_theme_font_size_override("normal_font_size", 11)
	_details.text = L10n.game("trace.details_hint")
	add_child(_details)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 10)
	_status.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
	add_child(_status)

# ── 刷新 ─────────────────────────────────────────────────

func refresh(force: bool = false) -> void:
	if runtime == null:
		return
	_trace = runtime.get("trace")
	if _tree == null or _trace == null:
		return
	if _enable.button_pressed != _trace.enabled:
		_enable.set_pressed_no_signal(_trace.enabled)
	var result_id := _result_filter.get_item_id(_result_filter.selected)
	var signature := "%s|%s|%d|%d|%d" % [
		_event_filter.text, _state_filter.text, result_id,
		_trace.record_count(), _trace.dropped_count(),
	]
	if not force and signature == _signature:
		return
	_signature = signature
	_rebuild()
	_export_status = ""

var _export_status := ""

func _rebuild() -> void:
	var selected_seq := -1
	var selected := _tree.get_selected()
	if selected != null:
		var prior: Dictionary = selected.get_metadata(0)
		selected_seq = int(prior.get("seq", -1))
	_tree.clear()
	var root := _tree.create_item()

	_visible.clear()
	var all_records := _trace.records()
	var filter_event := _event_filter.text.strip_edges().to_lower()
	var filter_state := _state_filter.text.strip_edges().to_lower()
	var result_id := _result_filter.get_item_id(_result_filter.selected)

	# 事件过滤：先找出匹配的 trace_id，再保留该 trace 的全部记录。
	var matched_traces := {}
	if filter_event != "":
		for record in all_records:
			var event_id := str(record.get("event_id", "")).to_lower()
			var event_name := str(record.get("event_name", "")).to_lower()
			if event_id.contains(filter_event) or event_name.contains(filter_event):
				matched_traces[int(record.get("trace_id", 0))] = true
	# 结果过滤：只保留对应事件结束结果的 trace。
	var result_traces := {}
	if result_id > 0:
		for record in all_records:
			if str(record.get("kind", "")) == "event_end":
				var value := _result_value(str(record.get("result", "")))
				if value == result_id:
					result_traces[int(record.get("trace_id", 0))] = true

	for record in all_records:
		var kind := str(record.get("kind", ""))
		var trace_id := int(record.get("trace_id", 0))
		if filter_event != "" and trace_id != 0 and not matched_traces.has(trace_id):
			continue
		if filter_state != "":
			if kind != "state" or not str(record.get("key", "")).to_lower().contains(filter_state):
				continue
		if result_id > 0:
			if trace_id == 0:
				continue
			if not result_traces.has(trace_id):
				continue
		_visible.append(record)
		var item := _tree.create_item(root)
		item.set_text(0, "%dms" % int(record.get("t_ms", 0)))
		item.set_text(1, _kind_label(kind))
		item.set_text(2, _summary(record))
		item.set_text(3, _result_text(record))
		item.set_metadata(0, record)
		item.set_custom_color(1, _kind_color(kind))
		if int(record.get("seq", -1)) == selected_seq:
			_tree.set_selected(item, 0)

	_update_status()
	_update_current()

func _update_status() -> void:
	var stats: Dictionary = _trace.stats()
	var text := L10n.game("trace.status", {
		"shown": _visible.size(),
		"total": int(stats.get("records", 0)),
		"capacity": int(stats.get("capacity", 0)),
		"dropped": int(stats.get("dropped", 0)),
	})
	if _export_status != "":
		text += "  ·  " + _export_status
	_status.text = text

func _update_current() -> void:
	var records := _trace.records()
	var current := ""
	for index in range(records.size() - 1, -1, -1):
		var record: Dictionary = records[index]
		var kind := str(record.get("kind", ""))
		if kind == "event_start":
			current = L10n.game("trace.current_event", {
				"event": str(record.get("event_name", record.get("event_id", ""))),
				"page": int(record.get("page_index", 0)) + 1,
			})
			break
		if kind == "event_end":
			current = L10n.game("trace.current_finished", {"event": str(record.get("trace_id", ""))})
			break
	if current == "":
		current = L10n.game("trace.current_none")
	_current.text = current

# ── 显示 ─────────────────────────────────────────────────

func _kind_label(kind: String) -> String:
	return L10n.game("trace.kind." + kind)

func _kind_color(kind: String) -> Color:
	if kind.begins_with("graph"):
		return Color(0.62, 0.78, 0.95)
	match kind:
		"event_start":
			return Color(0.60, 0.90, 0.65)
		"event_end":
			return Color(0.95, 0.82, 0.48)
		"event_rejected", "condition":
			return Color(0.95, 0.66, 0.52)
		"state":
			return Color(0.72, 0.88, 0.62)
		"call":
			return Color(0.86, 0.72, 0.95)
	return Color(0.82, 0.84, 0.90)

func _summary(record: Dictionary) -> String:
	match str(record.get("kind", "")):
		"event_start":
			return "%s（%s）" % [str(record.get("event_name", "")), str(record.get("event_id", ""))]
		"event_end":
			return "%s  #%d" % [str(record.get("result", "")), int(record.get("trace_id", 0))]
		"event_rejected":
			return "%s · %s" % [str(record.get("event_name", "")), str(record.get("event_id", ""))]
		"page":
			return L10n.game("trace.summary.page", {
				"page": int(record.get("page_index", 0)) + 1,
				"trigger": str(record.get("trigger", "")),
				"state": L10n.game("trace.selected" if bool(record.get("selected", false)) else "trace.not_selected"),
			})
		"command_start":
			return "#%d %s" % [int(record.get("command_index", 0)), str(record.get("command_type", ""))]
		"command_end":
			return "#%d %s → %s" % [int(record.get("command_index", 0)), str(record.get("command_type", "")), str(record.get("result", ""))]
		"condition":
			return L10n.game("trace.summary.condition", {
				"key": str(record.get("key", "")),
				"actual": _value_text(record.get("actual", null)),
				"branch": str(record.get("branch", "")),
			})
		"state":
			return "%s：%s → %s" % [str(record.get("key", "")), _value_text(record.get("old", null)), _value_text(record.get("new", null))]
		"call":
			return "%s %s %s" % [str(record.get("phase", "")), str(record.get("call_kind", "")), str(record.get("target", ""))]
		"graph_node":
			return "%s · %s · %s" % [str(record.get("graph_id", "")), str(record.get("node_id", "")), str(record.get("phase", ""))]
		"graph_branch":
			return "%s：%s → %s" % [str(record.get("node_id", "")), str(record.get("port", "")), str(record.get("to_node", ""))]
		"graph_merge":
			return "%s %s %d/%d" % [str(record.get("node_id", "")), str(record.get("mode", "")), int(record.get("count", 0)), int(record.get("required", 0))]
	return str(record.get("kind", ""))

func _result_text(record: Dictionary) -> String:
	if record.has("result"):
		return str(record.get("result", ""))
	if record.has("selected"):
		return L10n.game("trace.selected" if bool(record.get("selected", false)) else "trace.not_selected")
	if record.has("matched"):
		return L10n.game("trace.true" if bool(record.get("matched", false)) else "trace.false")
	if record.has("fired"):
		return L10n.game("trace.fired" if bool(record.get("fired", false)) else "trace.waiting")
	return ""

func _value_text(value: Variant) -> String:
	if value == null:
		return "—"
	if value is bool:
		return L10n.game("debug.value_true") if value else L10n.game("debug.value_false")
	return str(value)

# ── 详情 / 定位 / 导出 ──────────────────────────────────

func select_first() -> void:
	var root := _tree.get_root()
	if root == null or root.get_child_count() == 0:
		return
	var item := root.get_child(0)
	_tree.set_selected(item, 0)
	_on_selected()

func _on_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var record: Dictionary = item.get_metadata(0)
	if record.is_empty():
		return
	_details.text = _summary(record) + "\n\n" + JSON.stringify(record, "  ")

func _on_activated() -> void:
	var item := _tree.get_selected()
	if item == null or runtime == null:
		return
	var record: Dictionary = item.get_metadata(0)
	var kind := str(record.get("kind", ""))
	if kind.begins_with("graph") and str(record.get("node_id", "")) != "":
		runtime.call("trace_focus_node", str(record.get("graph_id", "")), str(record.get("node_id", "")),
			str(record.get("graph_path", "")))
	elif str(record.get("event_id", "")) != "":
		runtime.call("trace_focus_event", str(record.get("event_id", "")), str(record.get("event_path", "")))

func _export() -> void:
	if _trace == null:
		return
	var path := "user://rpg_event_studio_trace.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_export_status = L10n.game("trace.export_failed")
		_update_status()
		return
	file.store_string(_trace.export_json())
	file.close()
	_export_status = L10n.game("trace.exported", {"path": path})
	_update_status()

func _result_value(result: String) -> int:
	match result:
		"completed": return 1
		"cancelled": return 2
		"failed": return 3
	return 0
