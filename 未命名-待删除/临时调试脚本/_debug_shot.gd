extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "biscuit"
	var w := int(args[1]) if args.size() > 1 else 1152
	var h := int(args[2]) if args.size() > 2 else 648
	var choices := args.size() > 3 and args[3] == "choices"
	root.size = Vector2i(w,h)
	DisplayServer.window_set_size(Vector2i(w,h))
	var runtime := root.get_node_or_null("RPGEventStudio")
	var p: Node = runtime.get("default_presenter")
	var t: RpgEventStudioTheme = runtime.call("apply_dialogue_theme_preset", id)
	t.portrait_enabled = true
	p.call("set_dialogue_theme", t)
	runtime.call("set_dialogue_portrait", load("res://addons/rpgeventstudio/samples/ui/sample_portrait.png"))
	await create_timer(0.5).timeout
	if choices:
		p.call("show_choices", "要问点什么吗？", ["翻开烘焙手账第 3 页", "帮可可搅拌焦糖", "把曲奇分给门口的猫"])
		await create_timer(0.5).timeout
		p.set("_choice_index", 1)
		p.call("_update_choice_highlight")
	else:
		p.call("show_text", "面包房主 · 可可", "今天的「薄荷焦糖曲奇」烤得刚刚好！我已经把配方贴在你的手账第 3 页啦～")
		p.call("_finish_typing")
		await create_timer(0.5).timeout
	print("before frame")
	await RenderingServer.frame_post_draw
	print("after frame")
	var img := root.get_texture().get_image()
	img.save_png("res://.godot/debug_shot.png")
	print("saved")
	quit()
