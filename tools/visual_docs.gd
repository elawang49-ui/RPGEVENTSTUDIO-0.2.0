extends SceneTree
## 生成教程截图（仅开发时手动运行）：
##   godot --path . --script res://tools/visual_docs.gd
## 会在游戏窗口里把编辑器面板与状态库渲染出来，存到 docs/images/。

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.gui_embed_subwindows = true
	L10n.set_game_locale("zh_CN", false)

	var background := ColorRect.new()
	background.color = Color(0.13, 0.14, 0.17)
	background.size = Vector2(1152, 648)
	root.add_child(background)

	var panel: Control = load("res://addons/rpgeventstudio/editor/event_editor/event_editor_panel.gd").new()
	panel.position = Vector2(8, 4)
	panel.size = Vector2(440, 640)
	root.add_child(panel)
	await process_frame

	var definition: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	panel.call("open_definition", definition, null)
	panel.call("_on_page_selected", 1)
	await create_timer(0.4).timeout
	await _shot("res://docs/images/event_panel.png")

	# 事件列表
	var list_panel: Control = load("res://addons/rpgeventstudio/editor/event_list/event_list_panel.gd").new()
	list_panel.position = Vector2(700, 16)
	list_panel.size = Vector2(380, 580)
	root.add_child(list_panel)
	await process_frame
	list_panel.call("refresh")
	await create_timer(0.4).timeout
	await _shot("res://docs/images/event_list.png")
	list_panel.hide()

	var dialog := StateLibraryDialog.new()
	root.add_child(dialog)
	dialog.open_catalog()
	await create_timer(0.6).timeout
	await _shot("res://docs/images/state_library.png")

	dialog.hide()
	await create_timer(0.2).timeout

	# F2 状态调试面板
	var demo: Node = load("res://addons/rpgeventstudio/samples/scenes/school_demo.tscn").instantiate()
	root.add_child(demo)
	await create_timer(0.6).timeout
	var runtime := root.get_node_or_null("RPGEventStudio")
	if runtime != null:
		runtime.call("set_state", "School.Office.DiaryFound", true)
		runtime.call("set_state", "School.Classroom.ClueFound", false)
		# 制造一次「未触发」，让面板里出现原因
		var door: Node = demo.get_node_or_null("ClassroomDoor/EventInteractor")
		if door != null:
			door.call("_trigger")
		await create_timer(0.4).timeout
		runtime.call("cancel_all", "shot")
		await create_timer(0.3).timeout
		# 制造一次「触发方式不匹配」，让面板显示未执行原因
		var hint: EventDefinition = load("res://addons/rpgeventstudio/samples/events/basement_cutscene.tres")
		runtime.get("runner").start(hint, {}, ["autorun"])
		await create_timer(0.3).timeout
		runtime.call("open_state_debug")
		await create_timer(0.6).timeout
		await _shot("res://docs/images/state_debug.png")
		runtime.call("close_state_debug")

	await create_timer(0.2).timeout
	quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		return
	var error := image.save_png(path)
	print("[visual_docs] %s -> %d" % [path, error])
