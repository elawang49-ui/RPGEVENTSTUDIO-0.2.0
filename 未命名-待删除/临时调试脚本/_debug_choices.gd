extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280, 820)
	var p := DialoguePresenter.new()
	root.add_child(p)
	await process_frame
	await process_frame
	p.set_dialogue_theme(DialogueThemePresets.create("biscuit"))
	await process_frame
	p.show_choices("接下来要怎么做？", ["翻开烘焙手账第 3 页", "帮可可搅拌焦糖", "把曲奇分给门口的猫"])
	for i in 8:
		await process_frame
	var cp: PanelContainer = p.get("_choices_panel")
	var scroll: ScrollContainer = p.get("_choices_scroll")
	var box: VBoxContainer = p.get("_choices_box")
	var rows: Array = p.get("_choice_rows")
	print("panel visible=", cp.visible, " size=", cp.size, " pos=", cp.position)
	print("scroll size=", scroll.size, " min=", scroll.custom_minimum_size, " box min=", box.get_combined_minimum_size(), " vbar vis=", scroll.get_v_scroll_bar().visible, " vbar w=", scroll.get_v_scroll_bar().size.x)
	for r in rows:
		var f = r.button.get_theme_font("font")
		print("row size=", r.size, " min=", r.custom_minimum_size, " btn min=", r.button.get_combined_minimum_size(), " btn size=", r.button.size, " font=", f, " strw=", f.get_string_size(r.button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18) if f != null else -1)
	print("hint=", (p.get("_hint_label") as Label).text)
	quit()
