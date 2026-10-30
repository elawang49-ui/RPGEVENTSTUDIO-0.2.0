@tool
class_name RuntimeTrace
extends RefCounted
## 运行时剧情追踪：统一记录「事件 → 页面 → 指令 → 条件 → 状态 → 图节点」。
##
## 设计原则：
##   - 只观察，不驱动；所有记录方法都不返回值、不抛错、不改变执行顺序。
##   - 容量上限的环形缓冲；关闭后所有记录立即变成空操作。
##   - 记录的是执行时真实拿到的数据（页面选择、条件实际值、状态旧值/新值），
##     拿不到的数据留空，不推断、不伪造。
##   - 导出 JSON 只用于调试，不进入存档结构。

const VERSION := 1
const DEFAULT_CAPACITY := 2000

## 正式导出版本默认关闭；调试构建默认开启。可用 configure()/环境变量覆盖。
var enabled: bool = OS.is_debug_build()
var capacity: int = DEFAULT_CAPACITY

var _records: Array = []
var _next_trace_id: int = 1
var _seq: int = 0
var _dropped: int = 0
var _start_ms: int = Time.get_ticks_msec()

## 当前执行上下文栈：每层 {trace_id, event_id, command_index, command_type}
var _contexts: Array = []
## 当前图节点（没有事件上下文时，状态写入归到图上）
var _graph_context: Dictionary = {}
var _graph_path: String = ""
## GraphRunner 在调用事件前放入来源，EventRunner.start 同步取走。
var _pending_source: Dictionary = {}

# ── 配置 / 读取 ──────────────────────────────────────────

func configure(p_enabled: bool, p_capacity: int = DEFAULT_CAPACITY) -> void:
	enabled = p_enabled
	capacity = maxi(1, p_capacity)
	while _records.size() > capacity:
		_records.pop_front()
		_dropped += 1

func clear() -> void:
	_records.clear()
	_contexts.clear()
	_graph_context.clear()
	_pending_source.clear()
	_next_trace_id = 1
	_seq = 0
	_dropped = 0
	_start_ms = Time.get_ticks_msec()

func record_count() -> int:
	return _records.size()

func dropped_count() -> int:
	return _dropped

func records() -> Array:
	return _records

func stats() -> Dictionary:
	return {
		"enabled": enabled,
		"capacity": capacity,
		"records": _records.size(),
		"dropped": _dropped,
	}

# ── 事件 / 页面 ──────────────────────────────────────────

func new_trace_id() -> int:
	var value := _next_trace_id
	_next_trace_id += 1
	return value

## 记录一次事件开始（含该事件所有页面的选择结果）。
func begin_event(trace_id: int, definition: EventDefinition, instance_id: int, depth: int,
		parent_trace_id: int, trigger_filter: Array, pages: Array, source: Dictionary) -> void:
	if not enabled or definition == null:
		return
	var selected_page := -1
	for page in pages:
		if bool((page as Dictionary).get("selected", false)):
			selected_page = int((page as Dictionary).get("index", -1))
			break
	_push({
		"kind": "event_start",
		"trace_id": trace_id,
		"parent_trace_id": parent_trace_id,
		"depth": depth,
		"event_id": String(definition.event_id),
		"event_name": definition.display_name,
		"event_path": definition.resource_path,
		"instance_id": instance_id,
		"trigger_filter": _plain(trigger_filter),
		"page_index": selected_page,
		"source": _plain(source),
	})
	for page in pages:
		var data: Dictionary = page
		_push({
			"kind": "page",
			"trace_id": trace_id,
			"page_index": int(data.get("index", 0)),
			"trigger": str(data.get("trigger", "")),
			"trigger_ok": bool(data.get("trigger_ok", true)),
			"active": bool(data.get("active", false)),
			"selected": bool(data.get("selected", false)),
			"conditions": _plain(data.get("conditions", [])),
		})

func end_event(trace_id: int, result: int, reason: String, duration_ms: int) -> void:
	if not enabled:
		return
	_push({
		"kind": "event_end",
		"trace_id": trace_id,
		"result": _result_name(result),
		"reason": reason,
		"duration_ms": duration_ms,
	})

## 事件被拒绝（没有一页命中）：记录每一页的触发/条件结果。
func record_rejected(trace_id: int, definition: EventDefinition, trigger_filter: Array,
		diagnosis: Dictionary) -> void:
	if not enabled or definition == null:
		return
	_push({
		"kind": "event_rejected",
		"trace_id": trace_id,
		"event_id": String(definition.event_id),
		"event_name": definition.display_name,
		"event_path": definition.resource_path,
		"trigger_filter": _plain(trigger_filter),
		"pages": _plain(diagnosis.get("pages", [])),
	})

# ── 指令 / 条件 ──────────────────────────────────────────

func command_start(trace_id: int, serial: int, index: int, command_type: String, depth: int) -> void:
	if not enabled:
		return
	_push({
		"kind": "command_start",
		"trace_id": trace_id,
		"command_id": "%d:%d" % [trace_id, serial],
		"command_serial": serial,
		"command_index": index,
		"command_type": command_type,
		"depth": depth,
	})

func command_end(trace_id: int, serial: int, index: int, command_type: String, result: int, duration_ms: int) -> void:
	if not enabled:
		return
	_push({
		"kind": "command_end",
		"trace_id": trace_id,
		"command_id": "%d:%d" % [trace_id, serial],
		"command_serial": serial,
		"command_index": index,
		"command_type": command_type,
		"result": _control_name(result),
		"duration_ms": duration_ms,
	})

func condition(trace_id: int, command_index: int, key: String, op: String, expected: Variant,
		actual: Variant, matched: bool, branch: String) -> void:
	if not enabled:
		return
	_push({
		"kind": "condition",
		"trace_id": trace_id,
		"command_index": command_index,
		"key": key,
		"op": op,
		"expected": _plain(expected),
		"actual": _plain(actual),
		"matched": matched,
		"branch": branch,
	})

# ── 调用栈 ───────────────────────────────────────────────

func enter_context(trace_id: int, event_id: StringName) -> void:
	_contexts.append({
		"trace_id": trace_id,
		"event_id": String(event_id),
		"command_index": -1,
		"command_type": "",
	})

func exit_context(trace_id: int) -> void:
	for index in range(_contexts.size() - 1, -1, -1):
		if int(_contexts[index].get("trace_id", -1)) == trace_id:
			_contexts.remove_at(index)
			return

func set_command(trace_id: int, index: int, command_type: String) -> void:
	for i in range(_contexts.size() - 1, -1, -1):
		if int(_contexts[i].get("trace_id", -1)) == trace_id:
			_contexts[i]["command_index"] = index
			_contexts[i]["command_type"] = command_type
			return

func record_call(trace_id: int, parent_trace_id: int, call_kind: String, target: String,
		depth: int, phase: String, event_id: String = "") -> void:
	if not enabled:
		return
	_push({
		"kind": "call",
		"trace_id": trace_id,
		"parent_trace_id": parent_trace_id,
		"call_kind": call_kind,
		"target": target,
		"target_event_id": event_id,
		"depth": depth,
		"phase": phase,
	})

# ── 状态 ─────────────────────────────────────────────────

## StateStore 的 write_observer 调用这里；用当前事件/指令上下文归因。
## 没有事件上下文时（关卡图动作）归到当前图节点。
func state_changed(key: String, old_value: Variant, new_value: Variant, existed: bool) -> void:
	if not enabled:
		return
	var context := _current_context()
	var record := {
		"kind": "state",
		"key": key,
		"old": _plain(old_value),
		"new": _plain(new_value),
		"existed": existed,
		"trace_id": int(context.get("trace_id", 0)),
		"command_index": int(context.get("command_index", -1)),
		"command_type": str(context.get("command_type", "")),
	}
	# 事件与图可能同时活动（图节点等待事件时监视条件仍会写状态）：两者都带上，
	# 不把并发来源中的一个伪装成另一个。
	if not _graph_context.is_empty():
		record["graph_id"] = str(_graph_context.get("graph_id", ""))
		record["node_id"] = str(_graph_context.get("node_id", ""))
	_push(record)

## 供 GraphRunner 在节点执行期间标记当前图上下文。
func set_graph_context(graph_id: String, node_id: String, graph_path: String = "") -> void:
	_graph_context = {"graph_id": graph_id, "node_id": node_id}
	if graph_path != "":
		_graph_path = graph_path

func clear_graph_context() -> void:
	_graph_context.clear()

# ── 关卡图 ───────────────────────────────────────────────

func graph_node(graph_id: String, node_id: String, node_type: String, phase: String,
		state: int, cause: Variant = null) -> void:
	if not enabled:
		return
	_push({
		"kind": "graph_node",
		"graph_id": graph_id,
		"node_id": node_id,
		"node_type": node_type,
		"phase": phase,
		"node_state": state,
		"graph_path": _graph_path,
		"cause": _plain(cause),
	})

func graph_branch(graph_id: String, node_id: String, port: String, to_node: String,
		active: bool, detail: Variant = null) -> void:
	if not enabled:
		return
	_push({
		"kind": "graph_branch",
		"graph_id": graph_id,
		"node_id": node_id,
		"port": port,
		"to_node": to_node,
		"active": active,
		"graph_path": _graph_path,
		"detail": _plain(detail),
	})

func graph_merge(graph_id: String, node_id: String, mode: String, count: int, required: int,
		fired: bool, branch: String) -> void:
	if not enabled:
		return
	_push({
		"kind": "graph_merge",
		"graph_id": graph_id,
		"node_id": node_id,
		"mode": mode,
		"count": count,
		"required": required,
		"fired": fired,
		"branch": branch,
		"graph_path": _graph_path,
	})

## GraphRunner 在调用事件前设置来源；EventRunner.start 同步取走。
func set_pending_source(source: Dictionary) -> void:
	_pending_source = source.duplicate(true)

func take_pending_source() -> Dictionary:
	var source := _pending_source
	_pending_source = {}
	return source

# ── 导出 ─────────────────────────────────────────────────

func export_json() -> String:
	return JSON.stringify({
		"version": VERSION,
		"enabled": enabled,
		"capacity": capacity,
		"dropped": _dropped,
		"records": _records,
	}, "  ")

# ── 内部 ─────────────────────────────────────────────────

func _current_context() -> Dictionary:
	if _contexts.is_empty():
		return {}
	return _contexts.back()

func _push(record: Dictionary) -> void:
	if not enabled:
		return
	_seq += 1
	record["seq"] = _seq
	record["t_ms"] = Time.get_ticks_msec() - _start_ms
	_records.append(record)
	if _records.size() > capacity:
		_records.pop_front()
		_dropped += 1

func _plain(value: Variant) -> Variant:
	if value is StringName:
		return String(value)
	if value is Vector2:
		return [value.x, value.y]
	if value is Vector2i:
		return [value.x, value.y]
	if value is Color:
		return value.to_html()
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_plain(item))
		return out
	if value is Dictionary:
		var out := {}
		for key in value.keys():
			out[str(key)] = _plain(value[key])
		return out
	if value is Object:
		return str(value)
	return value

func _result_name(result: int) -> String:
	match result:
		0: return "completed"
		1: return "cancelled"
		2: return "failed"
	return "unknown"

func _control_name(code: int) -> String:
	match code:
		0: return "continue"
		1: return "wait"
		2: return "enter_block"
		3: return "call"
		4: return "halt"
		5: return "abort"
	return "unknown"
