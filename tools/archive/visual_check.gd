extends SceneTree
## 可视验证用脚本（仅开发时手动运行，不参与发布）：
##   godot --path . --script res://tools/visual_check.gd
## 依次展示：交互提示 → 对话选项 → 按键设置 → 剧情过场，并保存到 docs/images/。

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://addons/rpgeventstudio/samples/scenes/school_demo.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.8).timeout

	var runtime := root.get_node_or_null("RPGEventStudio")
	if runtime == null:
		quit()
		return
	var presenter: Node = runtime.get("presenter")
	var player: Node2D = scene.get_node_or_null("Player")
	var npc: Node = scene.get_node_or_null("Librarian/EventInteractor")
	if player != null and npc != null:
		player.set_physics_process(false)
		player.global_position = (npc as Node2D).global_position + Vector2(26, 0)
	await create_timer(0.5).timeout
	await _shot("res://docs/images/interaction_prompt.png")

	if npc != null:
		npc.call("trigger")
	await create_timer(1.2).timeout
	presenter.set("_mouse_click", true)
	await create_timer(1.2).timeout
	await _shot("res://docs/images/dialogue_choices.png")

	runtime.call("cancel_all", "visual check")
	await create_timer(0.6).timeout
	runtime.call("open_input_settings")
	await create_timer(0.8).timeout
	await _shot("res://docs/images/input_settings.png")
	runtime.call("close_input_settings")
	await create_timer(0.3).timeout

	# 剧情过场：两条线索齐了，关卡图调用演出事件
	runtime.call("set_state", "School.Office.DiaryFound", true)
	runtime.call("set_state", "School.Classroom.ClueFound", true)

	var waited := 0
	var captured := false
	while waited < 1200 and not captured:
		waited += 1
		await process_frame
		var current := str(presenter.get("last_text"))
		var finished := bool(presenter.call("is_text_finished"))
		if current != "你终于来了。" and not finished:
			presenter.set("_mouse_click", true)
		if current == "你终于来了。" and not captured:
			await create_timer(0.6).timeout
			await _shot("res://docs/images/cutscene.png")
			captured = true

	await create_timer(0.3).timeout
	runtime.call("cancel_all", "visual check")
	quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		return
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var error := image.save_png(path)
	print("[visual_check] %s -> %d" % [path, error])
