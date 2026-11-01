extends SceneTree
## 嵌套事件语义对齐 + 图等待真实时间超时（Batch 2）：
##   godot --headless --path . --script res://tests/nested_event_semantics_test.gd
## 覆盖：
##   1. 嵌套调用 once 页事件：首次执行、再次嵌套调用被 repeat_policy 拒绝
##   2. 同事件已运行时嵌套调用自身：被重入闸门拒绝
##   3. 嵌套事件执行期间 bus.event_started / event_finished 各发一次（带嵌套来源标注）
##   4. 父级取消（cancel_all / presenter 离树）级联取消子事件（Batch 1 行为不回归）
##   5. 公共事件递归上限不回归
##   6. 图事件等待按真实时间超时（event_wait_timeout 可注入，秒）
##   7. 图等待 event_finished 提前释放不回归

const SELF_EVENT_PATH := "res://.godot/nested_self_ref.tres"
const REC_COMMON_PATH := "res://.godot/nested_rec_common.tres"
const GRAPH_NEVER_PATH := "res://.godot/nested_graph_never.tres"
const GRAPH_QUICK_PATH := "res://.godot/nested_graph_quick.tres"

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_register_test_command()
	await _test_once_page_policy()
	await _test_reentry_gate()
	await _test_nested_bus_events()
	await _test_cancel_all_cascade()
	await _test_presenter_leave_tree_cascade()
	await _test_common_recursion_limit()
	await _test_graph_wait_realtime_timeout()
	await _test_graph_wait_early_release()
	_cleanup_temp_resources()
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 用例 ─────────────────────────────────────────────────

## 1) 嵌套调用 once 页事件：首次执行、再次嵌套调用被 repeat_policy 拒绝。
func _test_once_page_policy() -> void:
	var ctx := _make_runner()
	var runner: EventRunner = ctx["runner"]
	var state: StateStore = ctx["state"]
	var trace: RuntimeTrace = ctx["trace"]
	state.define("Nested.Once.Count", TYPE_INT, 0)

	var child := EventDefinition.new()
	child.event_id = &"nested_once_page"
	var page := EventPage.new()
	page.repeat_policy = "once"
	page.commands = [_cmd(&"variable_op", {"key": "Nested.Once.Count", "op": "+", "value": 1})]
	child.pages = [page]

	var parent := _event(&"nested_once_caller", [_call_event(child), _call_event(child), _end()])
	runner.start(parent)
	await _wait_idle(runner)

	_check(int(state.get_value("Nested.Once.Count", -1)) == 1,
		"once 页嵌套调用只应执行一次（实际 %d 次）" % int(state.get_value("Nested.Once.Count", -1)))
	_check(_has_ignored(trace, "repeat_policy", "nested_once_page"),
		"第二次嵌套调用应记 event_ignored/repeat_policy")
	var source := _ignored_source(trace, "repeat_policy", "nested_once_page")
	_check(str(source.get("kind", "")) == "nested" and str(source.get("parent_event_id", "")) == "nested_once_caller",
		"repeat_policy 忽略记录应带嵌套来源标注（实际 %s）" % str(source))
	ctx["host"].queue_free()
	await process_frame

## 2) 同事件已运行时嵌套调用自身：被重入闸门拒绝（与顶层 start 一致）。
func _test_reentry_gate() -> void:
	var ctx := _make_runner()
	var runner: EventRunner = ctx["runner"]
	var trace: RuntimeTrace = ctx["trace"]

	# 自调用事件：指令引用自己的资源路径（嵌套调用加载的是同一 event_id 的副本）
	var definition := _event(&"nested_self", [_call_event(SELF_EVENT_PATH), _end()])
	ResourceSaver.save(definition, SELF_EVENT_PATH)

	runner.start(definition)
	await _wait_idle(runner)

	_check(_has_ignored(trace, "reentry", "nested_self"),
		"运行中事件嵌套调用自身应记 event_ignored/reentry")
	var source := _ignored_source(trace, "reentry", "nested_self")
	_check(str(source.get("kind", "")) == "nested" and str(source.get("parent_event_id", "")) == "nested_self",
		"reentry 忽略记录应带嵌套来源标注（实际 %s）" % str(source))
	ctx["host"].queue_free()
	await process_frame

## 3) 嵌套事件执行期间 bus.event_started / event_finished 各发一次（带嵌套来源标注）。
func _test_nested_bus_events() -> void:
	var ctx := _make_runner()
	var runner: EventRunner = ctx["runner"]
	var bus: EventBus = ctx["bus"]
	var state: StateStore = ctx["state"]
	state.define("Nested.Bus.Flag", TYPE_BOOL, false)

	var child := _event(&"nested_bus_child", [_set_state("Nested.Bus.Flag", true), _end()])
	var parent := _event(&"nested_bus_parent", [_call_event(child), _end()])

	var started: Array = []
	var reports: Array = []
	bus.event_started.connect(func(id: StringName, instance: int) -> void:
		started.append({"event_id": String(id), "instance_id": instance}))
	bus.event_finished.connect(func(report: Dictionary) -> void:
		reports.append(report))

	runner.start(parent)
	await _wait_idle(runner)

	var child_started := started.filter(func(s: Dictionary) -> bool: return str(s.get("event_id", "")) == "nested_bus_child")
	var child_reports := _reports_for(reports, "nested_bus_child")
	_check(not _reports_for(reports, "nested_bus_parent").is_empty(), "顶层事件仍应发 event_finished")
	_check(child_started.size() == 1,
		"嵌套事件应发恰好一次 event_started（实际 %d）" % child_started.size())
	_check(child_reports.size() == 1,
		"嵌套事件应发恰好一次 event_finished（实际 %d）" % child_reports.size())
	var report: Dictionary = child_reports[0] if not child_reports.is_empty() else {}
	_check(int(report.get("result", -1)) == EventRunner.Result.COMPLETED,
		"嵌套事件报告应为 COMPLETED（实际 %s）" % str(report.get("result", "?")))
	_check(bool(state.get_bool("Nested.Bus.Flag")), "嵌套事件应真实执行")
	_check(int(report.get("depth", -1)) == 1,
		"嵌套事件报告应带 depth=1（实际 %s）" % str(report.get("depth", "?")))
	var source: Dictionary = report.get("source", {})
	_check(str(source.get("kind", "")) == "nested" and str(source.get("parent_event_id", "")) == "nested_bus_parent",
		"嵌套事件报告应带嵌套来源标注（实际 %s）" % str(source))
	var started_instance := int(child_started[0].get("instance_id", -1)) if not child_started.is_empty() else -1
	_check(started_instance > 0 and int(report.get("instance_id", -1)) == started_instance,
		"嵌套事件 started/finished 应可按 instance_id 关联（started=%s finished=%s）"
			% [str(started_instance), str(report.get("instance_id", "?"))])
	ctx["host"].queue_free()
	await process_frame

## 4a) runner.cancel_all 级联取消嵌套子事件（Batch 1 行为不回归 + 子事件收尾上报）。
func _test_cancel_all_cascade() -> void:
	var ctx := _make_runner()
	var runner: EventRunner = ctx["runner"]
	var bus: EventBus = ctx["bus"]

	var child := _event(&"nested_cancel_child", [_cmd(&"wait", {"seconds": 10.0}), _end()])
	var parent := _event(&"nested_cancel_parent", [_call_event(child), _end()])

	var reports: Array = []
	bus.event_finished.connect(func(report: Dictionary) -> void: reports.append(report))

	runner.start(parent)
	await _frames(5)
	_check(int(runner.active_count()) == 1, "父事件应正在运行（等待嵌套子事件）")
	runner.cancel_all("测试级联取消")
	var idle := await _wait_idle(runner)
	_check(idle, "级联取消后运行实例应在有限帧内清空")

	var parent_report: Dictionary = _reports_for(reports, "nested_cancel_parent")[0] \
		if not _reports_for(reports, "nested_cancel_parent").is_empty() else {}
	var child_report: Dictionary = _reports_for(reports, "nested_cancel_child")[0] \
		if not _reports_for(reports, "nested_cancel_child").is_empty() else {}
	_check(int(parent_report.get("result", -1)) == EventRunner.Result.CANCELLED,
		"父事件应以 CANCELLED 结束（实际 %s）" % str(parent_report.get("result", "?")))
	_check(int(child_report.get("result", -1)) == EventRunner.Result.CANCELLED,
		"嵌套子事件应随父级取消并以 CANCELLED 结束（Batch 1 级联不回归，实际 %s）" % str(child_report.get("result", "?")))
	_check(str(child_report.get("reason", "")) == "测试级联取消",
		"嵌套子事件应带取消原因（实际 %s）" % str(child_report.get("reason", "?")))
	ctx["host"].queue_free()
	await process_frame

## 4b) presenter 离树（模拟切场景）级联取消嵌套子事件。
func _test_presenter_leave_tree_cascade() -> void:
	var ctx := _make_runner()
	var runner: EventRunner = ctx["runner"]
	var bus: EventBus = ctx["bus"]

	var child := _event(&"nested_leave_child", [_cmd(&"wait", {"seconds": 10.0}), _end()])
	var parent := _event(&"nested_leave_parent", [_call_event(child), _end()])

	var reports: Array = []
	bus.event_finished.connect(func(report: Dictionary) -> void: reports.append(report))

	runner.start(parent)
	await _frames(5)
	_check(int(runner.active_count()) == 1, "离树用例父事件应正在运行")
	root.remove_child(ctx["host"])   # presenter 随宿主一起离树
	var idle := await _wait_idle(runner)
	_check(idle, "presenter 离树后运行实例应在有限帧内清空")

	var parent_report: Dictionary = _reports_for(reports, "nested_leave_parent")[0] \
		if not _reports_for(reports, "nested_leave_parent").is_empty() else {}
	var child_report: Dictionary = _reports_for(reports, "nested_leave_child")[0] \
		if not _reports_for(reports, "nested_leave_child").is_empty() else {}
	_check(int(parent_report.get("result", -1)) == EventRunner.Result.CANCELLED,
		"离树路径父事件应以 CANCELLED 结束（实际 %s）" % str(parent_report.get("result", "?")))
	_check(int(child_report.get("result", -1)) == EventRunner.Result.CANCELLED,
		"离树路径嵌套子事件应以 CANCELLED 结束（实际 %s）" % str(child_report.get("result", "?")))
	_check(str(child_report.get("reason", "")) == "presenter 已释放",
		"离树路径嵌套子事件应带取消原因（实际 %s）" % str(child_report.get("reason", "?")))
	ctx["host"].queue_free()
	await process_frame

## 5) 公共事件递归上限不回归（递归到深度上限按 FAILED 收尾）。
func _test_common_recursion_limit() -> void:
	var ctx := _make_runner()
	var runner: EventRunner = ctx["runner"]
	var bus: EventBus = ctx["bus"]

	var common := CommonEvent.new()
	common.common_id = &"nested_rec_common"
	var commands: Array[EventCommand] = []
	commands.append(_cmd(&"call_common", {"common_path": REC_COMMON_PATH}))
	common.commands = commands
	ResourceSaver.save(common, REC_COMMON_PATH)

	var parent := _event(&"nested_rec_caller", [_cmd(&"call_common", {"common_path": REC_COMMON_PATH}), _end()])

	var reports: Array = []
	bus.event_finished.connect(func(report: Dictionary) -> void: reports.append(report))

	_expect_error_begin("recursion-limit")
	runner.start(parent)
	await _wait_idle(runner)
	_expect_error_end("recursion-limit")

	var report: Dictionary = _reports_for(reports, "nested_rec_caller")[0] \
		if not _reports_for(reports, "nested_rec_caller").is_empty() else {}
	_check(int(report.get("result", -1)) == EventRunner.Result.FAILED,
		"公共事件递归到上限应以 FAILED 收尾（既有行为不回归，实际 %s）" % str(report.get("result", "?")))
	ctx["host"].queue_free()
	await process_frame

## 6) 图事件等待按真实时间超时：注入 event_wait_timeout=0.3s，事件永远不完成，
##    图应在 ~0.3s 真实时间后放行 done 分支（修复前按 7200 帧计数且无法注入）。
func _test_graph_wait_realtime_timeout() -> void:
	var ctx := _make_runner()
	var host: Node = ctx["host"]
	var state: StateStore = ctx["state"]
	var bus: EventBus = ctx["bus"]

	var definition := _event(&"nested_graph_never", [_end()])
	ResourceSaver.save(definition, GRAPH_NEVER_PATH)

	var graph := _make_wait_graph(&"nested_wait_graph", GRAPH_NEVER_PATH)
	var graph_runner := GraphRunner.new()
	graph_runner.host = host
	graph_runner.graph = graph
	graph_runner.state = state
	graph_runner.bus = bus
	graph_runner.event_starter = func(_def: EventDefinition, _args: Dictionary, _filter: Array) -> void:
		pass   # 事件永远不启动、永远不完成

	graph_runner.set("event_wait_timeout", 0.3)
	var injected: Variant = graph_runner.get("event_wait_timeout")
	_check(injected != null and is_equal_approx(float(injected), 0.3),
		"图等待超时应可注入真实秒数 event_wait_timeout（实际 %s）" % str(injected))

	var finished_result := {"seen": false, "result": -1}
	graph_runner.finished.connect(func(_id: StringName, result: int) -> void:
		finished_result["seen"] = true
		finished_result["result"] = result)

	var started_ms := Time.get_ticks_msec()
	graph_runner.start()
	for i in 1800:   # 帧数兜底上限；正常应在 0.3s 真实时间内结束
		if not graph_runner.running:
			break
		await process_frame
	var elapsed := (Time.get_ticks_msec() - started_ms) / 1000.0

	_check(bool(finished_result["seen"]) and int(finished_result["result"]) == GraphRunner.Result.COMPLETED,
		"等待超时后图应继续推进 done 分支并正常结束（seen=%s result=%s）"
			% [str(finished_result["seen"]), str(finished_result["result"])])
	_check(elapsed >= 0.25, "图等待应至少等满注入的真实时间（实际 %.2fs）" % elapsed)
	_check(elapsed <= 2.0, "图等待应按注入秒数及时放行，不按 7200 帧计数（实际 %.2fs）" % elapsed)
	# 显式停掉再放引用：超时未放行时 _wait_event 还有挂起协程，避免悬空恢复报错。
	graph_runner.stop()
	await _frames(2)
	ctx["host"].queue_free()
	await process_frame

## 7) 图等待 event_finished 提前释放不回归：事件正常完成后图立即放行。
func _test_graph_wait_early_release() -> void:
	var ctx := _make_runner()
	var runner: EventRunner = ctx["runner"]
	var host: Node = ctx["host"]
	var state: StateStore = ctx["state"]
	var bus: EventBus = ctx["bus"]
	state.define("Nested.Graph.Quick", TYPE_BOOL, false)

	var definition := _event(&"nested_graph_quick", [_set_state("Nested.Graph.Quick", true), _end()])
	ResourceSaver.save(definition, GRAPH_QUICK_PATH)

	var graph := _make_wait_graph(&"nested_quick_graph", GRAPH_QUICK_PATH)
	var graph_runner := GraphRunner.new()
	graph_runner.host = host
	graph_runner.graph = graph
	graph_runner.state = state
	graph_runner.bus = bus
	graph_runner.event_starter = func(def: EventDefinition, args: Dictionary, filter: Array) -> void:
		runner.start(def, args, filter)

	graph_runner.set("event_wait_timeout", 0.3)
	var finished_result := {"seen": false, "result": -1}
	graph_runner.finished.connect(func(_id: StringName, result: int) -> void:
		finished_result["seen"] = true
		finished_result["result"] = result)

	var started_ms := Time.get_ticks_msec()
	graph_runner.start()
	for i in 1800:
		if not graph_runner.running:
			break
		await process_frame
	var elapsed := (Time.get_ticks_msec() - started_ms) / 1000.0

	_check(bool(finished_result["seen"]) and int(finished_result["result"]) == GraphRunner.Result.COMPLETED,
		"事件完成后图应从 event_finished 提前放行并正常结束")
	_check(bool(state.get_bool("Nested.Graph.Quick")), "图启动的事件应真实执行完成")
	_check(elapsed < 0.25, "提前放行不应等满超时时长（实际 %.2fs）" % elapsed)
	ctx["host"].queue_free()
	await process_frame

# ── 测试替身 / 工具 ───────────────────────────────────────

## 测试专用指令：把 pending_call 指到 kind="event"，对接 _execute_call 的嵌套事件路径。
class CmdCallEvent extends CommandHandler:
	func execute(ctx: EventContext) -> int:
		ctx.pending_call = {
			"kind": "event",
			"ref": ctx.get_param("event_ref"),
			"args": ctx.get_param("call_args", {}),
		}
		return CmdResult.CALL

func _register_test_command() -> void:
	# 只往静态 _handlers 塞测试指令，不动 _order/_specs：不进编辑器指令列表，
	# 且每个套件是独立 Godot 进程，不会泄漏到其他套件。
	CommandRegistry._handlers[&"test_call_event"] = CmdCallEvent.new()

func _make_runner() -> Dictionary:
	var trace := RuntimeTrace.new()
	trace.enabled = true
	var host := Node.new()
	host.name = "NestedTestHost"
	root.add_child(host)
	var presenter := MockPresenter.new()
	presenter.name = "NestedTestPresenter"
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
	return {"host": host, "presenter": presenter, "state": state, "bus": bus, "runner": runner, "trace": trace}

## start → event(wait=true) → end 的最小图。
func _make_wait_graph(graph_id: StringName, event_path: String) -> LevelGraph:
	var graph := LevelGraph.new()
	graph.graph_id = graph_id
	var start := LevelNode.new()
	start.node_id = &"start_1"
	start.type = "start"
	var event_node := LevelNode.new()
	event_node.node_id = &"event_1"
	event_node.type = "event"
	event_node.params = {"event_path": event_path, "trigger": "interact", "wait": true}
	var end_node := LevelNode.new()
	end_node.node_id = &"end_1"
	end_node.type = "end"
	graph.nodes = [start, event_node, end_node]
	graph.entry_node = &"start_1"
	for pair in [[&"start_1", &"event_1", "out"], [&"event_1", &"end_1", "done"]]:
		var connection := LevelConnection.new()
		connection.from_node = pair[0]
		connection.to_node = pair[1]
		connection.from_port = pair[2]
		graph.connections.append(connection)
	return graph

func _event(id: StringName, commands: Array, trigger: String = "interact") -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = id
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

func _call_event(ref: Variant) -> EventCommand:
	return _cmd(&"test_call_event", {"event_ref": ref})

func _set_state(key: String, value: Variant) -> EventCommand:
	return _cmd(&"set_switch", {"key": key, "value": value})

func _end() -> EventCommand:
	return _cmd(&"end")

func _wait_idle(runner: EventRunner, limit: int = 240) -> bool:
	var waited := 0
	while int(runner.active_count()) > 0 and waited < limit:
		await process_frame
		waited += 1
	return int(runner.active_count()) == 0

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _reports_for(reports: Array, event_id: String) -> Array:
	var out: Array = []
	for report in reports:
		if String((report as Dictionary).get("event_id", "")) == event_id:
			out.append(report)
	return out

func _has_ignored(trace: RuntimeTrace, reason: String, event_id: String) -> bool:
	for record in trace.records():
		if str(record.get("kind", "")) == "event_ignored" \
				and str(record.get("reason", "")) == reason \
				and str(record.get("event_id", "")) == event_id:
			return true
	return false

func _ignored_source(trace: RuntimeTrace, reason: String, event_id: String) -> Dictionary:
	for record in trace.records():
		if str(record.get("kind", "")) == "event_ignored" \
				and str(record.get("reason", "")) == reason \
				and str(record.get("event_id", "")) == event_id:
			return record.get("source", {})
	return {}

func _expect_error_begin(label: String) -> void:
	printerr("EXPECTED_ERROR_BEGIN ", label)

func _expect_error_end(label: String) -> void:
	printerr("EXPECTED_ERROR_END ", label)

func _cleanup_temp_resources() -> void:
	for path in [SELF_EVENT_PATH, REC_COMMON_PATH, GRAPH_NEVER_PATH, GRAPH_QUICK_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 嵌套事件语义 / 图等待超时测试结果 ────────")
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
