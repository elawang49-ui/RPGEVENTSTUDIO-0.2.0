extends SceneTree
## Release Hardening 截图：F2 状态调试视图（真实游戏窗口）。
##   godot --path . --script res://tools/hardening_shots.gd

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.gui_embed_subwindows = true
	var demo: Node = load("res://addons/rpgeventstudio/samples/scenes/school_demo.tscn").instantiate()
	root.add_child(demo)
	await create_timer(0.8).timeout
	var runtime := root.get_node_or_null("RPGEventStudio")
	if runtime != null:
		runtime.call("set_state", "School.Office.DiaryFound", true)
		runtime.call("set_state", "School.Classroom.ClueFound", false)
		var panel = runtime.get("debug_panel")
		if panel != null:
			panel.call("open")
	await create_timer(0.6).timeout
	var image := root.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("res://docs/images/hardening/state_debug.png")
		print("[HARD] saved state_debug")
	quit()
