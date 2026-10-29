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

	panel.queue_free()
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
