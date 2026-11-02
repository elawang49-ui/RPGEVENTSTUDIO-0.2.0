extends Node
## 编辑器内自测：验证「撤销 / 重做」在嵌套结构上真的生效。
## 只在环境变量 RPGEVENTSTUDIO_SELFTEST=1 时由 plugin.gd 启动：
##   RPGEVENTSTUDIO_SELFTEST=1 godot --headless --editor --path .
## 结果打印 [SELFTEST]，退出码由编辑器决定（看 FAIL 数）。

var _checks := 0
var _failures: PackedStringArray = []

func start(_dock_panel: Control) -> void:
	# 编辑器启动时会重载插件，dock 面板可能被重建；这里自己建一个同样的面板来测，
	# 跑的是同一个脚本、同一套撤销 API，但不受 dock 生命周期影响。
	await get_tree().create_timer(1.0).timeout

	var panel_script := load("res://addons/rpgeventstudio/editor/event_editor/event_editor_panel.gd")
	var panel: Control = panel_script.new()
	var base := EditorInterface.get_base_control()
	if base == null:
		_fail("拿不到编辑器根节点")
		_finish()
		return
	base.add_child(panel)
	await get_tree().process_frame

	# 用副本测试，绝不改到仓库里的示例资源
	var source: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	var definition: EventDefinition = source.duplicate(true) as EventDefinition
	if definition == null:
		_fail("无法加载示例事件")
		_finish()
		return

	panel.call("open_definition", definition, null)
	await get_tree().process_frame

	var page: EventPage = definition.pages[0]
	_test_add_and_undo(panel, page)
	_test_delete_and_undo(panel, page)
	_test_move_and_undo(panel, page)
	_test_param_and_undo(panel, page)
	_test_branch_add_and_undo(panel, page)
	_test_cross_branch_and_undo(panel, page)

	_test_cut_undo_paste(panel, page)
	_test_page_undo(panel, definition)
	_test_page_properties(panel, definition)
	await _test_panel_sync(panel, definition)
	panel.queue_free()
	await _test_closed_panel_undo()
	await _test_plugin_lifecycle()
	_finish()

# ── 用例 ─────────────────────────────────────────────────

func _test_add_and_undo(panel: Control, page: EventPage) -> void:
	var before := page.commands.size()
	panel.call("_on_add_command_pressed", 0)
	_check(page.commands.size() == before + 1, "添加指令：+1")

	_history(page).undo()
	_check(page.commands.size() == before, "撤销添加：恢复原状")

	_history(page).redo()
	_check(page.commands.size() == before + 1, "重做添加：再次 +1")

	_history(page).undo()

func _test_delete_and_undo(panel: Control, page: EventPage) -> void:
	var before := page.commands.size()
	var target: EventCommand = page.commands[0]
	panel.call("_on_command_row_pressed", target)
	panel.call("_on_delete_command")
	_check(page.commands.size() == before - 1, "删除指令：-1")

	_history(page).undo()
	_check(page.commands.size() == before, "撤销删除：指令回来了")
	_check(page.commands[0] == target, "撤销删除：对象是同一个（不是复制品）")

func _test_move_and_undo(panel: Control, page: EventPage) -> void:
	if page.commands.size() < 2:
		return
	var first: EventCommand = page.commands[0]
	var second: EventCommand = page.commands[1]
	panel.call("_on_command_row_pressed", second)
	panel.call("_on_move_command", -1)
	_check(page.commands[0] == second, "上移：顺序改变")

	_history(page).undo()
	_check(page.commands[0] == first and page.commands[1] == second, "撤销上移：顺序还原")

func _test_param_and_undo(panel: Control, page: EventPage) -> void:
	var target := _find_first(page.commands, &"if")
	if target == null:
		return
	var old_value: Variant = target.params.get("value")
	panel.call("_on_command_row_pressed", target)
	panel.call("_change_param", target, "value", "42")
	_check(str(target.params.get("value")) == "42", "改参数：写入成功")

	_history(page).undo()
	_check(str(target.params.get("value")) == str(old_value), "撤销改参数：值还原")

	_history(page).redo()
	_check(str(target.params.get("value")) == "42", "重做改参数：值再次生效")

	_history(page).undo()

func _test_branch_add_and_undo(panel: Control, page: EventPage) -> void:
	var if_command := _find_first(page.commands, &"if")
	if if_command == null:
		return
	var before := if_command.children.size()
	panel.call("_on_branch_add_pressed", if_command.children, ["测试"], null)
	panel.call("_on_add_command_pressed", 0)
	_check(if_command.children.size() == before + 1, "分支内添加：+1")

	_history(page).undo()
	_check(if_command.children.size() == before, "撤销分支内添加：恢复")

	_history(page).redo()
	_check(if_command.children.size() == before + 1, "重做分支内添加：+1")
	_history(page).undo()

func _test_cross_branch_and_undo(panel: Control, page: EventPage) -> void:
	var if_command := _find_first(page.commands, &"if")
	if if_command == null or if_command.children.is_empty():
		return
	var moved: EventCommand = if_command.children[0]
	var then_before := if_command.children.size()
	var else_before := if_command.else_children.size()

	panel.call("_on_command_row_pressed", moved)
	panel.call("_on_move_to_sibling")
	_check(if_command.children.size() == then_before - 1, "移到另一分支：源分支 -1")
	_check(if_command.else_children.size() == else_before + 1, "移到另一分支：目标分支 +1")

	_history(page).undo()
	_check(if_command.children.size() == then_before, "撤销移分支：源分支还原")
	_check(if_command.else_children.size() == else_before, "撤销移分支：目标分支还原")
	_check(if_command.children[0] == moved, "撤销移分支：对象回到原位")

func _test_cut_undo_paste(panel: Control, page: EventPage) -> void:
	var before := page.commands.size()
	var target := page.commands[0]
	panel.call("_on_command_row_pressed", target)
	panel.call("_on_cut")
	_history(page).undo()
	panel.call("_on_paste")
	_check(page.commands.size() == before + 1, "剪切撤销后粘贴新增副本")
	var identities := {}
	for command in page.commands:
		identities[command] = true
	_check(identities.size() == page.commands.size(), "剪切撤销粘贴不重复插入同一实例")
	_history(page).undo()
	_check(page.commands.size() == before and page.commands[0] == target, "撤销粘贴保留原实例")

func _test_page_undo(panel: Control, definition: EventDefinition) -> void:
	var manager := EditorInterface.get_editor_undo_redo()
	var history := manager.get_history_undo_redo(manager.get_object_history_id(definition))
	var before := definition.pages.duplicate()
	panel.call("_on_add_page")
	_check(definition.pages.size() == before.size() + 1, "新增事件页")
	history.undo()
	_check(definition.pages == before, "撤销新增页保留原页实例")
	history.redo()
	_check(definition.pages.size() == before.size() + 1, "重做新增页")
	if definition.pages.size() == before.size() + 1:
		panel.call("_on_remove_page")
		history.undo()
		_check(definition.pages.size() == before.size() + 1, "撤销删除页")
		history.redo()
		_check(definition.pages == before, "重做删除页")
	panel.call("_on_page_selected", 0)

# ── 工具 ─────────────────────────────────────────────────

func _history(page: EventPage) -> UndoRedo:
	var manager := EditorInterface.get_editor_undo_redo()
	var id := manager.get_object_history_id(page)
	return manager.get_history_undo_redo(id)

func _find_first(list: Array, type: StringName) -> EventCommand:
	for command in list:
		if command is EventCommand and command.type == type:
			return command
	return null

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[SELFTEST] ✓ ", message)
	else:
		_fail(message)

func _fail(message: String) -> void:
	_checks += 1
	_failures.append(message)
	print("[SELFTEST] ✗ ", message)

func _finish() -> void:
	print("[SELFTEST] ===== 检查 %d 项，失败 %d 项 =====" % [_checks, _failures.size()])
	for failure in _failures:
		print("[SELFTEST] ✗ ", failure)
	var tree := get_tree()
	if tree != null:
		tree.quit()

func _test_page_properties(panel: Control, definition: EventDefinition) -> void:
	panel.call("_on_page_selected", 0)
	var page := definition.pages[0]
	var history := _history(page)
	var old_trigger := page.trigger
	panel.call("_on_trigger_selected", 6)
	_check(page.trigger == "call", "修改页触发方式")
	history.undo()
	_check(page.trigger == old_trigger, "撤销页触发方式")
	panel.call("_on_repeat_selected", 1)
	_check(page.repeat_policy == "once", "修改重复策略")
	history.undo()
	_check(page.repeat_policy == "every_time", "撤销重复策略")
	var count := page.conditions.size()
	panel.call("_on_add_condition")
	_check(page.conditions.size() == count + 1, "添加出现条件")
	history.undo()
	_check(page.conditions.size() == count, "撤销添加条件")
	history.redo()
	_check(page.conditions.size() == count + 1, "重做添加条件")
	var condition := page.conditions[-1]
	panel.call("_change_page_property", condition, "key", "Global.Edited")
	history.undo()
	_check(condition.key == "Global.", "撤销条件字段")
	history.undo()

func _test_panel_sync(panel: Control, definition: EventDefinition) -> void:
	var story: Control = load("res://addons/rpgeventstudio/editor/story/story_editor_panel.gd").new()
	EditorInterface.get_base_control().add_child(story)
	story.call("open_definition", definition, null)
	panel.call("_on_page_selected", 0)
	var doc: StoryDocument = story.get("_document")
	var command := CommandRegistry.create_command(&"show_text")
	doc.insert_command(definition.pages[0].commands, 0, command)
	await get_tree().process_frame
	await get_tree().process_frame
	var contexts: Dictionary = panel.get("_contexts")
	_check(contexts.has(command), "Story 插入后 Inspector 同步出现新行")
	panel.call("_on_command_row_pressed", command)
	panel.call("_on_delete_command")
	await get_tree().process_frame
	await get_tree().process_frame
	var items: Array = story.get("_items")
	_check(items.is_empty() or items[0]["command"] != command, "Inspector 删除后 Story 同步刷新")
	story.queue_free()

func _test_plugin_lifecycle() -> void:
	# The test node outlives the plugin it disables. Re-enable restores project settings.
	reparent(EditorInterface.get_base_control())
	EditorInterface.set_plugin_enabled("rpgeventstudio", false)
	await get_tree().process_frame
	_check(not EditorInterface.is_plugin_enabled("rpgeventstudio"), "真实禁用插件")
	_check(not ProjectSettings.has_setting("autoload/RPGEventStudio"), "禁用时移除路径或 UID 形式的插件 Autoload")
	EditorInterface.set_plugin_enabled("rpgeventstudio", true)
	await get_tree().process_frame
	_check(EditorInterface.is_plugin_enabled("rpgeventstudio"), "真实重新启用插件")
	_check(ProjectSettings.has_setting("autoload/RPGEventStudio"), "重新启用自动安装 Autoload")
	var persisted := ConfigFile.new()
	_check(persisted.load("res://project.godot") == OK and "res://addons/rpgeventstudio/plugin.cfg" in persisted.get_value("editor_plugins", "enabled", PackedStringArray()), "重新启用状态真正写入 project.godot")

func _test_closed_panel_undo() -> void:
	var temporary: Control = load("res://addons/rpgeventstudio/editor/event_editor/event_editor_panel.gd").new()
	EditorInterface.get_base_control().add_child(temporary)
	var definition := EventDefinition.new()
	var page := definition.add_page()
	temporary.call("open_definition", definition, null)
	var command := CommandRegistry.create_command(&"show_text")
	temporary.call("_commit_insert", page.commands, 0, command)
	var history := _history(page)
	temporary.queue_free()
	await get_tree().process_frame
	history.undo()
	_check(page.commands.is_empty(), "关闭面板后仍能撤销资源操作")
	history.redo()
	_check(page.commands.size() == 1 and page.commands[0] == command, "关闭面板后重做恢复同一资源且无悬空调用")
	history.undo()
