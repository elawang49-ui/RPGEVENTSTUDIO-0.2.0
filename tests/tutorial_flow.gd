extends SceneTree
## 教程流程验证：完全按「新建状态 → 新建调查事件 → 新建关卡图 → 运行」的操作顺序走一遍，
## 用的都是编辑器按钮背后的同一套方法（不手改 .tres）。
##   godot --headless --path . --script res://tests/tutorial_flow.gd

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Node.new()
	host.name = "TutorialHost"
	root.add_child(host)

	_check(StateCatalogStore.display("School.Office.DiaryFound") == "办公室日记已调查", "状态库能给出可读名字")

	# ② 事件编辑器：新建一个调查事件（等价于点「新建事件…」）
	var event_panel: Control = load("res://addons/rpgeventstudio/editor/event_editor/event_editor_panel.gd").new()
	host.add_child(event_panel)
	await process_frame
	var event_path := "res://.godot/tutorial_desk.tres"
	event_panel.call("_create_event_at", event_path)
	var event: EventDefinition = load(event_path)
	_check(event != null, "能新建调查事件")
	if event == null:
		_report()
		quit(1)
		return

	# 配置：显示文字 → 设置开关（用状态库里的名字对应的内部标识）
	event_panel.call("_on_add_command_pressed", _command_id(event_panel, &"show_text"))
	event_panel.call("_change_param", event_panel.get("_selected"), "text", "桌上有一本被翻旧的日志。")
	event_panel.call("_on_add_command_pressed", _command_id(event_panel, &"set_switch"))
	var setter: EventCommand = event_panel.get("_selected")
	event_panel.call("_change_param", setter, "key", "School.Office.DiaryFound")
	event_panel.call("_change_param", setter, "value", true)
	event_panel.call("_on_save_pressed")

	var saved: EventDefinition = load(event_path)
	_check(saved.pages[0].commands.size() == 2, "事件里保存了 2 条指令")
	_check(str(saved.pages[0].commands[1].params.get("key", "")) == "School.Office.DiaryFound", "指令里存的是内部标识")
	_check(CommandRegistry.summary(saved.pages[0].commands[1]).contains("办公室日记已调查"), "列表里显示的是可读名字")

	# ③ 关卡图编辑器：新建图，加条件 + 汇合 + 动作 + 阶段
	var graph_panel: Control = load("res://addons/rpgeventstudio/editor/level_graph/level_graph_view.gd").new()
	host.add_child(graph_panel)
	await process_frame
	var graph_path := "res://.godot/tutorial_graph.tres"
	graph_panel.call("_create_graph_at", graph_path)
	var graph: LevelGraph = graph_panel.current_graph()
	_check(graph != null and graph.entry() != null, "新关卡图自带一个开始节点")
	if graph == null:
		_report()
		quit(1)
		return

	var start := graph.entry()
	var cond_a := _add_graph_node(graph_panel, "condition")
	graph_panel.call("_change_param", cond_a, "key", "School.Office.DiaryFound")
	var cond_b := _add_graph_node(graph_panel, "condition")
	graph_panel.call("_change_param", cond_b, "key", "School.Classroom.ClueFound")
	var merge := _add_graph_node(graph_panel, "merge_and")
	var action := _add_graph_node(graph_panel, "action")
	graph_panel.call("_change_param", action, "key", "School.BasementUnlocked")
	var stage := _add_graph_node(graph_panel, "stage")
	graph_panel.call("_change_param", stage, "stage_id", "basement")

	graph_panel.call("_on_connection_request", start.node_id, 0, stage.node_id, 0)
	graph_panel.call("_on_connection_request", cond_a.node_id, 0, merge.node_id, 0)
	graph_panel.call("_on_connection_request", cond_b.node_id, 0, merge.node_id, 0)
	graph_panel.call("_on_connection_request", merge.node_id, 0, action.node_id, 0)
	graph_panel.call("_on_connection_request", action.node_id, 0, stage.node_id, 0)
	_check(graph.connections.size() == 5, "连线都写进了数据（%d）" % graph.connections.size())

	# 参数检查：所有节点都填好了，不应有错误/警告（未接的条件出口只算提示）
	var check_text := str(graph_panel.get("_check_label").text)
	_check(check_text.contains("0 错误") and check_text.contains("0 警告"),
		"参数检查应通过且无错误/警告（实际：%s）" % check_text)

	graph_panel.call("_on_save_pressed")
	var reloaded: LevelGraph = load(graph_path)
	_check(reloaded != null and reloaded.nodes.size() == graph.nodes.size(), "关卡图保存后能重新读取")

	# ④ 运行：用事件改状态，图自动推进
	var state := StateStore.new()
	var bus := EventBus.new()
	var graph_host := Node.new()
	graph_host.name = "TutorialGraphHost"
	root.add_child(graph_host)
	var runner := GraphRunner.new()
	runner.host = graph_host
	runner.graph = reloaded
	runner.state = state
	runner.bus = bus
	runner.level_prefix = "School"
	runner.start()
	await _frames(6)
	_check(str(state.get_value("School.Stage")) == "basement", "开始节点应把阶段设为地下室")

	# 模拟「调查办公室」事件执行（事件里就一条设置开关）
	var probe_runner := EventRunner.new()
	var probe_host := Node.new()
	root.add_child(probe_host)
	probe_runner.host = probe_host
	probe_runner.state = state
	probe_runner.bus = bus
	probe_runner.registry = CommandRegistry.new()
	probe_runner.presenter = null
	probe_runner.start(saved, {}, ["interact"])
	await _frames(4)
	_check(state.get_bool("School.Office.DiaryFound"), "调查事件应写入线索 A")
	_check(not state.get_bool("School.BasementUnlocked"), "只有一条线索时不应解锁")

	state.set_value("School.Classroom.ClueFound", true)
	await _frames(8)
	_check(state.get_bool("School.BasementUnlocked"), "两条线索齐了应自动解锁")
	_check(str(state.get_value("School.Stage")) == "basement", "解锁后阶段应切到地下室")

	probe_host.queue_free()
	graph_host.queue_free()
	runner.stop()

	# 清理
	for path in [event_path, graph_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 工具 ─────────────────────────────────────────────────

func _command_id(panel: Control, type: StringName) -> int:
	var ids: Dictionary = panel.get("_add_ids")
	for id in ids.keys():
		if ids[id] == type:
			return int(id)
	return -1

func _add_graph_node(panel: Control, type: String) -> LevelNode:
	var ids: Dictionary = panel.get("_add_ids")
	for id in ids.keys():
		if str(ids[id]) == type:
			panel.call("_on_add_node_pressed", int(id))
			return panel.get("_selected")
	return null

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 教程流程验证：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
