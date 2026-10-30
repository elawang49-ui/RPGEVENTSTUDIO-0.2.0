@tool
extends VBoxContainer
## 关卡总控图编辑器（编辑器主屏）。
##
## 结构：工具栏 → GraphEdit 画布 + 右侧节点参数；底部可选的检查结果面板。
## 数据仍然是 LevelGraph 资源；GraphEdit 只是视图，所有改动都写回资源并登记撤销。
## 分组框用 Godot 原生 GraphFrame，只持久化外观与成员关系，不影响运行时执行语义。

const LEVEL_PREFIX := "School"   # 与运行时 StateStore 的默认前缀一致，仅供校验解析状态键

var _plugin: EditorPlugin
var _graph: LevelGraph
var _selected: LevelNode
var _selected_group: LevelGroup

var _title_label: Label
var _add_button: MenuButton
var _delete_button: Button
var _save_button: Button
var _open_button: Button
var _new_button: Button
var _state_library_button: Button
var _check_button: Button
var _layout_button: MenuButton
var _group_button: MenuButton
var _highlight_check: CheckButton
var _check_label: Label
var _graph_edit: GraphEdit
var _params_box: VBoxContainer
var _status_label: Label
var _empty_hint: Label

var _check_panel: PanelContainer
var _check_tree: Tree
var _check_summary: Label
var _save_confirm: ConfirmationDialog

var _node_views: Dictionary = {}   ## StringName -> GraphNode
var _frame_views: Dictionary = {}  ## StringName(分组 id) -> GraphFrame
var _summary_labels: Dictionary = {}  ## StringName -> Label
var _runtime_states: Dictionary = {}  ## StringName -> int
var _current_stage := ""
var _highlight_enabled := true
var _add_ids: Dictionary = {}
var _layout_ids: Dictionary = {}
var _group_action_ids: Dictionary = {}
var _loading := false

var _issues: Array[GraphIssue] = []
var _issues_by_node: Dictionary = {}   ## StringName -> true（有错误或警告的节点）

var _dragging := false
var _drag_positions: Dictionary = {}   ## node_id -> Vector2（拖动前的位置快照）
var _drag_frames: Dictionary = {}      ## group_id -> [Vector2, Vector2]

const GROUP_COLORS: Array[Color] = [
	Color(0.35, 0.55, 0.85, 0.14),
	Color(0.45, 0.75, 0.45, 0.14),
	Color(0.85, 0.65, 0.30, 0.15),
	Color(0.75, 0.45, 0.70, 0.15),
	Color(0.40, 0.72, 0.72, 0.14),
	Color(0.85, 0.45, 0.45, 0.13),
]

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
	_selected_group = null
	_runtime_states.clear()
	_current_stage = ""
	_issues.clear()
	_issues_by_node.clear()
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

	_check_button = Button.new()
	_check_button.text = L10n.ui("graph.check")
	_check_button.pressed.connect(_on_check_pressed)
	toolbar.add_child(_check_button)

	_layout_button = MenuButton.new()
	_layout_button.text = L10n.ui("graph.layout")
	_layout_button.tooltip_text = L10n.ui("graph.layout.tip")
	toolbar.add_child(_layout_button)

	_group_button = MenuButton.new()
	_group_button.text = L10n.ui("graph.group")
	_group_button.tooltip_text = L10n.ui("graph.group.tip")
	toolbar.add_child(_group_button)

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
	_graph_edit.begin_node_move.connect(_on_begin_node_move)
	_graph_edit.end_node_move.connect(_on_end_node_move)
	_graph_edit.graph_elements_linked_to_frame_request.connect(_on_elements_linked_to_frame)
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

	_build_check_panel()

	_check_label = Label.new()
	_check_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_check_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_check_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)

	_rebuild_add_menu()
	_rebuild_layout_menu()
	_rebuild_group_menu()

## 检查结果面板（默认收起，点工具栏「检查」展开）。
func _build_check_panel() -> void:
	_check_panel = PanelContainer.new()
	_check_panel.visible = false
	add_child(_check_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_check_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var title := Label.new()
	title.text = L10n.ui("graph.check.title")
	title.add_theme_font_size_override("font_size", 12)
	header.add_child(title)

	_check_summary = Label.new()
	_check_summary.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_check_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_check_summary)

	var rerun := Button.new()
	rerun.text = L10n.ui("graph.check.rerun")
	rerun.pressed.connect(_on_check_pressed)
	header.add_child(rerun)

	var close := Button.new()
	close.text = L10n.ui("graph.check.close")
	close.pressed.connect(func() -> void: _check_panel.visible = false)
	header.add_child(close)

	_check_tree = Tree.new()
	_check_tree.columns = 5
	_check_tree.column_titles_visible = true
	_check_tree.set_column_title(0, L10n.ui("graph.check.column.severity"))
	_check_tree.set_column_title(1, L10n.ui("graph.check.column.node"))
	_check_tree.set_column_title(2, L10n.ui("graph.check.column.id"))
	_check_tree.set_column_title(3, L10n.ui("graph.check.column.message"))
	_check_tree.set_column_title(4, L10n.ui("graph.check.column.suggestion"))
	_check_tree.set_column_expand(0, false)
	_check_tree.set_column_custom_minimum_width(0, 52)
	_check_tree.set_column_expand(2, false)
	_check_tree.set_column_custom_minimum_width(2, 100)
	_check_tree.set_column_expand(3, true)
	_check_tree.set_column_expand(4, true)
	_check_tree.custom_minimum_size = Vector2(0, 170)
	_check_tree.item_activated.connect(_on_issue_activated)
	box.add_child(_check_tree)

func _show_empty() -> void:
	_title_label.text = L10n.ui("graph.title")
	_empty_hint.visible = true
	_status_label.text = L10n.ui("graph.no_graph")
	_rebuild_params()

func _exit_tree() -> void:
	_detach_all_frames()

## 释放分组框前先摘掉挂接，避免 GraphEdit 在节点销毁时 move_child 到已移除节点。
func _detach_all_frames() -> void:
	if _graph_edit == null:
		return
	for group_id in _frame_views.keys():
		for member in _graph_edit.get_attached_nodes_of_frame(String(group_id)):
			_graph_edit.detach_graph_element_from_frame(member)

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
	# 先摘掉所有分组挂接：GraphFrame 仍挂着节点时直接 free，
	# GraphEdit 内部会 move_child 到已不属于它的节点并报「Child is not a child」。
	_detach_all_frames()
	for child in _graph_edit.get_children():
		if child is GraphNode or child is GraphFrame:
			child.free()
	_node_views.clear()
	_frame_views.clear()
	_summary_labels.clear()

	if _graph == null:
		_empty_hint.visible = true
		_loading = false
		return
	_empty_hint.visible = false

	# 分组框先建（垫在节点下面），再建节点，最后按模型挂接成员。
	for group in _graph.groups:
		if group != null:
			_frame_views[group.group_id] = _make_frame_view(group)
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
	for group in _graph.groups:
		if group == null:
			continue
		for member_id in group.member_ids:
			if _node_views.has(member_id):
				_graph_edit.attach_graph_element_to_frame(String(member_id), String(group.group_id))

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
	summary.add_theme_font_size_override("font_size", UiFonts.NOTE)
	summary.add_theme_color_override("font_color", Color(0.78, 0.80, 0.86))
	view.add_child(summary)

	var has_output := node.type != "end"
	view.set_slot(0, node.type != "start", 0, Color(0.55, 0.75, 1.0), has_output, 0, Color(0.85, 0.72, 0.45))

	if node.type == "condition":
		var else_label := Label.new()
		else_label.text = L10n.ui("graph.port.else")
		else_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
		else_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.55))
		view.add_child(else_label)
		view.set_slot(1, false, 0, Color(), true, 0, Color(0.9, 0.55, 0.5))
	elif node.type == "event":
		view.set_slot(0, true, 0, Color(0.55, 0.75, 1.0), true, 0, Color(0.85, 0.72, 0.45))

	_summary_labels[node.node_id] = summary
	_graph_edit.add_child(view)
	_apply_marker(node)
	return view

func _make_frame_view(group: LevelGroup) -> GraphFrame:
	var view := GraphFrame.new()
	view.name = String(group.group_id)
	view.title = group.title
	view.position_offset = group.position
	view.size = group.size
	view.resizable = true
	view.autoshrink_enabled = false
	view.tint_color_enabled = true
	view.tint_color = group.color
	view.position_offset_changed.connect(_on_frame_position_changed.bind(group))
	view.resize_end.connect(_on_frame_resize_end.bind(group))
	_graph_edit.add_child(view)
	return view

func _summary_of(node: LevelNode) -> String:
	var text := node.describe()
	if node.type == "event" and text == "":
		text = "—"
	if not node.enabled:
		text = L10n.ui("graph.disabled")
	elif _issues_by_node.has(node.node_id):
		text = "⚠ " + text
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
	elif _issues_by_node.has(node.node_id):
		color = Color(0.95, 0.7, 0.45)
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
	var node_ids: Array = []
	var group_ids: Array = []
	for item in nodes:
		var id := StringName(item)
		if _frame_views.has(id):
			group_ids.append(id)   # 删除分组只拆框，不动里面的节点
		else:
			node_ids.append(id)
	if not group_ids.is_empty():
		_delete_groups(group_ids)
	if not node_ids.is_empty():
		_delete_nodes(node_ids)

func _on_delete_selected() -> void:
	if _selected_group != null:
		_delete_groups([_selected_group.group_id])
		_selected_group = null
		_rebuild_params()
		return
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
	var membership: Array = []   # [[group_id, 原成员列表], …] 供撤销恢复
	for node_id in ids:
		var node := _graph.node_by_id(StringName(node_id))
		if node == null:
			continue
		for connection in _graph.connections:
			if connection != null and (connection.from_node == StringName(node_id) or connection.to_node == StringName(node_id)):
				removed_connections.append(connection)
		for group in _graph.groups:
			if group != null and group.contains(StringName(node_id)):
				membership.append([group.group_id, group.member_ids.duplicate()])
		removed_nodes.append(node)

	var undo := _undo_redo()
	if undo == null:
		for node in removed_nodes:
			_graph.remove_node(node.node_id)
		_after_change()
		return
	undo.create_action(L10n.ui("graph.undo.delete"), UndoRedo.MERGE_DISABLE, _graph)
	undo.add_do_method(self, "_do_remove_nodes", removed_nodes)
	undo.add_undo_method(self, "_do_restore", removed_nodes, removed_connections, membership)
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

func _do_restore(nodes: Array, connections: Array, membership: Array) -> void:
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
	for entry in membership:
		if entry.size() < 2:
			continue
		var group := _graph.group_by_id(entry[0])
		if group == null:
			continue
		for member_id in entry[1]:
			group.add_member(member_id)
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

# ── 移动 / 撤销 ──────────────────────────────────────────

func _on_begin_node_move() -> void:
	if _graph == null or _loading:
		return
	_dragging = true
	_drag_positions = _capture_positions()
	_drag_frames = _capture_frame_rects()

func _on_end_node_move() -> void:
	if _graph == null or _loading:
		_dragging = false
		return
	_dragging = false
	var new_positions := _capture_positions()
	var new_frames := _capture_frame_rects()
	if _differs(new_positions, _drag_positions) or _differs(new_frames, _drag_frames):
		var undo := _undo_redo()
		if undo == null:
			_apply_positions(new_positions)
			_apply_frame_rects(new_frames)
		else:
			undo.create_action(L10n.ui("graph.undo.move"), UndoRedo.MERGE_DISABLE, _graph)
			undo.add_do_method(self, "_apply_positions", new_positions)
			undo.add_do_method(self, "_apply_frame_rects", new_frames)
			# 快照必须以副本绑定：本方法末尾会 clear() 变量，而 UndoRedo 只保存引用，
			# 直接传原字典会让撤销拿到空表（撤销无效，重做却正常）。
			undo.add_undo_method(self, "_apply_positions", _drag_positions.duplicate())
			undo.add_undo_method(self, "_apply_frame_rects", _drag_frames.duplicate())
			undo.commit_action()
	_drag_positions.clear()
	_drag_frames.clear()
	_reconcile_group_members()

func _capture_positions() -> Dictionary:
	var snapshot := {}
	for node in _graph.nodes:
		if node == null:
			continue
		var view: GraphNode = _node_views.get(node.node_id, null)
		snapshot[node.node_id] = view.position_offset if view != null else node.position
	return snapshot

func _capture_frame_rects() -> Dictionary:
	var snapshot := {}
	for group in _graph.groups:
		if group == null:
			continue
		var view: GraphFrame = _frame_views.get(group.group_id, null)
		if view != null:
			snapshot[group.group_id] = [view.position_offset, view.size]
		else:
			snapshot[group.group_id] = [group.position, group.size]
	return snapshot

func _differs(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return true
	for key in a:
		if not b.has(key) or a[key] != b[key]:
			return true
	return false

## 把一批节点位置同时写进数据与视图（撤销 / 重做的公共出口）。
func _apply_positions(map: Dictionary) -> void:
	if _graph == null:
		return
	for node_id in map:
		var node := _graph.node_by_id(node_id)
		if node != null:
			node.position = map[node_id]
		var view: GraphNode = _node_views.get(node_id, null)
		if view != null:
			view.position_offset = map[node_id]
	_graph.emit_changed()

func _apply_frame_rects(map: Dictionary) -> void:
	if _graph == null:
		return
	for group_id in map:
		var group := _graph.group_by_id(group_id)
		var rect: Array = map[group_id]
		if group != null:
			group.position = rect[0]
			group.size = rect[1]
		var view: GraphFrame = _frame_views.get(group_id, null)
		if view != null:
			view.position_offset = rect[0]
			view.size = rect[1]
	_graph.emit_changed()

# ── 分组 ─────────────────────────────────────────────────

func _on_frame_position_changed(group: LevelGroup) -> void:
	if _graph == null or group == null:
		return
	var view: GraphFrame = _frame_views.get(group.group_id, null)
	if view != null:
		group.position = view.position_offset

func _on_frame_resize_end(group: LevelGroup, new_size: Vector2) -> void:
	if _graph == null or group == null or _loading:
		return
	var view: GraphFrame = _frame_views.get(group.group_id, null)
	if view == null:
		return
	var old_rect: Array = [group.position, group.size]
	var new_rect: Array = [view.position_offset, new_size]
	if old_rect[0] == new_rect[0] and old_rect[1] == new_rect[1]:
		return
	var undo := _undo_redo()
	if undo == null:
		group.position = new_rect[0]
		group.size = new_rect[1]
		_mark_dirty()
		return
	undo.create_action(L10n.ui("graph.undo.frame_resize"), UndoRedo.MERGE_DISABLE, _graph)
	undo.add_do_method(self, "_apply_frame_rects", {group.group_id: new_rect})
	undo.add_undo_method(self, "_apply_frame_rects", {group.group_id: old_rect})
	undo.commit_action()

func _rebuild_group_menu() -> void:
	if _group_button == null:
		return
	var popup := _group_button.get_popup()
	popup.clear()
	_group_action_ids.clear()
	var id := 0
	for action in ["new_selection", "new"]:
		popup.add_item(L10n.ui("graph.group." + action), id)
		_group_action_ids[id] = action
		id += 1
	if _graph != null:
		for group in _graph.groups:
			if group == null:
				continue
			popup.add_item(L10n.ui("graph.group.add_to", {"name": group.title}), id)
			_group_action_ids[id] = "add:" + String(group.group_id)
			id += 1
	popup.add_item(L10n.ui("graph.group.remove"), id)
	_group_action_ids[id] = "remove"
	id += 1
	popup.add_item(L10n.ui("graph.group.delete"), id)
	_group_action_ids[id] = "delete"
	id += 1
	if not popup.id_pressed.is_connected(_on_group_menu_pressed):
		popup.id_pressed.connect(_on_group_menu_pressed)

func _on_group_menu_pressed(id: int) -> void:
	var action := str(_group_action_ids.get(id, ""))
	if action == "" or _graph == null:
		return
	if action.begins_with("add:"):
		_add_selected_to_group(StringName(action.substr(4)))
		return
	match action:
		"new", "new_selection":
			_create_group(action == "new_selection")
		"remove":
			_remove_selected_from_groups()
		"delete":
			if _selected_group != null:
				_delete_groups([_selected_group.group_id])
				_selected_group = null
				_rebuild_params()

func _selected_node_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if _graph == null:
		return ids
	for node in _graph.nodes:
		if node == null:
			continue
		var view: GraphNode = _node_views.get(node.node_id, null)
		if view != null and view.selected:
			ids.append(node.node_id)
	return ids

func _create_group(from_selection: bool) -> void:
	if _graph == null:
		return
	var ids := _selected_node_ids() if from_selection else []
	var group := LevelGroup.new()
	group.group_id = _graph.next_group_id()
	group.title = L10n.ui("graph.group.default_title")
	group.color = GROUP_COLORS[_graph.groups.size() % GROUP_COLORS.size()]
	if ids.is_empty():
		group.position = _view_center() - Vector2(210, 140)
		group.size = Vector2(420, 280)
	else:
		var min_corner := Vector2(INF, INF)
		var max_corner := Vector2(-INF, -INF)
		for node_id in ids:
			var view: GraphNode = _node_views.get(node_id, null)
			if view == null:
				continue
			min_corner = min_corner.min(view.position_offset)
			max_corner = max_corner.max(view.position_offset + view.size)
		group.position = min_corner - Vector2(48, 48)
		group.size = (max_corner - min_corner) + Vector2(96, 96)
		group.member_ids = ids

	var undo := _undo_redo()
	if undo == null:
		_do_group_add(group)
	else:
		undo.create_action(L10n.ui("graph.undo.group_add"), UndoRedo.MERGE_DISABLE, _graph)
		undo.add_do_method(self, "_do_group_add", group)
		undo.add_undo_method(self, "_do_group_remove", group.group_id)
		undo.add_do_reference(group)
		undo.commit_action()
	var view: GraphFrame = _frame_views.get(group.group_id, null)
	if view != null:
		_graph_edit.set_selected(view)

func _do_group_add(group: LevelGroup) -> void:
	if _graph == null or group == null:
		return
	if _graph.group_by_id(group.group_id) == null:
		_graph.groups.append(group)
	_graph.emit_changed()
	if not _frame_views.has(group.group_id):
		_frame_views[group.group_id] = _make_frame_view(group)
	_sync_group_attachments(group)
	_rebuild_group_menu()
	_update_toolbar()

func _do_group_remove(group_id: StringName) -> void:
	if _graph == null:
		return
	var group := _graph.group_by_id(group_id)
	if group != null:
		_graph.groups.erase(group)
	_graph.emit_changed()
	var view: GraphFrame = _frame_views.get(group_id, null)
	if view != null:
		for member in _graph_edit.get_attached_nodes_of_frame(String(group_id)):
			_graph_edit.detach_graph_element_from_frame(member)
		_frame_views.erase(group_id)
		view.free()
	if _selected_group != null and _selected_group.group_id == group_id:
		_selected_group = null
		_rebuild_params()
	_rebuild_group_menu()
	_update_toolbar()

func _delete_groups(group_ids: Array) -> void:
	if _graph == null or group_ids.is_empty():
		return
	var groups: Array = []
	for group_id in group_ids:
		var group := _graph.group_by_id(StringName(group_id))
		if group != null:
			groups.append(group)
	if groups.is_empty():
		return
	var undo := _undo_redo()
	if undo == null:
		for group in groups:
			_do_group_remove(group.group_id)
		return
	undo.create_action(L10n.ui("graph.undo.group_delete"), UndoRedo.MERGE_DISABLE, _graph)
	for group in groups:
		undo.add_do_method(self, "_do_group_remove", group.group_id)
		undo.add_undo_method(self, "_do_group_add", group)
		undo.add_do_reference(group)
	undo.commit_action()

func _add_selected_to_group(group_id: StringName) -> void:
	var group := _graph.group_by_id(group_id) if _graph != null else null
	if group == null:
		return
	var ids := _selected_node_ids()
	var new_members := group.member_ids.duplicate()
	for node_id in ids:
		if not new_members.has(node_id):
			new_members.append(node_id)
	_commit_group_members(group, new_members)

func _remove_selected_from_groups() -> void:
	if _graph == null:
		return
	var ids := _selected_node_ids()
	for group in _graph.groups:
		if group == null:
			continue
		var new_members := group.member_ids.duplicate()
		for node_id in ids:
			new_members.erase(node_id)
		if new_members.size() != group.member_ids.size():
			_commit_group_members(group, new_members)

func _commit_group_members(group: LevelGroup, new_members: Array) -> void:
	if _graph == null or group == null:
		return
	var old_members := group.member_ids.duplicate()
	if _same_members(old_members, new_members):
		return
	var undo := _undo_redo()
	if undo == null:
		_do_group_members(group.group_id, new_members)
		return
	undo.create_action(L10n.ui("graph.undo.group_members"), UndoRedo.MERGE_DISABLE, _graph)
	undo.add_do_method(self, "_do_group_members", group.group_id, new_members)
	undo.add_undo_method(self, "_do_group_members", group.group_id, old_members)
	undo.commit_action()

func _do_group_members(group_id: StringName, member_ids: Array) -> void:
	if _graph == null:
		return
	var group := _graph.group_by_id(group_id)
	if group == null:
		return
	group.member_ids.clear()
	for member_id in member_ids:
		group.add_member(member_id)
	_sync_group_attachments(group)
	_graph.emit_changed()
	_mark_dirty()

## 把 GraphEdit 上的挂接关系与模型对齐（成员进了模型就挂上，出了模型就摘下）。
func _sync_group_attachments(group: LevelGroup) -> void:
	var frame_name := String(group.group_id)
	var attached := _graph_edit.get_attached_nodes_of_frame(frame_name)
	for member_id in group.member_ids:
		if not attached.has(member_id) and _node_views.has(member_id):
			_graph_edit.attach_graph_element_to_frame(String(member_id), frame_name)
	for member in attached:
		if not group.member_ids.has(member):
			_graph_edit.detach_graph_element_from_frame(member)

## 拖动结束后，把引擎侧的挂接变化写回模型（拖进/拖出分组框的节点随之入组、出组）。
func _reconcile_group_members() -> void:
	if _graph == null or _loading:
		return
	for group in _graph.groups:
		if group == null:
			continue
		var attached := _graph_edit.get_attached_nodes_of_frame(String(group.group_id))
		var wanted: Array[StringName] = []
		for member in attached:
			var member_id := StringName(member)
			if _node_views.has(member_id):
				wanted.append(member_id)
		if _same_members(group.member_ids, wanted):
			continue
		_commit_group_members(group, wanted)

func _same_members(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for item in a:
		if not b.has(item):
			return false
	return true

## 拖放节点到分组框上时引擎发来的挂接请求：入组并登记撤销。
func _on_elements_linked_to_frame(elements: PackedStringArray, frame_id: StringName) -> void:
	if _graph == null or _loading:
		return
	var group := _graph.group_by_id(frame_id)
	if group == null:
		return
	var new_members := group.member_ids.duplicate()
	for element in elements:
		var member_id := StringName(element)
		if not group.contains(member_id) and _node_views.has(member_id):
			new_members.append(member_id)
	_commit_group_members(group, new_members)

# ── 布局辅助 ─────────────────────────────────────────────

func _rebuild_layout_menu() -> void:
	if _layout_button == null:
		return
	var popup := _layout_button.get_popup()
	popup.clear()
	_layout_ids.clear()
	var id := 0
	for action in ["left", "right", "top", "bottom", "h_dist", "v_dist"]:
		popup.add_item(L10n.ui("graph.layout." + action), id)
		_layout_ids[id] = action
		id += 1
	popup.add_separator()
	popup.add_item(L10n.ui("graph.layout.auto"), id)
	_layout_ids[id] = "auto"
	if not popup.id_pressed.is_connected(_on_layout_menu_pressed):
		popup.id_pressed.connect(_on_layout_menu_pressed)

func _on_layout_menu_pressed(id: int) -> void:
	_apply_layout(str(_layout_ids.get(id, "")))

## 对齐 / 分布 / 自动排列。全部走同一条撤销通道：快照前后位置，do/undo 各应用一次。
func _apply_layout(mode: String) -> void:
	if _graph == null or mode == "":
		return
	if mode == "auto":
		_layout_auto()
		return
	var ids := _selected_node_ids()
	var before := _capture_positions()
	var after := _compute_layout(mode, ids, before)
	if after.is_empty():
		_toast(L10n.ui("graph.layout.need_selection"))
		return
	_commit_positions(before, after, L10n.ui("graph.undo.layout"))

func _compute_layout(mode: String, ids: Array[StringName], positions: Dictionary) -> Dictionary:
	var views := {}
	var min_x := INF
	var max_right := -INF
	var min_y := INF
	var max_bottom := -INF
	for node_id in ids:
		var view: GraphNode = _node_views.get(node_id, null)
		if view == null:
			return {}
		views[node_id] = view
		min_x = minf(min_x, view.position_offset.x)
		max_right = maxf(max_right, view.position_offset.x + view.size.x)
		min_y = minf(min_y, view.position_offset.y)
		max_bottom = maxf(max_bottom, view.position_offset.y + view.size.y)

	var after := {}
	match mode:
		"left":
			for node_id in ids:
				after[node_id] = Vector2(min_x, views[node_id].position_offset.y)
		"right":
			for node_id in ids:
				after[node_id] = Vector2(max_right - views[node_id].size.x, views[node_id].position_offset.y)
		"top":
			for node_id in ids:
				after[node_id] = Vector2(views[node_id].position_offset.x, min_y)
		"bottom":
			for node_id in ids:
				after[node_id] = Vector2(views[node_id].position_offset.x, max_bottom - views[node_id].size.y)
		"h_dist", "v_dist":
			if ids.size() < 3:
				return {}
			var horizontal := mode == "h_dist"
			var sorted := ids.duplicate()
			sorted.sort_custom(func(a: StringName, b: StringName) -> bool:
				var pa: Vector2 = views[a].position_offset
				var pb: Vector2 = views[b].position_offset
				return (pa.x if horizontal else pa.y) < (pb.x if horizontal else pb.y)
			)
			var first: GraphNode = views[sorted[0]]
			var last: GraphNode = views[sorted[sorted.size() - 1]]
			# 按中心点等距：首尾保持原位，中间节点均匀插入。
			var span_start: float = first.position_offset.x + first.size.x * 0.5 if horizontal \
					else first.position_offset.y + first.size.y * 0.5
			var span_end: float = last.position_offset.x + last.size.x * 0.5 if horizontal \
					else last.position_offset.y + last.size.y * 0.5
			for index in range(sorted.size()):
				var view: GraphNode = views[sorted[index]]
				var t := float(index) / float(sorted.size() - 1)
				var center := lerpf(span_start, span_end, t)
				if horizontal:
					after[sorted[index]] = Vector2(center - view.size.x * 0.5, view.position_offset.y)
				else:
					after[sorted[index]] = Vector2(view.position_offset.x, center - view.size.y * 0.5)
	return after

func _layout_auto() -> void:
	var before := _capture_positions()
	var before_frames := _capture_frame_rects()
	_graph_edit.arrange_nodes()
	var after := _capture_positions()
	var after_frames := _capture_frame_rects()
	if not _differs(after, before) and not _differs(after_frames, before_frames):
		return
	var undo := _undo_redo()
	if undo == null:
		_apply_positions(after)
		_apply_frame_rects(after_frames)
		return
	undo.create_action(L10n.ui("graph.undo.layout"), UndoRedo.MERGE_DISABLE, _graph)
	undo.add_do_method(self, "_apply_positions", after)
	undo.add_do_method(self, "_apply_frame_rects", after_frames)
	undo.add_undo_method(self, "_apply_positions", before)
	undo.add_undo_method(self, "_apply_frame_rects", before_frames)
	undo.commit_action()

func _commit_positions(before: Dictionary, after: Dictionary, action_name: String) -> void:
	var undo := _undo_redo()
	if undo == null:
		_apply_positions(after)
		return
	undo.create_action(action_name, UndoRedo.MERGE_DISABLE, _graph)
	undo.add_do_method(self, "_apply_positions", after)
	undo.add_undo_method(self, "_apply_positions", before)
	undo.commit_action()

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
	if _graph == null:
		return
	if node is GraphFrame:
		_selected = null
		_selected_group = _graph.group_by_id(StringName(node.name))
		_rebuild_params()
		_update_toolbar()
		return
	if not (node is GraphNode):
		return
	_selected_group = null
	_select_node(_graph.node_by_id(StringName(node.name)))

func _on_node_deselected(_node: Node) -> void:
	_selected = null
	_selected_group = null
	_rebuild_params()
	_update_toolbar()

func _select_node(node: LevelNode) -> void:
	_selected = node
	_selected_group = null
	_rebuild_params()
	_update_toolbar()

func _rebuild_params() -> void:
	if _params_box == null:
		return
	for child in _params_box.get_children():
		_params_box.remove_child(child)
		child.queue_free()

	if _selected_group != null:
		_build_group_params()
		return

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

	var group := _graph.group_of(_selected.node_id) if _graph != null else null
	if group != null:
		var group_label := Label.new()
		group_label.text = L10n.ui("graph.group.in_group", {"name": group.title})
		group_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
		group_label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.9))
		_params_box.add_child(group_label)

	for field in _fields_of(_selected.type):
		var name := str(field.get("name", ""))
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.text = L10n.ui(str(field.get("label", "")))
		label.add_theme_font_size_override("font_size", UiFonts.NOTE)
		row.add_child(label)
		row.add_child(_make_control(_selected, name, str(field.get("type", "text")), field))
		var hint_key := str(field.get("hint", ""))
		if hint_key != "":
			var hint := Label.new()
			hint.text = L10n.ui(hint_key)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_font_size_override("font_size", UiFonts.NOTE)
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

## 选中分组框时的参数面板：改名、调色、看成员、删除分组（大小直接拖边框）。
func _build_group_params() -> void:
	var group := _selected_group
	var title := Label.new()
	title.text = "%s　[%s]" % [L10n.ui("graph.group"), String(group.group_id)]
	title.add_theme_font_size_override("font_size", 13)
	_params_box.add_child(title)

	var name_label := Label.new()
	name_label.text = L10n.ui("graph.group.title_label")
	name_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_params_box.add_child(name_label)

	var name_edit := LineEdit.new()
	name_edit.text = group.title
	name_edit.text_changed.connect(func(value: String) -> void:
		_change_group_property(group, "title", value)
	)
	_params_box.add_child(name_edit)

	var color_label := Label.new()
	color_label.text = L10n.ui("graph.group.color")
	color_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_params_box.add_child(color_label)

	var color_picker := ColorPickerButton.new()
	color_picker.color = group.color
	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.color_changed.connect(func(value: Color) -> void:
		_change_group_property(group, "color", value)
	)
	_params_box.add_child(color_picker)

	var member_label := Label.new()
	member_label.text = L10n.ui("graph.group.members", {"count": group.member_ids.size()})
	member_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	member_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	_params_box.add_child(member_label)

	var resize_hint := Label.new()
	resize_hint.text = L10n.ui("graph.group.resize_hint")
	resize_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resize_hint.add_theme_font_size_override("font_size", UiFonts.NOTE)
	resize_hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	_params_box.add_child(resize_hint)

	var delete_button := Button.new()
	delete_button.text = L10n.ui("graph.group.delete")
	delete_button.pressed.connect(func() -> void:
		_delete_groups([group.group_id])
		if _selected_group == group:
			_selected_group = null
		_rebuild_params()
	)
	_params_box.add_child(delete_button)

func _change_group_property(group: LevelGroup, prop: String, value: Variant) -> void:
	if _loading or group == null or _graph == null:
		return
	if group.get(prop) == value:
		return
	var old_value: Variant = group.get(prop)
	_do_group_property(group.group_id, prop, value)   # 先立即生效，登记撤销时不再重复执行 do
	var undo := _undo_redo()
	if undo == null:
		return
	undo.create_action("%s:%s:%d" % [L10n.ui("graph.undo.group_prop"), prop, group.get_instance_id()],
		UndoRedo.MERGE_ENDS, _graph)
	undo.add_do_method(self, "_do_group_property", group.group_id, prop, value)
	undo.add_undo_method(self, "_do_group_property", group.group_id, prop, old_value)
	undo.commit_action(false)

func _do_group_property(group_id: StringName, prop: String, value: Variant) -> void:
	if _graph == null:
		return
	var group := _graph.group_by_id(group_id)
	if group == null:
		return
	group.set(prop, value)
	var view: GraphFrame = _frame_views.get(group_id, null)
	if view != null:
		match prop:
			"title":
				view.title = str(value)
			"color":
				view.tint_color_enabled = true
				view.tint_color = value
	_mark_dirty()

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

# ── 新建 / 状态库 ────────────────────────────────────────

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

# ── 静态校验 ─────────────────────────────────────────────

func _on_check_pressed() -> void:
	if _graph == null:
		return
	_run_validation()
	_check_panel.visible = true
	_fill_check_panel()
	_update_check_label()

func _validate_graph() -> void:
	if _check_label == null:
		return
	if _graph == null:
		_issues.clear()
		_issues_by_node.clear()
		_check_label.text = ""
		return
	_run_validation()
	_update_check_label()
	if _check_panel != null and _check_panel.visible:
		_fill_check_panel()

## 跑一遍 GraphValidator，更新节点 ⚠ 标记；不弹界面。
func _run_validation() -> void:
	if _graph == null:
		return
	_issues = GraphValidator.validate(_graph, LEVEL_PREFIX)
	_issues_by_node.clear()
	for issue in _issues:
		if issue.severity >= GraphIssue.Severity.WARNING and issue.node_id != &"":
			_issues_by_node[issue.node_id] = true
	_refresh_markers()

func _update_check_label() -> void:
	if _check_label == null:
		return
	var errors := GraphValidator.count_of(_issues, GraphIssue.Severity.ERROR)
	var warnings := GraphValidator.count_of(_issues, GraphIssue.Severity.WARNING)
	var infos := GraphValidator.count_of(_issues, GraphIssue.Severity.INFO)
	if errors == 0 and warnings == 0 and infos == 0:
		_check_label.text = L10n.ui("graph.check.ok")
		_check_label.add_theme_color_override("font_color", Color(0.55, 0.8, 0.6))
		return
	_check_label.text = L10n.ui("graph.check.label", {"summary": L10n.ui("graph.check.summary",
		{"errors": errors, "warnings": warnings, "infos": infos})})
	if errors > 0:
		_check_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.5))
	elif warnings > 0:
		_check_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))
	else:
		_check_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))

func _fill_check_panel() -> void:
	if _check_tree == null or _check_summary == null:
		return
	_check_tree.clear()
	var errors := GraphValidator.count_of(_issues, GraphIssue.Severity.ERROR)
	var warnings := GraphValidator.count_of(_issues, GraphIssue.Severity.WARNING)
	var infos := GraphValidator.count_of(_issues, GraphIssue.Severity.INFO)
	_check_summary.text = L10n.ui("graph.check.summary", {"errors": errors, "warnings": warnings, "infos": infos})

	var root := _check_tree.create_item()
	# 错误排最前，警告次之，提示最后；同级别保持校验器给出的顺序。
	var ordered := _issues.duplicate()
	ordered.sort_custom(func(a: GraphIssue, b: GraphIssue) -> bool:
		return a.severity > b.severity
	)
	for issue in ordered:
		var item := _check_tree.create_item(root)
		item.set_text(0, issue.severity_label())
		item.set_text(1, issue.node_name)
		item.set_text(2, String(issue.node_id))
		item.set_text(3, issue.message)
		item.set_text(4, issue.suggestion)
		item.set_metadata(0, issue)
		match issue.severity:
			GraphIssue.Severity.ERROR:
				item.set_custom_color(0, Color(0.95, 0.5, 0.45))
			GraphIssue.Severity.WARNING:
				item.set_custom_color(0, Color(0.95, 0.75, 0.4))
			_:
				item.set_custom_color(0, Color(0.65, 0.68, 0.74))

func _on_issue_activated() -> void:
	var item := _check_tree.get_selected()
	if item == null:
		return
	var issue: GraphIssue = item.get_metadata(0)
	if issue == null or issue.node_id == &"":
		return
	_locate_node(issue.node_id)

## 双击问题定位：把画布滚到节点正中并选中它。
func _locate_node(node_id: StringName) -> bool:
	var view: GraphNode = _node_views.get(node_id, null)
	if view == null:
		return false
	_graph_edit.set_selected(view)
	var center: Vector2 = view.position_offset + view.size * 0.5
	var zoom := maxf(_graph_edit.zoom, 0.05)
	_graph_edit.scroll_offset = _graph_edit.size * 0.5 - center * zoom
	_select_node(_graph.node_by_id(node_id))
	return true

# ── 保存 / 打开 ──────────────────────────────────────────

func _on_save_pressed() -> void:
	if _graph == null:
		return
	if _graph.resource_path == "":
		_status_label.text = L10n.ui("graph.status.no_path")
		return
	_run_validation()
	var errors := GraphValidator.count_of(_issues, GraphIssue.Severity.ERROR)
	if errors > 0:
		_check_panel.visible = true
		_fill_check_panel()
		_update_check_label()
		_confirm_save_with_errors(errors)
		return
	_do_save()

## 存在错误时明确提示，不允许静默保存成“看起来没问题”的图。
func _confirm_save_with_errors(error_count: int) -> void:
	if _save_confirm == null:
		_save_confirm = ConfirmationDialog.new()
		_save_confirm.ok_button_text = L10n.ui("graph.check.save_anyway")
		_save_confirm.cancel_button_text = L10n.ui("input.cancel")
		_save_confirm.confirmed.connect(_do_save)
		add_child(_save_confirm)
	_save_confirm.dialog_text = L10n.ui("graph.check.save_blocked", {"count": error_count})
	_save_confirm.popup_centered()

func _do_save() -> void:
	if _graph == null or _graph.resource_path == "":
		return
	_run_validation()
	var errors := GraphValidator.count_of(_issues, GraphIssue.Severity.ERROR)
	var error := ResourceSaver.save(_graph, _graph.resource_path)
	if error == OK:
		if errors > 0:
			_status_label.text = L10n.ui("graph.check.saved_with_errors", {"count": errors})
			_toast(L10n.ui("graph.check.saved_with_errors", {"count": errors}), EditorToaster.SEVERITY_WARNING)
		else:
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

func _toast(message: String, severity: int = EditorToaster.SEVERITY_INFO) -> void:
	if not Engine.is_editor_hint():
		return
	var toaster := EditorInterface.get_editor_toaster()
	if toaster != null:
		toaster.push_toast(message, severity)

# ── 验收辅助（仅供 RPGEVENTSTUDIO_GVL_SHOT 截图演示，不在正常流程调用） ──

## 在内存里把当前图搭成「有错误 + 有分组」的演示状态：不落盘、不影响仓库资源。
func gvl_acceptance_setup() -> void:
	if _graph == null or _graph_edit == null:
		return
	# 演示错误：第二个开始节点 + 没填参数的动作 + 未登记的状态
	var dup_start := LevelNode.new()
	dup_start.node_id = _graph.next_node_id("start")
	dup_start.type = "start"
	dup_start.position = Vector2(40, 520)
	_graph.nodes.append(dup_start)
	var broken := LevelNode.new()
	broken.node_id = _graph.next_node_id("action")
	broken.type = "action"
	broken.position = Vector2(540, 520)
	_graph.nodes.append(broken)
	var unknown := LevelNode.new()
	unknown.node_id = _graph.next_node_id("action")
	unknown.type = "action"
	unknown.params = {"key": "School.DemoUnregistered", "op": "set", "value": "true"}
	unknown.position = Vector2(760, 520)
	_graph.nodes.append(unknown)
	for node in _graph.nodes:
		if node != null and node.type == "stage" and str(node.params.get("stage_id", "")) == "basement":
			_graph.connect_nodes(node.node_id, "out", broken.node_id, "in")
			_graph.connect_nodes(broken.node_id, "out", unknown.node_id, "in")
	_rebuild_view()

	# 两个演示分组：前两个节点一组，汇合往后的三个节点一组
	var first_pair: Array[StringName] = []
	var second_pair: Array[StringName] = []
	for node in _graph.nodes:
		if node == null:
			continue
		if node.type == "start" and first_pair.size() < 1:
			first_pair.append(node.node_id)
		elif node.type == "stage" and first_pair.size() < 2:
			first_pair.append(node.node_id)
		elif node.type == "merge_and" and second_pair.is_empty():
			second_pair.append(node.node_id)
		elif node.type == "action" and second_pair.size() == 1:
			second_pair.append(node.node_id)
		elif node.type == "event" and second_pair.size() == 2:
			second_pair.append(node.node_id)
	for pair in [first_pair, second_pair]:
		for node_id in pair:
			var view: GraphNode = _node_views.get(node_id, null)
			if view != null:
				view.selected = true
		_create_group(true)
	if _graph.groups.size() > 0:
		_do_group_property(_graph.groups[0].group_id, "title", L10n.ui("stage.exploration"))
	if _graph.groups.size() > 1:
		_do_group_property(_graph.groups[1].group_id, "title", L10n.ui("stage.basement"))
		_do_group_property(_graph.groups[1].group_id, "color", GROUP_COLORS[3])

	_run_validation()
	_check_panel.visible = true
	_fill_check_panel()
	_update_check_label()
	# 定位演示：把画布滚到出错节点上
	for issue in _issues:
		if issue.code == "param_missing":
			_locate_node(issue.node_id)
			break

# ── 杂项 ─────────────────────────────────────────────────

func _update_toolbar() -> void:
	if _delete_button != null:
		_delete_button.disabled = _selected == null and _selected_group == null
	if _add_button != null:
		_add_button.disabled = _graph == null
	if _save_button != null:
		_save_button.disabled = _graph == null
	if _check_button != null:
		_check_button.disabled = _graph == null
	if _layout_button != null:
		_layout_button.disabled = _graph == null
	if _group_button != null:
		_group_button.disabled = _graph == null
		_rebuild_group_menu()

func _undo_redo() -> EditorUndoRedoManager:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_editor_undo_redo()
