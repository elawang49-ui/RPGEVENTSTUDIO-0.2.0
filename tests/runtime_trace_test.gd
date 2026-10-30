extends SceneTree
## 运行时剧情追踪核心测试：
##   godot --headless --path . --script res://tests/runtime_trace_test.gd
## 覆盖：事件/页面/指令/条件/状态/选项/公共事件/图节点/AND/OR/取消/失败/
##       容量/关闭/JSON 导出/开关追踪的行为一致性。

const COMMON_PATH := "res://.godot/trace_common.tres"
const GRAPH_EVENT_PATH := "res://.godot/trace_graph_event.tres"

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await _test_normal_event()
	await _test_page_selection()
	await _test_condition_branch()
	await _test_choice_branch()
	await _test_common_call()
	await _test_graph_event()
	await _test_graph_merge_or()
	await _test_graph_condition_or()
	await _test_cancel()
	await _test_failure()
	_test_capacity()
	_test_json()
	await _test_disabled_still_runs()
	await _test_trace_does_not_change_result()
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 场景搭建 ─────────────────────────────────────────────

func _make_runner(trace: RuntimeTrace) -> Dictionary:
	var host := Node.new()
	host.name = "TraceHost"
	root.add_child(host)
	var presenter := MockPresenter.new()
	presenter.name = "Presenter"
	host.add_child(presenter)
	var state := StateStore.new()
	state.level_prefix = "School"
	var bus := EventBus.new()
	var runner := EventRunner.new()
	runner.host = host
	runner.state = state
	runner.bus = bus
	runner.presenter = presenter
	runner.registry = CommandRegistry.new()
	runner.trace = trace
	return {"host": host, "presenter": presenter, "state": state, "bus": bus, "runner": runner}

func _event(id: StringName, commands: Array, trigger: String = "interact") -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = id
	definition.display_name = "追踪测试 " + String(id)
	var page := EventPage.new()
	page.trigger = trigger
	var typed: Array[EventCommand] = []
	typed.assign(commands)
	page.commands = typed
	definition.pages = [page]
	return definition

func _cmd(type: StringName, params: Dictionary = {}) -> EventCommand:
	var command := CommandRegistry.create_command(type)
	for key in params.keys():
		command.params[key] = params[key]
	return command

func _text(text: String) -> EventCommand:
	return _cmd(&"show_text", {"text": text, "speaker": ""})

func _set_state(key: String, value: Variant) -> EventCommand:
	return _cmd(&"set_switch", {"key": key, "value": value})

func _end() -> EventCommand:
	return _cmd(&"end")

func _wait_idle(runner: EventRunner, limit: int = 120) -> bool:
	for i in limit:
		if runner.active_count() == 0:
			return true
		await process_frame
	return false

func _records(kind: String) -> Array:
	var out: Array = []
	for record in _trace().records():
		if str(record.get("kind", "")) == kind:
			out.append(record)
	return out

var _active_trace: RuntimeTrace

func _trace() -> RuntimeTrace:
	return _active_trace

func _use(trace: RuntimeTrace) -> void:
	_active_trace = trace

func _has(kind: String, predicate: Callable = Callable()) -> bool:
	for record in _records(kind):
		if not predicate.is_valid() or bool(predicate.call(record)):
			return true
	return false

func _first(kind: String) -> Dictionary:
	var all := _records(kind)
	return all[0] if not all.is_empty() else {}

func _expect_error_begin(label: String) -> void:
	printerr("EXPECTED_ERROR_BEGIN ", label)

func _expect_error_end(label: String) -> void:
	printerr("EXPECTED_ERROR_END ", label)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

# ── 1. 普通事件 ──────────────────────────────────────────

func _test_normal_event() -> void:
	var trace := RuntimeTrace.new()
	trace.enabled = true
	_use(trace)
	var ctx := _make_runner(trace)
	var runner: EventRunner = ctx["runner"]
	var state: StateStore = ctx["state"]
	state.define("Trace.Flag", TYPE_BOOL, false)

	var definition := _event(&"trace_normal", [
		_text("第一句"),
		_set_state("Trace.Flag", true),
		_end(),
	])
	runner.start(definition)
	await _wait_idle(runner)

	_check(state.get_bool("Trace.Flag"), "普通事件应真实改变状态")
	var start := _first("event_start")
	_check(str(start.get("event_id", "")) == "trace_normal", "记录事件开始与 event_id")
	_check(str(start.get("event_name", "")).contains("追踪测试"), "记录事件显示名")
	var page := _first("page")
	_check(bool(page.get("selected", false)), "记录被选中的事件页")
	_check(_has("command_start", func(r: Dictionary) -> bool: return str(r.get("command_type", "")) == "set_switch"),
		"记录指令开始（set_switch）")
	var end := _first("event_end")
	_check(str(end.get("result", "")) == "completed", "事件正常结束记录为 completed")
	var state_record := _first("state")
	_check(str(state_record.get("key", "")) == "Trace.Flag", "状态记录真实 key")
	_check(state_record.get("old", null) == false and state_record.get("new", null) == true,
		"状态记录修改前后值（false → true）")
	_check(int(state_record.get("trace_id", 0)) == int(start.get("trace_id", -1)),
		"状态写入关联到所属事件")
	_check(int(state_record.get("command_index", -1)) >= 0, "状态写入关联到具体指令")
	ctx["host"].queue_free()

# ── 2. 多事件页 ──────────────────────────────────────────

func _test_page_selection() -> void:
	var trace := RuntimeTrace.new()
	trace.enabled = true
	_use(trace)
	var ctx := _make_runner(trace)
	var runner: EventRunner = ctx["runner"]
	var state: StateStore = ctx["state"]
	state.define("Trace.PageGate", TYPE_BOOL, false)

	var definition := EventDefinition.new()
	definition.event_id = &"trace_pages"
	var first := EventPage.new()
	var gate := EventCondition.new()
	gate.key = "Trace.PageGate"
	gate.op = "=="
	gate.value = true
	first.conditions = [gate]
	first.commands = [_text("第一页"), _end()]
	var second := EventPage.new()
	second.commands = [_text("第二页"), _end()]
	definition.pages = [first, second]

	runner.start(definition)
	await _wait_idle(runner)
	var pages := _records("page")
	_check(pages.size() == 2, "两页都应记录选择结果")
	_check(not bool(pages[0].get("selected", true)), "条件不满足的第 1 页不应被选中")
	_check(bool(pages[1].get("selected", false)), "兜底的第 2 页应被选中")
	var conditions: Array = pages[0].get("conditions", [])
	_check(not conditions.is_empty() and not bool(conditions[0].get("ok", true)),
		"记录第 1 页条件失败及实际值")
	ctx["host"].queue_free()

# ── 3. 条件分支 ──────────────────────────────────────────

func _test_condition_branch() -> void:
	var trace := RuntimeTrace.new()
	trace.enabled = true
	_use(trace)
	var ctx := _make_runner(trace)
	var runner: EventRunner = ctx["runner"]
	var state: StateStore = ctx["state"]
	state.define("Trace.Gate", TYPE_BOOL, false)
	state.define("Trace.Branch", TYPE_STRING, "")

	var branch := _cmd(&"if", {"key": "Trace.Gate", "op": "==", "value": "true"})
	branch.children = [_cmd(&"set_variable", {"key": "Trace.Branch", "value": "then"})]
	branch.else_children = [_cmd(&"set_variable", {"key": "Trace.Branch", "value": "else"})]
	runner.start(_event(&"trace_if", [branch, _end()]))
	await _wait_idle(runner)

	var condition := _first("condition")
	_check(condition.get("actual", null) == false, "条件记录实际值（false）")
	_check(bool(condition.get("matched", true)) == false, "条件记录判断结果")
	_check(str(condition.get("branch", "")) == "else", "条件记录进入 else 分支")
	_check(str(state.get_value("Trace.Branch", "")) == "else", "实际执行 else 分支")

	trace.clear()
	state.set_value("Trace.Gate", true)
	runner.start(_event(&"trace_if2", [branch.duplicate(true), _end()]))
	await _wait_idle(runner)
	var condition2 := _first("condition")
	_check(str(condition2.get("branch", "")) == "then", "条件成立时记录 then 分支")
	ctx["host"].queue_free()

# ── 4. 选项分支 ──────────────────────────────────────────

func _test_choice_branch() -> void:
	var trace := RuntimeTrace.new()
	trace.enabled = true
	_use(trace)
	var ctx := _make_runner(trace)
	var runner: EventRunner = ctx["runner"]
	var presenter: MockPresenter = ctx["presenter"]
	var state: StateStore = ctx["state"]
	presenter.auto_choice = 1

	var choice := _cmd(&"show_choices", {"prompt": "选一个", "options": ["A", "B"]})
	var branch := _cmd(&"if", {"key": "@@self.choice", "op": "==", "value": "1"})
	branch.children = [_cmd(&"set_variable", {"key": "Trace.Choice", "value": "B"})]
	runner.start(_event(&"trace_choice", [choice, branch, _end()]))
	await _wait_idle(runner)

	_check(str(state.get_value("Trace.Choice", "")) == "B", "选项结果驱动实际分支")
	var choice_state := false
	for record in _records("state"):
		if str(record.get("key", "")).ends_with(".choice"):
			choice_state = record.get("new", -1) == 1
	_check(choice_state, "选项状态写入被追踪（@@self.choice → 1）")
	_check(_has("command_start", func(r: Dictionary) -> bool: return str(r.get("command_type", "")) == "show_choices"),
		"show_choices 指令被追踪")
	ctx["host"].queue_free()

# ── 5. 公共事件调用 ──────────────────────────────────────

func _test_common_call() -> void:
	var common := CommonEvent.new()
	common.common_id = &"trace_common"
	var common_commands: Array[EventCommand] = []
	common_commands.append(_set_state("Trace.Common", true))
	common.commands = common_commands
	ResourceSaver.save(common, COMMON_PATH)

	var trace := RuntimeTrace.new()
	trace.enabled = true
	_use(trace)
	var ctx := _make_runner(trace)
	var runner: EventRunner = ctx["runner"]
	var state: StateStore = ctx["state"]
	state.define("Trace.Common", TYPE_BOOL, false)

	var call := _cmd(&"call_common", {"common_path": COMMON_PATH})
	runner.start(_event(&"trace_caller", [call, _end()]))
	await _wait_idle(runner)

	_check(state.get_bool("Trace.Common"), "公共事件里的指令应真实执行")
	_check(_has("call", func(r: Dictionary) -> bool: return str(r.get("phase", "")) == "enter" and str(r.get("call_kind", "")) == "common"),
		"记录公共事件调用进入")
	_check(_has("call", func(r: Dictionary) -> bool: return str(r.get("phase", "")) == "exit"),
		"记录公共事件调用返回")
	var state_record := {}
	for record in _records("state"):
		if str(record.get("key", "")) == "Trace.Common":
			state_record = record
	_check(not state_record.is_empty() and int(state_record.get("trace_id", 0)) > 0,
		"公共事件内的状态写入仍归到调用方事件")
	ctx["host"].queue_free()
	DirAccess.remove_absolute(COMMON_PATH)

# ── 6. 关卡图调用事件 ────────────────────────────────────

func _test_graph_event() -> void:
	var definition := _event(&"trace_graph_event", [_set_state("Trace.GraphEvent", true), _end()])
	ResourceSaver.save(definition, GRAPH_EVENT_PATH)

	var trace := RuntimeTrace.new()
	trace.enabled = true
	_use(trace)
	var ctx := _make_runner(trace)
	var runner: EventRunner = ctx["runner"]
	var state: StateStore = ctx["state"]
	var bus: EventBus = ctx["bus"]
	var host: Node = ctx["host"]
	state.define("Trace.GraphEvent", TYPE_BOOL, false)

	var graph := LevelGraph.new()
	graph.graph_id = &"trace_graph"
	var start := LevelNode.new()
	start.node_id = &"start_1"
	start.type = "start"
	var event_node := LevelNode.new()
	event_node.node_id = &"event_1"
	event_node.type = "event"
	event_node.params = {"event_path": GRAPH_EVENT_PATH, "trigger": "interact", "wait": true}
	var end_node := LevelNode.new()
	end_node.node_id = &"end_1"
	end_node.type = "end"
	graph.nodes = [start, event_node, end_node]
	graph.entry_node = &"start_1"
	for pair in [[&"start_1", &"event_1"], [&"event_1", &"end_1"]]:
		var connection := LevelConnection.new()
		connection.from_node = pair[0]
		connection.to_node = pair[1]
		connection.from_port = "out" if pair[0] == &"start_1" else "done"
		graph.connections.append(connection)

	var graph_runner := GraphRunner.new()
	graph_runner.host = host
	graph_runner.graph = graph
	graph_runner.state = state
	graph_runner.bus = bus
	graph_runner.trace = trace
	graph_runner.event_starter = func(def: EventDefinition, args: Dictionary, filter: Array) -> void:
		runner.start(def, args, filter)
	graph_runner.start()
	for i in 120:
		if not graph_runner.running and not runner.is_busy(&"trace_graph_event"):
			break
		await process_frame

	_check(_has("graph_node", func(r: Dictionary) -> bool: return str(r.get("node_id", "")) == "event_1"),
		"记录关卡图事件节点")
	var event_start := _first("event_start")
	var source: Dictionary = event_start.get("source", {})
	_check(str(source.get("kind", "")) == "graph" and str(source.get("node_id", "")) == "event_1",
		"事件记录带关卡图节点来源")
	_check(str(source.get("graph_id", "")) == "trace_graph", "事件记录带 graph_id")
	_check(state.get_bool("Trace.GraphEvent"), "图调用的事件真实执行")
	ctx["host"].queue_free()
	DirAccess.remove_absolute(GRAPH_EVENT_PATH)

# ── 7. AND / OR 汇合 ─────────────────────────────────────

func _test_graph_merge_or() -> void:
	var trace := RuntimeTrace.new()
	trace.enabled = true
	_use(trace)
	var ctx := _make_runner(trace)
	var state: StateStore = ctx["state"]
	var bus: EventBus = ctx["bus"]
	var host: Node = ctx["host"]
	state.define("Trace.Merge", TYPE_BOOL, false)

	var graph := LevelGraph.new()
	graph.graph_id = &"trace_merge"
	var start := LevelNode.new()
	start.node_id = &"start_1"
	start.type = "start"
	var merge := LevelNode.new()
	merge.node_id = &"merge_1"
	merge.type = "merge_and"
	merge.params = {"required": 2}
	var action := LevelNode.new()
	action.node_id = &"action_1"
	action.type = "action"
	action.params = {"key": "Trace.Merge", "op": "set", "value": "true"}
	var end := LevelNode.new()
	end.node_id = &"end_1"
	end.type = "end"
	graph.nodes = [start, merge, action, end]
	graph.entry_node = &"start_1"
	for pair in [[&"start_1", "out", &"merge_1"], [&"start_1", "out", &"merge_1"],
			[&"merge_1", "out", &"action_1"], [&"action_1", "out", &"end_1"]]:
		var connection := LevelConnection.new()
		connection.from_node = pair[0]
		connection.from_port = pair[1]
		connection.to_node = pair[2]
		graph.connections.append(connection)

	var graph_runner := GraphRunner.new()
	graph_runner.host = host
	graph_runner.graph = graph
	graph_runner.state = state
	graph_runner.bus = bus
	graph_runner.trace = trace
	graph_runner.start()
	for i in 120:
		if not graph_runner.running:
			break
		await process_frame
	_check(state.get_bool("Trace.Merge"), "AND 汇合达到 required 后应继续执行")
	var merges := _records("graph_merge")
	_check(not merges.is_empty() and str(merges[-1].get("mode", "")) == "and" and bool(merges[-1].get("fired", false)),
		"记录 AND 汇合计数与触发结果")
	var graph_state := {}
	for record in _records("state"):
		if str(record.get("key", "")) == "Trace.Merge":
			graph_state = record
	_check(not graph_state.is_empty() and str(graph_state.get("graph_id", "")) == "trace_merge",
		"关卡图动作的状态写入归到图节点")
	ctx["host"].queue_free()

func _test_graph_condition_or() -> void:
	var trace := RuntimeTrace.new()
	trace.enabled = true
	_use(trace)
	var ctx := _make_runner(trace)
	var state: StateStore = ctx["state"]
	var host: Node = ctx["host"]
	state.define("Trace.Cond", TYPE_BOOL, true)

	var graph := LevelGraph.new()
	graph.graph_id = &"trace_or"
	var start := LevelNode.new()
	start.node_id = &"start_1"
	start.type = "start"
	var condition := LevelNode.new()
	condition.node_id = &"condition_1"
	condition.type = "condition"
	condition.params = {"key": "Trace.Cond", "op": "==", "value": "true", "monitor": false}
	var merge := LevelNode.new()
	merge.node_id = &"merge_1"
	merge.type = "merge_or"
	var end := LevelNode.new()
	end.node_id = &"end_1"
	end.type = "end"
	graph.nodes = [start, condition, merge, end]
	graph.entry_node = &"start_1"
	for pair in [[&"start_1", "out", &"condition_1"], [&"condition_1", "true", &"merge_1"], [&"merge_1", "out", &"end_1"]]:
		var connection := LevelConnection.new()
		connection.from_node = pair[0]
		connection.from_port = pair[1]
		connection.to_node = pair[2]
		graph.connections.append(connection)
	var graph_runner := GraphRunner.new()
	graph_runner.host = host
	graph_runner.graph = graph
	graph_runner.state = state
	graph_runner.bus = ctx["bus"]
	graph_runner.trace = trace
	graph_runner.start()
	for i in 120:
		if not graph_runner.running:
			break
		await process_frame

	var conditions := _records("condition")
	_check(not conditions.is_empty() and str(conditions[-1].get("branch", "")) == "true",
		"记录关卡图条件为 true 的分支")
	var merges := _records("graph_merge")
	_check(not merges.is_empty() and str(merges[-1].get("mode", "")) == "or",
		"记录 OR 汇合")
	_check(_has("graph_branch", func(r: Dictionary) -> bool: return str(r.get("to_node", "")) == "merge_1"),
		"记录条件到 OR 汇合的实际连线")
	ctx["host"].queue_free()

# ── 8. 取消 / 9. 失败 ────────────────────────────────────

func _test_cancel() -> void:
	var trace := RuntimeTrace.new()
	trace.enabled = true
	_use(trace)
	var ctx := _make_runner(trace)
	var runner: EventRunner = ctx["runner"]
	runner.start(_event(&"trace_cancel", [_cmd(&"wait", {"seconds": 10.0}), _end()]))
	await process_frame
	runner.cancel_all("测试取消")
	await _wait_idle(runner)
	var end := _first("event_end")
	_check(str(end.get("result", "")) == "cancelled", "取消事件记录为 cancelled")
	_check(str(end.get("reason", "")) == "测试取消", "记录取消原因")
	ctx["host"].queue_free()

func _test_failure() -> void:
	var trace := RuntimeTrace.new()
	trace.enabled = true
	_use(trace)
	var ctx := _make_runner(trace)
	var runner: EventRunner = ctx["runner"]
	_expect_error_begin("missing-common")
	runner.start(_event(&"trace_fail", [_cmd(&"call_common", {"common_path": "res://.godot/nope.tres"}), _end()]))
	await _wait_idle(runner)
	_expect_error_end("missing-common")
	var end := _first("event_end")
	_check(str(end.get("result", "")) == "failed", "执行异常记录为 failed")
	_check(_has("command_end", func(r: Dictionary) -> bool: return str(r.get("result", "")) == "abort"),
		"失败指令记录 abort 结果")
	ctx["host"].queue_free()

# ── 10. 容量 / 11. JSON ──────────────────────────────────

func _test_capacity() -> void:
	var trace := RuntimeTrace.new()
	trace.configure(true, 5)
	for i in 10:
		trace.command_start(1, i, i, "show_text", 0)
	_check(trace.record_count() == 5, "环形缓冲不超过容量（5）")
	_check(trace.dropped_count() == 5, "记录被丢弃的数量（5）")

func _test_json() -> void:
	var trace := RuntimeTrace.new()
	trace.enabled = true
	trace.begin_event(1, _event(&"trace_json", [_end()]), 1, 0, 0, [], [], {})
	trace.end_event(1, 0, "", 3)
	var text := trace.export_json()
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Dictionary, "导出的 JSON 可解析")
	var data: Dictionary = parsed
	_check(int(data.get("version", 0)) == RuntimeTrace.VERSION, "JSON 带版本号")
	_check((data.get("records", []) as Array).size() == trace.record_count(), "JSON 记录数量一致")

# ── 12. 关闭追踪 / 13. 行为一致性 ────────────────────────

func _test_disabled_still_runs() -> void:
	var trace := RuntimeTrace.new()
	trace.configure(false)
	_use(trace)
	var ctx := _make_runner(trace)
	var runner: EventRunner = ctx["runner"]
	var state: StateStore = ctx["state"]
	state.define("Trace.Off", TYPE_BOOL, false)
	runner.start(_event(&"trace_off", [_set_state("Trace.Off", true), _end()]))
	await _wait_idle(runner)
	_check(state.get_bool("Trace.Off"), "关闭追踪后事件仍正常执行")
	_check(trace.record_count() == 0, "关闭追踪后不产生记录")
	ctx["host"].queue_free()

func _test_trace_does_not_change_result() -> void:
	var on_trace := RuntimeTrace.new()
	on_trace.enabled = true
	var on_ctx := _make_runner(on_trace)
	var on_state: StateStore = on_ctx["state"]
	on_state.define("Trace.Same", TYPE_BOOL, false)
	var on_runner: EventRunner = on_ctx["runner"]
	var on_captured := {"report": {}}
	on_ctx["bus"].event_finished.connect(func(report: Dictionary) -> void: on_captured["report"] = report)
	on_runner.start(_event(&"trace_same", [_set_state("Trace.Same", true), _end()]))
	await _wait_idle(on_runner)

	var off_trace := RuntimeTrace.new()
	off_trace.configure(false)
	var off_ctx := _make_runner(off_trace)
	var off_state: StateStore = off_ctx["state"]
	off_state.define("Trace.Same", TYPE_BOOL, false)
	var off_runner: EventRunner = off_ctx["runner"]
	var off_captured := {"report": {}}
	off_ctx["bus"].event_finished.connect(func(report: Dictionary) -> void: off_captured["report"] = report)
	off_runner.start(_event(&"trace_same", [_set_state("Trace.Same", true), _end()]))
	await _wait_idle(off_runner)

	_check(on_state.get_bool("Trace.Same") == off_state.get_bool("Trace.Same"), "开关追踪的状态结果一致")
	var on_report: Dictionary = on_captured["report"]
	var off_report: Dictionary = off_captured["report"]
	_check(str(on_report.get("result", "")) == str(off_report.get("result", "")), "开关追踪的事件结果一致")
	_check(int(on_report.get("instance_id", -1)) == int(off_report.get("instance_id", -2)),
		"实例 id 不受追踪影响（on=%s off=%s）" % [str(on_report.get("instance_id", "?")), str(off_report.get("instance_id", "?"))])
	on_ctx["host"].queue_free()
	off_ctx["host"].queue_free()

# ── 汇总 ─────────────────────────────────────────────────

func _report() -> void:
	print("")
	print("──────── 运行时追踪测试结果 ────────")
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
