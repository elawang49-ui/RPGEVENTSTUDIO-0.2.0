@tool
class_name GraphRunner
extends RefCounted
## 关卡总控图执行器：令牌流 + 状态监视 + 并行分支 + AND/OR 汇合。
## 只读 LevelGraph 数据，不依赖 GraphEdit，运行时不创建任何 UI。

signal node_activated(node_id: StringName, cause: Dictionary)
signal node_state_changed(node_id: StringName, state: int)
signal stage_changed(level_id: StringName, stage_id: String)
signal finished(graph_id: StringName, result: int)
## 停止广播：宿主释放 / 手动停止时发出，运行时用来把图从 graphs 里注销。
signal stopped(graph_runner: GraphRunner)

enum Result { COMPLETED, STOPPED, FAILED }
enum NodeState { UNVISITED, RUNNING, DONE, FAILED }

const MAX_ACTIVATIONS := 4000

## 图事件节点等待事件结束的超时（真实时间秒）。可按图注入：
## 长对话事件可调大；0 表示不等待（事件启动后立即放行 done 分支）。
var event_wait_timeout := 120.0

var graph: LevelGraph
var state: StateStore
var bus: EventBus
var host: Node
var level_prefix: String = "School"
## func(definition: EventDefinition, args: Dictionary, trigger_filter: Array) -> void
var event_starter: Callable = Callable()
## 可选运行时追踪；只观察，不改变执行顺序。
var trace: RuntimeTrace = null

var node_states: Dictionary = {}
var running := false

var _monitors: Dictionary = {}   ## node_id -> {key, op, value, last: bool}
var _merge: Dictionary = {}      ## node_id -> {count, fired}
var _activations := 0
var _stop := false
var _connected := false
var _owns_write_observer := false   ## trace 转发观察者是 start() 自己装上的（宿主没有观察者时）

# ── 生命周期 ─────────────────────────────────────────────

func start() -> void:
	if graph == null or state == null:
		return
	if trace != null and not state.write_observer.is_valid():
		var trace_ref: RuntimeTrace = trace
		state.write_observer = func(key: String, old_value: Variant, new_value: Variant, existed: bool) -> void:
			trace_ref.state_changed(key, old_value, new_value, existed)
		_owns_write_observer = true
	_stop = false
	if is_instance_valid(host) and not host.tree_exiting.is_connected(stop):
		host.tree_exiting.connect(stop)
	running = true
	_activations = 0
	node_states.clear()
	_monitors.clear()
	_merge.clear()

	for node in graph.nodes:
		if node != null:
			_set_node_state(node.node_id, NodeState.UNVISITED)
	if not _connected:
		state.changed.connect(_on_state_changed)
		_connected = true

	# 监视型条件从关卡开始就盯着状态，不靠入边触发
	for node in graph.nodes:
		if node != null and node.type == "condition" and bool(node.get_param("monitor", true)):
			_register_monitor(node)

	var entry := graph.entry()
	if entry == null:
		push_error("[RPGEventStudio] 关卡图没有起点：%s" % String(graph.graph_id))
		running = false
		return
	_activate.call_deferred(entry.node_id, {"kind": "start"})

func stop() -> void:
	if _stop:
		# 幂等：重复 stop 不重复断开、不重复广播
		return
	_stop = true
	running = false
	if _connected and state != null:
		state.changed.disconnect(_on_state_changed)
		_connected = false
	if _owns_write_observer and state != null:
		# start() 自己装上的 trace 转发观察者，停止时一并摘掉
		state.write_observer = Callable()
		_owns_write_observer = false
	if is_instance_valid(host) and host.tree_exiting.is_connected(stop):
		host.tree_exiting.disconnect(stop)
	stopped.emit(self)

func reset() -> void:
	stop()
	node_states.clear()
	_monitors.clear()
	_merge.clear()

# ── 执行 ─────────────────────────────────────────────────

func _activate(node_id: StringName, cause: Dictionary) -> void:
	# Keep the coroutine owner alive until a stopped await has unwound.
	var lifetime: RefCounted = self
	while not _stop and is_instance_valid(host) and host.is_inside_tree() and host.get_tree().paused:
		await host.get_tree().process_frame
	if _stop:
		return
	var node := graph.node_by_id(node_id)
	if node == null or not node.enabled:
		return

	_activations += 1
	if _activations > MAX_ACTIVATIONS:
		push_error("[RPGEventStudio] 关卡图传播次数异常，已中止（疑似死循环）")
		stop()
		return

	_set_node_state(node_id, NodeState.RUNNING)
	if trace != null:
		trace.set_graph_context(_graph_id(), String(node_id), graph.resource_path if graph != null else "")
		trace.graph_node(_graph_id(), String(node_id), node.type, "enter", NodeState.RUNNING, cause)
	node_activated.emit(node_id, cause)

	match node.type:
		"start":
			await _propagate(node, "out", cause)
		"stage":
			_apply_stage(node)
			await _propagate(node, "out", cause)
		"action":
			_apply_action(node)
			await _propagate(node, "out", cause)
		"condition":
			if not _monitors.has(node_id):
				await _activate_condition_once(node, cause)
		"merge_and":
			await _activate_merge_and(node, cause)
		"merge_or":
			if trace != null:
				trace.graph_merge(_graph_id(), String(node.node_id), "or", 1, 1, true, "out")
			await _propagate(node, "out", cause)
		"event":
			await _activate_event(node, cause)
		"end":
			_apply_end(node)
		_:
			push_warning("[RPGEventStudio] 未知的关卡图节点类型：%s" % node.type)

	if _stop or not is_instance_valid(lifetime):
		return
	_set_node_state(node_id, NodeState.DONE)
	if trace != null:
		trace.graph_node(_graph_id(), String(node_id), node.type, "exit", NodeState.DONE, cause)
		trace.clear_graph_context()

func _propagate(node: LevelNode, port: String, cause: Dictionary) -> void:
	for connection in graph.outgoing(node.node_id, port):
		if _stop:
			return
		if trace != null:
			trace.graph_branch(_graph_id(), String(node.node_id), port,
				String(connection.to_node), true, cause)
		await _activate(connection.to_node, cause)

# ── 各类节点 ─────────────────────────────────────────────

func _apply_action(node: LevelNode) -> void:
	var raw_key := str(node.get_param("key", ""))
	if raw_key == "":
		return
	var key := StateStore.resolve_key(raw_key, level_prefix)
	var op := str(node.get_param("op", "set"))
	var value: Variant = node.get_param("value", true)
	if value is String:
		value = ValueParser.parse(value)

	match op:
		"add":
			state.add(key, value)
		"toggle":
			state.set_value(key, not state.get_bool(key))
		_:
			state.set_value(key, value)

func _apply_stage(node: LevelNode) -> void:
	var stage_id := str(node.get_param("stage_id", ""))
	if stage_id == "":
		return
	var key := "%s.Stage" % level_prefix
	var previous := str(state.get_value(key, ""))
	state.set_value(key, stage_id)
	if trace != null:
		trace.graph_node(_graph_id(), String(node.node_id), "stage", "stage", NodeState.RUNNING,
			{"stage_id": stage_id, "previous": previous})
	stage_changed.emit(graph.level_id, stage_id)
	bus.stage_changed.emit(graph.level_id, StringName(previous), StringName(stage_id))

func _apply_end(node: LevelNode) -> void:
	var raw_key := str(node.get_param("completed_key", ""))
	if raw_key != "":
		state.set_value(StateStore.resolve_key(raw_key, level_prefix), true)
	running = false
	finished.emit(graph.graph_id, Result.COMPLETED)

func _activate_condition_once(node: LevelNode, cause: Dictionary) -> void:
	var result := _evaluate(node)
	_trace_graph_condition(node, result)
	await _propagate(node, "true" if result else "false", cause)

func _activate_merge_and(node: LevelNode, cause: Dictionary) -> void:
	var info: Dictionary = _merge.get(node.node_id, {"count": 0, "fired": false})
	if bool(info.get("fired", false)):
		return
	info["count"] = int(info.get("count", 0)) + 1
	_merge[node.node_id] = info

	var required := int(node.get_param("required", 0))
	if required <= 0:
		required = max(1, graph.incoming_count(node.node_id))
	if int(info["count"]) < required:
		if trace != null:
			trace.graph_merge(_graph_id(), String(node.node_id), "and", int(info["count"]),
				required, false, "wait")
		return

	info["fired"] = true
	_merge[node.node_id] = info
	if trace != null:
		trace.graph_merge(_graph_id(), String(node.node_id), "and", int(info["count"]),
			required, true, "out")
	await _propagate(node, "out", cause)

func _activate_event(node: LevelNode, cause: Dictionary) -> void:
	var path := str(node.get_param("event_path", ""))
	var wait := bool(node.get_param("wait", true))
	if path == "" or not ResourceLoader.exists(path):
		push_warning("[RPGEventStudio] 关卡图里的事件找不到：%s" % path)
		await _propagate(node, "done", cause)
		return

	var definition := load(path) as EventDefinition
	if definition == null:
		await _propagate(node, "done", cause)
		return

	var trigger := str(node.get_param("trigger", "interact"))
	var trigger_filter: Array = [StringName(trigger)] if trigger != "" else []
	if trace != null:
		trace.set_pending_source({
			"kind": "graph",
			"graph_id": _graph_id(),
			"node_id": String(node.node_id),
			"event_path": path,
			"trigger": trigger,
		})
	# Listen before invoking the host: a custom starter may complete synchronously.
	var completed: Array = []
	var capture := func(report: Dictionary) -> void:
		if StringName(report.get("event_id", &"")) == definition.event_id:
			completed.append(report)
	if bus != null:
		bus.event_finished.connect(capture)
	var serial: int = bus._start_serial if bus != null else -1
	if event_starter.is_valid():
		event_starter.call(definition, {}, trigger_filter)
	elif trace != null:
		trace.take_pending_source()
	var receipt: Dictionary = bus._last_start if bus != null and bus._start_serial != serial else {}
	var accepted := event_starter.is_valid() and bool(receipt.get("accepted", true))
	if wait and accepted:
		await _wait_event(definition.event_id, int(receipt.get("instance_id", -1)), completed)
	if bus != null:
		bus.event_finished.disconnect(capture)
	await _propagate(node, "done", cause)

func _wait_event(event_id: StringName, instance_id: int = -1, completed: Array = []) -> void:
	if bus == null:
		return
	var lifetime: RefCounted = self
	var done := {"value": false}
	for report in completed:
		if instance_id < 0 or int(report.get("instance_id", -1)) == instance_id:
			done["value"] = true
	var handler := func(report: Dictionary) -> void:
		if StringName(report.get("event_id", &"")) == event_id and (instance_id < 0 or int(report.get("instance_id", -1)) == instance_id):
			done["value"] = true
	bus.event_finished.connect(handler)

	# 按真实时间（Time.get_ticks_msec）判超时，不按帧计数：
	# 240Hz 显示器上按帧计数会让 2 分钟缩水成 30 秒，长对话被提前判超时推进。
	var deadline_ms := Time.get_ticks_msec() + int(maxf(event_wait_timeout, 0.0) * 1000.0)
	var timed_out := false
	while not bool(done["value"]) and not _stop:
		if not is_instance_valid(host) or not host.is_inside_tree():
			break
		var paused_at := Time.get_ticks_msec()
		while not _stop and is_instance_valid(host) and host.is_inside_tree() and host.get_tree().paused:
			await host.get_tree().process_frame
		if _stop or not is_instance_valid(host) or not host.is_inside_tree():
			break
		deadline_ms += Time.get_ticks_msec() - paused_at
		if Time.get_ticks_msec() >= deadline_ms:
			timed_out = true
			break
		await host.get_tree().process_frame
	bus.event_finished.disconnect(handler)
	if timed_out and is_instance_valid(lifetime):
		push_warning("[RPGEventStudio] 关卡图等待事件超时（%.1fs）：%s，按 done 分支继续" % [event_wait_timeout, String(event_id)])

# ── 状态监视 ─────────────────────────────────────────────

func _register_monitor(node: LevelNode) -> void:
	var key := _condition_key(node)
	if key == "":
		return
	var result := _evaluate(node)
	_monitors[node.node_id] = {
		"key": key,
		"op": str(node.get_param("op", "==")),
		"last": result,
	}
	_trace_graph_condition(node, result)
	if result:
		_emit_from(node, "true", {"kind": "condition"})

func _on_state_changed(key: String, _old_value: Variant, _new_value: Variant) -> void:
	if _stop:
		return
	for node_id in _monitors.keys():
		if str(_monitors[node_id].get("key", "")) == key:
			_refresh_condition.call_deferred(node_id)

func _refresh_condition(node_id: StringName) -> void:
	if _stop or not _monitors.has(node_id):
		return
	var node := graph.node_by_id(node_id)
	if node == null:
		return
	var info: Dictionary = _monitors[node_id]
	var result := _evaluate(node)
	if result == bool(info.get("last", false)):
		return
	info["last"] = result
	_monitors[node_id] = info
	_emit_from(node, "true" if result else "false", {"kind": "condition"})

func _emit_from(node: LevelNode, port: String, cause: Dictionary) -> void:
	for connection in graph.outgoing(node.node_id, port):
		_activate.call_deferred(connection.to_node, cause)

## 关卡图条件记录：trace_id=0，但带 graph_id/node_id 供定位。
func _trace_graph_condition(node: LevelNode, result: bool) -> void:
	if trace == null:
		return
	var key := _condition_key(node)
	var expected: Variant = node.get_param("value", true)
	if expected is String:
		expected = ValueParser.parse(expected)
	trace.graph_condition(_graph_id(), String(node.node_id), key,
		str(node.get_param("op", "==")), expected, state.get_value(key, null),
		result, "true" if result else "false")

func _condition_key(node: LevelNode) -> String:
	var raw := str(node.get_param("key", ""))
	if raw == "":
		return ""
	return StateStore.resolve_key(raw, level_prefix)

func _evaluate(node: LevelNode) -> bool:
	var key := _condition_key(node)
	if key == "":
		return false
	var expected: Variant = node.get_param("value", true)
	if expected is String:
		expected = ValueParser.parse(expected)
	return state.compare(key, str(node.get_param("op", "==")), expected)

# ── 查询（编辑器高亮 / 调试用） ──────────────────────────

func node_state(node_id: StringName) -> int:
	return int(node_states.get(node_id, NodeState.UNVISITED))

func monitored_keys() -> Array:
	var keys: Array = []
	for info in _monitors.values():
		keys.append(str(info.get("key", "")))
	return keys

func _set_node_state(node_id: StringName, value: int) -> void:
	node_states[node_id] = value
	node_state_changed.emit(node_id, value)

func _graph_id() -> String:
	return String(graph.graph_id) if graph != null else ""
