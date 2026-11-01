@tool
class_name EventRunner
extends RefCounted
## 统一事件运行时：顺序执行、条件分支、等待、取消、防重复触发、结果上报。
##
## 设计要点：指令处理器同步返回控制流意图，异步由本类轮询 —— 
## 这样不需要在处理器里写 await，也不会被 GDScript 的协程静态检查绊住。

enum Result { COMPLETED, CANCELLED, FAILED }

const MAX_CALL_DEPTH := 8
const COMMANDS_PER_FRAME := 64

var host: Node
var state: StateStore
var bus: EventBus
var presenter
var registry: CommandRegistry
## 可选运行时追踪；为 null 时零开销。
var trace: RuntimeTrace = null

var _active: Dictionary = {}       ## event_id -> instance_id
var _page_runs: Dictionary = {}    ## "event@page" -> {count, revision}
var _next_instance_id: int = 1
var _running_instances: Array = []
## 当前监听离树信号的 Node 型展示层（切场景 / 释放时取消运行中的事件）。
var _watched_presenter: Node = null

# ── 启动 ─────────────────────────────────────────────────

## 让状态写入能被追踪归因；已有观察者（StudioRuntime 设置）时不重复覆盖。
func _ensure_trace_observer() -> void:
	if trace == null or state == null or state.write_observer.is_valid():
		return
	var trace_ref: RuntimeTrace = trace
	state.write_observer = func(key: String, old_value: Variant, new_value: Variant, existed: bool) -> void:
		trace_ref.state_changed(key, old_value, new_value, existed)

func start(definition: EventDefinition, p_args: Dictionary = {}, trigger_filter: Array = [],
		source: Dictionary = {}) -> void:
	if definition == null:
		return
	_ensure_trace_observer()
	# 真实来源：图节点放入 pending 的来源优先，其次是调用方显式传入（交互组件等）。
	var event_source := {}
	if trace != null:
		var pending := trace.take_pending_source()
		event_source = pending if not pending.is_empty() else source
		# 空闲时清掉上一条因引擎异常残留的上下文，避免旧事件污染后续归因。
		if _running_instances.is_empty():
			trace.clear_stale_contexts()
	else:
		event_source = source

	if _active.has(definition.event_id):
		# 同一事件正在执行：丢弃，防止连点导致重入
		if trace != null:
			trace.record_ignored(trace.new_trace_id(), definition, "reentry",
				{"running_instance": int(_active[definition.event_id])}, event_source)
		return

	var page_index := definition.get_active_page(state, trigger_filter)
	if page_index < 0:
		# 一页都没命中：把每一页的条件结果记下来，调试面板与「为什么没触发」用
		var rejection := diagnose(definition, trigger_filter)
		if trace != null:
			trace.record_rejected(trace.new_trace_id(), definition, trigger_filter, rejection, event_source)
		bus.event_rejected.emit(definition.event_id, rejection)
		return

	var page: EventPage = definition.pages[page_index]
	if not _should_run(definition, page_index, page):
		if trace != null:
			trace.record_ignored(trace.new_trace_id(), definition, "repeat_policy",
				{"policy": page.repeat_policy, "page_index": page_index}, event_source)
		return

	var ctx := EventContext.new()
	ctx.host = host
	ctx.state = state
	ctx.bus = bus
	ctx.presenter = presenter
	ctx.definition = definition
	ctx.page = page
	ctx.event_id = definition.event_id
	ctx.args = p_args
	ctx.instance_id = _next_instance_id
	_next_instance_id += 1
	ctx.trace = trace
	ctx.page_index = page_index
	ctx.trigger_filter = trigger_filter
	ctx.source = event_source
	if trace != null:
		ctx.trace_pages = _page_decisions(definition, trigger_filter, page_index)

	_active[definition.event_id] = ctx.instance_id
	_running_instances.append(ctx)
	_watch_presenter(presenter)
	_drive.call_deferred(ctx)

func is_busy(event_id: StringName) -> bool:
	return _active.has(event_id)

func active_count() -> int:
	return _running_instances.size()

func cancel_all(reason: String = "场景切换") -> void:
	for ctx in _running_instances:
		if ctx is EventContext and not ctx.cancelled:
			ctx.cancel(reason)

# ── 展示层生命周期 ───────────────────────────────────────
## Node 型展示层可以被宿主挂在自己的场景树里（set_presenter 不重复挂载），
## 会随场景切换一起离树甚至释放。监听 tree_exited：离树即对持有它的运行中
## 上下文执行带原因的取消，让等待谓词、_active 擦除与 event_finished 正常收尾，
## 避免「已释放实例逐帧报错且永不满足」导致的全场交互软锁。
## 非 Node（RefCounted / Object）展示层没有 tree_exited 信号，不监听，
## 只靠等待谓词与调用点的 is_instance_valid 防护。
func _watch_presenter(candidate) -> void:
	if candidate == null or not is_instance_valid(candidate) or not (candidate is Node):
		return
	if _watched_presenter == candidate:
		return
	_unwatch_presenter()
	_watched_presenter = candidate
	(candidate as Node).tree_exited.connect(_on_watched_presenter_tree_exited)

func _unwatch_presenter() -> void:
	if _watched_presenter != null and is_instance_valid(_watched_presenter):
		_watched_presenter.tree_exited.disconnect(_on_watched_presenter_tree_exited)
	_watched_presenter = null

func _on_watched_presenter_tree_exited() -> void:
	var exited: Node = _watched_presenter
	for ctx in _running_instances:
		if ctx is EventContext and not ctx.cancelled and ctx.presenter == exited:
			ctx.cancel("presenter 已释放")

# ── 主循环 ───────────────────────────────────────────────

func _drive(ctx: EventContext) -> void:
	if trace != null:
		ctx.trace_id = trace.new_trace_id()
		trace.begin_event(ctx.trace_id, ctx.definition, ctx.instance_id, ctx.depth,
			ctx.parent_trace_id, ctx.trigger_filter, ctx.trace_pages, ctx.source)
		trace.enter_context(ctx.trace_id, ctx.event_id)
	bus.event_started.emit(ctx.event_id, ctx.instance_id)
	var started_at := Time.get_ticks_msec()
	var result := Result.COMPLETED
	var fail_reason := ""

	state.transaction()
	var code := await _execute_list(ctx, ctx.page.commands)
	state.commit()

	if ctx.cancelled:
		result = Result.CANCELLED
	elif code == CmdResult.ABORT:
		result = Result.FAILED
		fail_reason = L10n.game("diag.command_failed")

	_active.erase(ctx.event_id)
	_running_instances.erase(ctx)

	var report := {
		"event_id": ctx.event_id,
		"instance_id": ctx.instance_id,
		"result": result,
		"reason": ctx.cancel_reason if result == Result.CANCELLED else fail_reason,
		"duration_ms": Time.get_ticks_msec() - started_at,
	}
	if trace != null:
		trace.end_event(ctx.trace_id, result, str(report["reason"]), int(report["duration_ms"]))
		trace.exit_context(ctx.trace_id)
	bus.event_finished.emit(report)
	# 收尾时关闭「本事件实际使用的」展示层：presenter 可能在事件中途被替换，
	# 不能拿新的展示层去关别人的 UI。
	if ctx.presenter != null and is_instance_valid(ctx.presenter) and ctx.presenter.has_method("close_all") and _running_instances.is_empty():
		ctx.presenter.close_all()

func _execute_list(ctx: EventContext, commands: Array) -> int:
	var executed := 0
	for index in commands.size():
		if ctx.cancelled:
			return CmdResult.ABORT
		var command: EventCommand = commands[index]
		if command == null or not (command is EventCommand):
			continue
		if not command.enabled or command.type == &"" or command.type == &"comment":
			continue

		ctx.params = command.params
		ctx.command = command
		ctx.command_index = index
		ctx.command_serial += 1
		var serial := ctx.command_serial
		var command_type := String(command.type)
		ctx.pending_block = []
		ctx.pending_call = {}
		var started_ms := Time.get_ticks_msec()
		if trace != null:
			trace.command_start(ctx.trace_id, serial, index, command_type, ctx.depth)
			trace.set_command(ctx.trace_id, index, command_type)

		var handler := registry.handler(command.type)
		if handler == null:
			push_error("[RPGEventStudio] " + L10n.game("diag.unknown_command", {"type": str(command.type)}))
			_trace_command_end(ctx, serial, index, command_type, CmdResult.ABORT, started_ms)
			continue

		var code: int = handler.execute(ctx)
		match code:
			CmdResult.CONTINUE:
				pass
			CmdResult.WAIT:
				await _pump(ctx)
				if ctx.cancelled:
					_trace_command_end(ctx, serial, index, command_type, CmdResult.ABORT, started_ms)
					return CmdResult.ABORT
			CmdResult.ENTER_BLOCK:
				var inner := await _execute_list(ctx, ctx.pending_block)
				if inner == CmdResult.ABORT:
					_trace_command_end(ctx, serial, index, command_type, CmdResult.ABORT, started_ms)
					return CmdResult.ABORT
				if inner == CmdResult.HALT:
					_trace_command_end(ctx, serial, index, command_type, CmdResult.HALT, started_ms)
					return CmdResult.HALT
			CmdResult.CALL:
				var inner_code := await _execute_call(ctx)
				if inner_code == CmdResult.ABORT:
					_trace_command_end(ctx, serial, index, command_type, CmdResult.ABORT, started_ms)
					return CmdResult.ABORT
			CmdResult.HALT:
				_trace_command_end(ctx, serial, index, command_type, CmdResult.HALT, started_ms)
				return CmdResult.HALT
			CmdResult.ABORT:
				_trace_command_end(ctx, serial, index, command_type, CmdResult.ABORT, started_ms)
				return CmdResult.ABORT
			_:
				pass

		_trace_command_end(ctx, serial, index, command_type, code, started_ms)
		executed += 1
		if executed % COMMANDS_PER_FRAME == 0:
			await _next_frame()

	return CmdResult.CONTINUE

func _trace_command_end(ctx: EventContext, serial: int, index: int, command_type: String,
		result: int, started_ms: int) -> void:
	if trace == null:
		return
	trace.command_end(ctx.trace_id, serial, index, command_type, result,
		Time.get_ticks_msec() - started_ms)

func _pump(ctx: EventContext) -> void:
	while not ctx.is_wait_done():
		if ctx.cancelled:
			return
		await _next_frame()
	ctx.finish_wait()

func _execute_call(ctx: EventContext) -> int:
	var call_info: Dictionary = ctx.pending_call
	var kind: String = str(call_info.get("kind", ""))
	var ref: Variant = call_info.get("ref", null)
	var call_args: Dictionary = call_info.get("args", {})

	if ctx.depth >= MAX_CALL_DEPTH:
		push_error("[RPGEventStudio] " + L10n.game("diag.recursion", {"depth": ctx.depth}))
		return CmdResult.ABORT

	match kind:
		"common":
			var common: CommonEvent = null
			if ref is CommonEvent:
				common = ref
			elif ref is String and String(ref) != "":
				common = load(String(ref)) as CommonEvent
			if common == null:
				push_error("[RPGEventStudio] " + L10n.game("diag.common_missing", {"ref": str(ref)}))
				return CmdResult.ABORT
			ctx.depth += 1
			if trace != null:
				trace.record_call(ctx.trace_id, ctx.parent_trace_id, "common", str(ref), ctx.depth, "enter")
			var saved_page := ctx.page
			var saved_params := ctx.params
			var code := await _execute_list(ctx, common.commands)
			ctx.page = saved_page
			ctx.params = saved_params
			ctx.depth -= 1
			if trace != null:
				trace.record_call(ctx.trace_id, ctx.parent_trace_id, "common", str(ref), ctx.depth, "exit")
			return code
		"event":
			var target: EventDefinition = null
			if ref is EventDefinition:
				target = ref
			elif ref is String and String(ref) != "":
				target = load(String(ref)) as EventDefinition
			if target == null:
				push_error("[RPGEventStudio] " + L10n.game("diag.event_missing", {"ref": str(ref)}))
				return CmdResult.ABORT
			if trace != null:
				trace.record_call(ctx.trace_id, ctx.parent_trace_id, "event", String(target.event_id),
					ctx.depth + 1, "enter", String(target.event_id))
			await _run_nested_event(ctx, target, call_args)
			if trace != null:
				trace.record_call(ctx.trace_id, ctx.parent_trace_id, "event", String(target.event_id),
					ctx.depth + 1, "exit", String(target.event_id))
			return CmdResult.CONTINUE
	return CmdResult.CONTINUE

func _run_nested_event(parent: EventContext, target: EventDefinition, call_args: Dictionary) -> void:
	var page_index := target.get_active_page(state)
	var child_trace_id := trace.new_trace_id() if trace != null else 0
	if page_index < 0:
		if trace != null:
			trace.record_rejected(child_trace_id, target, [], diagnose(target, []),
				{"kind": "nested", "parent_event_id": String(parent.event_id)})
		return
	var child := EventContext.new()
	child.host = host
	child.state = state
	child.bus = bus
	child.presenter = parent.presenter
	child.definition = target
	child.page = target.pages[page_index]
	child.event_id = target.event_id
	child.args = call_args
	child.depth = parent.depth + 1
	child.instance_id = _next_instance_id
	child.page_index = page_index
	child.parent_trace_id = parent.trace_id
	child.source = {"kind": "nested", "parent_event_id": String(parent.event_id)}
	child.trace = trace
	child.trace_id = child_trace_id
	if trace != null:
		child.trace_pages = _page_decisions(target, [], page_index)
		trace.begin_event(child.trace_id, target, child.instance_id, child.depth,
			child.parent_trace_id, [], child.trace_pages, child.source)
		trace.enter_context(child.trace_id, child.event_id)
	_next_instance_id += 1
	var started_ms := Time.get_ticks_msec()
	# 嵌套事件有独立上下文且不在 _running_instances 里：登记到父级，
	# 父级被取消（如展示层离树）时随级联一起取消，避免子级独自等待、父级收不了尾。
	parent._attach_child(child)
	var code := await _execute_list(child, child.page.commands)
	parent._detach_child(child)
	if trace != null:
		var result := Result.COMPLETED
		var reason := ""
		if child.cancelled:
			result = Result.CANCELLED
			reason = child.cancel_reason
		elif code == CmdResult.ABORT:
			result = Result.FAILED
			reason = L10n.game("diag.command_failed")
		trace.end_event(child.trace_id, result, reason, Time.get_ticks_msec() - started_ms)
		trace.exit_context(child.trace_id)

func _next_frame() -> void:
	var tree := host.get_tree() if host != null and host.is_inside_tree() else null
	if tree != null:
		await tree.process_frame
	else:
		await Engine.get_main_loop().process_frame

## 把 diagnose 的结果标上本次实际选中的页；追踪开启时才调用。
func _page_decisions(definition: EventDefinition, trigger_filter: Array, selected: int) -> Array:
	var out: Array = []
	for page in diagnose(definition, trigger_filter).get("pages", []):
		var copy: Dictionary = page
		copy["selected"] = int(copy.get("index", -1)) == selected
		out.append(copy)
	return out

## 给出「为什么这个事件没执行」的逐条说明。
func diagnose(definition: EventDefinition, trigger_filter: Array = []) -> Dictionary:
	var pages: Array = []
	for index in definition.pages.size():
		var page: EventPage = definition.pages[index]
		if page == null:
			continue
		var trigger_ok: bool = trigger_filter.is_empty() or definition.matches_trigger(page, trigger_filter)
		var conditions: Array = []
		var conditions_ok := true
		for condition in page.conditions:
			if condition == null:
				continue
			var resolved := StateStore.resolve_key(condition.key, state.level_prefix)
			var matched := state.compare(resolved, condition.op, condition.value)
			conditions.append({
				"key": condition.key,
				"op": condition.op,
				"value": condition.value,
				"actual": state.get_value(resolved, null),
				"ok": matched,
			})
			if not matched:
				conditions_ok = false
		pages.append({
			"index": index,
			"trigger": page.trigger,
			"trigger_ok": trigger_ok,
			"conditions": conditions,
			"active": trigger_ok and conditions_ok,
		})
	return {"trigger_filter": trigger_filter, "pages": pages}

# ── 触发策略 ─────────────────────────────────────────────

func _should_run(definition: EventDefinition, page_index: int, page: EventPage) -> bool:
	var key := "%s@%d" % [definition.event_id, page_index]
	var record: Dictionary = _page_runs.get(key, {})
	match page.repeat_policy:
		"once":
			if int(record.get("count", 0)) > 0:
				return false
		"on_change":
			if record.has("revision") and int(record["revision"]) == state.revision:
				return false
	_page_runs[key] = {
		"count": int(record.get("count", 0)) + 1,
		"revision": state.revision,
	}
	return true
