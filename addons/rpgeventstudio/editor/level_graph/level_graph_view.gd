@tool
extends VBoxContainer
## 关卡总控图编辑器（编辑器主屏）。
##
## 结构：工具栏 → GraphEdit 画布 + 右侧节点参数。
## 数据仍然是 LevelGraph 资源；GraphEdit 只是视图，所有改动都写回资源并登记撤销。

var _plugin: EditorPlugin
var _graph: LevelGraph
var _selected: LevelNode

var _title_label: Label
var _add_button: MenuButton
var _delete_button: Button
var _save_button: Button
var _open_button: Button
var _new_button: Button
var _state_library_button: Button
var _highlight_check: CheckButton
var _check_label: Label
var _graph_edit: GraphEdit
var _params_box: VBoxContainer
var _status_label: Label
var _empty_hint: Label

var _node_views: Dictionary = {}   ## StringName -> GraphNode
var _summary_labels: Dictionary = {}  ## StringName -> Label
var _runtime_states: Dictionary = {}  ## StringName -> int
var _current_stage := ""
var _highlight_enabled := true
var _add_ids: Dictionary = {}
var _loading := false

func bind_plugin(plugin: EditorPlugin) -> void:
	_plugin = plugin

func _ready() -> void:
	_build_ui()
	_show_empty()

# ── 对外 ─────────────────────────────────────────────────

func open_from_selection(nodes: Array) -> void:
	for node in nodes:
		if node is LevelGraph:
			open_graph(node)
			return

func open_graph(graph: LevelGraph) -> void:
	_graph = graph
	_selected = null
	_runtime_states.clear()
	_current_stage = ""
	_rebuild_view()
	_rebuild_params()
	_title_label.text = "%s　[%s]" % [String(graph.graph_id), String(graph.level_id)]
	_show_status()
	_validate_graph()

func current_graph() -> LevelGraph:
	return _graph

# ── 界面 ─────────────────────────────────────────────────

func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	add_child(toolbar)

	_title_label = Label.new()
	_title_label.text = L10n.ui("graph.title")
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 15)
	toolbar.add_child(_title_label)

	_new_button = Button.new()
	_new_button.text = L10n.ui("graph.new")
	_new_button.pressed.connect(_on_new_pressed)
	toolbar.add_child(_new_button)

	_open_button = Button.new()
	_open_button.text = L10n.ui("graph.open")
	_open_button.pressed.connect(_on_open_pressed)
	toolbar.add_child(_open_button)

	_add_button = MenuButton.new()
	_add_button.text = L10n.ui("graph.add_node")
	toolbar.add_child(_add_button)

	_delete_button = Button.new()
	_delete_button.text = L10n.ui("graph.delete")
	_delete_button.pressed.connect(_on_delete_selected)
	toolbar.add_child(_delete_button)

	_state_library_button = Button.new()
	_state_library_button.text = L10n.ui("graph.state_library")
	_state_library_button.pressed.connect(_on_state_library_pressed)
	toolbar.add_child(_state_library_button)

	_highlight_check = CheckButton.new()
	_highlight_check.text = L10n.ui("graph.highlight")
	_highlight_check.tooltip_text = L10n.ui("graph.highlight.tip")
	_highlight_check.button_pressed = true
	_highlight_check.toggled.connect(func(pressed: bool) -> void:
		_highlight_enabled = pressed
		_refresh_markers()
	)
	toolbar.add_child(_highlight_check)

	_save_button = Button.new()
	_save_button.text = L10n.ui("graph.save")
	_save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(_save_button)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 900
	add_child(split)

	var canvas := Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(canvas)

	_graph_edit = GraphEdit.new()
	_graph_edit.name = "GraphEdit"
	_graph_edit.set_anchors_preset(Control.PRESET_FULL_RECT)
	_graph_edit.right_disconnects = true
	_graph_edit.show_grid = true
	_graph_edit.minimap_enabled = true
	_graph_edit.connection_lines_curvature = 0.4
	_graph_edit.connection_request.connect(_on_connection_request)
	_graph_edit.disconnection_request.connect(_on_disconnection_request)
	_graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	_graph_edit.node_selected.connect(_on_node_selected)
	_graph_edit.node_deselected.connect(_on_node_deselected)
	_graph_edit.end_node_move.connect(_on_end_node_move)
	canvas.add_child(_graph_edit)

	_empty_hint = Label.new()
	_empty_hint.text = L10n.ui("graph.no_graph")
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	canvas.add_child(_empty_hint)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(320, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(side)

	var params_title := Label.new()
	params_title.text = L10n.ui("graph.params")
	params_title.add_theme_font_size_override("font_size", 12)
	params_title.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	side.add_child(params_title)

	var params_scroll := ScrollContainer.new()
	params_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(params_scroll)

	_params_box = VBoxContainer.new()
	_params_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_params_box.add_theme_constant_override("separation", 6)
	params_scroll.add_child(_params_box)

	_check_label = Label.new()
	_check_label.add_theme_font_size_override("font_size", 11)
	_check_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_check_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)

	_rebuild_add_menu()

func _show_empty() -> void:
	_title_label.text = L10n.ui("graph.title")
	_empty_hint.visible = true
	_status_label.text = L10n.ui("graph.no_graph")
	_rebuild_params()

func _show_status() -> void:
	if _graph == null:
		return
	if _graph.resource_path == "":
		_status_label.text = L10n.ui("graph.status.no_path")
	else:
		_status_label.text = L10n.ui("graph.status.resource", {"path": _graph.resource_path})

# ── 视图 ─────────────────────────────────────────────────

func _rebuild_view() -> void:
	if _graph_edit == null:
		return
	_loading = true
	_graph_edit.clear_connections()
	for child in _graph_edit.get_children():
		if child is GraphNode:
			_graph_edit.remove_child(child)
			child.queue_free()
	_node_views.clear()
	_summary_labels.clear()

	if _graph == null:
		_empty_hint.visible = true
		_loading = false
		return
	_empty_hint.visible = false

	for node in _graph.nodes:
		if node == null:
			continue
		_node_views[node.node_id] = _make_node_view(node)
	for connection in _graph.connections:
		if connection == null:
			continue
		var from_view: GraphNode = _node_views.get(connection.from_node, null)
		var to_view: GraphNode = _node_views.get(connection.to_node, null)
		if from_view == null or to_view == null:
			continue
		_graph_edit.connect_node(connection.from_node, _out_port_index(connection.from_node, connection.from_port), connection.to_node, 0)

	_loading = false
	_update_toolbar()

func _make_node_view(node: LevelNode) -> GraphNode:
	var view := GraphNode.new()
	view.name = String(node.node_id)
	view.title = L10n.ui("graph.node." + node.type)
	view.position_offset = node.position
	view.custom_minimum_size = Vector2(200, 0)
	view.add_theme_font_size_override("title_font_size", 13)

	var summary := Label.new()
	summary.text = _summary_of(node)
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", Color(0.78, 0.80, 0.86))
	view.add_child(summary)

	var has_output := node.type != "end"
	view.set_slot(0, node.type != "start", 0, Color(0.55, 0.75, 1.0), has_output, 0, Color(0.85, 0.72, 0.45))

	if node.type == "condition":
		var else_label := Label.new()
		else_label.text = L10n.ui("graph.port.else")
		else_label.add_theme_font_size_override("font_size", 11)
		else_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.55))
		view.add_child(else_label)
		view.set_slot(1, false, 0, Color(), true, 0, Color(0.9, 0.55, 0.5))
	elif node.type == "event":
		view.set_slot(0, true, 0, Color(0.55, 0.75, 1.0), true, 0, Color(0.85, 0.72, 0.45))

	_summary_labels[node.node_id] = summary
	_graph_edit.add_child(view)
	_apply_marker(node)
	return view

func _summary_of(node: LevelNode) -> String:
	var text := node.describe()
	if node.type == "event" and text == "":
		text = "—"
	if not node.enabled:
		text = L10n.ui("graph.disabled")
	return text

func _out_port_index(node_id: StringName, port: String) -> int:
	var node := _graph.node_by_id(node_id)
	if node != null and node.type == "condition" and port == "false":
		return 1
	return 0

# ── 运行高亮 ─────────────────────────────────────────────

func apply_debug_node(graph_id: String, node_id: String, state: int) -> void:
	if _graph == null or String(_graph.graph_id) != graph_id:
		return
	_runtime_states[StringName(node_id)] = state
	var node := _graph.node_by_id(StringName(node_id))
	if node != null:
		_apply_marker(node)

func apply_debug_stage(graph_id: String, stage: String) -> void:
	if _graph == null or String(_graph.graph_id) != graph_id:
		return
	_current_stage = stage
	_refresh_markers()

func clear_debug_state() -> void:
	_runtime_states.clear()
	_current_stage = ""
	_refresh_markers()

func _refresh_markers() -> void:
	if _graph == null:
		return
	for node in _graph.nodes:
		if node != null:
			_apply_marker(node)

func _apply_marker(node: LevelNode) -> void:
	var label: Label = _summary_labels.get(node.node_id, null)
	if label == null:
		return
	var text := _summary_of(node)
	var color := Color(0.78, 0.80, 0.86)
	var state := int(_runtime_states.get(node.node_id, -1))

	if _highlight_enabled:
		match state:
			1:  # RUNNING
				text = "▶ " + text
				color = Color(0.55, 0.78, 1.0)
			2:  # DONE
				text = "✓ " + text
				color = Color(0.6, 0.86, 0.62)
			3:  # FAILED
				text = "✗ " + text
				color = Color(0.95, 0.6, 0.55)
			_:
				if _current_stage != "" and node.type == "stage" and str(node.params.get("stage_id", "")) == _current_stage:
					text = "● " + text
					color = Color(0.95, 0.85, 0.5)
	label.text = text
	label.add_theme_color_override("font_color", color)

# ── 图编辑 ───────────────────────────────────────────────

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if _graph == null or from_node == to_node:
		return
	var target := _graph.node_by_id(to_node)
	if target == null or target.type == "start":
		return
	if to_port != 0:
		return
	var port_name := "out"
	var source := _graph.node_by_id(from_node)
	if source != null and source.type == "condition" and from_port == 1:
		port_name = "false"
	elif source != null and source.type == "condition":
		port_name = "true"
	elif source != null and source.type == "event":
		port_name = "done"

	var undo := _undo_redo()
	var connection := LevelConnection.new()
	connection.from_node = from_node
	connection.from_port = port_name
	connection.to_node = to_node
	connection.to_port = "in"
	if undo == null:
		_graph.connect_nodes(from_node, port_name, to_node, "in")
		_after_change()
		return
	undo.create_action(L10n.ui("graph.undo.connect"), UndoRedo.MERGE_DISABLE, _graph)
	undo.add_do_method(self, "_do_connect", connection)
	undo.add_undo_method(self, "_do_disconnect", connection)
	undo.add_do_reference(connection)
	undo.commit_action()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if _graph == null:
		return
	var connection := _find_connection(from_node, _out_port_index(from_node, "false" if from_port == 1 else "out"), to_node)
	if connection == null:
		return
	var undo := _undo_redo()
	if undo == null:
		_graph.disconnect_nodes(connection.from_node, connection.from_port, connection.to_node, connection.to_port)
		_after_change()
		return
	undo.create_action(L10n.ui("graph.undo.disconnect"), UndoRedo.MERGE_DISABLE, _graph)
	undo.add_do_method(self, "_do_disconnect", connection)
	undo.add_undo_method(self, "_do_connect", connection)
	undo.add_do_reference(connection)
	undo.commit_action()

func _find_connection(from_node: StringName, from_port_index: int, to_node: StringName) -> LevelConnection:
	for connection in _graph.connections:
		if connection == null:
			continue
		if connection.from_node == from_node and connection.to_node == to_node:
			if _out_port_index(from_node, connection.from_port) == from_port_index:
				return connection
	return null

func _on_delete_nodes_request(nodes: Array) -> void:
	if _graph == null:
		return
	var ids: Array[StringName] = []
	for item in nodes:
		ids.append(StringName(item))
	_delete_nodes(ids)

func _on_delete_selected() -> void:
	if _selected == null:
		return
	_delete_nodes([_selected.node_id])
	_selected = null
	_rebuild_params()

func _delete_nodes(ids: Array) -> void:
	if _graph == null or ids.is_empty():
		return
	var removed_nodes: Array = []
	var removed_connections: Array = []
	for node_id in ids:
		var node := _graph.node_by_id(StringName(node_id))
		if node == null:
			continue
		for connection in _graph.connections:
			if connection != null and (connection.from_node == StringName(node_id) or connection.to_node == StringName(node_id)):
				removed_connections.append(connection)
		removed_nodes.append(node)

	var undo := _undo_redo()
	if undo == null:
		for node in removed_nodes:
			_graph.remove_node(node.node_id)
		_after_change()
		return
	undo.create_action(L10n.ui("graph.undo.delete"), UndoRedo.MERGE_DISABLE, _graph)
	undo.add_do_method(self, "_do_remove_nodes", removed_nodes)
	undo.add_undo_method(self, "_do_restore", removed_nodes, removed_connections)
	for node in removed_nodes:
		undo.add_do_reference(node)
	for connection in removed_connections:
		undo.add_do_reference(connection)
	undo.commit_action()

func _do_remove_nodes(nodes: Array) -> void:
	for node in nodes:
		if node != null:
			_graph.remove_node(node.node_id)
	_after_change()

func _do_restore(nodes: Array, connections: Array) -> void:
	for node in nodes:
		if node != null and _graph.node_by_id(node.node_id) == null:
			_graph.nodes.append(node)
	for connection in connections:
		if connection == null:
			continue
		var exists := false
		for existing in _graph.connections:
			if existing != null and existing.from_node == connection.from_node and existing.from_port == connection.from_port \
					and existing.to_node == connection.to_node and existing.to_port == connection.to_port:
				exists = true
				break
		if not exists:
			_graph.connections.append(connection)
	_after_change()

func _do_connect(connection: LevelConnection) -> void:
	if connection == null:
		return
	_graph.connect_nodes(connection.from_node, connection.from_port, connection.to_node, connection.to_port)
	_after_change()

func _do_disconnect(connection: LevelConnection) -> void:
	if connection == null:
		return
	_graph.disconnect_nodes(connection.from_node, connection.from_port, connection.to_node, connection.to_port)
	_after_change()

func _after_change() -> void:
	if _graph != null:
		_graph.emit_changed()
	_rebuild_view()
	_validate_graph()

func _on_end_node_move() -> void:
	if _graph == null or _loading:
		return
	for node in _graph.nodes:
		if node == null:
			continue
		var view: GraphNode = _node_views.get(node.node_id, null)
		if view != null:
			node.position = view.position_offset
	_graph.emit_changed()

# ── 新增节点 ─────────────────────────────────────────────

func _rebuild_add_menu() -> void:
	if _add_button == null:
		return
	var popup := _add_button.get_popup()
	popup.clear()
	_add_ids.clear()
	var id := 0
	for type in ["start", "stage", "condition", "action", "event", "merge_and", "merge_or", "end"]:
		popup.add_item(L10n.ui("graph.node." + type), id)
		_add_ids[id] = type
		id += 1
	if not popup.id_pressed.is_connected(_on_add_node_pressed):
		popup.id_pressed.connect(_on_add_node_pressed)

func _on_add_node_pressed(id: int) -> void:
	var type: String = str(_add_ids.get(id, ""))
	if type == "" or _graph == null:
		return
	var node := LevelNode.new()
	node.node_id = _graph.next_node_id(type)
	node.type = type
	node.params = _default_params(type)
	node.position = _view_center()
	node.title = L10n.ui("graph.node." + type)

	var undo := _undo_redo()
	if undo == null:
		_graph.nodes.append(node)
		_after_change()
		_select_node(node)
		return
	undo.create_action(L10n.ui("graph.undo.add"), UndoRedo.MERGE_DISABLE, _graph)
	undo.add_do_method(self, "_do_add_node", node)
	undo.add_undo_method(self, "_do_remove_nodes", [node])
	undo.add_do_reference(node)
	undo.commit_action()
	_select_node(node)

func _do_add_node(node: LevelNode) -> void:
	if node == null:
		return
	_graph.nodes.append(node)
	_after_change()

func _default_params(type: String) -> Dictionary:
	match type:
		"stage":
			return {"stage_id": "exploration", "label": ""}
		"condition":
			return {"key": "", "op": "==", "value": "true", "monitor": true}
		"action":
			return {"key": "", "op": "set", "value": "true"}
		"event":
			return {"event_path": "", "trigger": "interact", "wait": true}
		"merge_and":
			return {"required": 0}
		"end":
			return {"completed_key": ""}
	return {}

func _view_center() -> Vector2:
	if _graph_edit == null:
		return Vector2.ZERO
	var zoom := maxf(_graph_edit.zoom, 0.05)
	var offset := _graph_edit.scroll_offset
	return (Vector2(-offset.x, -offset.y) + _graph_edit.size * 0.5) / zoom

# ── 选中与参数 ───────────────────────────────────────────

func _on_node_selected(node: Node) -> void:
	if _graph == null or not (node is GraphNode):
		return
	_select_node(_graph.node_by_id(StringName(node.name)))

func _on_node_deselected(_node: Node) -> void:
	_selected = null
	_rebuild_params()
	_update_toolbar()

func _select_node(node: LevelNode) -> void:
	_selected = node
	_rebuild_params()
	_update_toolbar()

func _rebuild_params() -> void:
	if _params_box == null:
		return
	for child in _params_box.get_children():
		_params_box.remove_child(child)
		child.queue_free()

	if _selected == null:
		var hint := Label.new()
		hint.text = L10n.ui("graph.params.empty")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
		_params_box.add_child(hint)
		return

	var title := Label.new()
	title.text = "%s　[%s]" % [L10n.ui("graph.node." + _selected.type), String(_selected.node_id)]
	title.add_theme_font_size_override("font_size", 13)
	_params_box.add_child(title)

	for field in _fields_of(_selected.type):
		var name := str(field.get("name", ""))
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.text = L10n.ui(str(field.get("label", "")))
		label.add_theme_font_size_override("font_size", 11)
		row.add_child(label)
		row.add_child(_make_control(_selected, name, str(field.get("type", "text")), field))
		var hint_key := str(field.get("hint", ""))
		if hint_key != "":
			var hint := Label.new()
			hint.text = L10n.ui(hint_key)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_font_size_override("font_size", 10)
			hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
			row.add_child(hint)
		_params_box.add_child(row)

	var enabled_check := CheckBox.new()
	enabled_check.text = L10n.ui("graph.enabled")
	enabled_check.button_pressed = _selected.enabled
	enabled_check.toggled.connect(func(pressed: bool) -> void:
		_selected.enabled = pressed
		_mark_dirty()
		_rebuild_view()
	)
	_params_box.add_child(enabled_check)

func _fields_of(type: String) -> Array:
	match type:
		"stage":
			return [
				{"name": "stage_id", "label": "param.stage_id", "type": "text"},
				{"name": "label", "label": "param.stage_label", "type": "text"},
			]
		"condition":
			return [
				{"name": "key", "label": "param.state", "type": "state"},
				{"name": "op", "label": "param.op", "type": "op"},
				{"name": "value", "label": "param.value", "type": "state_value"},
				{"name": "monitor", "label": "param.monitor", "type": "bool"},
			]
		"action":
			return [
				{"name": "key", "label": "param.state", "type": "state"},
				{"name": "op", "label": "param.action_op", "type": "option", "options": ["set", "add", "toggle"]},
				{"name": "value", "label": "param.value", "type": "state_value"},
			]
		"event":
			return [
				{"name": "event_path", "label": "param.event_path", "type": "event_path"},
				{"name": "trigger", "label": "param.trigger", "type": "option",
					"options": ["interact", "autorun", "call", "touch"],
					"hint": "param.event_trigger_hint"},
				{"name": "wait", "label": "param.wait", "type": "bool"},
			]
		"merge_and":
			return [{"name": "required", "label": "param.required", "type": "int"}]
		"end":
			return [{"name": "completed_key", "label": "param.completed_key", "type": "text"}]
	return []

func _make_control(node: LevelNode, name: String, type: String, field: Dictionary) -> Control:
	var current: Variant = node.get_param(name, _default_params(node.type).get(name, ""))

	match type:
		"bool":
			var check := CheckBox.new()
			check.button_pressed = bool(current)
			check.toggled.connect(func(pressed: bool) -> void:
				_change_param(node, name, pressed)
			)
			return check
		"int":
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = 999
			spin.step = 1
			spin.value = float(current) if current is int or current is float else 0.0
			spin.value_changed.connect(func(value: float) -> void:
				_change_param(node, name, int(value))
			)
			return spin
		"op":
			var option := OptionButton.new()
			var ops := ["==", "!=", ">", ">=", "<", "<="]
			for op in ops:
				option.add_item(op)
			option.selected = max(0, ops.find(str(current)))
			option.item_selected.connect(func(index: int) -> void:
				_change_param(node, name, ops[index])
			)
			return option
		"option":
			var option := OptionButton.new()
			var options: Array = field.get("options", [])
			for item in options:
				option.add_item(str(item))
			option.selected = max(0, options.find(str(current)))
			option.item_selected.connect(func(index: int) -> void:
				_change_param(node, name, str(options[index]))
			)
			return option
		"state_value":
			var key_type := StateCatalogStore.type_of(str(node.params.get("key", "")))
			if key_type == "bool":
				var choice := OptionButton.new()
				choice.add_item(L10n.ui("debug.value_true"))
				choice.add_item(L10n.ui("debug.value_false"))
				var wanted: Variant = current
				if wanted is String:
					wanted = ValueParser.parse(wanted)
				choice.selected = 0 if bool(wanted) else 1
				choice.item_selected.connect(func(index: int) -> void:
					_change_param(node, name, index == 0)
				)
				return choice
			var fallback := LineEdit.new()
			fallback.text = str(current)
			fallback.text_changed.connect(func(value: String) -> void:
				_change_param(node, name, value)
			)
			return fallback
		"state":
			var selector := StateSelector.new()
			selector.set_key(str(current))
			selector.state_changed.connect(func(value: String) -> void:
				_change_param(node, name, value)
			)
			return selector
		"event_path":
			var box := HBoxContainer.new()
			var edit := LineEdit.new()
			edit.text = str(current)
			edit.placeholder_text = "res://…"
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text_changed.connect(func(value: String) -> void:
				_change_param(node, name, value)
			)
			box.add_child(edit)
			var browse := Button.new()
			browse.text = "…"
			browse.pressed.connect(func() -> void:
				_open_file_dialog(edit, node, name)
			)
			box.add_child(browse)
			return box
		_:
			var edit := LineEdit.new()
			edit.text = str(current)
			edit.text_changed.connect(func(value: String) -> void:
				_change_param(node, name, value)
			)
			return edit

func _change_param(node: LevelNode, key: String, value: Variant) -> void:
	if _loading or node == null:
		return
	if node.params.get(key) == value:
		return
	node.params[key] = value
	node.emit_changed()
	_mark_dirty()

	var undo := _undo_redo()
	if undo == null:
		return
	undo.create_action(
		"%s:%s:%d" % [L10n.ui("graph.undo.param"), key, node.get_instance_id()],
		UndoRedo.MERGE_ENDS,
		_graph
	)
	undo.add_do_method(self, "_apply_param", node, key, value)
	undo.add_undo_method(self, "_apply_param", node, key, node.params.get(key, null))
	undo.commit_action(false)

	# 摘要要实时更新
	var view: GraphNode = _node_views.get(node.node_id, null)
	if view != null and view.get_child_count() > 0:
		var summary := view.get_child(0) as Label
		if summary != null:
			summary.text = _summary_of(node)

func _apply_param(node: LevelNode, key: String, value: Variant) -> void:
	if node == null:
		return
	node.params[key] = value
	node.emit_changed()
	_mark_dirty()
	_rebuild_view()
	_rebuild_params()

func _mark_dirty() -> void:
	if _graph != null:
		_graph.emit_changed()

# ── 新建 / 状态库 / 检查 ────────────────────────────────

func _on_new_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "res://")
	dialog.title = L10n.ui("graph.new")
	dialog.file_selected.connect(func(path: String) -> void:
		_create_graph_at(path)
		dialog.queue_free()
	)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(760, 520))

func _create_graph_at(path: String) -> void:
	var graph := LevelGraph.new()
	graph.graph_id = StringName(path.get_file().get_basename())
	graph.level_id = graph.graph_id
	var start := LevelNode.new()
	start.node_id = graph.next_node_id("start")
	start.type = "start"
	start.position = Vector2(40, 60)
	graph.nodes.append(start)
	graph.entry_node = start.node_id
	var error := ResourceSaver.save(graph, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		_status_label.text = L10n.ui("graph.status.save_failed", {"code": error})
		return
	graph.take_over_path(path)
	open_graph(graph)

func _on_state_library_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := StateLibraryDialog.new()
	add_child(dialog)
	dialog.state_saved.connect(func(_key: String) -> void:
		_rebuild_params()
		_rebuild_view()
	)
	dialog.open_catalog()

func _validate_graph() -> void:
	if _check_label == null:
		return
	if _graph == null:
		_check_label.text = ""
		return
	var issues: Array[String] = []
	if _graph.entry() == null:
		issues.append(L10n.ui("graph.validate.no_start"))
	for node in _graph.nodes:
		if node == null:
			continue
		match node.type:
			"condition":
				if str(node.params.get("key", "")).strip_edges() == "":
					issues.append(L10n.ui("graph.validate.condition", {"node": String(node.node_id)}))
			"action":
				if str(node.params.get("key", "")).strip_edges() == "":
					issues.append(L10n.ui("graph.validate.action", {"node": String(node.node_id)}))
			"event":
				var path := str(node.params.get("event_path", ""))
				if path == "" or not ResourceLoader.exists(path):
					issues.append(L10n.ui("graph.validate.event", {"node": String(node.node_id)}))
			"stage":
				if str(node.params.get("stage_id", "")).strip_edges() == "":
					issues.append(L10n.ui("graph.validate.stage", {"node": String(node.node_id)}))

	if issues.is_empty():
		_check_label.text = L10n.ui("graph.validate.ok")
		_check_label.add_theme_color_override("font_color", Color(0.55, 0.8, 0.6))
	else:
		var joined := PackedStringArray()
		for issue in issues:
			joined.append(issue)
		_check_label.text = L10n.ui("graph.validate.issues", {"count": issues.size(), "list": "；".join(joined)})
		_check_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))

# ── 保存 / 打开 ──────────────────────────────────────────

func _on_save_pressed() -> void:
	if _graph == null:
		return
	if _graph.resource_path == "":
		_status_label.text = L10n.ui("graph.status.no_path")
		return
	_validate_graph()
	var error := ResourceSaver.save(_graph, _graph.resource_path)
	if error == OK:
		_status_label.text = L10n.ui("graph.status.saved", {"path": _graph.resource_path})
		_toast(L10n.ui("graph.toast.saved"))
	else:
		_status_label.text = L10n.ui("graph.status.save_failed", {"code": error})

func _on_open_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "res://")
	dialog.file_selected.connect(func(path: String) -> void:
		var graph := load(path) as LevelGraph
		if graph != null:
			open_graph(graph)
		dialog.queue_free()
	)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(760, 520))

func _open_file_dialog(edit: LineEdit, node: LevelNode, key: String) -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "res://")
	dialog.file_selected.connect(func(path: String) -> void:
		edit.text = path
		_change_param(node, key, path)
		dialog.queue_free()
	)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(720, 480))

func _toast(message: String) -> void:
	if not Engine.is_editor_hint():
		return
	var toaster := EditorInterface.get_editor_toaster()
	if toaster != null:
		toaster.push_toast(message, EditorToaster.SEVERITY_INFO)

# ── 杂项 ─────────────────────────────────────────────────

func _update_toolbar() -> void:
	if _delete_button != null:
		_delete_button.disabled = _selected == null
	if _add_button != null:
		_add_button.disabled = _graph == null
	if _save_button != null:
		_save_button.disabled = _graph == null

func _undo_redo() -> EditorUndoRedoManager:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_editor_undo_redo()
