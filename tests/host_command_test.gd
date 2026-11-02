extends SceneTree
## 宿主自定义指令注册（register_host_command）自动化测试：
##   godot --headless --path . --script res://tests/host_command_test.gd
## 退出码 0 = 全部通过。
##
## 覆盖：
##   1. 宿主指令注册后进 all_types/spec/create_command，参数默认值正确
##   2. display_name 走 L10n，缺失时回退 fallback_name；自定义分类可用
##   3. summary 支持 {param} 模板；无模板时返回显示名
##   4. 内置指令不可被宿主覆盖（handler 与 spec 保持原样）
##   5. 同名宿主指令重复注册被拒绝（先到先得）
##   6. 运行时：事件里的宿主指令能读参数、写状态、等待后收尾（COMPLETED 上报）
##   7. 运行时：宿主指令内 ctx.cancel 生效（CANCELLED 上报）

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# 第 1 条用例本身就负责注册 host_demo；host_demo_wait 供取消用例使用。
	var wait_error := CommandRegistry.register_host_command(&"host_demo_wait", {
		"name_key": "cmd.host_demo_wait_missing_key",
		"fallback_name": "示例等待",
		"category": "cat.host",
		"params": [],
	}, HostDemoWaitCommand.new())
	_check(wait_error == OK, "注册等待型宿主指令应返回 OK（实际 %d）" % wait_error)
	_test_register_and_spec()
	_test_display_name_and_category()
	_test_summary_template()
	_test_builtin_protected()
	_test_duplicate_rejected()
	await _test_runtime_execution()
	await _test_runtime_cancel()
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 用例 ─────────────────────────────────────────────────

func _test_register_and_spec() -> void:
	var error := CommandRegistry.register_host_command(&"host_demo", {
		"name_key": "cmd.host_demo_missing_key",
		"fallback_name": "示例宿主指令",
		"category": "cat.host",
		"params": [
			{"name": "target_key", "label_key": "param.state", "type": "state", "default": ""},
			{"name": "amount", "label_key": "param.number", "type": "float", "default": 1.0},
		],
		"summary": "示例 → {target_key}({amount})",
	}, HostDemoCommand.new())
	_check(error == OK, "注册新宿主指令应返回 OK（实际 %d）" % error)
	_check(CommandRegistry.all_types().has(&"host_demo"), "all_types 应包含宿主指令")
	var spec := CommandRegistry.spec(&"host_demo")
	_check(int(spec.get("params", []).size()) == 2, "spec.params 应保留宿主参数表")
	var command := CommandRegistry.create_command(&"host_demo")
	_check(command != null and command.type == &"host_demo", "create_command 应产出宿主指令")
	_check(str(command.params.get("amount", 0.0)) == "1.0", "参数默认值应来自 spec（amount）")
	_check(CommandRegistry.handler(&"host_demo") is HostDemoCommand, "handler 应可取回宿主处理器")

func _test_display_name_and_category() -> void:
	var name_text := CommandRegistry.display_name(&"host_demo")
	_check(name_text == "示例宿主指令",
		"L10n 缺键时 display_name 应回退 fallback_name（实际 %s）" % name_text)
	_check(CommandRegistry.categories().has("cat.host"), "categories 应包含宿主自定义分类")
	_check(CommandRegistry.types_in_category("cat.host").has(&"host_demo"),
		"types_in_category 应能取到宿主指令")

func _test_summary_template() -> void:
	var command := CommandRegistry.create_command(&"host_demo")
	command.params["target_key"] = "School.Office.PcChecked"
	command.params["amount"] = 3
	var text := CommandRegistry.summary(command)
	_check(text.contains("School.Office.PcChecked") and text.contains("3"),
		"summary 应渲染 {param} 模板（实际 %s）" % text)
	var spec := CommandRegistry.spec(&"host_demo")
	spec.erase("summary")
	var fallback := CommandRegistry.summary(command)
	_check(fallback == "示例宿主指令", "无模板时 summary 应回退显示名（实际 %s）" % fallback)

func _test_builtin_protected() -> void:
	var builtin := CommandRegistry.handler(&"show_text")
	var error := CommandRegistry.register_host_command(&"show_text", {}, HostDemoCommand.new())
	_check(error == ERR_ALREADY_EXISTS, "内置指令不可被覆盖（实际 %d）" % error)
	_check(CommandRegistry.handler(&"show_text") == builtin, "内置 handler 不应被替换")
	_check(CommandRegistry.handler(&"show_text") is CmdShowText, "内置 handler 类型应保持 CmdShowText")

func _test_duplicate_rejected() -> void:
	var error := CommandRegistry.register_host_command(&"host_demo", {}, HostDemoCommand.new())
	_check(error == ERR_ALREADY_EXISTS, "重复注册同名宿主指令应拒绝（实际 %d）" % error)

func _test_runtime_execution() -> void:
	var ctx := _make_runner()
	var runner: EventRunner = ctx["runner"]
	var state: StateStore = ctx["state"]
	state.define("Host.Demo.Count", TYPE_INT, 0)
	var finished := []
	ctx["bus"].event_finished.connect(func(report: Dictionary) -> void: finished.append(report))

	var definition := EventDefinition.new()
	definition.event_id = &"host_demo_event"
	var page := EventPage.new()
	page.commands = [
		_cmd(&"host_demo", {"target_key": "Host.Demo.Count", "amount": 2.0}),
		_end(),
	]
	definition.pages = [page]
	runner.start(definition)
	await _wait_idle(runner, 5.0)

	_check(int(state.get_value("Host.Demo.Count", -1)) == 2,
		"宿主指令应能写状态（实际 %s）" % str(state.get_value("Host.Demo.Count", -1)))
	_check(not finished.is_empty() and int(finished[0].get("result", -1)) == EventRunner.Result.COMPLETED,
		"事件应以 COMPLETED 收尾（实际 %s）" % str(finished))
	ctx["host"].queue_free()
	await process_frame

func _test_runtime_cancel() -> void:
	var ctx := _make_runner()
	var runner: EventRunner = ctx["runner"]
	var finished := []
	ctx["bus"].event_finished.connect(func(report: Dictionary) -> void: finished.append(report))

	var definition := EventDefinition.new()
	definition.event_id = &"host_demo_cancel"
	var page := EventPage.new()
	page.commands = [
		_cmd(&"host_demo_wait", {}),
		_end(),
	]
	definition.pages = [page]
	runner.start(definition)
	await process_frame
	await process_frame
	runner.cancel_all("测试取消")
	await _wait_idle(runner, 5.0)

	_check(not finished.is_empty() and int(finished[0].get("result", -1)) == EventRunner.Result.CANCELLED,
		"宿主指令等待中的事件被取消应以 CANCELLED 收尾（实际 %s）" % str(finished))
	ctx["host"].queue_free()
	await process_frame

# ── 工具 ─────────────────────────────────────────────────

class HostDemoCommand extends CommandHandler:
	func execute(ctx: EventContext) -> int:
		var amount := float(ctx.get_param("amount", 1.0))
		ctx.set_state(str(ctx.get_param("target_key", "")), int(amount))
		return CmdResult.CONTINUE

class HostDemoWaitCommand extends CommandHandler:
	func execute(ctx: EventContext) -> int:
		ctx.wait_seconds(30.0)
		return CmdResult.WAIT

func _cmd(type: StringName, params: Dictionary) -> EventCommand:
	var command := EventCommand.new()
	command.type = type
	command.params = params
	return command

func _end() -> EventCommand:
	return _cmd(&"end", {})

func _make_runner() -> Dictionary:
	var host := Node.new()
	host.name = "HostCommandTestHost"
	root.add_child(host)
	var presenter := MockPresenter.new()
	presenter.name = "HostCommandTestPresenter"
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
	return {"host": host, "presenter": presenter, "state": state, "bus": bus, "runner": runner}

## 等待运行队列清空（最多 timeout 秒），避免测试固定 sleep。
func _wait_idle(runner: EventRunner, timeout: float = 5.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if int(runner.active_count()) == 0:
			return
		await process_frame

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ " + message)
	else:
		_failures.append(message)
		print("  ✗ " + message)

func _report() -> void:
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("    FAIL: " + failure)
