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

var _active: Dictionary = {}       ## event_id -> instance_id
var _page_runs: Dictionary = {}    ## "event@page" -> {count, revision}
var _next_instance_id: int = 1
var _running_instances: Array = []

# ── 启动 ─────────────────────────────────────────────────

func start(definition: EventDefinition, p_args: Dictionary = {}, trigger_filter: Array = []) -> void:
	if definition == null:
		return
	if _active.has(definition.event_id):
		# 同一事件正在执行：丢弃，防止连点导致重入
		return

	var page_index := definition.get_active_page(state, trigger_filter)
	if page_index < 0:
		# 一页都没命中：把每一页的条件结果记下来，调试面板与「为什么没触发」用
		bus.event_rejected.emit(definition.event_id, diagnose(definition, trigger_filter))
		return

	var page: EventPage = definition.pages[page_index]
	if not _should_run(definition, page_index, page):
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

	_active[definition.event_id] = ctx.instance_id
	_running_instances.append(ctx)
	_drive.call_deferred(ctx)

func is_busy(event_id: StringName) -> bool:
	return _active.has(event_id)

func active_count() -> int:
	return _running_instances.size()

func cancel_all(reason: String = "场景切换") -> void:
	for ctx in _running_instances:
		if ctx is EventContext and not ctx.cancelled:
			ctx.cancel(reason)

# ── 主循环 ───────────────────────────────────────────────

func _drive(ctx: EventContext) -> void:
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
	bus.event_finished.emit(report)
	# 收尾时关闭「本事件实际使用的」展示层：presenter 可能在事件中途被替换，
	# 不能拿新的展示层去关别人的 UI。
	if ctx.presenter != null and ctx.presenter.has_method("close_all") and _running_instances.is_empty():
		ctx.presenter.close_all()

func _execute_list(ctx: EventContext, commands: Array) -> int:
	var executed := 0
	for command in commands:
		if ctx.cancelled:
			return CmdResult.ABORT
		if command == null or not (command is EventCommand):
			continue
		if not command.enabled or command.type == &"" or command.type == &"comment":
			continue

		ctx.params = command.params
		ctx.command = command
		ctx.pending_block = []
		ctx.pending_call = {}

		var handler := registry.handler(command.type)
		if handler == null:
			push_error("[RPGEventStudio] " + L10n.game("diag.unknown_command", {"type": str(command.type)}))
			continue

		var code: int = handler.execute(ctx)
		match code:
			CmdResult.CONTINUE:
				pass
			CmdResult.WAIT:
				await _pump(ctx)
				if ctx.cancelled:
					return CmdResult.ABORT
			CmdResult.ENTER_BLOCK:
				var inner := await _execute_list(ctx, ctx.pending_block)
				if inner == CmdResult.ABORT:
					return CmdResult.ABORT
				if inner == CmdResult.HALT:
					return CmdResult.HALT
			CmdResult.CALL:
				var inner_code := await _execute_call(ctx)
				if inner_code == CmdResult.ABORT:
					return CmdResult.ABORT
			CmdResult.HALT:
				return CmdResult.HALT
			CmdResult.ABORT:
				return CmdResult.ABORT
			_:
				pass

		executed += 1
		if executed % COMMANDS_PER_FRAME == 0:
			await _next_frame()

	return CmdResult.CONTINUE

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
			var saved_page := ctx.page
			var saved_params := ctx.params
			var code := await _execute_list(ctx, common.commands)
			ctx.page = saved_page
			ctx.params = saved_params
			ctx.depth -= 1
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
			await _run_nested_event(ctx, target, call_args)
			return CmdResult.CONTINUE
	return CmdResult.CONTINUE

func _run_nested_event(parent: EventContext, target: EventDefinition, call_args: Dictionary) -> void:
	var page_index := target.get_active_page(state)
	if page_index < 0:
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
	_next_instance_id += 1
	await _execute_list(child, child.page.commands)

func _next_frame() -> void:
	var tree := host.get_tree() if host != null and host.is_inside_tree() else null
	if tree != null:
		await tree.process_frame
	else:
		await Engine.get_main_loop().process_frame

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
