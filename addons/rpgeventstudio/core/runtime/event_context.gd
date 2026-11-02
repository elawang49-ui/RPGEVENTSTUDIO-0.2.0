@tool
class_name EventContext
extends RefCounted
## 一次事件执行的上下文。指令处理器只通过它改世界，不直接摸节点。

var host: Node
var state: StateStore
var bus: EventBus
var presenter
var definition: EventDefinition
var page: EventPage

var event_id: StringName = &""
var instance_id: int = 0
var args: Dictionary = {}
var locals: Dictionary = {}
var params: Dictionary = {}
var command: EventCommand = null
var depth: int = 0

# ── 运行时追踪（可选；为 null 时所有追踪调用都是空操作） ──
var trace: RuntimeTrace = null
var trace_id: int = 0
var parent_trace_id: int = 0
var source: Dictionary = {}
var page_index: int = -1
var trigger_filter: Array = []
var command_index: int = -1
var command_serial: int = 0
var trace_pages: Array = []

var _settling := false
var cancelled: bool = false
var cancel_reason: String = ""
var _presentation_owner_id: int = 0
var _owns_presenter := true

var pending_block: Array[EventCommand] = []
var pending_call: Dictionary = {}

var _wait_predicate: Callable = Callable()
var _wait_deadline_ms: int = -1
var _after_wait: Callable = Callable()
var _logs: PackedStringArray = []
var _cancel_hooks: Array = []
var _active_children: Array = []   ## 运行中的嵌套 / 公共事件上下文：随父级一起取消

# ── 状态读写 ─────────────────────────────────────────────

## 把指令里的相对状态名展开成真实键：
##   @@self.X  -> Local.<事件id>.X
##   @@level.X -> <关卡前缀>.X
func key(raw: String) -> String:
	if raw.begins_with("@@self."):
		return "Local.%s.%s" % [event_id, raw.substr(7)]
	return StateStore.resolve_key(raw, state.level_prefix)

func get_state(raw: String, fallback: Variant = null) -> Variant:
	return state.get_value(key(raw), fallback)

func set_state(raw: String, value: Variant) -> int:
	return state.set_value(key(raw), value)

func has_state(raw: String) -> bool:
	return state.has(key(raw))

func compare_state(raw: String, op: String, expected: Variant) -> bool:
	return state.compare(key(raw), op, expected)

## 记录条件判断的实际值、结果与进入的分支。拿不到实际值时传 null，不编造。
func trace_condition(raw_key: String, op: String, expected: Variant, actual: Variant,
		matched: bool, branch: String) -> void:
	if trace == null:
		return
	trace.condition(trace_id, command_index, key(raw_key), op, expected, actual, matched, branch)

# ── 等待 ─────────────────────────────────────────────────

func wait_seconds(seconds: float) -> void:
	wait_until(Callable(), seconds)

func wait_until(predicate: Callable, timeout_seconds: float = -1.0, after: Callable = Callable()) -> void:
	_wait_predicate = predicate
	_wait_deadline_ms = -1
	if timeout_seconds >= 0.0:
		_wait_deadline_ms = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	_after_wait = after

func is_wait_done() -> bool:
	if cancelled:
		return true
	if _wait_deadline_ms >= 0 and Time.get_ticks_msec() >= _wait_deadline_ms:
		return true
	if _wait_predicate.is_valid():
		if bool(_wait_predicate.call()):
			return true
		return false
	# 既无谓词也无超时：视为无需等待
	return _wait_deadline_ms < 0

func finish_wait() -> void:
	if cancelled:
		_after_wait = Callable()
	if _after_wait.is_valid():
		var cb := _after_wait
		_after_wait = Callable()
		cb.call()
	_wait_predicate = Callable()
	_wait_deadline_ms = -1

# ── 取消 ─────────────────────────────────────────────────

## 演出类指令注册「被取消时怎么收尾」（停 tween、收镜头、清淡入淡出）。
func on_cancel(hook: Callable) -> void:
	if hook.is_valid():
		if cancelled:
			hook.call()
		else:
			_cancel_hooks.append(hook)

## 嵌套 / 公共事件开始执行时登记，结束时注销（见 EventRunner._run_nested_event）。
func _attach_child(child: EventContext) -> void:
	_active_children.append(child)

func _detach_child(child: EventContext) -> void:
	_active_children.erase(child)

func cancel(reason: String = "调用方取消") -> void:
	if cancelled or _settling:
		return
	cancelled = true
	cancel_reason = reason
	_wait_predicate = Callable()
	_after_wait = Callable()
	_wait_deadline_ms = -1
	for index in range(_cancel_hooks.size() - 1, -1, -1):
		var hook: Callable = _cancel_hooks[index]
		if hook.is_valid():
			hook.call()
	_cancel_hooks.clear()
	# 嵌套 / 公共事件有独立上下文，不在 EventRunner 的运行列表里：
	# 父级取消时必须级联，否则子级会继续等下去，父级协程收不了尾。
	for child in _active_children.duplicate():
		if child is EventContext and not child.cancelled:
			child.cancel(reason)
	_active_children.clear()
	if _owns_presenter and presenter != null and is_instance_valid(presenter) and presenter.has_method("close_all"):
		presenter.close_all()

## 统一的场景对象解析规则（详见 docs/16）：
##   scene_path 为空 → 相对「当前场景」解析，可跨场景复用；
##   scene_path 非空 → 必须是同一个场景，否则明确报错，绝不解析成别的对象。
func resolve_scene_object(scene_path: String, path: String) -> Dictionary:
	if path.strip_edges() == "":
		return {"node": null, "error": "empty"}
	if host == null:
		return {"node": null, "error": "no_host"}
	var tree := host.get_tree()
	if tree == null:
		return {"node": null, "error": "no_tree"}
	var active: Node = tree.current_scene
	var using_root := false
	if active == null:
		active = tree.root
		using_root = true
	if scene_path != "" and not using_root:
		var active_path := String(active.scene_file_path)
		if active_path != "" and active_path != scene_path:
			return {"node": null, "error": "wrong_scene:" + active_path}
	var node := active.get_node_or_null(NodePath(path))
	if node == null:
		return {"node": null, "error": "not_found:" + path}
	return {"node": node, "error": ""}

func resolve_node(path: String) -> Node:
	if path.strip_edges() == "" or host == null:
		return null
	var tree := host.get_tree()
	if tree == null:
		return null
	var search_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var node := search_root.get_node_or_null(NodePath(path))
	if node != null:
		return node
	return search_root.find_child(path, true, false)

func resolve_player() -> Node2D:
	if host == null:
		return null
	return host.get_tree().get_first_node_in_group("player") as Node2D

func resolve_camera() -> Camera2D:
	if host == null:
		return null
	var found := host.get_tree().get_first_node_in_group("camera")
	if found is Camera2D:
		return found
	var search_root: Node = host.get_tree().current_scene if host.get_tree().current_scene != null else host.get_tree().root
	for candidate in search_root.find_children("*", "Camera2D", true, false):
		if candidate is Camera2D:
			return candidate
	return null

func is_cancelled() -> bool:
	return cancelled

# ── 其它 ─────────────────────────────────────────────────

func get_param(name: String, default_value: Variant = null) -> Variant:
	return params.get(name, default_value)

func log(message: String) -> void:
	_logs.append(message)
	if OS.is_debug_build():
		print("[RPGEventStudio][%s] %s" % [event_id, message])

func take_logs() -> PackedStringArray:
	var out := _logs
	_logs = PackedStringArray()
	return out
