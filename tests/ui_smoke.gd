extends SceneTree
## 编辑器面板冒烟测试（不需要真正打开编辑器窗口）：
##   godot --headless --path . --script res://tests/ui_smoke.gd
## 覆盖：打开事件、加/删指令、翻页、分支内编辑、嵌套分歧、移动分支、保存后重读。

var _failures: PackedStringArray = []
var _checks := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Node.new()
	root.add_child(host)

	var interactor := Node2D.new()
	interactor.set_script(load("res://addons/rpgeventstudio/runtime/components/event_interactor.gd"))
	interactor.set("event_path", "res://addons/rpgeventstudio/samples/events/librarian.tres")
	host.add_child(interactor)

	var panel_script := load("res://addons/rpgeventstudio/editor/event_editor/event_editor_panel.gd")
	if panel_script == null:
		_fail("面板脚本加载失败")
		_report()
		return
	var panel: Control = panel_script.new()
	host.add_child(panel)
	await process_frame

	panel.call("open_from_selection", [interactor])
	await process_frame

	var definition: EventDefinition = interactor.get("event")
	_check(definition != null, "面板能从节点解析出事件资源")
	_check(definition != null and String(panel.get("_title_label").text).contains("图书管理员"), "标题应显示事件名")

	var page: EventPage = definition.pages[0]
	await _test_basic_edit(panel, page)
	await _test_state_selector(panel)
	await _test_bbcode_preview(panel, page)
	await _test_branch_edit(panel, page)
	await _test_move_between_branches(panel, page)
	await _test_nested_edit(panel, page)
	await _test_cut_paste(panel, page)
	await _test_save_and_reload(panel, definition)
	await _test_language(panel)

	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 基础编辑 ─────────────────────────────────────────────

func _test_basic_edit(panel: Control, page: EventPage) -> void:
	var before := page.commands.size()
	panel.call("_on_add_command_pressed", 0)
	_check(page.commands.size() == before + 1, "点「添加指令」后指令数 +1")
	_check(panel.get("_selected") != null, "新指令应自动选中")

	panel.call("_on_delete_command")
	_check(page.commands.size() == before, "删除后指令数恢复")

	panel.call("_on_page_selected", 1)
	_check(int(panel.get("_page_index")) == 1, "能切换到第 2 页")
	panel.call("_on_page_selected", 0)

# ── 状态选择器 ───────────────────────────────────────────

func _test_state_selector(panel: Control) -> void:
	panel.call("_on_page_selected", 1)
	await process_frame
	var selectors := panel.find_children("*", "StateSelector", true, false)
	_check(selectors.size() >= 1, "条件行使用状态选择器（不是手输内部标识）")
	if not selectors.is_empty():
		var selector: StateSelector = selectors[0]
		_check(selector.key == "Global.Player.HasKey", "选择器绑定的是内部标识（%s）" % selector.key)
		var option: OptionButton = selector.get("_option")
		var shown := ""
		for index in option.get_item_count():
			if str(option.get_item_metadata(index)) == "Global.Player.HasKey":
				shown = option.get_item_text(index)
		_check(shown.contains("教室钥匙"), "选择器显示可读名称（实际：%s）" % shown)
	panel.call("_on_page_selected", 0)

# ── BBCode 编辑 / 预览 ───────────────────────────────────

func _test_bbcode_preview(panel: Control, page: EventPage) -> void:
	var command := _find_first(page.commands, &"show_text")
	_check(command != null, "示例事件里应有显示文字指令")
	if command == null:
		return
	panel.call("_on_command_row_pressed", command)
	await process_frame

	var preview: RichTextLabel = panel.find_child("BBCodePreview", true, false)
	var warning: Label = panel.find_child("BBCodeWarning", true, false)
	var edits := panel.find_children("*", "TextEdit", true, false)
	_check(preview != null, "显示文字参数下应有 BBCode 预览")
	_check(warning != null, "显示文字参数下应有 BBCode 警告标签")
	_check(not edits.is_empty(), "显示文字仍有原始 TextEdit")
	if preview == null or warning == null or edits.is_empty():
		return
	var edit: TextEdit = edits[0]
	var original := str(command.params.get("text", ""))

	var sample := "[b]重点文字[/b]\n[color=#FFD700]关键线索[/color] [font_size=24]大字[/font_size]\n[center]居中[/center]"
	edit.text = sample
	edit.text_changed.emit()
	await process_frame
	_check(str(command.params.get("text", "")) == sample, "原始 BBCode 应原样写入参数")
	_check(preview.text == sample, "预览应保留原始 BBCode 文本")
	_check(preview.get_parsed_text() == "重点文字\n关键线索 大字\n居中", "预览应渲染标签并保留换行（实际：%s）" % preview.get_parsed_text())
	_check(not warning.visible, "合法 BBCode 不应显示警告")

	var invalid := "[b]未闭合 [foo]未知[/foo]"
	edit.text = invalid
	edit.text_changed.emit()
	await process_frame
	_check(warning.visible, "未闭合 / 不支持的标签应显示警告")
	_check(warning.text.contains("[b]") and warning.text.contains("[foo]"), "警告应指出具体标签（实际：%s）" % warning.text)
	_check(str(command.params.get("text", "")) == invalid, "有问题时也不应改写原始文本")

	edit.text = original
	edit.text_changed.emit()
	await process_frame
	_check(not warning.visible, "恢复合法文本后警告应消失")

# ── 分支内编辑 ───────────────────────────────────────────

func _test_branch_edit(panel: Control, page: EventPage) -> void:
	var if_command := _find_first(page.commands, &"if")
	_check(if_command != null, "示例事件里应有一个条件分歧")
	if if_command == null:
		return

	var then_before := if_command.children.size()
	var else_before := if_command.else_children.size()

	# 模拟点击「是」分支上的 ＋
	panel.call("_on_branch_add_pressed", if_command.children, ["测试", "是"], null)
	_check(String(panel.get("_insert_path")).contains("是"), "插入目标应指向「是」分支")

	panel.call("_on_add_command_pressed", 0)
	_check(if_command.children.size() == then_before + 1, "「是」分支应新增一条指令")
	_check(if_command.else_children.size() == else_before, "「否」分支不应被影响")
	_check(panel.get("_selected") != null, "分支内新增后应选中新指令")

	var context: Dictionary = panel.get("_contexts").get(panel.get("_selected"), {})
	_check(str(context.get("branch", "")) == "then", "新指令应属于「是」分支")

	# 删掉它
	panel.call("_on_delete_command")
	_check(if_command.children.size() == then_before, "删除后「是」分支恢复")

	# 用选择 + 工具栏添加：应插在被选中指令后面，且仍在同一分支
	var inside := if_command.children[0]
	panel.call("_on_command_row_pressed", inside)
	panel.call("_on_add_command_pressed", 0)
	_check(if_command.children.size() == then_before + 1, "选中分支内指令时新增应进入同一分支")
	_check(if_command.children[1] == panel.get("_selected") or if_command.children[0] == panel.get("_selected"), "新指令应紧跟在选中项之后")
	panel.call("_on_delete_command")

# ── 移到另一分支 / 移出分支 ──────────────────────────────

func _test_move_between_branches(panel: Control, page: EventPage) -> void:
	var if_command := _find_first(page.commands, &"if")
	if if_command == null or if_command.children.is_empty():
		return

	var moved: EventCommand = if_command.children[0]
	var then_before := if_command.children.size()
	var else_before := if_command.else_children.size()

	panel.call("_on_command_row_pressed", moved)
	panel.call("_on_move_to_sibling")

	_check(if_command.children.size() == then_before - 1, "移走后「是」分支少一条")
	_check(if_command.else_children.size() == else_before + 1, "移入后「否」分支多一条")
	_check(if_command.else_children[else_before] == moved, "同一条指令应被移动到另一分支末尾")

	# 再移回去，验证「移出分支」把指令放回条件分歧后面
	panel.call("_on_command_row_pressed", moved)
	panel.call("_on_move_out_of_branch")
	_check(if_command.else_children.size() == else_before, "移出后「否」分支恢复")
	_check(page.commands.size() >= 1, "移出的指令应落在上层列表里")

# ── 嵌套分歧 ─────────────────────────────────────────────

func _test_nested_edit(panel: Control, page: EventPage) -> void:
	var outer := _find_first(page.commands, &"if")
	if outer == null:
		return

	# 在「是」分支里再放一个条件分歧
	panel.call("_on_branch_add_pressed", outer.children, ["测试"], null)
	var inner_before := outer.children.size()
	panel.call("_on_add_command_pressed", _id_of(panel, &"if"))
	var inner := _find_first(outer.children, &"if")
	_check(outer.children.size() == inner_before + 1, "分支内可以再加条件分歧")
	if inner == null:
		return

	# 往内层的「否」分支塞一条显示文字
	panel.call("_on_branch_add_pressed", inner.else_children, ["测试", "否"], null)
	panel.call("_on_add_command_pressed", _id_of(panel, &"show_text"))
	_check(inner.else_children.size() == 1, "三层结构：内层「否」分支可新增指令")
	_check(inner.children.is_empty(), "内层「是」分支应保持为空")

	var context: Dictionary = panel.get("_contexts").get(panel.get("_selected"), {})
	_check(int(context.get("depth", 0)) >= 4, "嵌套指令的层级应正确（depth=%d）" % int(context.get("depth", 0)))
	_check(str(context.get("branch", "")) == "else", "嵌套指令应属于内层「否」分支")

	panel.call("_on_delete_command")
	_check(inner.else_children.is_empty(), "删除后内层「否」分支恢复为空")

	# 清掉刚加的内层分歧，避免影响后续保存校验
	panel.call("_on_command_row_pressed", inner)
	panel.call("_on_delete_command")
	_check(_find_first(outer.children, &"if") == null, "内层条件分歧应被删除")

# ── 剪切 / 粘贴（跨分歧搬运） ────────────────────────────

func _test_cut_paste(panel: Control, page: EventPage) -> void:
	var if_command := _find_first(page.commands, &"if")
	if if_command == null or if_command.children.is_empty():
		return

	var moved: EventCommand = if_command.children[0]
	var then_before := if_command.children.size()
	var top_before := page.commands.size()

	panel.call("_on_command_row_pressed", moved)
	panel.call("_on_cut")
	_check(if_command.children.size() == then_before - 1, "剪切后原分支少一条")

	# 选中顶层最后一条指令，把剪贴板粘到它后面
	var anchor: EventCommand = page.commands[page.commands.size() - 1]
	panel.call("_on_command_row_pressed", anchor)
	panel.call("_on_paste")

	_check(page.commands.size() == top_before + 1, "粘贴后顶层多一条")
	_check(page.commands[page.commands.size() - 1] == moved, "被剪切的指令应落在目标位置")
	_check(if_command.children.size() == then_before - 1, "原分支不应残留副本")

	# 收尾：删掉搬过来的那条，恢复结构
	panel.call("_on_command_row_pressed", moved)
	panel.call("_on_delete_command")

# ── 保存 / 重新读取 ──────────────────────────────────────

func _test_save_and_reload(panel: Control, definition: EventDefinition) -> void:
	var path := "res://.godot/test_panel_roundtrip.tres"

	# BBCode 文本保存后必须原样读回
	var bbcode_sample := "[b]粗体[/b] [color=#FFD700]金色[/color]\n[font_size=24]大字[/font_size]\n[center]居中[/center]"
	var text_command := _find_first(definition.pages[0].commands, &"show_text")
	if text_command != null:
		panel.call("_on_command_row_pressed", text_command)
		panel.call("_change_param", text_command, "text", bbcode_sample)

	# 改一个参数，确认保存后仍能读到
	var if_command := _find_first(definition.pages[0].commands, &"if")
	if if_command != null:
		panel.call("_on_command_row_pressed", if_command)
		panel.call("_change_param", if_command, "value", "3")

	var error := ResourceSaver.save(definition, path)
	_check(error == OK, "面板改动的资源应能保存")
	var loaded: EventDefinition = load(path)
	_check(loaded != null, "保存后应能重新读取")
	if loaded != null:
		var loaded_if := _find_first(loaded.pages[0].commands, &"if")
		_check(loaded_if != null, "重新读取后条件分歧仍在")
		if loaded_if != null:
			_check(str(loaded_if.params.get("value", "")) == "3", "重新读取后修改过的参数应保留")
			_check(loaded_if.children.size() == if_command.children.size(), "重新读取后「是」分支指令数一致")
			_check(loaded_if.else_children.size() == if_command.else_children.size(), "重新读取后「否」分支指令数一致")
		var loaded_text := _find_first(loaded.pages[0].commands, &"show_text")
		_check(loaded_text != null and str(loaded_text.params.get("text", "")) == bbcode_sample, "重新读取后 BBCode 原文应完整保留")
	DirAccess.remove_absolute(path)

# ── 语言 ─────────────────────────────────────────────────

func _test_language(panel: Control) -> void:
	L10n.reset_missing()
	panel.call("_on_language_selected", 1)
	await process_frame
	var save_button: Button = panel.get("_save_button")
	_check(save_button.text == "Save", "编辑器界面应能切换成英文")
	_check(L10n.missing_keys().is_empty(), "英文界面不应缺翻译：%s" % str(L10n.missing_keys().slice(0, 5)))

	panel.call("_on_language_selected", 0)
	await process_frame
	save_button = panel.get("_save_button")
	_check(save_button.text == "保存", "编辑器界面应能切回中文")

# ── 工具 ─────────────────────────────────────────────────

func _find_first(list: Array, type: StringName) -> EventCommand:
	for command in list:
		if command is EventCommand and command.type == type:
			return command
	return null

func _id_of(panel: Control, type: StringName) -> int:
	var ids: Dictionary = panel.get("_add_ids")
	for id in ids.keys():
		if ids[id] == type:
			return int(id)
	return -1

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 面板冒烟测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
