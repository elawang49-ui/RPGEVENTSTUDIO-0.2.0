class_name TraceDebugView
extends VBoxContainer
## F2 面板内的「运行追踪」视图。复用 StateDebugPanel，不新建调试器。
## 只看 RuntimeTrace 已经记录的真实数据；没有的记录项显示为空，不推断。
## 自然语言视图把内部 ID 转成显示名（状态库 / 图节点标题 / 事件显示名）；
## 取不到显示名时保留原始 ID 并明确标注，不伪装成已本地化。
## 原始 JSON（专业）视图保留全部原始 ID 与数据，JSON 内容不做任何改写。

var runtime: Node
var _trace: RuntimeTrace

var _enable: CheckBox
var _event_filter: LineEdit
var _state_filter: LineEdit
var _result_filter: OptionButton
var _tree: Tree
var _details: RichTextLabel
var _detail_mode: OptionButton
var _status: Label
var _current: Label

var _visible: Array = []
var _signature := ""
## trace_id -> 事件显示信息（event_start 记录；供 event_end / 当前事件行补全名称）。
var _event_names: Dictionary = {}
## graph_id + "/" + node_id -> node_type（来自 graph_node 记录，供分支 / 汇合行使用）。
var _node_types: Dictionary = {}
var _has_selection := false

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

	_detail_mode = OptionButton.new()
	_detail_mode.add_item(L10n.game("trace.detail.natural"), 0)
	_detail_mode.add_item(L10n.game("trace.detail.raw"), 1)
	_detail_mode.item_selected.connect(func(_index: int) -> void:
		refresh(true)
		_on_selected()
	)
	toolbar.add_child(_detail_mode)

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
	_current.add_theme_font_size_override("font_size", RuntimeFonts.NOTE)
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
	_tree.set_column_custom_minimum_width(0, 64)
	_tree.set_column_custom_minimum_width(1, 92)
	_tree.set_column_custom_minimum_width(3, 96)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_selected)
	_tree.item_activated.connect(_on_activated)
	add_child(_tree)

	# 详情区只在选中记录后出现，平时不挤压时间线；高度容纳常见详情（约 8 行）。
	_details = RichTextLabel.new()
	_details.custom_minimum_size = Vector2(0, 150)
	_details.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_details.scroll_active = true
	_details.add_theme_font_size_override("normal_font_size", RuntimeFonts.NOTE)
	_details.text = L10n.game("trace.details_hint")
	_details.visible = false
	add_child(_details)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", RuntimeFonts.NOTE)
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
	var mode_id := _detail_mode.get_item_id(_detail_mode.selected) if _detail_mode != null else 0
	var signature := "%s|%s|%d|%d|%d|%d" % [
		_event_filter.text, _state_filter.text, result_id, mode_id,
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
	_event_names.clear()
	_node_types.clear()
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

	# 显示名索引：事件名（event_start）与节点类型（graph_node），全部来自已记录数据。
	for record in all_records:
		match str(record.get("kind", "")):
			"event_start":
				var name := str(record.get("event_name", ""))
				if name == "":
					name = str(record.get("event_id", ""))
				if name != "":
					_event_names[int(record.get("trace_id", 0))] = name
			"graph_node":
				var node_key := "%s/%s" % [str(record.get("graph_id", "")), str(record.get("node_id", ""))]
				if not _node_types.has(node_key):
					_node_types[node_key] = str(record.get("node_type", ""))

	for record in all_records:
		var kind := str(record.get("kind", ""))
		var trace_id := int(record.get("trace_id", 0))
		if filter_event != "" and trace_id != 0 and not matched_traces.has(trace_id):
			continue
		if filter_state != "":
			# 状态过滤同时匹配原始标识与显示名，策划可以直接搜「教室钥匙」。
			var state_key := str(record.get("key", ""))
			var matches_state := state_key.to_lower().contains(filter_state) \
				or RuntimeDisplayNames.state_label(state_key).to_lower().contains(filter_state)
			if kind != "state" or not matches_state:
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
		for column in 4:
			item.set_tooltip_text(column, item.get_text(column))
		item.set_metadata(0, record)
		item.set_custom_color(1, _kind_color(kind))
		if int(record.get("seq", -1)) == selected_seq:
			_tree.set_selected(item, 0)

	if selected_seq >= 0 and _tree.get_selected() != null:
		_on_selected()
	else:
		_has_selection = false
		_details.visible = false
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
	if not _has_selection:
		text += "  ·  " + L10n.game("trace.details_hint")
	if _export_status != "":
		text += "  ·  " + _export_status
	_status.text = text

func _update_current() -> void:
	var records := _trace.records()
	var current := ""
	var raw := _raw_mode()
	for index in range(records.size() - 1, -1, -1):
		var record: Dictionary = records[index]
		var kind := str(record.get("kind", ""))
		if kind == "event_start":
			var event_text := _raw_event_id(record) if raw else RuntimeDisplayNames.event_label(
				str(record.get("event_name", "")), str(record.get("event_id", "")))
			current = L10n.game("trace.current_event", {
				"event": event_text,
				"page": int(record.get("page_index", 0)) + 1,
			})
			break
		if kind == "event_end":
			current = L10n.game("trace.current_finished", {
				"event": _raw_event_id(record) if raw else _event_name_for(int(record.get("trace_id", 0))),
			})
			break
	if current == "":
		current = L10n.game("trace.current_none")
	_current.text = current

func _event_name_for(trace_id: int) -> String:
	var name := str(_event_names.get(trace_id, ""))
	if name != "":
		return name
	return L10n.game("trace.event.id", {"id": trace_id})

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
		"event_rejected", "event_ignored", "condition":
			return Color(0.95, 0.66, 0.52)
		"state":
			return Color(0.72, 0.88, 0.62)
		"call":
			return Color(0.86, 0.72, 0.95)
	return Color(0.82, 0.84, 0.90)

func _command_label(command_type: String) -> String:
	var text := L10n.game("cmd." + command_type)
	return command_type if text.begins_with("cmd.") else text

func _node_label(record: Dictionary, node_id: String) -> String:
	var graph_id := str(record.get("graph_id", ""))
	var node_key := "%s/%s" % [graph_id, node_id]
	var node_type := str(_node_types.get(node_key, ""))
	if node_type == "":
		node_type = str(record.get("node_type", ""))
	return RuntimeDisplayNames.node_label(
		str(record.get("graph_path", "")), graph_id, node_id, node_type)

## 普通视图（自然语言）优先显示名；专业视图保留原始枚举值。
func _raw_mode() -> bool:
	return _detail_mode != null and int(_detail_mode.get_item_id(_detail_mode.selected)) == 1

## 专业视图摘要：只翻译模板文字，变量一律使用原始 ID / 原始枚举。
## 这样「自然语言」和「原始 JSON」两种模式的边界是可验证的：
## 切到专业视图后，true/false、out、and/or、stage id、状态键、节点 ID 都不再被替换成中文。
func _raw_summary(record: Dictionary) -> String:
	match str(record.get("kind", "")):
		"event_start":
			return L10n.game("trace.summary.event_start", {
				"name": _raw_event_id(record),
			})
		"event_end":
			return L10n.game("trace.summary.event_end", {
				"event": _raw_event_id(record),
				"result": str(record.get("result", "")),
			})
		"event_rejected":
			return L10n.game("trace.summary.event_rejected", {
				"name": _raw_event_id(record),
			})
		"event_ignored":
			return L10n.game("trace.summary.event_ignored", {
				"name": _raw_event_id(record),
				"reason": str(record.get("reason", "")),
			})
		"page":
			return L10n.game("trace.summary.page", {
				"page": int(record.get("page_index", 0)) + 1,
				"trigger": str(record.get("trigger", "")),
				"state": _raw_bool(record.get("selected", false)),
			})
		"command_start":
			return L10n.game("trace.summary.command_start", {
				"command": str(record.get("command_type", "")),
			})
		"command_end":
			return L10n.game("trace.summary.command_end", {
				"command": str(record.get("command_type", "")),
			})
		"condition":
			return L10n.game("trace.summary.condition", {
				"key": str(record.get("key", "")),
				"actual": _raw_text(record.get("actual", null)),
				"branch": str(record.get("branch", "")),
			})
		"state":
			return L10n.game("trace.summary.state", {
				"name": str(record.get("key", "")),
				"old": _raw_text(record.get("old", null)),
				"new": _raw_text(record.get("new", null)),
			})
		"call":
			return L10n.game("trace.summary.call", {
				"phase": str(record.get("phase", "")),
				"target": str(record.get("target", "")),
			})
		"graph_node":
			return L10n.game("trace.summary.graph_node", {
				"graph": str(record.get("graph_id", "")),
				"node": str(record.get("node_id", "")),
				"phase": str(record.get("phase", "")),
			})
		"graph_branch":
			return L10n.game("trace.summary.graph_branch", {
				"node": str(record.get("node_id", "")),
				"port": str(record.get("port", "")),
				"to": str(record.get("to_node", "")),
			})
		"graph_merge":
			return L10n.game("trace.summary.graph_merge", {
				"node": str(record.get("node_id", "")),
				"mode": str(record.get("mode", "")),
				"count": int(record.get("count", 0)),
				"required": int(record.get("required", 0)),
			})
	return str(record.get("kind", ""))

## 专业视图里的事件标识：优先原始 event_id，没有就退回 trace 编号。
func _raw_event_id(record: Dictionary) -> String:
	var event_id := str(record.get("event_id", ""))
	if event_id != "":
		return event_id
	return "#%d" % int(record.get("trace_id", 0))

## 专业视图的标量显示：布尔保留 JSON 形式，null 明确写 null。
func _raw_text(value: Variant) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "true" if value else "false"
	return str(value)

func _raw_bool(value: Variant) -> String:
	return "true" if bool(value) else "false"

func _summary(record: Dictionary) -> String:
	if _raw_mode():
		return _raw_summary(record)
	match str(record.get("kind", "")):
		"event_start":
			return L10n.game("trace.summary.event_start", {
				"name": RuntimeDisplayNames.event_label(
					str(record.get("event_name", "")), str(record.get("event_id", ""))),
			})
		"event_end":
			return L10n.game("trace.summary.event_end", {
				"event": _event_name_for(int(record.get("trace_id", 0))),
				"result": _result_text_for(record),
			})
		"event_rejected":
			return L10n.game("trace.summary.event_rejected", {
				"name": RuntimeDisplayNames.event_label(
					str(record.get("event_name", "")), str(record.get("event_id", ""))),
			})
		"event_ignored":
			return L10n.game("trace.summary.event_ignored", {
				"name": RuntimeDisplayNames.event_label(
					str(record.get("event_name", "")), str(record.get("event_id", ""))),
				"reason": _reason_label(record),
			})
		"page":
			return L10n.game("trace.summary.page", {
				"page": int(record.get("page_index", 0)) + 1,
				"trigger": _trigger_label(str(record.get("trigger", ""))),
				"state": L10n.game("trace.selected" if bool(record.get("selected", false)) else "trace.not_selected"),
			})
		"command_start":
			return L10n.game("trace.summary.command_start", {
				"command": _command_label(str(record.get("command_type", ""))),
			})
		"command_end":
			return L10n.game("trace.summary.command_end", {
				"command": _command_label(str(record.get("command_type", ""))),
			})
		"condition":
			var key := str(record.get("key", ""))
			return L10n.game("trace.summary.condition", {
				"key": RuntimeDisplayNames.state_label(key),
				"actual": RuntimeDisplayNames.value_text(record.get("actual", null), key),
				"branch": _branch_label(str(record.get("branch", ""))),
			})
		"state":
			var key := str(record.get("key", ""))
			return L10n.game("trace.summary.state", {
				"name": RuntimeDisplayNames.state_label(key),
				"old": RuntimeDisplayNames.value_text(record.get("old", null), key),
				"new": RuntimeDisplayNames.value_text(record.get("new", null), key),
			})
		"call":
			var target := str(record.get("target", "")).get_file()
			return L10n.game("trace.summary.call", {
				"phase": L10n.game("trace.call.enter" if str(record.get("phase", "")) == "enter" else "trace.call.exit"),
				"target": target.trim_suffix(".tres").trim_suffix(".tscn"),
			})
		"graph_node":
			return L10n.game("trace.summary.graph_node", {
				"graph": str(record.get("graph_id", "")),
				"node": _node_label(record, str(record.get("node_id", ""))),
				"phase": L10n.game("trace.graph.enter" if str(record.get("phase", "")) == "enter" else "trace.graph.exit"),
			})
		"graph_branch":
			return L10n.game("trace.summary.graph_branch", {
				"node": _node_label(record, str(record.get("node_id", ""))),
				"port": RuntimeDisplayNames.port_label(str(record.get("port", ""))),
				"to": _node_label(record, str(record.get("to_node", ""))),
			})
		"graph_merge":
			return L10n.game("trace.summary.graph_merge", {
				"node": _node_label(record, str(record.get("node_id", ""))),
				"mode": L10n.game("trace.merge.and" if str(record.get("mode", "")) == "and" else "trace.merge.or"),
				"count": int(record.get("count", 0)),
				"required": int(record.get("required", 0)),
			})
	return str(record.get("kind", ""))

func _trigger_label(trigger: String) -> String:
	var text := L10n.game("trigger." + trigger)
	return trigger if text.begins_with("trigger.") else text

func _branch_label(branch: String) -> String:
	return L10n.game("trace.cond.branch.then" if branch == "true" else "trace.cond.branch.else")

func _result_label(result: String) -> String:
	var text := L10n.game("trace.result." + result)
	if not text.begins_with("trace.result."):
		return text
	# 未收录的结果枚举：明确标出原始值，不静默误译。
	return L10n.game("trace.result.fallback", {"value": result})

func _reason_label(record: Dictionary) -> String:
	match str(record.get("reason", "")):
		"reentry":
			return L10n.game("trace.reason.reentry")
		"repeat_policy":
			var detail: Dictionary = record.get("detail", {})
			return L10n.game("trace.reason.repeat_policy", {"policy": str(detail.get("policy", "?"))})
	return L10n.game("trace.reason.unknown")

## 结果列：自然语言视图一律中文；专业视图保留原始枚举（continue / completed 等）。
func _result_text_for(record: Dictionary) -> String:
	var raw := str(record.get("result", ""))
	if _raw_mode():
		return raw
	return _result_label(raw)

func _result_text(record: Dictionary) -> String:
	if _raw_mode():
		return _raw_result_text(record)
	match str(record.get("kind", "")):
		"event_end", "command_end":
			return _result_text_for(record)
	if record.has("selected"):
		return L10n.game("trace.selected" if bool(record.get("selected", false)) else "trace.not_selected")
	if record.has("matched"):
		return L10n.game("trace.true" if bool(record.get("matched", false)) else "trace.false")
	if record.has("fired"):
		return L10n.game("trace.fired" if bool(record.get("fired", false)) else "trace.waiting")
	return ""

## 专业视图结果列：事件/指令结果保留原始枚举，布尔字段保留 true/false。
func _raw_result_text(record: Dictionary) -> String:
	match str(record.get("kind", "")):
		"event_end", "command_end":
			return str(record.get("result", ""))
	if record.has("selected"):
		return _raw_bool(record.get("selected", false))
	if record.has("matched"):
		return _raw_bool(record.get("matched", false))
	if record.has("fired"):
		return _raw_bool(record.get("fired", false))
	return ""

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
	_has_selection = true
	_details.visible = true
	_details.text = _detail_text(record)
	_update_status()

## 详情两层：自然语言（普通视图）/ 原始数据（专业模式）。
## 专业模式保留原始 ID 与完整 JSON，JSON.stringify 的数据不做任何改写。
func _detail_text(record: Dictionary) -> String:
	if _raw_mode():
		return _raw_detail(record)
	return _natural_detail(record)

## 专业视图：一行原始标识（kind / trace / event / node / key）+ 原始 JSON。
func _raw_detail(record: Dictionary) -> String:
	var tags := PackedStringArray()
	tags.append(str(record.get("kind", "")))
	if record.has("trace_id"):
		tags.append("trace #%s" % str(record.get("trace_id")))
	if record.has("event_id"):
		tags.append("event=%s" % str(record.get("event_id")))
	if record.has("graph_id"):
		tags.append("graph=%s" % str(record.get("graph_id")))
	if record.has("node_id"):
		tags.append("node=%s" % str(record.get("node_id")))
	if record.has("page_index"):
		tags.append("page=%s" % str(record.get("page_index")))
	if record.has("command_index") and int(record.get("command_index", -1)) >= 0:
		tags.append("command=%s" % str(record.get("command_index")))
	if record.has("key"):
		tags.append("key=%s" % str(record.get("key")))
	tags.append("seq=%s" % str(record.get("seq", "")))
	return " ".join(tags) + "\n\n" + JSON.stringify(record, "  ")

func _natural_detail(record: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append(_summary(record))
	var kind := str(record.get("kind", ""))
	match kind:
		"event_start":
			var source: Dictionary = record.get("source", {})
			if not source.is_empty():
				lines.append(L10n.game("trace.detail.source", {
					"source": _source_label(source),
				}))
			if int(record.get("page_index", -1)) >= 0:
				lines.append(L10n.game("trace.detail.selected_page", {
					"page": int(record.get("page_index", 0)) + 1,
				}))
		"event_end":
			lines.append(L10n.game("trace.detail.duration", {
				"ms": int(record.get("duration_ms", 0)),
			}))
		"event_rejected":
			var src: Dictionary = record.get("source", {})
			if not src.is_empty():
				lines.append(L10n.game("trace.detail.source", {"source": _source_label(src)}))
			lines.append(L10n.game("trace.detail.rejected_hint"))
			var pages: Array = record.get("pages", [])
			for page in pages:
				lines.append("  " + L10n.game("trace.summary.page", {
					"page": int(page.get("index", 0)) + 1,
					"trigger": _trigger_label(str(page.get("trigger", ""))),
					"state": L10n.game("trace.selected" if bool(page.get("active", false)) else "trace.not_selected"),
				}))
				for condition in page.get("conditions", []):
					var cond_key := str(condition.get("key", ""))
					lines.append("    " + L10n.game("trace.summary.condition", {
						"key": RuntimeDisplayNames.state_label(cond_key),
						"actual": RuntimeDisplayNames.value_text(condition.get("actual", null), cond_key),
						"branch": L10n.game("trace.cond.branch.then" if bool(condition.get("ok", false)) else "trace.cond.branch.else"),
					}))
					lines.append("      " + L10n.game("trace.detail.state_key", {"key": cond_key}))
		"event_ignored":
			lines.append(L10n.game("trace.detail.ignored_hint", {"reason": _reason_label(record)}))
		"condition":
			var key := str(record.get("key", ""))
			lines.append(L10n.game("trace.detail.state_key", {"key": key}))
			lines.append(L10n.game("trace.detail.condition_expected", {
				"expected": RuntimeDisplayNames.value_text(record.get("expected", null), key),
			}))
			lines.append(L10n.game("trace.detail.condition_actual", {
				"actual": RuntimeDisplayNames.value_text(record.get("actual", null), key),
			}))
			lines.append(L10n.game("trace.cond.matched" if bool(record.get("matched", false)) else "trace.cond.not_matched"))
			lines.append(L10n.game("trace.detail.condition_branch", {
				"branch": _branch_label(str(record.get("branch", ""))),
			}))
			if str(record.get("node_id", "")) != "":
				lines.append(L10n.game("trace.detail.graph_location", {
					"graph": str(record.get("graph_id", "")),
					"node": _node_label(record, str(record.get("node_id", ""))),
				}))
		"state":
			var key := str(record.get("key", ""))
			lines.append(L10n.game("trace.detail.state_key", {"key": key}))
			lines.append(L10n.game("trace.detail.state_old", {"value": RuntimeDisplayNames.value_text(record.get("old", null), key)}))
			lines.append(L10n.game("trace.detail.state_new", {"value": RuntimeDisplayNames.value_text(record.get("new", null), key)}))
			if int(record.get("command_index", -1)) >= 0:
				lines.append(L10n.game("trace.detail.state_by_command", {
					"command": _command_label(str(record.get("command_type", ""))),
				}))
		"graph_merge":
			if not bool(record.get("fired", false)):
				lines.append(L10n.game("trace.detail.merge_waiting", {
					"required": int(record.get("required", 0)),
				}))
		"graph_node":
			var phase := str(record.get("phase", ""))
			if phase == "stage":
				var cause: Dictionary = record.get("cause", {})
				lines.append(L10n.game("trace.detail.stage", {
					"stage": RuntimeDisplayNames.stage_label(str(cause.get("stage_id", ""))),
				}))
	return "\n".join(lines)

func _source_label(source: Dictionary) -> String:
	match str(source.get("kind", "")):
		"graph":
			return L10n.game("trace.source.graph", {
				"graph": str(source.get("graph_id", "")),
				"node": RuntimeDisplayNames.node_label(
					str(source.get("graph_path", "")), str(source.get("graph_id", "")),
					str(source.get("node_id", "")), ""),
			})
		"interactor":
			return L10n.game("trace.source.interactor", {"node": str(source.get("node", ""))})
		"trigger_area":
			return L10n.game("trace.source.trigger_area", {"node": str(source.get("node", ""))})
		"autorun":
			return L10n.game("trace.source.autorun", {"node": str(source.get("node", ""))})
		"nested":
			return L10n.game("trace.source.nested", {"parent": str(source.get("parent_event_id", ""))})
	return JSON.stringify(source)

func _on_activated() -> void:
	var item := _tree.get_selected()
	if item == null or runtime == null:
		return
	var record: Dictionary = item.get_metadata(0)
	var kind := str(record.get("kind", ""))
	if (kind.begins_with("graph") or kind == "condition") and str(record.get("node_id", "")) != "":
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
