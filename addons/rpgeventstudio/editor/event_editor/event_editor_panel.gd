@tool
extends VBoxContainer
## 事件编辑面板（停靠在编辑器右侧）。
##
## 结构：事件页 → 出现条件 → 指令树（含「是 / 否」分支）→ 选中指令的参数。
## 分支内的指令直接在列表里编辑：分支标题右侧的「＋」把新指令加到该分支末尾；
## 选中分支内的指令时，工具栏的「＋ 指令」插在它后面（同一条分支）。
## 所有结构改动都登记到 EditorUndoRedoManager，参数改动同样可撤销。

const TRIGGERS := [
	{"id": "interact", "label": "input.action.interact"},
	{"id": "touch", "label": "trigger.touch"},
	{"id": "region_enter", "label": "trigger.region_enter"},
	{"id": "region_exit", "label": "trigger.region_exit"},
	{"id": "autorun", "label": "trigger.autorun"},
	{"id": "parallel", "label": "trigger.parallel"},
	{"id": "call", "label": "trigger.call"},
]

const REPEAT_POLICIES := [
	{"id": "every_time", "label": "repeat.every_time"},
	{"id": "once", "label": "repeat.once"},
	{"id": "on_change", "label": "repeat.on_change"},
]

const OPS := ["==", "!=", ">", ">=", "<", "<="]
const ARITH_OPS := ["+", "-", "*", "/"]

var _plugin: EditorPlugin
var _definition: EventDefinition
var _source_node: Node
var _page_index: int = 0

var _selected: EventCommand = null
var _contexts: Dictionary = {}        ## EventCommand -> {list, index, path, list_path, depth, if, branch}
var _insert_list: Array = []
var _insert_index: int = 0
var _insert_path: String = ""
var _clipboard: EventCommand = null
var _clipboard_is_cut := false

var _title_label: Label
var _new_event_button: Button
var _state_library_button: Button
var _show_internal_check: CheckButton
var _language_option: OptionButton
var _save_button: Button
var _pages_box: HBoxContainer
var _trigger_option: OptionButton
var _repeat_option: OptionButton
var _conditions_box: VBoxContainer
var _commands_box: VBoxContainer
var _params_box: VBoxContainer
var _add_button: MenuButton
var _delete_button: Button
var _up_button: Button
var _down_button: Button
var _cut_button: Button
var _paste_button: Button
var _branch_button: Button
var _out_button: Button
var _status_label: Label
var _target_label: Label

var _add_ids: Dictionary = {}
var _row_buttons: Dictionary = {}
var _building := false

func bind_plugin(plugin: EditorPlugin) -> void:
	_plugin = plugin

func _ready() -> void:
	_build_ui()
	_show_placeholder(L10n.ui("editor.placeholder"))

# ── 对外 ─────────────────────────────────────────────────

func open_from_selection(nodes: Array) -> void:
	for node in nodes:
		if node is EventDefinition:
			open_definition(node, null)
			return
		if node is Node:
			var definition := _definition_of_node(node)
			if definition != null:
				open_definition(definition, node)
				return
	if _definition != null and _definition.changed.is_connected(_on_definition_changed):
		_definition.changed.disconnect(_on_definition_changed)
	_definition = null
	_source_node = null
	_show_placeholder(L10n.ui("editor.placeholder"))

func open_definition(definition: EventDefinition, source_node: Node) -> void:
	if _definition != null and _definition.changed.is_connected(_on_definition_changed):
		_definition.changed.disconnect(_on_definition_changed)
	_definition = definition
	_source_node = source_node
	_page_index = clampi(_page_index, 0, max(0, _definition.pages.size() - 1))
	_selected = null
	_contexts.clear()
	_clipboard = null
	if definition.resource_path != "":
		_definition.changed.connect(_on_definition_changed)
	_reset_insert_target()
	_refresh_all()

func _definition_of_node(node: Node) -> EventDefinition:
	var value: Variant = node.get("event")
	if value is EventDefinition:
		return value
	var path_value: Variant = node.get("event_path")
	if path_value is String and String(path_value) != "":
		return load(String(path_value)) as EventDefinition
	return null

# ── 界面 ─────────────────────────────────────────────────

func _rebuild_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build_ui()
	if _definition != null:
		_refresh_all()
	else:
		_show_placeholder(L10n.ui("editor.placeholder"))

func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	add_child(header)

	_title_label = Label.new()
	_title_label.text = L10n.ui("editor.title")
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 15)
	header.add_child(_title_label)

	_save_button = Button.new()
	_save_button.text = L10n.ui("editor.save")
	_save_button.pressed.connect(_on_save_pressed)
	header.add_child(_save_button)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	add_child(tools)

	_new_event_button = Button.new()
	_new_event_button.text = L10n.ui("editor.new_event")
	_new_event_button.pressed.connect(_on_new_event_pressed)
	tools.add_child(_new_event_button)

	_state_library_button = Button.new()
	_state_library_button.text = L10n.ui("editor.state_library")
	_state_library_button.pressed.connect(_on_state_library_pressed)
	tools.add_child(_state_library_button)

	_show_internal_check = CheckButton.new()
	_show_internal_check.text = L10n.ui("editor.show_internal")
	_show_internal_check.tooltip_text = L10n.ui("state.library.hint")
	_show_internal_check.toggled.connect(_on_show_internal_toggled)
	tools.add_child(_show_internal_check)

	_language_option = OptionButton.new()
	_language_option.add_item("简体中文")
	_language_option.add_item("English")
	_language_option.selected = 0 if L10n.get_editor_locale() == "zh_CN" else 1
	_language_option.tooltip_text = L10n.ui("editor.language")
	_language_option.item_selected.connect(_on_language_selected)
	tools.add_child(_language_option)

	_pages_box = HBoxContainer.new()
	_pages_box.add_theme_constant_override("separation", 2)
	add_child(_pages_box)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 6)
	add_child(meta)

	var trigger_label := Label.new()
	trigger_label.text = L10n.ui("editor.trigger")
	meta.add_child(trigger_label)

	_trigger_option = OptionButton.new()
	_trigger_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in TRIGGERS:
		_trigger_option.add_item(L10n.ui(str(entry["label"])))
	_trigger_option.item_selected.connect(_on_trigger_selected)
	meta.add_child(_trigger_option)

	_repeat_option = OptionButton.new()
	for entry in REPEAT_POLICIES:
		_repeat_option.add_item(L10n.ui(str(entry["label"])))
	_repeat_option.item_selected.connect(_on_repeat_selected)
	meta.add_child(_repeat_option)

	var conditions_title := Label.new()
	conditions_title.text = L10n.ui("editor.conditions")
	conditions_title.add_theme_font_size_override("font_size", 12)
	conditions_title.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	add_child(conditions_title)

	_conditions_box = VBoxContainer.new()
	_conditions_box.add_theme_constant_override("separation", 3)
	add_child(_conditions_box)

	var add_condition := Button.new()
	add_condition.text = L10n.ui("editor.condition.add")
	add_condition.pressed.connect(_on_add_condition)
	add_child(add_condition)

	add_child(HSeparator.new())

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	add_child(toolbar)

	_add_button = MenuButton.new()
	_add_button.text = L10n.ui("editor.commands.add")
	toolbar.add_child(_add_button)

	_delete_button = Button.new()
	_delete_button.text = L10n.ui("editor.commands.delete")
	_delete_button.pressed.connect(_on_delete_command)
	toolbar.add_child(_delete_button)

	_up_button = Button.new()
	_up_button.text = L10n.ui("editor.commands.up")
	_up_button.pressed.connect(_on_move_command.bind(-1))
	toolbar.add_child(_up_button)

	_down_button = Button.new()
	_down_button.text = L10n.ui("editor.commands.down")
	_down_button.pressed.connect(_on_move_command.bind(1))
	toolbar.add_child(_down_button)

	var toolbar2 := HBoxContainer.new()
	toolbar2.add_theme_constant_override("separation", 4)
	add_child(toolbar2)

	_cut_button = Button.new()
	_cut_button.text = L10n.ui("editor.commands.cut")
	_cut_button.pressed.connect(_on_cut)
	toolbar2.add_child(_cut_button)

	_paste_button = Button.new()
	_paste_button.text = L10n.ui("editor.commands.paste")
	_paste_button.pressed.connect(_on_paste)
	toolbar2.add_child(_paste_button)

	_branch_button = Button.new()
	_branch_button.text = L10n.ui("editor.commands.to_branch")
	_branch_button.tooltip_text = L10n.ui("editor.commands.to_branch")
	_branch_button.pressed.connect(_on_move_to_sibling)
	toolbar2.add_child(_branch_button)

	_out_button = Button.new()
	_out_button.text = L10n.ui("editor.commands.out_of_branch")
	_out_button.pressed.connect(_on_move_out_of_branch)
	toolbar2.add_child(_out_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	add_child(scroll)

	_commands_box = VBoxContainer.new()
	_commands_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_commands_box.add_theme_constant_override("separation", 1)
	scroll.add_child(_commands_box)

	var params_title := Label.new()
	params_title.text = L10n.ui("editor.params.title")
	params_title.add_theme_font_size_override("font_size", 12)
	params_title.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	add_child(params_title)

	var params_scroll := ScrollContainer.new()
	# 多行文本下面有 BBCode 预览与警告，参数区需要比原来高一些。
	params_scroll.custom_minimum_size = Vector2(0, 360)
	add_child(params_scroll)

	_params_box = VBoxContainer.new()
	_params_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_params_box.add_theme_constant_override("separation", 4)
	params_scroll.add_child(_params_box)

	_target_label = Label.new()
	_target_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.95))
	add_child(_target_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)

func _show_placeholder(text: String) -> void:
	_title_label.text = L10n.ui("editor.title")
	_clear_children(_pages_box)
	_clear_children(_conditions_box)
	_clear_children(_commands_box)
	_clear_children(_params_box)
	_status_label.text = text
	_target_label.text = ""

# ── 刷新 ─────────────────────────────────────────────────

func _refresh_all() -> void:
	if _definition == null:
		return
	_building = true
	_title_label.text = "%s　[%s]" % [_definition.display_name, String(_definition.event_id)]
	_rebuild_pages()
	_rebuild_page_meta()
	_rebuild_conditions()
	_rebuild_commands()
	_rebuild_params()
	_rebuild_add_menu()
	_building = false
	_show_status()
	_update_toolbar_state()

func _show_status() -> void:
	if _definition == null:
		return
	var path := _definition.resource_path
	if path == "":
		_status_label.text = L10n.ui("editor.status.no_path")
	else:
		_status_label.text = L10n.ui("editor.status.resource", {"path": path})

func _update_target_label() -> void:
	if _insert_path == "":
		_target_label.text = ""
		return
	_target_label.text = L10n.ui("editor.insert_target", {"path": _insert_path})

func _rebuild_pages() -> void:
	_clear_children(_pages_box)
	for index in _definition.pages.size():
		var button := Button.new()
		button.text = str(index + 1)
		button.toggle_mode = true
		button.button_pressed = index == _page_index
		button.custom_minimum_size = Vector2(30, 0)
		button.tooltip_text = L10n.ui("editor.tooltip.page", {"page": index + 1})
		button.pressed.connect(_on_page_selected.bind(index))
		_pages_box.add_child(button)

	var add := Button.new()
	add.text = "＋"
	add.tooltip_text = L10n.ui("editor.page.add_tip")
	add.pressed.connect(_on_add_page)
	_pages_box.add_child(add)

	if _definition.pages.size() > 1:
		var remove := Button.new()
		remove.text = "－"
		remove.tooltip_text = L10n.ui("editor.page.remove_tip")
		remove.pressed.connect(_on_remove_page)
		_pages_box.add_child(remove)

func _rebuild_page_meta() -> void:
	var page := _current_page()
	if page == null:
		_trigger_option.disabled = true
		_repeat_option.disabled = true
		return
	_trigger_option.disabled = false
	_repeat_option.disabled = false
	_trigger_option.selected = _index_of_id(TRIGGERS, page.trigger)
	_repeat_option.selected = _index_of_id(REPEAT_POLICIES, page.repeat_policy)

func _rebuild_conditions() -> void:
	_clear_children(_conditions_box)
	var page := _current_page()
	if page == null:
		return
	for condition in page.conditions:
		_conditions_box.add_child(_make_condition_row(condition, page))

func _make_condition_row(condition: EventCondition, page: EventPage) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var selector := StateSelector.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(selector)
	selector.set_show_internal(_show_internal_check.button_pressed)
	selector.set_key(condition.key)
	selector.state_changed.connect(func(value: String) -> void:
		condition.key = value
		condition.emit_changed()
		page.emit_changed()
		_rebuild_conditions()
	)

	var state_type := StateCatalogStore.type_of(condition.key)
	var is_bool := state_type == "bool"

	var op_option := OptionButton.new()
	for op in OPS:
		op_option.add_item(op)
	op_option.selected = max(0, OPS.find(condition.op))
	op_option.disabled = is_bool
	if is_bool:
		op_option.tooltip_text = L10n.ui("editor.condition.bool_op_tip")
	op_option.item_selected.connect(func(index: int) -> void:
		condition.op = OPS[index]
		condition.emit_changed()
		page.emit_changed()
	)
	row.add_child(op_option)

	if is_bool:
		var choice := OptionButton.new()
		choice.add_item(L10n.ui("debug.value_true"))
		choice.add_item(L10n.ui("debug.value_false"))
		var want := false
		if condition.value is bool:
			want = condition.value
		else:
			want = ValueParser.parse(str(condition.value)) == true
		choice.selected = 0 if want else 1
		choice.item_selected.connect(func(index: int) -> void:
			condition.value = (index == 0)
			condition.emit_changed()
			page.emit_changed()
		)
		row.add_child(choice)
	else:
		var value_edit := LineEdit.new()
		value_edit.text = str(condition.value)
		value_edit.placeholder_text = L10n.ui("editor.condition.value")
		value_edit.custom_minimum_size = Vector2(64, 0)
		value_edit.text_changed.connect(func(text: String) -> void:
			condition.value = ValueParser.parse(text)
			condition.emit_changed()
			page.emit_changed()
		)
		row.add_child(value_edit)

	var remove := Button.new()
	remove.text = "×"
	remove.pressed.connect(func() -> void:
		page.conditions.erase(condition)
		page.emit_changed()
		_rebuild_conditions()
	)
	row.add_child(remove)
	return row

func _rebuild_commands() -> void:
	_clear_children(_commands_box)
	_row_buttons.clear()
	_contexts.clear()
	var page := _current_page()
	if page == null:
		return
	var root_path := L10n.ui("editor.path.page", {"page": _page_index + 1})
	_add_command_list(page.commands, 0, [root_path], null, "")

	if page.commands.is_empty():
		var hint := Label.new()
		hint.text = "  " + L10n.ui("editor.commands.empty")
		hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
		_commands_box.add_child(hint)

	# 重建后修正插入目标：有选中就跟着选中走，否则回到当前页末尾
	if _selected != null and _contexts.has(_selected):
		var context: Dictionary = _contexts[_selected]
		_insert_list = context["list"]
		_insert_index = int(context["index"]) + 1
		_insert_path = str(context["list_path"])
	else:
		_reset_insert_target()

func _add_command_list(list: Array, depth: int, path: Array, parent_if: EventCommand, branch: String) -> void:
	if list.is_empty() and depth > 0:
		var empty := Label.new()
		empty.text = _indent(depth) + L10n.ui("editor.branch.empty")
		empty.add_theme_font_size_override("font_size", UiFonts.NOTE)
		empty.add_theme_color_override("font_color", Color(0.55, 0.57, 0.62))
		_commands_box.add_child(empty)

	for index in list.size():
		var command: EventCommand = list[index]
		if command == null or not (command is EventCommand):
			continue
		var command_path := path.duplicate()
		command_path.append(L10n.ui("editor.path.command", {
			"name": CommandRegistry.display_name(command.type),
			"index": index + 1,
		}))
		_contexts[command] = {
			"list": list,
			"index": index,
			"path": command_path,
			"list_path": _join_path(path),
			"depth": depth,
			"if": parent_if,
			"branch": branch,
		}

		var button := Button.new()
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = _indent(depth) + "◆ " + CommandRegistry.summary(command)
		button.button_pressed = command == _selected
		button.tooltip_text = L10n.ui("editor.tooltip.select")
		button.pressed.connect(_on_command_row_pressed.bind(command))
		_commands_box.add_child(button)
		_row_buttons[command] = button

		if CommandRegistry.is_block(command.type):
			_add_branch_block(command, depth, command_path)

func _add_branch_block(command: EventCommand, depth: int, command_path: Array) -> void:
	var then_path := command_path.duplicate()
	then_path.append(L10n.ui("editor.path.branch_then"))
	_commands_box.add_child(_make_branch_header(depth + 1, L10n.ui("editor.branch.then"), command.children, then_path))
	_add_command_list(command.children, depth + 2, then_path, command, "then")

	var else_path := command_path.duplicate()
	else_path.append(L10n.ui("editor.path.branch_else"))
	_commands_box.add_child(_make_branch_header(depth + 1, L10n.ui("editor.branch.else"), command.else_children, else_path))
	_add_command_list(command.else_children, depth + 2, else_path, command, "else")

func _make_branch_header(depth: int, title: String, list: Array, path: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = _indent(depth) + "├ " + title + "："
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var add := Button.new()
	add.text = "＋"
	add.tooltip_text = L10n.ui("editor.branch.add", {"branch": title})
	add.pressed.connect(_on_branch_add_pressed.bind(list, path, add))
	row.add_child(add)
	return row

func _on_branch_add_pressed(list: Array, path: Array, source: Control) -> void:
	_insert_list = list
	_insert_index = list.size()
	_insert_path = _join_path(path)
	_update_target_label()
	_open_add_menu_at(source)

func _open_add_menu_at(source: Control) -> void:
	var popup := _add_button.get_popup()
	popup.reset_size()
	var screen_pos := Vector2i.ZERO
	if source != null and source.is_inside_tree():
		screen_pos = Vector2i(source.get_screen_position()) + Vector2i(0, int(source.size.y))
	popup.popup(Rect2i(screen_pos, Vector2i.ZERO))

func _on_command_row_pressed(command: EventCommand) -> void:
	_select(command)

func _select(command: EventCommand) -> void:
	_selected = command
	var context: Dictionary = _contexts.get(command, {})
	if not context.is_empty():
		_insert_list = context["list"]
		_insert_index = int(context["index"]) + 1
		_insert_path = str(context["list_path"])
	for key in _row_buttons.keys():
		var button: Button = _row_buttons[key]
		button.button_pressed = key == command
	_rebuild_params()
	_update_target_label()
	_update_toolbar_state()

func _reset_insert_target() -> void:
	var page := _current_page()
	if page == null:
		_insert_list = []
		_insert_index = 0
		_insert_path = ""
		return
	_insert_list = page.commands
	_insert_index = page.commands.size()
	_insert_path = L10n.ui("editor.path.page", {"page": _page_index + 1})
	_update_target_label()

func _update_toolbar_state() -> void:
	var has_selection := _selected != null
	_delete_button.disabled = not has_selection
	_up_button.disabled = not has_selection
	_down_button.disabled = not has_selection
	_cut_button.disabled = not has_selection
	_paste_button.disabled = _clipboard == null
	_branch_button.disabled = not _can_move_to_sibling()
	_out_button.disabled = not _can_move_out()

func _can_move_to_sibling() -> bool:
	if _selected == null:
		return false
	var context: Dictionary = _contexts.get(_selected, {})
	if context.is_empty():
		return false
	return context.get("if") != null and str(context.get("branch", "")) != ""

func _can_move_out() -> bool:
	if _selected == null:
		return false
	var context: Dictionary = _contexts.get(_selected, {})
	return not context.is_empty() and context.get("if") != null

# ── 参数 ─────────────────────────────────────────────────

func _rebuild_params() -> void:
	_clear_children(_params_box)
	if _selected == null:
		var hint := Label.new()
		hint.text = L10n.ui("editor.params.empty")
		hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
		_params_box.add_child(hint)
		return

	var params: Array = CommandRegistry.params_of(_selected.type)
	if params.is_empty():
		var none := Label.new()
		none.text = L10n.ui("editor.params.none")
		_params_box.add_child(none)
		return

	for param in params:
		var name := str(param.get("name", ""))
		var type := str(param.get("type", "text"))

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.text = CommandRegistry.param_label(param)
		label.add_theme_font_size_override("font_size", UiFonts.NOTE)
		row.add_child(label)

		row.add_child(_make_param_control(_selected, name, type, param))
		var hint_key := str(param.get("hint", ""))
		if hint_key != "":
			var hint := Label.new()
			hint.text = L10n.ui(hint_key)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_font_size_override("font_size", UiFonts.NOTE)
			hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
			row.add_child(hint)
		_params_box.add_child(row)

	if CommandRegistry.is_block(_selected.type):
		var note := Label.new()
		note.text = L10n.ui("editor.params.block_note")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", UiFonts.NOTE)
		note.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
		_params_box.add_child(note)

func _make_param_control(command: EventCommand, name: String, type: String, param: Dictionary) -> Control:
	var current: Variant = command.params.get(name, param.get("default", ""))

	# 条件分歧 / 设置变量里的「值」：如果对应状态是开关，用「是 / 否」下拉，不让人填 true/false
	if name == "value" and command.params.has("key") and type == "text":
		var key_type := StateCatalogStore.type_of(str(command.params.get("key", "")))
		if key_type == "bool":
			var choice := OptionButton.new()
			choice.add_item(L10n.ui("debug.value_true"))
			choice.add_item(L10n.ui("debug.value_false"))
			var want: Variant = current
			if want is String:
				want = ValueParser.parse(want)
			choice.selected = 0 if bool(want) else 1
			choice.item_selected.connect(func(index: int) -> void:
				_change_param(command, name, index == 0)
			)
			return choice

	match type:
		"bool":
			var check := CheckBox.new()
			check.text = L10n.ui("param.switch_on")
			check.button_pressed = bool(current)
			check.toggled.connect(func(pressed: bool) -> void:
				_change_param(command, name, pressed)
			)
			return check
		"int":
			var spin := SpinBox.new()
			spin.min_value = -999999
			spin.max_value = 999999
			spin.step = 1
			spin.value = float(current) if current is int or current is float else 0.0
			spin.value_changed.connect(func(value: float) -> void:
				_change_param(command, name, int(value))
			)
			return spin
		"float":
			var spin := SpinBox.new()
			spin.min_value = -999999
			spin.max_value = 999999
			spin.step = 0.1
			spin.value = float(current) if current is int or current is float else 0.0
			spin.value_changed.connect(func(value: float) -> void:
				_change_param(command, name, value)
			)
			return spin
		"choice":
			var option := OptionButton.new()
			var option_keys: Array = param.get("options", [])
			var option_values: Array = param.get("values", [])
			for option_key in option_keys:
				option.add_item(L10n.ui(str(option_key)))
			var selected := option_values.find(str(current))
			option.selected = max(0, selected)
			option.item_selected.connect(func(index: int) -> void:
				var value: Variant = option_values[index] if index < option_values.size() else str(current)
				_change_param(command, name, value)
			)
			return option
		"op", "arith":
			var option := OptionButton.new()
			var ops := OPS if type == "op" else ARITH_OPS
			for op in ops:
				option.add_item(op)
			option.selected = max(0, ops.find(str(current)))
			option.item_selected.connect(func(index: int) -> void:
				_change_param(command, name, ops[index])
			)
			return option
		"multiline", "options":
			var editor_box := VBoxContainer.new()
			editor_box.add_theme_constant_override("separation", 4)
			var text := TextEdit.new()
			text.custom_minimum_size = Vector2(0, 88)
			text.text = _to_text(current)
			editor_box.add_child(text)

			var preview: RichTextLabel = null
			var warning: Label = null
			if type == "multiline":
				var preview_title := Label.new()
				preview_title.text = L10n.ui("editor.bbcode.preview")
				preview_title.add_theme_font_size_override("font_size", UiFonts.NOTE)
				preview_title.add_theme_color_override("font_color", Color(0.64, 0.72, 0.86))
				editor_box.add_child(preview_title)

				var preview_panel := PanelContainer.new()
				preview_panel.name = "BBCodePreviewPanel"
				preview_panel.custom_minimum_size = Vector2(0, 64)
				var style := StyleBoxFlat.new()
				style.bg_color = Color(0.06, 0.07, 0.10, 0.92)
				style.border_color = Color(0.24, 0.28, 0.38, 0.9)
				style.set_border_width_all(1)
				style.set_corner_radius_all(4)
				style.content_margin_left = 8.0
				style.content_margin_right = 8.0
				style.content_margin_top = 6.0
				style.content_margin_bottom = 6.0
				preview_panel.add_theme_stylebox_override("panel", style)
				editor_box.add_child(preview_panel)

				preview = RichTextLabel.new()
				preview.name = "BBCodePreview"
				preview.bbcode_enabled = true
				preview.fit_content = true
				preview.scroll_active = false
				preview.selection_enabled = false
				preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
				preview.add_theme_font_size_override("normal_font_size", 14)
				preview.add_theme_color_override("default_color", Color(0.90, 0.92, 0.96))
				preview.add_theme_constant_override("line_separation", 4)
				preview_panel.add_child(preview)

				var bbcode_hint := Label.new()
				bbcode_hint.text = L10n.ui("editor.bbcode.hint")
				bbcode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				bbcode_hint.add_theme_font_size_override("font_size", UiFonts.NOTE)
				bbcode_hint.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68))
				editor_box.add_child(bbcode_hint)

				warning = Label.new()
				warning.name = "BBCodeWarning"
				warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				warning.add_theme_font_size_override("font_size", UiFonts.NOTE)
				warning.add_theme_color_override("font_color", Color(0.98, 0.68, 0.42))
				warning.visible = false
				editor_box.add_child(warning)
				_refresh_bbcode_preview(text.text, preview, warning)

			text.text_changed.connect(func() -> void:
				var value: Variant = text.text
				if type == "options":
					value = text.text.split("\n", false)
				_change_param(command, name, value)
				if preview != null:
					_refresh_bbcode_preview(text.text, preview, warning)
			)
			return editor_box
		"node_ref":
			var wrap := VBoxContainer.new()
			var box := HBoxContainer.new()
			var path := str(current)
			var display := LineEdit.new()
			display.editable = false
			display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			display.text = path.get_file() if path != "" else L10n.ui("param.clear_node")
			display.tooltip_text = path
			box.add_child(display)
			var pick := Button.new()
			pick.text = L10n.ui("param.pick_node")
			pick.pressed.connect(func() -> void:
				_open_node_picker(command, name)
			)
			box.add_child(pick)
			var clear := Button.new()
			clear.text = "×"
			clear.pressed.connect(func() -> void:
				_change_param(command, name, "")
				_change_param(command, name + "_scene", "")
				_rebuild_params()
			)
			box.add_child(clear)
			wrap.add_child(box)
			var status_text := _node_status(command, name)
			if status_text != "":
				var status := Label.new()
				status.text = status_text
				status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				status.add_theme_font_size_override("font_size", UiFonts.NOTE)
				status.add_theme_color_override("font_color", Color(0.95, 0.65, 0.5))
				wrap.add_child(status)
			return wrap
		"state":
			var selector := StateSelector.new()
			selector.set_show_internal(_show_internal_check.button_pressed)
			selector.set_key(str(current))
			selector.state_changed.connect(func(value: String) -> void:
				_change_param(command, name, value)
			)
			return selector
		"event_path", "sound_path":
			var box := HBoxContainer.new()
			var edit := LineEdit.new()
			edit.text = str(current)
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.placeholder_text = "res://…"
			edit.text_changed.connect(func(value: String) -> void:
				_change_param(command, name, value)
			)
			box.add_child(edit)
			var browse := Button.new()
			browse.text = "…"
			browse.pressed.connect(func() -> void:
				_open_file_dialog(edit, command, name)
			)
			box.add_child(browse)
			return box
		_:
			var edit := LineEdit.new()
			edit.text = str(current)
			edit.text_changed.connect(func(value: String) -> void:
				_change_param(command, name, value)
			)
			return edit

func _to_text(value: Variant) -> String:
	if value is Array:
		var lines := PackedStringArray()
		for item in value:
			lines.append(str(item))
		return "\n".join(lines)
	return str(value)

## 预览完全由 RichTextLabel 渲染；警告只做提示，不修改原始文本。
func _refresh_bbcode_preview(source: String, preview: RichTextLabel, warning: Label) -> void:
	if preview == null or warning == null:
		return
	preview.text = source
	var issues := Bbcode.analyze(source)
	var has_issues := Bbcode.has_issues(issues)
	warning.visible = has_issues
	warning.text = Bbcode.describe(issues, true) if has_issues else ""

func _change_param(command: EventCommand, name: String, value: Variant) -> void:
	if _building or command == null:
		return
	var old_value: Variant = command.params.get(name)
	if _values_equal(old_value, value):
		return

	command.params[name] = value
	command.emit_changed()
	_update_row_text(command)

	var undo := _undo_redo()
	if undo == null:
		return
	# execute = false：值已经写入，这里只登记历史；连续输入按动作名合并成一步
	undo.create_action(
		"%s:%s:%d" % [L10n.ui("editor.undo.param"), name, command.get_instance_id()],
		UndoRedo.MERGE_ENDS,
		_current_page()
	)
	undo.force_fixed_history()
	undo.add_do_method(self, "_apply_param", command, name, value)
	undo.add_undo_method(self, "_apply_param", command, name, old_value)
	undo.commit_action(false)

func _apply_param(command: EventCommand, name: String, value: Variant) -> void:
	if command == null:
		return
	command.params[name] = value
	command.emit_changed()
	_rebuild_commands()
	if _selected == command:
		_rebuild_params()
	_update_target_label()

func _values_equal(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return a == b

func _update_row_text(command: EventCommand) -> void:
	var button: Button = _row_buttons.get(command, null)
	if button == null:
		return
	var context: Dictionary = _contexts.get(command, {})
	var depth := int(context.get("depth", 0))
	button.text = _indent(depth) + "◆ " + CommandRegistry.summary(command)

# ── 事件页操作 ───────────────────────────────────────────

func _current_page() -> EventPage:
	if _definition == null or _definition.pages.is_empty():
		return null
	_page_index = clampi(_page_index, 0, _definition.pages.size() - 1)
	return _definition.pages[_page_index]

func _on_page_selected(index: int) -> void:
	_page_index = index
	_selected = null
	_contexts.clear()
	_reset_insert_target()
	_refresh_all()

func _on_add_page() -> void:
	if _definition == null:
		return
	var pages := _definition.pages.duplicate()
	pages.append(EventPage.new())
	_commit_pages(pages, pages.size() - 1)

func _on_remove_page() -> void:
	if _definition == null or _definition.pages.size() <= 1:
		return
	var pages := _definition.pages.duplicate()
	pages.remove_at(_page_index)
	_commit_pages(pages, mini(_page_index, pages.size() - 1))

func _commit_pages(pages: Array, selected: int) -> void:
	var undo := _undo_redo()
	if undo == null:
		_apply_pages(_definition, pages, selected)
		return
	undo.create_action(L10n.ui("editor.path.page", {"page": selected + 1}), UndoRedo.MERGE_DISABLE, _definition)
	undo.force_fixed_history()
	undo.add_do_method(self, "_apply_pages", _definition, pages, selected)
	undo.add_undo_method(self, "_apply_pages", _definition, _definition.pages.duplicate(), _page_index)
	undo.commit_action()

func _apply_pages(definition: EventDefinition, pages: Array, selected: int) -> void:
	definition.pages.assign(pages)
	definition.emit_changed()
	if definition != _definition:
		return
	_page_index = clampi(selected, 0, maxi(0, pages.size() - 1))
	_selected = null
	_refresh_all()

func _on_trigger_selected(index: int) -> void:
	var page := _current_page()
	if page == null:
		return
	page.trigger = str(TRIGGERS[index]["id"])
	page.emit_changed()
	_definition.emit_changed()

func _on_repeat_selected(index: int) -> void:
	var page := _current_page()
	if page == null:
		return
	page.repeat_policy = str(REPEAT_POLICIES[index]["id"])
	page.emit_changed()
	_definition.emit_changed()

func _on_add_condition() -> void:
	var page := _current_page()
	if page == null:
		return
	var condition := EventCondition.new()
	condition.key = "Global."
	condition.value = true
	page.conditions.append(condition)
	page.emit_changed()
	_definition.emit_changed()
	_rebuild_conditions()

# ── 指令操作 ─────────────────────────────────────────────

func _on_add_command_pressed(id: int) -> void:
	var type: StringName = _add_ids.get(id, &"")
	if type == &"":
		return
	var page := _current_page()
	if page == null:
		return

	var target_list: Array = _insert_list
	if target_list == null:
		target_list = page.commands
	var insert_at: int = clampi(_insert_index, 0, target_list.size())

	var command := CommandRegistry.create_command(type)
	_commit_insert(target_list, insert_at, command)
	_rebuild_commands()

	if _contexts.has(command):
		_select(command)
	else:
		_selected = command
		_rebuild_params()
	_update_toolbar_state()

func _commit_insert(list: Array, index: int, command: EventCommand) -> void:
	var undo := _undo_redo()
	if undo == null:
		list.insert(index, command)
		return
	undo.create_action(L10n.ui("editor.undo.add"), UndoRedo.MERGE_DISABLE, _current_page())
	undo.force_fixed_history()
	undo.add_do_method(self, "_do_insert", list, index, command)
	undo.add_undo_method(self, "_do_remove", list, index)
	undo.add_do_reference(command)
	undo.commit_action()

func _do_insert(list: Array, index: int, command: EventCommand) -> void:
	index = clampi(index, 0, list.size())
	list.insert(index, command)
	_after_structure_change()

func _do_remove(list: Array, index: int) -> void:
	if index >= 0 and index < list.size():
		list.remove_at(index)
	_after_structure_change()

func _do_move(list: Array, from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= list.size():
		return
	var command = list[from_index]
	list.remove_at(from_index)
	list.insert(clampi(to_index, 0, list.size()), command)
	_after_structure_change()

func _do_cross_move(from_list: Array, from_index: int, to_list: Array, to_index: int) -> void:
	if from_index < 0 or from_index >= from_list.size():
		return
	var command = from_list[from_index]
	from_list.remove_at(from_index)
	to_list.insert(clampi(to_index, 0, to_list.size()), command)
	_after_structure_change()

func _after_structure_change() -> void:
	_mark_dirty()
	_selected = null
	_rebuild_commands()
	_rebuild_params()
	_update_toolbar_state()

func _mark_dirty() -> void:
	if _definition != null:
		_definition.emit_changed()

func _on_delete_command() -> void:
	if _selected == null:
		return
	var context: Dictionary = _contexts.get(_selected, {})
	if context.is_empty():
		return
	var list: Array = context["list"]
	var index := int(context["index"])
	var command := _selected

	var undo := _undo_redo()
	if undo == null:
		list.remove_at(index)
	else:
		undo.create_action(L10n.ui("editor.undo.delete"), UndoRedo.MERGE_DISABLE, _current_page())
		undo.add_do_method(self, "_do_remove", list, index)
		undo.add_undo_method(self, "_do_insert", list, index, command)
		undo.add_undo_reference(command)
		undo.commit_action()

	_selected = null
	_rebuild_commands()
	_rebuild_params()
	_update_toolbar_state()

func _on_move_command(delta: int) -> void:
	if _selected == null:
		return
	var context: Dictionary = _contexts.get(_selected, {})
	if context.is_empty():
		return
	var list: Array = context["list"]
	var index := int(context["index"])
	var target := index + delta
	if target < 0 or target >= list.size():
		return

	var undo := _undo_redo()
	if undo == null:
		var command = list[index]
		list.remove_at(index)
		list.insert(target, command)
		_selected = command
		_rebuild_commands()
		_select(command)
	else:
		undo.create_action(L10n.ui("editor.undo.move"), UndoRedo.MERGE_DISABLE, _current_page())
		undo.add_do_method(self, "_do_move", list, index, target)
		undo.add_undo_method(self, "_do_move", list, target, index)
		undo.commit_action()
		_selected = null
		_rebuild_commands()
	_rebuild_params()
	_update_toolbar_state()

## 移到同一条件分歧的另一条分支（追加到末尾）。
func _on_move_to_sibling() -> void:
	if not _can_move_to_sibling():
		return
	var context: Dictionary = _contexts.get(_selected, {})
	var parent_if: EventCommand = context["if"]
	var branch := str(context["branch"])
	var source_list: Array = context["list"]
	var target_list: Array = parent_if.else_children if branch == "then" else parent_if.children
	_cross_move(source_list, int(context["index"]), target_list, target_list.size())

## 从分支移回上层（放在所属条件分歧后面）。
func _on_move_out_of_branch() -> void:
	if not _can_move_out():
		return
	var context: Dictionary = _contexts.get(_selected, {})
	var parent_if: EventCommand = context["if"]
	var parent_context: Dictionary = _contexts.get(parent_if, {})
	var target_list: Array = parent_context.get("list", [])
	var target_index := int(parent_context.get("index", 0)) + 1
	_cross_move(context["list"], int(context["index"]), target_list, target_index)

func _cross_move(from_list: Array, from_index: int, to_list: Array, to_index: int) -> void:
	var undo := _undo_redo()
	if undo == null:
		if from_index < 0 or from_index >= from_list.size():
			return
		var command = from_list[from_index]
		from_list.remove_at(from_index)
		to_list.insert(clampi(to_index, 0, to_list.size()), command)
		_selected = null
		_rebuild_commands()
		return

	undo.create_action(L10n.ui("editor.undo.branch"), UndoRedo.MERGE_DISABLE, _current_page())
	undo.force_fixed_history()
	undo.add_do_method(self, "_do_cross_move", from_list, from_index, to_list, to_index)
	undo.add_undo_method(self, "_do_cross_move", to_list, to_index, from_list, from_index)
	undo.commit_action()
	_selected = null
	_rebuild_commands()
	_update_toolbar_state()

func _on_cut() -> void:
	if _selected == null:
		return
	# 存对象本身：删除操作可撤销，且粘贴后仍是同一条指令（真正的「移动」）
	_clipboard = _selected
	_clipboard_is_cut = true
	_on_delete_command()
	_update_toolbar_state()

func _on_paste() -> void:
	if _clipboard == null:
		return
	var page := _current_page()
	if page == null:
		return
	var target_list: Array = _insert_list if _insert_list != null else page.commands
	var insert_at: int = clampi(_insert_index, 0, target_list.size())
	# 剪切后再粘贴 = 移动（保留同一个对象）；将来若加「复制」，再走 duplicate
	var restored := false
	for existing_page in _definition.pages:
		if _contains_command(existing_page.commands, _clipboard):
			restored = true
	var command: EventCommand = _clipboard if _clipboard_is_cut and not restored else _clipboard.duplicate_command()
	_commit_insert(target_list, insert_at, command)
	if _clipboard_is_cut:
		_clipboard = null
		_clipboard_is_cut = false
	_rebuild_commands()
	if _contexts.has(command):
		_select(command)
	_update_toolbar_state()

func _contains_command(commands: Array, target: EventCommand) -> bool:
	for command in commands:
		if command == target:
			return true
		if command != null and (_contains_command(command.children, target) or _contains_command(command.else_children, target)):
			return true
	return false

func _undo_redo() -> EditorUndoRedoManager:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_editor_undo_redo()

# ── 添加菜单 ─────────────────────────────────────────────

func _rebuild_add_menu() -> void:
	var popup := _add_button.get_popup()
	popup.clear()
	_add_ids.clear()
	var id := 0
	for category in CommandRegistry.categories():
		popup.add_separator(CommandRegistry.category_label(category))
		for type in CommandRegistry.types_in_category(category):
			var text := CommandRegistry.display_name(type)
			if CommandRegistry.is_block(type):
				text += "…"
			popup.add_item(text, id)
			_add_ids[id] = type
			id += 1
	if not popup.id_pressed.is_connected(_on_add_command_pressed):
		popup.id_pressed.connect(_on_add_command_pressed)

# ── 保存与文件 ───────────────────────────────────────────

func _on_save_pressed() -> void:
	if _definition == null:
		return
	if _definition.resource_path == "":
		_status_label.text = L10n.ui("editor.status.no_path")
		return
	var error := ResourceSaver.save(_definition, _definition.resource_path)
	if error == OK:
		_status_label.text = L10n.ui("editor.status.saved", {"path": _definition.resource_path})
		_toast(L10n.ui("editor.toast.saved"))
	else:
		_status_label.text = L10n.ui("editor.status.save_failed", {"code": error})

func _open_file_dialog(edit: LineEdit, command: EventCommand, param_name: String) -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "res://")
	dialog.file_selected.connect(func(path: String) -> void:
		edit.text = path
		_change_param(command, param_name, path)
		dialog.queue_free()
	)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(720, 480))

func _toast(message: String) -> void:
	if not Engine.is_editor_hint():
		return
	var toaster := EditorInterface.get_editor_toaster()
	if toaster != null:
		toaster.push_toast(message, EditorToaster.SEVERITY_INFO)

# ── 新建事件 / 状态库 ────────────────────────────────────

func _node_status(command: EventCommand, name: String) -> String:
	if not Engine.is_editor_hint():
		return ""
	var path := str(command.params.get(name, ""))
	if path == "":
		return ""
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return ""
	var scene_path := str(command.params.get(name + "_scene", ""))
	if scene_path != "" and scene_path != String(scene_root.scene_file_path):
		return L10n.ui("param.node_other_scene")
	if scene_root.get_node_or_null(NodePath(path)) == null:
		return L10n.ui("param.node_missing")
	return ""

func _open_node_picker(command: EventCommand, name: String) -> void:
	if not Engine.is_editor_hint():
		return
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_toast(L10n.ui("picker.no_scene"))
		return
	var picker := SceneObjectPicker.new()
	add_child(picker)
	picker.picked.connect(func(node_path: String, scene_path: String) -> void:
		_change_param(command, name, node_path)
		_change_param(command, name + "_scene", scene_path)
		_rebuild_params()
	)
	picker.open_for(scene_root, str(command.params.get(name, "")))

func _on_new_event_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "res://")
	dialog.title = L10n.ui("editor.new_event")
	dialog.file_selected.connect(func(path: String) -> void:
		_create_event_at(path)
		dialog.queue_free()
	)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(760, 520))

func _create_event_at(path: String) -> void:
	var definition := EventDefinition.new()
	definition.event_id = StringName(path.get_file().get_basename())
	definition.display_name = String(definition.event_id)
	definition.pages = [EventPage.new()]
	var error := ResourceSaver.save(definition, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		_status_label.text = L10n.ui("editor.status.save_failed", {"code": error})
		return
	definition.take_over_path(path)

	# 如果当前选中的节点带 event_path，把新事件顺手挂上去（可撤销）
	if _source_node != null and _source_node.get("event_path") != null:
		var previous := str(_source_node.get("event_path"))
		var undo := _undo_redo()
		if undo != null:
			undo.create_action(L10n.ui("editor.bind_event"), UndoRedo.MERGE_DISABLE, _source_node)
			undo.add_do_property(_source_node, "event_path", path)
			undo.add_undo_property(_source_node, "event_path", previous)
			undo.commit_action()
		else:
			_source_node.set("event_path", path)
		_toast(L10n.ui("editor.new_event_bind"))

	var loaded := load(path) as EventDefinition
	if loaded != null:
		open_definition(loaded, _source_node)

func _on_state_library_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := StateLibraryDialog.new()
	add_child(dialog)
	dialog.state_saved.connect(func(_key: String) -> void:
		_refresh_state_selectors()
	)
	dialog.open_catalog()

func _refresh_state_selectors() -> void:
	for node in find_children("*", "StateSelector", true, false):
		if node is StateSelector:
			node.refresh()

func _on_show_internal_toggled(pressed: bool) -> void:
	for node in find_children("*", "StateSelector", true, false):
		if node is StateSelector:
			node.set_show_internal(pressed)

# ── 语言 ─────────────────────────────────────────────────

func _on_language_selected(index: int) -> void:
	var locale := "zh_CN" if index == 0 else "en"
	L10n.set_editor_locale(locale)
	if _plugin != null:
		if _plugin.has_method("save_editor_language"):
			_plugin.call("save_editor_language", locale)
		if _plugin.has_method("refresh_dock_title"):
			_plugin.call("refresh_dock_title")
	_rebuild_ui()

# ── 杂项 ─────────────────────────────────────────────────

func _on_definition_changed() -> void:
	if _building or _definition == null:
		return
	_rebuild_commands()

func _index_of_id(entries: Array, value: String) -> int:
	for index in entries.size():
		if str(entries[index].get("id", "")) == value:
			return index
	return 0

func _join_path(segments: Array) -> String:
	var texts := PackedStringArray()
	for segment in segments:
		texts.append(str(segment))
	return " › ".join(texts)

func _indent(depth: int) -> String:
	var text := ""
	for i in depth:
		text += "   "
	return text

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
