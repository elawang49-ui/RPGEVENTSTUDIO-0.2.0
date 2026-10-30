extends Node
## 运行时追踪视图的编辑器验收（真实 EditorInterface 环境）。
##   RPGEVENTSTUDIO_TRACE_SELFTEST=1 godot --editor --path .
## 结果打印 [TRACE]，并保存 docs/images/runtime_trace_editor.png。

var _checks := 0
var _failures: PackedStringArray = []
var _view: TraceDebugView
var _frame: PanelContainer
var _trace: RuntimeTrace

class MockRuntime:
	extends Node
	var trace: RuntimeTrace
	func set_trace_enabled(value: bool) -> void:
		if trace != null:
			trace.enabled = value
	func clear_trace() -> void:
		if trace != null:
			trace.clear()
	func trace_focus_node(_graph_id: String, _node_id: String, _graph_path: String = "") -> void:
		pass
	func trace_focus_event(_event_id: String, _event_path: String) -> void:
		pass

func start(_plugin: EditorPlugin) -> void:
	await get_tree().create_timer(2.0).timeout
	var filesystem := EditorInterface.get_resource_filesystem()
	for i in 120:
		if filesystem == null or not filesystem.is_scanning():
			break
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.8).timeout
	var base := EditorInterface.get_base_control()
	if base == null:
		_fail("拿不到编辑器根节点")
		_finish()
		return

	_trace = RuntimeTrace.new()
	_trace.enabled = true
	_build_records()

	var mock := MockRuntime.new()
	mock.name = "MockTraceRuntime"
	mock.trace = _trace
	add_child(mock)

	_frame = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.09, 0.98)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.55, 0.80, 0.9)
	_frame.add_theme_stylebox_override("panel", style)
	base.add_child(_frame)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.z_index = 4096
	_frame.move_to_front()
	_view = TraceDebugView.new()
	_frame.add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.setup(mock)
	await get_tree().process_frame
	_view.refresh(true)
	await get_tree().process_frame

	var tree: Tree = _view.get("_tree")
	_check(tree != null and tree.get_root() != null and tree.get_root().get_child_count() > 0,
		"编辑器内追踪视图渲染时间线")
	var rows := tree.get_root().get_child_count()
	_check(rows == _trace.record_count(), "编辑器内显示全部记录（%d）" % rows)

	var state_filter: LineEdit = _view.get("_state_filter")
	state_filter.text = "Trace.Editor.Flag"
	_view.refresh(true)
	_check(tree.get_root().get_child_count() == 1, "状态过滤生效")
	state_filter.text = ""

	var event_filter: LineEdit = _view.get("_event_filter")
	event_filter.text = "trace_editor"
	_view.refresh(true)
	_check(tree.get_root().get_child_count() > 0, "事件过滤生效")
	event_filter.text = ""
	_view.refresh(true)

	var first := tree.get_root().get_child(0)
	tree.set_selected(first, 0)
	_view.call("_on_selected")
	var details: RichTextLabel = _view.get("_details")
	_check(details != null and details.text.contains("\"kind\""), "详情显示记录 JSON")

	# 编辑器调试器通道：F2 的 trace_node / trace_event 消息应被解析。
	var debugger := StudioDebuggerPlugin.new()
	var captured := {"node": [], "event": []}
	debugger.trace_node.connect(func(graph_id: String, node_id: String, graph_path: String) -> void:
		captured["node"] = [graph_id, node_id, graph_path]
	)
	debugger.trace_event.connect(func(event_id: String, event_path: String) -> void:
		captured["event"] = [event_id, event_path]
	)
	debugger._capture("rpg_event_studio:trace_node", ["trace_graph", "event_1", "res://trace_graph.tres"], 1)
	debugger._capture("rpg_event_studio:trace_event", ["trace_editor", "res://trace_editor.tres"], 1)
	_check((captured["node"] as Array).size() == 3 and String((captured["node"] as Array)[2]) == "res://trace_graph.tres",
		"trace_node 消息带图路径")
	_check((captured["event"] as Array).size() == 2, "trace_event 消息带事件路径")

	_view.call("select_first")
	await get_tree().create_timer(0.4).timeout
	var image: Image = null
	if DisplayServer.get_name() != "headless":
		image = base.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("res://docs/images/hardening/runtime_trace_editor.png")
		print("[TRACE] 已保存 docs/images/hardening/runtime_trace_editor.png")
	else:
		print("[TRACE] headless 无渲染，跳过截图（真实窗口验收会生成）")

	_frame.queue_free()
	_view.queue_free()
	mock.queue_free()
	_finish()

func _build_records() -> void:
	var definition := EventDefinition.new()
	definition.event_id = &"trace_editor"
	definition.display_name = "编辑器追踪演示"
	var page := EventPage.new()
	page.trigger = "interact"
	page.commands = [CommandRegistry.create_command(&"end")]
	definition.pages = [page]

	var id := _trace.new_trace_id()
	_trace.begin_event(id, definition, 1, 0, 0, [&"interact"], [
		{"index": 0, "trigger": "interact", "trigger_ok": true, "active": true,
		"selected": true, "conditions": []},
	], {"kind": "interactor", "node": "TraceDemo/Interactor"})
	_trace.enter_context(id, definition.event_id)
	_trace.command_start(id, 1, 0, "set_switch", 0)
	_trace.set_command(id, 0, "set_switch")
	_trace.state_changed("Trace.Editor.Flag", false, true, true)
	_trace.command_end(id, 1, 0, "set_switch", 0, 2)
	_trace.command_start(id, 2, 1, "if", 0)
	_trace.set_command(id, 1, "if")
	_trace.condition(id, 1, "Trace.Editor.Flag", "==", true, true, true, "then")
	_trace.command_end(id, 2, 1, "if", 2, 1)
	_trace.command_start(id, 3, 2, "end", 0)
	_trace.command_end(id, 3, 2, "end", 4, 0)
	_trace.record_call(id, 0, "common", "res://common.tres", 1, "enter")
	_trace.record_call(id, 0, "common", "res://common.tres", 1, "exit")
	_trace.graph_node("trace_graph", "event_1", "event", "enter", 1, {"kind": "start"})
	_trace.graph_branch("trace_graph", "event_1", "done", "end_1", true)
	_trace.graph_merge("trace_graph", "merge_1", "and", 2, 2, true, "out")
	_trace.end_event(id, 0, "", 5)
	_trace.exit_context(id)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[TRACE] ✓ ", message)
	else:
		_failures.append(message)
		print("[TRACE] ✗ ", message)

func _fail(message: String) -> void:
	_checks += 1
	_failures.append(message)
	print("[TRACE] ✗ ", message)

func _finish() -> void:
	print("")
	print("[TRACE] ===== 检查 %d 项，失败 %d 项 =====" % [_checks, _failures.size()])
	for failure in _failures:
		print("[TRACE] ✗ ", failure)
	print("[TRACE] RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)
