extends Node
## 真实窗口验收辅助：跑一段事件，打开 F2 追踪视图并截图。
##   godot --path . res://tests/trace_demo.tscn

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(0.6).timeout
	var runtime := get_node_or_null("/root/RPGEventStudio")
	if runtime == null:
		push_error("没有运行时 Autoload")
		get_tree().quit(2)
		return
	runtime.call("set_state", "School.Office.DiaryFound", true)
	runtime.call("set_trace_enabled", true)
	runtime.call("clear_trace")

	var definition := EventDefinition.new()
	definition.event_id = &"trace_demo"
	definition.display_name = "地下室调查（追踪演示）"
	var page := EventPage.new()
	page.trigger = "interact"
	var commands: Array[EventCommand] = []
	var flag := CommandRegistry.create_command(&"set_switch")
	flag.params["key"] = "Trace.DemoFlag"
	flag.params["value"] = true
	commands.append(flag)
	var branch := CommandRegistry.create_command(&"if")
	branch.params["key"] = "School.Office.DiaryFound"
	branch.params["op"] = "=="
	branch.params["value"] = "true"
	var then_cmd := CommandRegistry.create_command(&"set_switch")
	then_cmd.params["key"] = "School.BasementUnlocked"
	then_cmd.params["value"] = true
	branch.children = [then_cmd]
	commands.append(branch)
	var wait := CommandRegistry.create_command(&"wait")
	wait.params["seconds"] = 0.2
	commands.append(wait)
	commands.append(CommandRegistry.create_command(&"end"))
	page.commands = commands
	definition.pages = [page]

	runtime.call("start_event", definition, {}, [&"interact"])
	for i in 60:
		await get_tree().process_frame
		if not bool(runtime.call("is_event_running", &"trace_demo")):
			break
	await get_tree().create_timer(0.3).timeout

	var panel = runtime.get("debug_panel")
	if panel != null:
		panel.call("open")
		panel.call("_show_trace", true)
		var button: Button = panel.get("_trace_button")
		if button != null:
			button.set_pressed_no_signal(true)
		var trace_view = panel.get("_trace_view")
		if trace_view != null:
			trace_view.call("select_first")
	await get_tree().create_timer(0.6).timeout

	DirAccess.make_dir_recursive_absolute("res://docs/qa/2026-10-30")
	var sample := FileAccess.open("res://docs/qa/2026-10-30/runtime_trace_sample.json", FileAccess.WRITE)
	if sample != null:
		sample.store_string(runtime.call("trace_json"))
		sample.close()
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("res://docs/images/runtime_trace.png")
		print("[TRACE_SHOT] saved res://docs/images/runtime_trace.png")
	get_tree().quit()
