extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1152, 648)
	var p := DialoguePresenter.new()
	root.add_child(p)
	await process_frame
	await process_frame
	var t := DialogueThemePresets.create("crimson")
	p.set_dialogue_theme(t)
	await process_frame
	p.show_text("处刑人 · 维克多", "「午夜的钟声已经敲响了十二下。在绯红之月落下之前，交出你的底牌吧。」")
	p.call("_finish_typing")
	for i in 10:
		await process_frame
	var panel: PanelContainer = p.get("_panel")
	var np = p.get("_nameplate")
	var portrait = p.get("_portrait")
	print("panel pos=", panel.position, " size=", panel.size, " rect=", panel.get_global_rect())
	print("nameplate pos=", np.position, " size=", np.size, " rect=", np.get_global_rect(), " off=", t.nameplate_offset, " style=", t.nameplate_style)
	print("portrait pos=", portrait.position, " size=", portrait.size, " rect=", portrait.get_global_rect())
	var tl: RichTextLabel = p.get("_text_label")
	print("text pos=", tl.position, " size=", tl.size, " min=", tl.custom_minimum_size, " content=", tl.get_content_height(), " linecount=", tl.get_line_count(), " textmin=", t.text_min_height)
	print("style top/bottom=", t.panel_top, "/", t.panel_bottom, " textmin=", t.text_min_height, " sep=", t.line_separation)
	print("before manual min=", tl.custom_minimum_size)
	p.call("_update_heights")
	await process_frame
	print("after manual min=", tl.custom_minimum_size, " content=", tl.get_content_height())
	print("root size=", (p.get("_root") as Control).size)
	quit()
