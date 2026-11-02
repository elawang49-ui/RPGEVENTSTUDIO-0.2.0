extends SceneTree
## Deliberate extension faults. The harness must see SCRIPT ERROR; the runner must
## still report FAILED, roll back, and release all instances. No diagnostic exemption.
class BrokenHandler:
	extends CommandHandler
	func execute(ctx: EventContext) -> int:
		ctx.set_state("Fault.Partial", 1)
		var missing: Node = null
		missing.name = "boom"
		return CmdResult.CONTINUE
class BrokenWait:
	extends CommandHandler
	func execute(ctx: EventContext) -> int:
		ctx.set_state("Fault.Partial", 1)
		ctx.wait_until(_broken)
		return CmdResult.WAIT
	func _broken() -> bool:
		var missing: Node = null
		missing.name = "boom"
		return true
class BrokenAfter:
	extends CommandHandler
	func execute(ctx: EventContext) -> int:
		ctx.set_state("Fault.Partial", 1)
		ctx.wait_until(func(): return true, -1.0, _broken)
		return CmdResult.WAIT
	func _broken() -> void:
		var missing: Node = null
		missing.name = "boom"
var checks := 0
var failures := 0
func _initialize(): _run.call_deferred()
func _check(ok: bool):
	checks += 1
	if not ok: failures += 1
func _run():
	CommandRegistry.ensure_built()
	var host := Node.new(); root.add_child(host)
	var runner := EventRunner.new(); runner.host = host
	runner.state = StateStore.new(); runner.bus = EventBus.new(); runner.registry = CommandRegistry.new()
	var reports: Array = []
	runner.bus.event_finished.connect(func(report): reports.append(report))
	for handler in [BrokenHandler.new(), BrokenWait.new(), BrokenAfter.new()]:
		CommandRegistry._register(&"broken_extension", "broken", CommandRegistry.CAT_FLOW, [], handler)
		var event := EventDefinition.new(); event.event_id = &"broken_extension"
		var page := event.add_page(); page.repeat_policy = "once"
		page.commands = [CommandRegistry.create_command(&"broken_extension")]
		runner.start(event)
		for i in 12: await process_frame
		_check(runner.active_count() == 0)
		_check(not runner.state.has("Fault.Partial"))
		_check(not reports.is_empty() and reports[-1].result == EventRunner.Result.FAILED)
		_check(not reports.is_empty() and str(reports[-1].reason).contains("Nil"))
	if failures == 0: print("RUNTIME_GUARD_PASS checks=12")
	print("检查项：%d，失败：%d" % [checks, failures])
	host.queue_free(); await process_frame
	quit(0 if failures == 0 else 1)
