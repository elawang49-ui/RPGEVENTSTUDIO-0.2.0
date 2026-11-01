extends SceneTree
## 剧情工作台选项块插入错位回归测试（P1-2 扩充）：
##   godot --headless --path . --script res://tests/story_insert_choice_test.gd
## 选项块在底层占 1 + N 条连续指令（show_choices + N 条 if @@self.choice == k）。
## 选中选项块后点「+ 台词 / + 选项 / + 条件」，新内容必须插到整块之后，
## 而不是插进 show_choices 与第一条 if 之间把分支配对拆断。

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Node.new()
	host.name = "StoryInsertChoiceHost"
	root.add_child(host)

	var panel: Control = load("res://addons/rpgeventstudio/editor/story/story_editor_panel.gd").new()
	host.add_child(panel)
	await process_frame
	_check(panel.get("_script_list") != null, "剧情工作台应能在 headless 下完成构建")

	await _test_choice_insert_target_after_block(panel)
	await _test_insert_line_keeps_choice_block_intact(panel)
	await _test_insert_condition_after_block(panel)
	await _test_insert_choice_after_block(panel)
	await _test_line_selection_still_index_plus_one(panel)

	panel.queue_free()
	await process_frame
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 用例 ─────────────────────────────────────────────────

## 1) 选中选项块后 _insert_target 应返回「show_choices 下标 + consumed」（整块之后）。
func _test_choice_insert_target_after_block(panel: Control) -> void:
	var page: EventPage = await _open(panel)
	var choice: Dictionary = _choice_item_of(panel)
	_check(not choice.is_empty(), "重建视图应包含选项块条目")
	if choice.is_empty():
		return
	_check(int(choice["consumed"]) == 3, "顺序式选项块（1 show_choices + 2 if）应占 3 条指令（实际 %d）" % int(choice["consumed"]))
	_check(int(choice["index"]) == 1, "选项块的 show_choices 下标应为 1（实际 %d）" % int(choice["index"]))
	panel.call("_on_row_pressed", choice)
	var target: Dictionary = panel.call("_insert_target")
	_check(target["list"] == page.commands, "插入目标列表应是事件页指令数组")
	_check(int(target["index"]) == int(choice["index"]) + int(choice["consumed"]),
		"选中选项块后插入位应是整块之后（预期 4，实际 %d）" % int(target["index"]))

## 2) 选中选项块后插入台词：新台词紧跟整块之后，选项块重新扫描仍完整。
func _test_insert_line_keeps_choice_block_intact(panel: Control) -> void:
	var page: EventPage = await _open(panel)
	var choice: Dictionary = _choice_item_of(panel)
	panel.call("_on_row_pressed", choice)
	panel.call("_on_insert_quick", "line")
	await process_frame
	var commands: Array = page.commands
	_check(commands.size() == 6, "插入一句台词后指令数应为 6（实际 %d）" % commands.size())
	_check(_type_of(commands, 1) == &"show_choices", "show_choices 仍应在下标 1")
	_check(_type_of(commands, 2) == &"if" and _type_of(commands, 3) == &"if",
		"选项块的两条 if 仍应紧跟 show_choices（实际 %s / %s）" % [_type_of(commands, 2), _type_of(commands, 3)])
	_check(_type_of(commands, 4) == &"show_text", "新台词应插到整块之后（下标 4 实际是 %s）" % _type_of(commands, 4))
	var items: Array = panel.get("_items")
	_check(items.size() == 4, "重建后条目数应为 4（台词 / 选项块 / 新台词 / 台词，实际 %d）" % items.size())
	var rebuilt: Dictionary = _choice_item_of(panel)
	_check(not rebuilt.is_empty() and bool(rebuilt.get("well_formed", false)), "插入后选项块应仍 well_formed")
	if not rebuilt.is_empty():
		_check(int(rebuilt["consumed"]) == 3, "插入后选项块仍应占 3 条指令（实际 %d）" % int(rebuilt["consumed"]))
		var views: Array = rebuilt["option_views"]
		_check(views.size() == 2 and _view_line_count(views, 0) == 1 and _view_line_count(views, 1) == 1,
			"两个选项各应保留 1 句分支台词（实际 %d / %d）" % [_view_line_count(views, 0), _view_line_count(views, 1)])
	var after: Dictionary = _item_at(items, 4)
	_check(str(after.get("kind", "")) == "line" and int(after.get("index", -1)) == 4,
		"新台词条目应紧跟选项块（实际 kind=%s index=%s）" % [str(after.get("kind", "?")), str(after.get("index", "?"))])

## 3) 选中选项块后插入条件（同类入口走同一 _insert_target，行为一致）。
func _test_insert_condition_after_block(panel: Control) -> void:
	var page: EventPage = await _open(panel)
	var choice: Dictionary = _choice_item_of(panel)
	panel.call("_on_row_pressed", choice)
	panel.call("_on_insert_quick", "condition")
	await process_frame
	var commands: Array = page.commands
	_check(_type_of(commands, 4) == &"if", "新条件应插到选项块整块之后（下标 4 实际是 %s）" % _type_of(commands, 4))
	var rebuilt: Dictionary = _choice_item_of(panel)
	_check(not rebuilt.is_empty() and bool(rebuilt.get("well_formed", false)) and int(rebuilt["consumed"]) == 3,
		"插入条件后选项块应仍完整（3 条指令、well_formed）")
	_check(rebuilt.is_empty() or int(rebuilt["index"]) == 1, "插入条件不应改变选项块自身的下标")

## 4) 选中选项块后插入选项（show_choices + 2 if 多条插入）：同样落在整块之后。
func _test_insert_choice_after_block(panel: Control) -> void:
	var page: EventPage = await _open(panel)
	var choice: Dictionary = _choice_item_of(panel)
	panel.call("_on_row_pressed", choice)
	panel.call("_on_insert_quick", "choice")
	await process_frame
	var commands: Array = page.commands
	_check(commands.size() == 8, "插入新选项块（3 条指令）后指令数应为 8（实际 %d）" % commands.size())
	_check(_type_of(commands, 4) == &"show_choices", "新选项块的 show_choices 应在整块之后（下标 4 实际是 %s）" % _type_of(commands, 4))
	_check(_type_of(commands, 5) == &"if" and _type_of(commands, 6) == &"if",
		"新选项块的两条 if 应紧跟其后（实际 %s / %s）" % [_type_of(commands, 5), _type_of(commands, 6)])
	var items: Array = panel.get("_items")
	_check(items.size() == 4, "重建后条目数应为 4（台词 / 两个选项块 / 台词，实际 %d）" % items.size())
	for item in items:
		if str(item.get("kind", "")) == "choice":
			_check(bool(item.get("well_formed", false)) and int(item.get("consumed", 0)) == 3,
				"每个选项块都应完整（consumed=3、well_formed，实际 consumed=%s）" % str(item.get("consumed", "?")))

## 5) 不回归：选中普通台词条目时插入位仍是 index + 1。
func _test_line_selection_still_index_plus_one(panel: Control) -> void:
	var page: EventPage = await _open(panel)
	var items: Array = panel.get("_items")
	var first_line: Dictionary = _item_at(items, 0)
	_check(str(first_line.get("kind", "")) == "line", "首条目应是普通台词")
	panel.call("_on_row_pressed", first_line)
	var target: Dictionary = panel.call("_insert_target")
	_check(int(target["index"]) == 1, "选中台词后插入位仍是 index+1（预期 1，实际 %d）" % int(target["index"]))
	panel.call("_on_insert_quick", "line")
	await process_frame
	var commands: Array = page.commands
	_check(_type_of(commands, 1) == &"show_text", "新台词应插到所选台词之后（下标 1 实际是 %s）" % _type_of(commands, 1))
	_check(_type_of(commands, 2) == &"show_choices" and _type_of(commands, 3) == &"if" and _type_of(commands, 4) == &"if",
		"选项块整体应顺移到下标 2-4 且不被拆断")
	var rebuilt: Dictionary = _choice_item_of(panel)
	_check(not rebuilt.is_empty() and bool(rebuilt.get("well_formed", false)) and int(rebuilt["consumed"]) == 3,
		"台词插进块前时选项块应仍完整")

# ── 工具 ─────────────────────────────────────────────────

## 构造并打开：[台词] [show_choices + 2 条 if（各带 1 句台词）] [台词]。
func _open(panel: Control) -> EventPage:
	var definition := EventDefinition.new()
	definition.event_id = &"story_insert_choice_test"
	definition.display_name = "选项块插入测试"
	var page := EventPage.new()
	page.trigger = "interact"
	var commands: Array[EventCommand] = [_make_line("块前台词")]
	commands.append_array(_make_choice_block())
	commands.append(_make_line("块后台词"))
	page.commands = commands
	definition.pages = [page]
	panel.call("open_definition", definition, null)
	await process_frame
	return page

func _make_line(text: String) -> EventCommand:
	var command := CommandRegistry.create_command(&"show_text")
	command.params["text"] = text
	return command

## 选项块：1 条 show_choices + 2 条顺序式 if（各带 1 句分支台词）。
func _make_choice_block() -> Array[EventCommand]:
	var block: Array[EventCommand] = []
	var show := CommandRegistry.create_command(&"show_choices")
	show.params["prompt"] = "选一个"
	show.params["options"] = ["甲", "乙"]
	block.append(show)
	for k in 2:
		var branch := CommandRegistry.create_command(&"if")
		branch.params["key"] = StoryDocument.CHOICE_STATE
		branch.params["op"] = "=="
		branch.params["value"] = str(k)
		branch.children = [_make_line("选项 %d 的台词" % k)]
		block.append(branch)
	return block

func _choice_item_of(panel: Control) -> Dictionary:
	for item in panel.get("_items"):
		if str(item.get("kind", "")) == "choice":
			return item
	return {}

func _item_at(items: Array, index: int) -> Dictionary:
	for item in items:
		if int(item.get("index", -1)) == index:
			return item
	return {}

func _type_of(commands: Array, index: int) -> StringName:
	if index < 0 or index >= commands.size():
		return &"<out-of-range>"
	return (commands[index] as EventCommand).type

func _view_line_count(views: Array, option_index: int) -> int:
	if option_index >= views.size():
		return -1
	var count := 0
	for view in views[option_index]:
		if str(view.get("kind", "")) == "line":
			count += 1
	return count

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 剧情选项块插入测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
