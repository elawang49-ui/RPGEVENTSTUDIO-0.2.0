extends SceneTree
## F2 追踪视图测试（无编辑器）：时间线、过滤、详情、JSON 导出。
##   godot --headless --path . --script res://tests/trace_ui_test.gd

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var runtime := root.get_node_or_null("RPGEventStudio")
	_check(runtime != null, "运行时 Autoload 存在")
	if runtime == null:
		_report()
		quit(1)
		return

	runtime.call("set_trace_enabled", true)
	runtime.call("clear_trace")
	var definition := EventDefinition.new()
	definition.event_id = &"trace_ui"
	definition.display_name = "追踪 UI 测试"
	var page := EventPage.new()
	var setter := CommandRegistry.create_command(&"set_variable")
	setter.params["key"] = "Trace.UI.Value"
	setter.params["value"] = "ui"
	var commands: Array[EventCommand] = [setter, CommandRegistry.create_command(&"end")]
	page.commands = commands
	definition.pages = [page]
	runtime.call("start_event", definition, {}, [], {"kind": "interactor", "node": "TraceDemo/Interactor"})
	for i in 120:
		if not bool(runtime.call("is_event_running", &"trace_ui")):
			break
		await process_frame

	var trace: RuntimeTrace = runtime.get("trace")
	_check(trace != null and trace.record_count() > 0, "事件执行后产生追踪记录")
	var source_ok := false
	for record in trace.records():
		if str(record.get("kind", "")) == "event_start":
			var source: Dictionary = record.get("source", {})
			source_ok = str(source.get("kind", "")) == "interactor" and str(source.get("node", "")) == "TraceDemo/Interactor"
	_check(source_ok, "追踪记录带触发对象来源")

	var view := TraceDebugView.new()
	root.add_child(view)
	view.setup(runtime)
	await process_frame
	var tree: Tree = view.get("_tree")
	_check(tree != null and tree.get_root() != null and tree.get_root().get_child_count() > 0,
		"追踪视图渲染时间线")
	var all_rows := tree.get_root().get_child_count()
	_check(all_rows == trace.record_count(), "默认显示全部记录（%d）" % all_rows)

	var event_filter: LineEdit = view.get("_event_filter")
	event_filter.text = "trace_ui"
	view.refresh(true)
	_check(tree.get_root().get_child_count() > 0, "按事件 ID 过滤后仍显示该事件记录")

	event_filter.text = ""
	var state_filter: LineEdit = view.get("_state_filter")
	state_filter.text = "Trace.UI.Value"
	view.refresh(true)
	var state_rows := tree.get_root().get_child_count()
	_check(state_rows == 1, "按状态标识过滤只显示该状态记录（实际 %d）" % state_rows)
	state_filter.text = ""

	var result_filter: OptionButton = view.get("_result_filter")
	result_filter.select(1)   # completed
	view.refresh(true)
	_check(tree.get_root().get_child_count() > 0, "按完成结果过滤仍保留该 trace")
	result_filter.select(0)
	view.refresh(true)

	view.call("_export")
	var path := "user://rpg_event_studio_trace.json"
	_check(FileAccess.file_exists(path), "导出 JSON 文件")
	if FileAccess.file_exists(path):
		var raw := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(raw)
		_check(parsed is Dictionary and int(parsed.get("version", 0)) == RuntimeTrace.VERSION,
			"导出 JSON 可解析且带版本")
		DirAccess.remove_absolute(path)

	# 普通视图：时间线摘要用自然语言（状态行显示 显示名 + 前后值）
	var state_summary := ""
	for i in tree.get_root().get_child_count():
		var row := tree.get_root().get_child(i)
		var record: Dictionary = row.get_metadata(0)
		if str(record.get("kind", "")) == "state":
			state_summary = row.get_text(2)
	_check(state_summary.contains("→") or state_summary.contains("游戏状态"), "状态行使用自然语言摘要")

	# 详情三层：自然语言 / 原始 JSON
	var first := tree.get_root().get_child(0)
	tree.set_selected(first, 0)
	view.call("_on_selected")
	var details: RichTextLabel = view.get("_details")
	_check(details != null and details.text.contains("剧情"), "默认显示自然语言详情")
	var mode: OptionButton = view.get("_detail_mode")
	_check(mode != null and mode.item_count == 2, "详情提供两种模式")
	mode.select(1)
	view.call("_on_selected")
	_check(details != null and details.text.contains("\"kind\""), "原始 JSON 详情保留专业字段")

	# 专业视图的时间线也要保留原始 ID/枚举，而不是只把详情换成 JSON。
	var raw_condition := {
		"kind": "condition", "key": "Trace.UI.Stage",
		"actual": "exploration", "branch": "false", "matched": false,
	}
	var raw_condition_summary := str(view.call("_summary", raw_condition))
	_check(raw_condition_summary.contains("Trace.UI.Stage") and raw_condition_summary.contains("false")
		and not raw_condition_summary.contains("否"), "专业视图条件摘要保留原始键与分支枚举")
	_check(str(view.call("_result_text", raw_condition)) == "false", "专业视图条件结果保留 false")

	var raw_state := {"kind": "state", "key": "Trace.UI.Stage", "old": null, "new": "exploration"}
	var raw_state_summary := str(view.call("_summary", raw_state))
	_check(raw_state_summary.contains("exploration") and raw_state_summary.contains("null")
		and not raw_state_summary.contains("探索"), "专业视图状态值不翻译阶段词条")

	var raw_branch := {
		"kind": "graph_branch", "graph_id": "school", "graph_path": "",
		"node_id": "node_a", "port": "true", "to_node": "node_b",
	}
	var raw_branch_summary := str(view.call("_summary", raw_branch))
	_check(raw_branch_summary.contains("node_a") and raw_branch_summary.contains("true")
		and raw_branch_summary.contains("node_b") and not raw_branch_summary.contains("是"),
		"专业视图图分支保留原始端口与节点 ID")

	var raw_merge := {
		"kind": "graph_merge", "graph_id": "school", "graph_path": "",
		"node_id": "merge", "mode": "and", "count": 1, "required": 2, "fired": false,
	}
	_check(str(view.call("_result_text", raw_merge)) == "false", "专业视图汇合结果保留 false")
	var raw_page := {"kind": "page", "page_index": 0, "trigger": "interact", "selected": true}
	_check(str(view.call("_result_text", raw_page)) == "true", "专业视图页面结果保留 true")

	# 切回自然视图后，同一批记录应恢复显示名/中文枚举。
	mode.select(0)
	var natural_branch_summary := str(view.call("_summary", raw_branch))
	_check(natural_branch_summary.contains("是") and not natural_branch_summary.contains("true"),
		"自然视图仍把 true 端口翻译为中文")

	view.queue_free()
	_report()
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──────── 追踪 UI 测试结果 ────────")
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
