extends SceneTree
## 关卡图编辑器冒烟测试（不需要真正打开编辑器窗口）：
##   godot --headless --path . --script res://tests/graph_editor_smoke.gd

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Node.new()
	host.name = "GraphEditorHost"
	root.add_child(host)

	var panel: Control = load("res://addons/rpgeventstudio/editor/level_graph/level_graph_view.gd").new()
	host.add_child(panel)
	await process_frame

	var graph: LevelGraph = load("res://addons/rpgeventstudio/samples/graphs/school_graph.tres")
	_check(graph != null, "示例关卡图应能加载")
	if graph == null:
		_report()
		quit(1)
		return

	panel.call("open_graph", graph)
	await process_frame

	var views: Dictionary = panel.get("_node_views")
	_check(views.size() == graph.nodes.size(), "画布节点数应与数据一致（%d / %d）" % [views.size(), graph.nodes.size()])
	_check(graph.connections.size() == 6, "示例关卡图应有 6 条连线（实际 %d）" % graph.connections.size())

	# 新增节点
	var before_nodes := graph.nodes.size()
	panel.call("_on_add_node_pressed", _id_of(panel, "action"))
	_check(graph.nodes.size() == before_nodes + 1, "添加节点后数据 +1")
	_check(panel.get("_selected") != null, "新节点应自动选中")
	var new_node: LevelNode = panel.get("_selected")

	# 改参数
	panel.call("_change_param", new_node, "key", "Global.EditorTest")
	_check(str(new_node.params.get("key", "")) == "Global.EditorTest", "参数应写入数据")

	# 连线：从「开始」连到新节点
	var start_node := graph.entry()
	panel.call("_on_connection_request", start_node.node_id, 0, new_node.node_id, 0)
	_check(graph.outgoing(start_node.node_id, "out").size() == 2, "新增连线应写入数据")

	# 连线不能连回起点
	var before_connections := graph.connections.size()
	panel.call("_on_connection_request", new_node.node_id, 0, start_node.node_id, 0)
	_check(graph.connections.size() == before_connections, "不允许连到「开始」节点")

	# 保存 / 重新读取
	var path := "res://.godot/test_graph_roundtrip.tres"
	_check(ResourceSaver.save(graph, path) == OK, "关卡图应能保存")
	var reloaded: LevelGraph = load(path)
	_check(reloaded != null and reloaded.nodes.size() == graph.nodes.size(), "重新读取后节点数一致")
	if reloaded != null:
		_check(reloaded.connections.size() == graph.connections.size(), "重新读取后连线数一致")
		var reloaded_node := reloaded.node_by_id(new_node.node_id)
		_check(reloaded_node != null and str(reloaded_node.params.get("key", "")) == "Global.EditorTest", "重新读取后参数保留")

	# 删除节点（连带连线）
	var removed_id := new_node.node_id
	panel.call("_on_delete_nodes_request", [removed_id])
	_check(graph.node_by_id(removed_id) == null, "删除后节点不存在")
	_check(graph.outgoing(start_node.node_id, "out").size() == 1, "删除节点应连带删掉它的连线")

	# 运行高亮
	var condition := _first_of_type(graph, "condition")
	var basement_stage := _stage_node(graph, "basement")
	_check(condition != null and basement_stage != null, "示例图里应有条件和地下室阶段节点")
	if condition != null and basement_stage != null:
		var labels: Dictionary = panel.get("_summary_labels")
		panel.call("apply_debug_node", "school", condition.node_id, 1)
		var label: Label = labels.get(condition.node_id)
		_check(label != null and label.text.begins_with("▶"), "运行中的节点应显示 ▶")
		panel.call("apply_debug_node", "school", condition.node_id, 2)
		_check(label != null and label.text.begins_with("✓"), "完成的节点应显示 ✓")
		panel.call("apply_debug_stage", "school", "basement")
		var stage_label: Label = labels.get(basement_stage.node_id)
		_check(stage_label != null and stage_label.text.begins_with("●"), "当前阶段应显示 ●")
		panel.call("apply_debug_node", "another_graph", condition.node_id, 1)
		_check(label != null and label.text.begins_with("✓"), "其它图的消息应被忽略")

	DirAccess.remove_absolute(path)
	_report()
	quit(0 if _failures.is_empty() else 1)

func _first_of_type(graph: LevelGraph, type: String) -> LevelNode:
	for node in graph.nodes:
		if node != null and node.type == type:
			return node
	return null

func _stage_node(graph: LevelGraph, stage_id: String) -> LevelNode:
	for node in graph.nodes:
		if node != null and node.type == "stage" and str(node.params.get("stage_id", "")) == stage_id:
			return node
	return null

func _id_of(panel: Control, type: String) -> int:
	var ids: Dictionary = panel.get("_add_ids")
	for id in ids.keys():
		if str(ids[id]) == type:
			return int(id)
	return -1

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 关卡图编辑器测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
