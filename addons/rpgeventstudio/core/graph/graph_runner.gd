@tool
class_name GraphRunner
extends RefCounted
## 关卡总控图执行器：令牌流 + 状态监视 + 并行分支 + AND/OR 汇合。
## 只读 LevelGraph 数据，不依赖 GraphEdit，运行时不创建任何 UI。

signal node_activated(node_id: StringName, cause: Dictionary)
signal node_state_changed(node_id: StringName, state: int)
signal stage_changed(level_id: StringName, stage_id: String)
signal finished(graph_id: StringName, result: int)

enum Result { COMPLETED, STOPPED, FAILED }
enum NodeState { UNVISITED, RUNNING, DONE, FAILED }

const MAX_ACTIVATIONS := 4000
const EVENT_WAIT_FRAMES := 60 * 120

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

# ── 生命周期 ─────────────────────────────────────────────

func start() -> void:
	if graph == null or state == null:
		return
	if trace != null and not state.write_observer.is_valid():
		var trace_ref: RuntimeTrace = trace
		state.write_observer = func(key: String, old_value: Variant, new_value: Variant, existed: bool) -> void:
			trace_ref.state_changed(key, old_value, new_value, existed)
	_stop = false
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
	_stop = true
	running = false
	if _connected and state != null:
		state.changed.disconnect(_on_state_changed)
		_connected = false

func reset() -> void:
	stop()
	node_states.clear()
	_monitors.clear()
	_merge.clear()

# ── 执行 ─────────────────────────────────────────────────

func _activate(node_id: StringName, cause: Dictionary) -> void:
	if _stop:
		return
	var node := graph.node_by_id(node_id)
	if node == null or not node.enabled:
		return

	_activations += 1
	if _activations > MAX_ACTIVATIONS:
		push_error("[RPGEventStudio] 关卡图传播次数异常，已中止（疑似死循环）")
		_stop = true
		running = false
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
	if trace != null:
		var key := _condition_key(node)
		var expected: Variant = node.get_param("value", true)
		if expected is String:
			expected = ValueParser.parse(expected)
		trace.condition(0, -1, key, str(node.get_param("op", "==")), expected,
			state.get_value(key, null), result, "true" if result else "false")
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
	if event_starter.is_valid():
		event_starter.call(definition, {}, trigger_filter)
	elif trace != null:
		trace.take_pending_source()
	if wait:
		await _wait_event(definition.event_id)
	await _propagate(node, "done", cause)

func _wait_event(event_id: StringName) -> void:
	if bus == null:
		return
	var done := {"value": false}
	var handler := func(report: Dictionary) -> void:
		if StringName(report.get("event_id", &"")) == event_id:
			done["value"] = true
	bus.event_finished.connect(handler)

	var frames := 0
	while not bool(done["value"]) and not _stop and frames < EVENT_WAIT_FRAMES:
		if host == null or not host.is_inside_tree():
			break
		await host.get_tree().process_frame
		frames += 1
	bus.event_finished.disconnect(handler)

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
