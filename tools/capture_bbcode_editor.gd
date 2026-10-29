extends SceneTree
## 编辑器「显示文字」参数区与 BBCode 预览的真实窗口截图（开发用）。
## 使用与编辑器停靠面板相同的 event_editor_panel.gd，不改任何事件资源。
##   CAPTURE_DIR=... godot --path RPGEVENTSTUDIO --script res://tools/capture_bbcode_editor.gd

const SAMPLE := "[b]重点文字[/b]\n[color=#FFD700]关键线索[/color] 与 [color=red]红色警告[/color]\n[font_size=26]大字号[/font_size]\n[center]居中文字[/center]\n换行与中文标点：是的。"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out_dir := OS.get_environment("CAPTURE_DIR")
	if out_dir.strip_edges() == "":
		out_dir = ProjectSettings.globalize_path("user://bbcode_editor_capture")
	DirAccess.make_dir_recursive_absolute(out_dir)

	DisplayServer.window_set_size(Vector2i(900, 1000))
	var frame := Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(frame)
	var background := ColorRect.new()
	background.color = Color(0.085, 0.095, 0.125)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	frame.add_child(margin)

	var panel_script := load("res://addons/rpgeventstudio/editor/event_editor/event_editor_panel.gd")
	if panel_script == null:
		push_error("无法加载事件编辑面板")
		quit(2)
		return
	var panel: Control = panel_script.new()
	panel.custom_minimum_size = Vector2(860, 960)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(panel)
	await _frames(3)

	var definition := EventDefinition.new()
	definition.event_id = &"bbcode_preview_demo"
	definition.display_name = "BBCode 预览示例"
	var page := EventPage.new()
	var command := CommandRegistry.create_command(&"show_text")
	command.params["speaker"] = "旁白"
	command.params["text"] = SAMPLE
	page.commands = [command]
	definition.pages = [page]

	panel.call("open_definition", definition, null)
	await _frames(2)
	panel.call("_on_command_row_pressed", command)
	await _frames(4)
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("09_bbcode_editor_preview.png")
	var error := root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " error=", error)

	# 第二个截图：未闭合 / 不支持标签的明确提示
	var edits := panel.find_children("*", "TextEdit", true, false)
	if not edits.is_empty():
		var edit: TextEdit = edits[0]
		edit.text = "[b]未闭合 [foo]未知[/foo]"
		edit.text_changed.emit()
		await _frames(3)
		await RenderingServer.frame_post_draw
		var warn_path := out_dir.path_join("10_bbcode_editor_warning.png")
		var warn_error := root.get_texture().get_image().save_png(warn_path)
		print("CAPTURE ", warn_path, " error=", warn_error)
		error = warn_error if error == OK else error
	quit(0 if error == OK else 1)

func _frames(count: int) -> void:
	for _index in count:
		await process_frame
