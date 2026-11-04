extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,820)
	var p := DialoguePresenter.new(); root.add_child(p)
	await process_frame; await process_frame
	p.set_dialogue_theme(DialogueThemePresets.create("feather"))
	p.show_text("守夜诗人 · 奥菲莉娅", "「森林记住了每一片雪花落下的名字，正如灰烬记住了火焰最初的形状。」")
	p.call("_finish_typing")
	for i in 8: await process_frame
	var panel: PanelContainer = p.get("_panel")
	var np = p.get("_nameplate")
	var text: RichTextLabel = p.get("_text_label")
	print("panel pos=", panel.position, " size=", panel.size)
	print("nameplate pos=", np.position, " size=", np.size, " label=", np.label.position, np.label.size, " visible=", np.visible)
	print("text pos=", text.position, " size=", text.size, " custom=", text.custom_minimum_size, " content=", text.get_content_height())
	print("header gap=", (p.get("_header_gap") as Control).custom_minimum_size)
	p.show_choices("接下来要怎么做？", ["拾起白鸦之羽，继续守夜", "询问奥菲莉娅诗篇的结尾", "合上诗集，静候黎明"])
	for i in 8: await process_frame
	var cp: PanelContainer = p.get("_choices_panel")
	var rows: Array = p.get("_choice_rows")
	print("before manual choices pos=", cp.position, " size=", cp.size, " panel=", panel.position)
	p.call("_layout_choices_panel")
	print("after manual choices pos=", cp.position, " size=", cp.size, " bottom=", cp.position.y+cp.size.y)
	for r in rows: print("row pos=", r.global_position, " size=", r.size)
	quit()
