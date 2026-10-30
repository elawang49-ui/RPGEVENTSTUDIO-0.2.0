extends Node
## 剧情工作台自测 / 截图：只在 plugin.gd 的钩子里启动。
##   RPGEVENTSTUDIO_STORY_SELFTEST=1 godot --editor --path .   → 功能自测（撤销/重做/保存读回）
##   RPGEVENTSTUDIO_STORY_SHOT=1      godot --editor --path .   → 保存 docs/images/story_workbench.png
## 自测用副本资源，不改动仓库里的示例。

var _checks := 0
var _failures: PackedStringArray = []

func start(_plugin: EditorPlugin, story_view: Control) -> void:
	await get_tree().create_timer(1.5).timeout
	if story_view == null:
		_fail("拿不到剧情工作台实例")
		_finish()
		return

	if OS.get_environment("RPGEVENTSTUDIO_STORY_SHOT") == "1":
		await _capture(story_view)
		return

	var panel_script := load("res://addons/rpgeventstudio/editor/story/story_editor_panel.gd")
	var panel: Control = panel_script.new()
	var base := EditorInterface.get_base_control()
	if base == null:
		_fail("拿不到编辑器根节点")
		_finish()
		return
	base.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame

	# 副本测试，不动仓库示例
	var source: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	var definition: EventDefinition = source.duplicate(true) as EventDefinition
	panel.call("open_definition", definition, null)
	await get_tree().process_frame

	_test_panel_built(panel, definition)
	_test_insert_and_undo(panel, definition)
	_test_text_edit_and_undo(panel, definition)
	_test_choice_add_and_undo(panel, definition)
	_test_save_reload(panel, definition)
	_test_roster(panel)

	panel.queue_free()
	_finish()

# ── 用例 ─────────────────────────────────────────────────

func _test_panel_built(panel: Control, definition: EventDefinition) -> void:
	var list: VBoxContainer = panel.get("_script_list")
	_check(list != null and list.get_child_count() >= 4, "打开事件后台词列表应渲染多行（实际 %s）" % str(list.get_child_count() if list != null else -1))
	_check(panel.get("_title_label").text.contains("图书管理员"), "标题应显示事件显示名")
	_check(definition.pages[0].commands.size() == 4, "打开剧情视图不应改动指令数量")

func _test_insert_and_undo(panel: Control, definition: EventDefinition) -> void:
	var page: EventPage = definition.pages[0]
	var before := page.commands.size()
	panel.call("_on_row_pressed", _first_item(panel))
	panel.call("_on_insert_quick", "line")
	_check(page.commands.size() == before + 1, "插入台词：+1")

	var history := _history(page)
	history.undo()
	_check(page.commands.size() == before, "撤销插入：恢复原状")
	history.redo()
	_check(page.commands.size() == before + 1, "重做插入：再次 +1")
	history.undo()

func _test_text_edit_and_undo(panel: Control, definition: EventDefinition) -> void:
	var page: EventPage = definition.pages[0]
	var line: EventCommand = page.commands[0]
	var original := str(line.params.get("text", ""))

	panel.call("_on_row_pressed", _first_item(panel))
	var item: Dictionary = panel.get("_selected_item")
	_check(not item.is_empty(), "选中第一条台词")
	var document: StoryDocument = panel.get("_document")
	document.set_line_param(item, "text", "自测里改写的正文")
	_check(str(line.params.get("text", "")) == "自测里改写的正文", "正文直接写进原指令")

	var history := _history(page)
	history.undo()
	_check(str(line.params.get("text", "")) == original, "撤销正文修改：恢复原文")
	history.redo()
	_check(str(line.params.get("text", "")) == "自测里改写的正文", "重做正文修改")
	history.undo()
	_check(str(line.params.get("text", "")) == original, "收尾：恢复原文")

func _test_choice_add_and_undo(panel: Control, definition: EventDefinition) -> void:
	var page: EventPage = definition.pages[0]
	var before := page.commands.duplicate()
	var before_size := page.commands.size()

	panel.call("_on_row_pressed", _choice_item(panel))
	var item: Dictionary = panel.get("_selected_item")
	var document: StoryDocument = panel.get("_document")
	var ok: bool = document.choice_add_option(item, "第三句")
	_check(ok, "嵌套式选项块允许添加选项（改写为顺序式）")
	# 嵌套式（show + 1 个 if 链）改写成顺序式后是 show + 3 个 if：顶层命令数净增 2。
	_check(page.commands.size() == before_size + 2, "添加选项后应改写成顺序式并净增 2 条命令（实际 %d）" % page.commands.size())

	var history := _history(page)
	history.undo()
	_check(page.commands.size() == before_size, "撤销添加选项：恢复原结构")
	var same := true
	for index in before.size():
		if page.commands[index] != before[index]:
			same = false
	_check(same, "撤销后命令对象与原来完全一致")
	_check(str(page.commands[2].children[0].params.get("text", "")) == "这把钥匙给你，别弄丢了。", "撤销后分支内容回到原位")

func _test_save_reload(_panel: Control, definition: EventDefinition) -> void:
	var page: EventPage = definition.pages[0]
	var signature := _signature(page)
	var path := "res://.godot/story_selftest_event.tres"
	definition.take_over_path(path)
	_check(ResourceSaver.save(definition, path) == OK, "剧情视图编辑后应能保存")
	var loaded := load(path) as EventDefinition
	_check(loaded != null and _signature(loaded.pages[0]) == signature, "保存→关闭→重新打开内容一致")
	DirAccess.remove_absolute(path)
	definition.resource_path = ""

func _test_roster(panel: Control) -> void:
	var had_file := FileAccess.file_exists("res://state/story_characters.tres")
	panel.call("_on_roster_add")
	_check(FileAccess.file_exists("res://state/story_characters.tres"), "新增角色应触发花名册保存")
	var roster: StoryCharacters = load("res://state/story_characters.tres")
	_check(roster != null and roster.characters.size() == 1, "花名册应包含一个角色")
	if not had_file:
		DirAccess.remove_absolute("res://state/story_characters.tres")

# ── 截图 ─────────────────────────────────────────────────

func _capture(story_view: Control) -> void:
	# 造一份演示事件 + 两个角色，让截图贴近真实使用
	var roster := StoryCharacters.new()
	var lily := roster.add_character("lily", "莉莉")
	lily.color = Color(0.95, 0.72, 0.55)
	lily.notes = "图书委员，负责文化节接待"
	var ache := roster.add_character("ache", "阿澈")
	ache.color = Color(0.6, 0.8, 0.95)
	ache.notes = "转学生，故事的叙述者"
	StoryCharacters.save_roster(roster)

	var definition := _demo_definition()
	story_view.call("open_definition", definition, null)
	var plugin := _plugin()
	if plugin != null:
		plugin.call("open_story_tab")
	await get_tree().create_timer(1.2).timeout

	# 选中第一条台词，让编辑区也出现在截图里
	var document: StoryDocument = story_view.get("_document")
	if document != null:
		var items := document.build_items()
		if not items.is_empty():
			story_view.call("_on_row_pressed", items[0])
	await get_tree().create_timer(0.8).timeout

	var base := EditorInterface.get_base_control()
	if base != null:
		var image := base.get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("res://docs/images/story_workbench.png")
			print("[SHOT] 已保存 docs/images/story_workbench.png")
	DirAccess.remove_absolute("res://state/story_characters.tres")
	get_tree().quit(0)

func _demo_definition() -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = &"story_demo"
	definition.display_name = "文化节准备（演示）"
	var page := EventPage.new()

	var t1 := CommandRegistry.create_command(&"show_text")
	t1.params["speaker"] = "莉莉"
	t1.params["text"] = "文化节 [b]下周[/b]就开始了，海报画好了吗？\n[color=#7fd4a0]（她抱着一大卷纸站在走廊尽头。）[/color]"
	var t2 := CommandRegistry.create_command(&"show_text")
	t2.params["speaker"] = ""
	t2.params["text"] = "（走廊上贴满了各班的招募启事。）"
	var show := CommandRegistry.create_command(&"show_choices")
	show.params["prompt"] = "怎么回答？"
	show.params["options"] = ["已经画好了", "还在赶工"]
	var b1 := CommandRegistry.create_command(&"if")
	b1.params["key"] = "@@self.choice"
	b1.params["op"] = "=="
	b1.params["value"] = "0"
	var b1t := CommandRegistry.create_command(&"show_text")
	b1t.params["speaker"] = "莉莉"
	b1t.params["text"] = "[font_size=20]太好了！[/font_size]那今天放学前贴出去。"
	b1.children = [b1t]
	var b2 := CommandRegistry.create_command(&"if")
	b2.params["key"] = "@@self.choice"
	b2.params["op"] = "=="
	b2.params["value"] = "1"
	var b2t := CommandRegistry.create_command(&"show_text")
	b2t.params["speaker"] = "莉莉"
	b2t.params["text"] = "那我帮你一起画，放学后来美术教室。"
	b2.children = [b2t]
	var condition := CommandRegistry.create_command(&"if")
	condition.params["key"] = "Global.Mission.PosterDone"
	condition.params["op"] = "=="
	condition.params["value"] = "true"
	var ct := CommandRegistry.create_command(&"show_text")
	ct.params["speaker"] = "阿澈"
	ct.params["text"] = "[color=#e8c56b]（海报已经贴在了公告栏上。）[/color]"
	condition.children = [ct]
	var finish := CommandRegistry.create_command(&"end")

	page.commands = [t1, t2, show, b1, b2, condition, finish]
	definition.pages = [page]
	return definition

func _plugin() -> EditorPlugin:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var nodes: Array = tree.root.get_children()
	for node in nodes:
		if node is EditorPlugin:
			return node
	return null

# ── 工具 ─────────────────────────────────────────────────

func _first_item(panel: Control) -> Dictionary:
	var items: Array = panel.get("_items")
	return items[0] if not items.is_empty() else {}

func _choice_item(panel: Control) -> Dictionary:
	var items: Array = panel.get("_items")
	for item in items:
		if str(item.get("kind", "")) == "choice":
			return item
	return {}

func _signature(page: EventPage) -> String:
	var parts := PackedStringArray()
	_append_signature(parts, page.commands)
	return "\n".join(parts)

func _append_signature(parts: PackedStringArray, list: Array) -> void:
	for command in list:
		if command == null:
			continue
		parts.append("%s|%s|%s" % [String(command.type), command.params, command.enabled])
		_append_signature(parts, command.children)
		_append_signature(parts, command.else_children)

func _history(page: EventPage) -> UndoRedo:
	var manager := EditorInterface.get_editor_undo_redo()
	return manager.get_history_undo_redo(manager.get_object_history_id(page))

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _fail(message: String) -> void:
	_failures.append(message)
	print("  ✗ ", message)

func _finish() -> void:
	print("")
	print("──────── 剧情工作台自测结果 ────────")
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
