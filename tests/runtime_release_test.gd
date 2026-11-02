extends SceneTree
## Release regressions: transaction isolation/cancellation, once, presenter ownership, pause.
var _checks := 0
var _failures: Array[String] = []
class ReleasePresenter:
	extends Node
	var texts: Array[String] = []
	var done := false
	var closed := 0
	func show_text(_speaker, text, _auto = 0.0): texts.append(text); done = false
	func is_text_finished(): return done
	func show_choices(_prompt, _options): pass
	func get_choice(): return -1
	func close_all(): closed += 1; done = true
class FailCommand:
	extends CommandHandler
	func execute(_ctx: EventContext) -> int: return CmdResult.ABORT
class CleanupCommand:
	extends CommandHandler
	func execute(ctx: EventContext) -> int:
		var counter: Array = ctx.params["counter"]
		ctx.on_cancel(func(): counter[0] += 1)
		return CmdResult.CONTINUE
class StoreLifecycleCommand:
	extends CommandHandler
	func execute(ctx: EventContext) -> int:
		match str(ctx.params.get("mode", "")):
			"restore": ctx.state.restore({"revision": 3, "values": {"Restored": 9}})
			"reset": ctx.state.reset()
			"snapshot":
				var data := ctx.state.snapshot()
				ctx.set_state("Derived", data["values"].get("ReadOnly", 0))
		ctx.set_state("AfterLifecycle", 1)
		ctx.wait_seconds(float(ctx.params.get("wait", 0.0)))
		return CmdResult.WAIT
class CallCommand:
	extends CommandHandler
	func execute(ctx: EventContext) -> int:
		ctx.pending_call = {"kind": "event", "ref": ctx.params["target"]}
		return CmdResult.CALL
func _init(): _run.call_deferred()
func _run():
	CommandRegistry.ensure_built()
	CommandRegistry._register(&"release_fail", "fail", CommandRegistry.CAT_FLOW, [], FailCommand.new())
	CommandRegistry._register(&"release_call", "call", CommandRegistry.CAT_FLOW, [], CallCommand.new())
	CommandRegistry._register(&"release_cleanup", "cleanup", CommandRegistry.CAT_FLOW, [], CleanupCommand.new())
	CommandRegistry._register(&"release_store_lifecycle", "store", CommandRegistry.CAT_STATE, [], StoreLifecycleCommand.new())
	_test_batching()
	await _test_cancel_once()
	await _test_conflict()
	await _test_nested()
	await _test_presenter()
	await _test_pause()
	await _test_graph_gates()
	await _test_lifecycle_edges()
	await _test_runtime_scene_scope()
	await _test_store_lifecycle()
	await _test_graph_restore()
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures: print("  ✗ ", failure)
	quit(0 if _failures.is_empty() else 1)
func _check(ok: bool, message: String):
	_checks += 1
	if not ok: _failures.append(message)
func _fixture() -> Dictionary:
	var host := Node.new()
	root.add_child(host)
	var r := EventRunner.new()
	r.host = host; r.state = StateStore.new(); r.bus = EventBus.new(); r.registry = CommandRegistry.new()
	var reports: Array = []
	r.bus.event_finished.connect(func(report): reports.append(report))
	return {"host": host, "runner": r, "reports": reports}
func _event(id: String, commands: Array, policy := "every_time") -> EventDefinition:
	var e := EventDefinition.new(); e.event_id = StringName(id)
	var p := EventPage.new(); p.repeat_policy = policy; p.commands.assign(commands); e.pages = [p]
	return e
func _cmd(type: StringName, params: Dictionary = {}) -> EventCommand:
	var c := CommandRegistry.create_command(type); c.params.merge(params, true); return c
func _setter(key: String, value: Variant) -> EventCommand: return _cmd(&"set_variable", {"key": key, "value": value})
func _frames(count := 4):
	for i in count: await process_frame
func _idle(r: EventRunner):
	for i in 150:
		if r.active_count() == 0: break
		await process_frame
	_check(r.active_count() == 0, "runner settles within bounded frames")
func _test_batching():
	var s := StateStore.new(); var changes: Array = []; var batches: Array = []
	s.changed.connect(func(key, old, value): changes.append([key, old, value]))
	s.batch_committed.connect(func(keys, _revision): batches.append(keys))
	s.transaction(); s.set_value("A", 1); s.transaction(); s.set_value("B", 2); s.commit()
	_check(changes.is_empty(), "inner commit must not flush outer transaction")
	s.set_value("A", 3); s.commit()
	_check(changes.size() == 2 and batches.size() == 1, "one outer batch, one change per key")
	_check(s.get_int("A") == 3 and s.revision == 1, "batch final values/revision")
	var nested := StateStore.new(); var result: Array = []
	nested.changed.connect(func(key, _old, _new):
		if key == "A":
			nested.transaction(); nested.set_value("B", 7)
	)
	nested.batch_committed.connect(func(keys, _revision): result.append(keys))
	nested.transaction(); nested.set_value("A", 1); nested.commit(); nested.commit()
	_check(result.size() == 2 and result[1] == PackedStringArray(["B"]), "signal reentry keeps next batch intact")
	var immediate := StateStore.new(); var revisions: Array = []
	immediate.changed.connect(func(key, _old, _new):
		if key == "A":
			immediate.transaction(); immediate.set_value("B", 2); immediate.commit()
	)
	immediate.batch_committed.connect(func(_keys, rev): revisions.append(rev))
	immediate.transaction(); immediate.set_value("A", 1); immediate.commit()
	_check(revisions == [1, 2], "listener commits preserve batch notification revision order")
func _test_cancel_once():
	var f := _fixture(); var r: EventRunner = f.runner
	var event := _event("once", [_setter("Flag", 1), _cmd(&"wait", {"seconds": 0.12}), _setter("Done", 1)], "once")
	r.start(event); await _frames()
	_check(not r.state.has("Flag"), "uncommitted state invisible to host")
	r.cancel_all(); await _idle(r)
	_check(not r.state.has("Flag") and not r.state.has("Done"), "cancel discards partial state")
	_check(f.reports[-1].result == EventRunner.Result.CANCELLED, "cancel report")
	event.pages[0].commands[1].params.seconds = 0.0
	r.start(event); await _idle(r)
	_check(r.state.get_int("Flag") == 1 and r.state.get_int("Done") == 1, "cancelled once can retry")
	var count: int = f.reports.size(); r.start(event); await _frames()
	_check(f.reports.size() == count, "successful once consumed")
	var cleanup := [0]
	var failed := _event("fail", [_cmd(&"release_cleanup", {"counter": cleanup}), _setter("Bad", 1), _cmd(&"release_fail")], "once")
	r.start(failed); await _idle(r)
	_check(not r.state.has("Bad") and f.reports[-1].result == EventRunner.Result.FAILED, "failed state discarded")
	_check(cleanup[0] == 1, "failure unwinds registered cancellation cleanup")
	failed.pages[0].commands.pop_back(); r.start(failed); await _idle(r)
	_check(r.state.get_int("Bad") == 1, "failed once can retry")
	f.host.queue_free(); await _frames(1)
func _test_conflict():
	var f := _fixture(); var r: EventRunner = f.runner
	r.state.set_value("Count", 1)
	r.start(_event("slow", [_cmd(&"variable_op", {"key": "Count", "value": 1}), _cmd(&"wait", {"seconds": 0.05})]))
	await _frames(); r.state.set_value("Count", 10)
	await _idle(r)
	_check(r.state.get_int("Count") == 10, "host write survives stale event commit")
	_check(f.reports[-1].result == EventRunner.Result.FAILED and str(f.reports[-1].reason).contains("conflict"), "conflict explicit failure")
	r.start(_event("a", [_setter("A", 1), _cmd(&"wait", {"seconds": 0.04})]))
	r.start(_event("b", [_setter("B", 2)])); await _idle(r)
	_check(r.state.get_int("A") == 1 and r.state.get_int("B") == 2, "disjoint concurrent writes both commit")
	f.host.queue_free(); await _frames(1)
func _test_nested():
	var f := _fixture(); var r: EventRunner = f.runner
	var cleanup := [0]
	var child := _event("child", [_cmd(&"release_cleanup", {"counter": cleanup}), _setter("Child", 1)], "once")
	var parent := _event("parent", [_cmd(&"release_call", {"target": child}), _cmd(&"wait", {"seconds": 1.0})])
	r.start(parent); await _frames()
	var report_count: int = f.reports.size()
	r.start(child); await _frames()
	_check(f.reports.size() == report_count, "nested once reserved until parent commits or rolls back")
	r.cancel_all(); await _idle(r)
	_check(not r.state.has("Child"), "parent cancel discards completed child writes")
	_check(cleanup[0] == 1, "parent cancellation rolls back completed child cleanup hooks")
	r.start(child); await _idle(r)
	_check(r.state.get_int("Child") == 1, "child once not consumed by rolled back parent")
	var bad_child := _event("bad_child", [_cmd(&"release_fail")])
	r.start(_event("bad_parent", [_setter("Parent", 1), _cmd(&"release_call", {"target": bad_child})])); await _idle(r)
	_check(f.reports[-1].result == EventRunner.Result.FAILED and not r.state.has("Parent"), "child failure aborts parent session")
	f.host.queue_free(); await _frames(1)
func _test_presenter():
	var f := _fixture(); var r: EventRunner = f.runner
	var p := ReleasePresenter.new(); f.host.add_child(p); r.presenter = p
	r.start(_event("text_a", [_cmd(&"show_text", {"text": "A"})]))
	r.start(_event("text_b", [_cmd(&"show_text", {"text": "B"})]))
	await _frames()
	_check(p.texts == ["A"], "shared presenter serialized without text overwrite")
	p.done = true; await _frames()
	_check(p.texts == ["A", "B"], "waiting presentation starts after owner finishes")
	_check(r.active_count() == 1, "one completed text cannot complete another event")
	p.done = true; await _idle(r)
	r.start(_event("owner", [_cmd(&"show_text", {"text": "owner"})])); await _frames()
	r.start(_event("state_only", [_setter("Background", 1)])); await _frames()
	_check(p.texts[-1] == "owner" and not p.done, "state-only event must not close another presenter")
	r.cancel_all(); await _idle(r)
	f.host.queue_free(); await _frames(1)
func _test_pause():
	var f := _fixture(); var r: EventRunner = f.runner
	r.start(_event("pause", [_cmd(&"wait", {"seconds": 0.08}), _setter("AfterPause", 1)]))
	await _frames(2); paused = true
	await create_timer(0.13, true).timeout
	_check(not r.state.has("AfterPause") and r.active_count() == 1, "pause freezes event execution")
	paused = false; await _frames(2)
	_check(not r.state.has("AfterPause"), "wait retains remaining duration across pause")
	await _idle(r)
	_check(r.state.get_int("AfterPause") == 1, "resume completes wait")
	var cancel_during_commit := func(key, _old, _new):
		if key == "CommitBoundary": r.cancel_all("during committed notification")
	r.state.changed.connect(cancel_during_commit)
	r.start(_event("commit_boundary", [_setter("CommitBoundary", 1)])); await _idle(r)
	_check(f.reports[-1].result == EventRunner.Result.COMPLETED and r.state.get_int("CommitBoundary") == 1, "published batch is a completed terminal boundary")
	r.state.changed.disconnect(cancel_during_commit)
	paused = true
	r.start(_event("cancel_paused", [_cmd(&"wait", {"seconds": 3.0})])); r.cancel_all(); await _idle(r)
	_check(f.reports[-1].result == EventRunner.Result.CANCELLED, "cancellation settles while paused")
	paused = false; f.host.queue_free(); await _frames(1)

func _test_graph_gates():
	var f := _fixture(); var r: EventRunner = f.runner
	var event := _event("graph_once", [_setter("GraphOnce", 1)], "once")
	var path := "res://.godot/release_graph_once.tres"
	_check(ResourceSaver.save(event, path) == OK, "graph fixture saved")
	r.start(event); await _idle(r)
	for rejected in [false, true]:
		if rejected:
			event.pages[0].trigger = "call"
			ResourceSaver.save(event, path)
		var graph := LevelGraph.new()
		var entry := LevelNode.new(); entry.node_id = &"start"; entry.type = "start"
		var execute := LevelNode.new(); execute.node_id = &"event"; execute.type = "event"; execute.params = {"event_path": path, "wait": true}
		var end := LevelNode.new(); end.node_id = &"end"; end.type = "end"
		graph.nodes = [entry, execute, end]; graph.entry_node = &"start"
		for pair in [["start", "out", "event"], ["event", "done", "end"]]:
			var edge := LevelConnection.new(); edge.from_node = StringName(pair[0]); edge.from_port = pair[1]; edge.to_node = StringName(pair[2]); graph.connections.append(edge)
		var g := GraphRunner.new(); g.host = f.host; g.state = r.state; g.bus = r.bus; g.graph = graph; g.event_starter = r.start
		g.start(); await _frames(6)
		_check(not g.running and g.node_state(&"end") == GraphRunner.NodeState.DONE, "ignored/rejected event releases graph promptly")
		g.stop()
	DirAccess.remove_absolute(path)
	f.host.queue_free(); await _frames(1)

func _test_lifecycle_edges():
	var f := _fixture(); var r: EventRunner = f.runner
	var p := ReleasePresenter.new(); f.host.add_child(p); r.presenter = p
	var child := _event("nested_ui", [_cmd(&"show_text", {"text": "nested"})])
	r.start(_event("parent_ui", [_cmd(&"release_call", {"target": child})])); await _frames()
	_check(p.texts == ["nested"], "nested presentation acquired by parent session")
	p.done = true; await _idle(r)
	r.start(_event("later_ui", [_cmd(&"show_text", {"text": "later"})])); await _frames()
	_check(p.texts == ["nested", "later"], "nested presenter lease released at parent completion")
	r.cancel_all(); await _idle(r)
	var start_cancel := func(id, _instance):
		if id == &"immediate_cancel": r.cancel_all("start listener")
	r.bus.event_started.connect(start_cancel)
	r.start(_event("immediate_cancel", [_setter("Never", 1)], "once")); await _idle(r)
	_check(not r.state.has("Never"), "synchronous start listener cancels before commands")
	r.bus.event_started.disconnect(start_cancel)
	r.start(_event("restore_conflict", [_setter("Stale", 1), _cmd(&"wait", {"seconds": 0.04})])); await _frames()
	r.state.restore(r.state.snapshot()); await _idle(r)
	_check(not r.state.has("Stale") and f.reports[-1].result == EventRunner.Result.FAILED, "restore invalidates in-flight event snapshot")
	var store := StateStore.new(); store.set_value("N", 2)
	_check(store.add("N", "bad") == ERR_INVALID_DATA and store.get_int("N") == 2, "invalid add operand rejected without exception")
	r.start(_event("free_host", [_cmd(&"wait", {"seconds": 5.0}), _setter("Ghost", 1)])); await _frames()
	f.host.queue_free(); await _idle(r)
	_check(not r.state.has("Ghost") and f.reports[-1].result == EventRunner.Result.CANCELLED, "host removal cancels detached runner")
	var ui := DialoguePresenter.new(); root.add_child(ui)
	ui.show_text("", "", 0.04)
	await _wait_text_finished(ui)
	_check(ui.is_text_finished(), "empty auto-advance text completes")
	ui.show_text("", "", 0.08)
	await _frames(1); paused = true; await create_timer(0.13, true).timeout
	_check(not ui.is_text_finished(), "default presenter paused with host")
	paused = false; await _frames(1)
	_check(not ui.is_text_finished(), "default presenter auto deadline preserves remaining pause time")
	await _wait_text_finished(ui)
	_check(ui.is_text_finished(), "default presenter resumes auto advance")
	ui.queue_free(); await _frames(1)

func _test_runtime_scene_scope():
	var runtime: StudioRuntime = root.get_node("RPGEventStudio")
	var scene := Node.new(); root.add_child(scene); current_scene = scene
	await _frames(2)
	runtime.start_event(_event("scene_scope", [_cmd(&"wait", {"seconds": 5.0}), _setter("SceneGhost", 1)]))
	await _frames(2)
	scene.queue_free(); await _idle(runtime.runner)
	_check(not runtime.state.has("SceneGhost"), "default autoload presenter cannot keep old scene event alive")
	current_scene = null

func _wait_text_finished(ui: DialoguePresenter) -> void:
	var deadline := Time.get_ticks_msec() + 1000
	while not ui.is_text_finished() and Time.get_ticks_msec() < deadline:
		await process_frame

func _test_store_lifecycle():
	var f := _fixture(); var r: EventRunner = f.runner
	r.state.set_value("ReadOnly", 1)
	r.start(_event("snapshot_reader", [_cmd(&"release_store_lifecycle", {"mode": "snapshot", "wait": 0.05})])); await _frames()
	r.state.set_value("ReadOnly", 2); await _idle(r)
	_check(f.reports[-1].result == EventRunner.Result.FAILED and not r.state.has("Derived"), "snapshot reads participate in conflict detection")
	r.start(_event("restore", [_cmd(&"release_store_lifecycle", {"mode": "restore"})])); await _idle(r)
	_check(not r.state.has("ReadOnly") and r.state.get_int("Restored") == 9 and r.state.get_int("AfterLifecycle") == 1, "session restore publishes its complete replacement atomically")
	r.state.set_value("ResetOld", 7)
	r.start(_event("reset", [_cmd(&"release_store_lifecycle", {"mode": "reset"})])); await _idle(r)
	_check(not r.state.has("Restored") and not r.state.has("ResetOld") and r.state.get_int("AfterLifecycle") == 1, "session reset retains subsequent writes and removes old state")
	r.start(_event("cancel_restore", [_cmd(&"release_store_lifecycle", {"mode": "restore", "wait": 2.0})])); await _frames()
	r.cancel_all(); await _idle(r)
	_check(not r.state.has("Restored") and r.state.get_int("AfterLifecycle") == 1, "cancelled session restore cannot change host state")
	f.host.queue_free(); await _frames(1)

func _test_graph_restore():
	var f := _fixture(); var r: EventRunner = f.runner
	r.state.set_value("Monitor", false)
	var graph := LevelGraph.new()
	var start := LevelNode.new(); start.node_id = &"start"; start.type = "start"
	var condition := LevelNode.new(); condition.node_id = &"watch"; condition.type = "condition"; condition.params = {"key": "Monitor", "op": "==", "value": true, "monitor": true}
	var action := LevelNode.new(); action.node_id = &"action"; action.type = "action"; action.params = {"key": "Observed", "value": 1}
	graph.nodes = [start, condition, action]; graph.entry_node = &"start"
	var edge := LevelConnection.new(); edge.from_node = &"watch"; edge.from_port = "true"; edge.to_node = &"action"; graph.connections = [edge]
	var g := GraphRunner.new(); g.host = f.host; g.state = r.state; g.bus = r.bus; g.graph = graph
	g.start(); await _frames()
	r.state.restore({"values": {"Monitor": true}}); await _frames()
	_check(r.state.get_int("Observed") == 1, "graph monitor reevaluates host snapshot restore")
	g.stop(); f.host.queue_free(); await _frames(1)
