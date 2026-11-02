@tool
extends VBoxContainer
## 剧情创作工作台（主屏标签页）：面向写作者的剧情编辑视图。
##
## 左：角色花名册（显示名 / 标识 / 头像参考 / 颜色）；
## 中：台词列表（逐条编辑，台词之间可插入选项 / 条件 / 状态 / 指令）+ 条目编辑区；
## 右：整段文案预览（RichTextLabel 渲染 BBCode，明确提示不支持的标签）。
##
## 所有编辑都通过 StoryDocument 落在原有 EventCommand / EventPage 上，
## 不重建数据，旧事件资源零丢失；结构变更全部登记 EditorUndoRedoManager。

const INSERT_DEFAULT_CHOICE_OPTIONS := 2

const ResourceEdits = preload("res://addons/rpgeventstudio/editor/resource_edits.gd")

var _plugin: EditorPlugin
var _definition: EventDefinition
var _source_node: Node
var _page_index: int = 0
var _document: StoryDocument
var _items: Array = []
var _selected_command: EventCommand = null
var _selected_item: Dictionary = {}
var _roster: StoryCharacters
var _selected_character: StoryCharacter = null

var _building := false
var _refresh_queued := false
var _roster_save_timer: Timer
var _live_editing := false

var _title_label: Label
var _body_split: HSplitContainer
var _roster_panel: Control
var _preview_panel: Control
var _panels_menu: MenuButton
var _roster_visible := true
var _preview_visible := true
var _panels_user_set := false

var _pages_box: HBoxContainer
var _save_button: Button
var _undo_button: Button
var _redo_button: Button
var _template_button: MenuButton
var _open_button: Button

var _roster_list: VBoxContainer
var _roster_fields: VBoxContainer
var _roster_id_edit: LineEdit
var _roster_name_edit: LineEdit
var _roster_avatar_edit: LineEdit
var _roster_color_picker: ColorPickerButton
var _roster_notes_edit: LineEdit

var _insert_label: Label
var _script_list: VBoxContainer
var _editor_box: VBoxContainer
var _preview_label: RichTextLabel
var _preview_issues: Label
var _status_label: Label

var _rows: Dictionary = {}          ## command 实例 id -> {summary, speaker}
var _template_ids: Dictionary = {}
var _insert_ids: Dictionary = {}

func bind_plugin(plugin: EditorPlugin) -> void:
	_plugin = plugin

func _ready() -> void:
	_roster = StoryCharacters.load_roster()
	_build_ui()
	_roster_save_timer = Timer.new()
	_roster_save_timer.one_shot = true
	_roster_save_timer.wait_time = 0.35
	_roster_save_timer.timeout.connect(_persist_roster)
	add_child(_roster_save_timer)
	_show_placeholder(L10n.ui("story.open_hint"))

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

func open_definition(definition: EventDefinition, source_node: Node) -> void:
	if _definition != null and _definition.changed.is_connected(_on_definition_changed):
		_definition.changed.disconnect(_on_definition_changed)
	_definition = definition
	_definition.changed.connect(_on_definition_changed)
	_source_node = source_node
	_page_index = clampi(_page_index, 0, max(0, _definition.pages.size() - 1))
	_selected_command = null
	_selected_item = {}
	_refresh_all()

func _definition_of_node(node: Node) -> EventDefinition:
	var value: Variant = node.get("event")
	if value is EventDefinition:
		return value
	var path_value: Variant = node.get("event_path")
	if path_value is String and String(path_value) != "":
		return load(String(path_value)) as EventDefinition
	return null

# ── 界面骨架 ─────────────────────────────────────────────

func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	add_child(header)

	_title_label = Label.new()
	_title_label.text = L10n.ui("story.title")
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 15)
	header.add_child(_title_label)

	_open_button = Button.new()
	_open_button.text = L10n.ui("story.open_button")
	_open_button.pressed.connect(_on_open_file_pressed)
	header.add_child(_open_button)

	_template_button = MenuButton.new()
	_template_button.text = L10n.ui("story.template_menu")
	_template_button.about_to_popup.connect(_fill_template_menu)
	header.add_child(_template_button)

	_undo_button = Button.new()
	_undo_button.text = L10n.ui("story.undo_button")
	_undo_button.pressed.connect(_on_undo_pressed)
	header.add_child(_undo_button)

	_redo_button = Button.new()
	_redo_button.text = L10n.ui("story.redo_button")
	_redo_button.pressed.connect(_on_redo_pressed)
	header.add_child(_redo_button)

	_save_button = Button.new()
	_save_button.text = L10n.ui("editor.save")
	_save_button.pressed.connect(_on_save_pressed)
	header.add_child(_save_button)

	_panels_menu = MenuButton.new()
	_panels_menu.text = L10n.ui("story.panels")
	_panels_menu.tooltip_text = L10n.ui("story.panels.tip")
	var panels_popup := _panels_menu.get_popup()
	panels_popup.add_check_item(L10n.ui("story.panels.roster"), 0)
	panels_popup.add_check_item(L10n.ui("story.panels.preview"), 1)
	panels_popup.set_item_checked(0, true)
	panels_popup.set_item_checked(1, true)
	panels_popup.id_pressed.connect(_on_panels_menu)
	header.add_child(_panels_menu)

	_pages_box = HBoxContainer.new()
	_pages_box.add_theme_constant_override("separation", 2)
	add_child(_pages_box)

	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.split_offset = -560
	add_child(body)
	_body_split = body

	_roster_panel = _build_roster_section()
	body.add_child(_roster_panel)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 4)
	body.add_child(center)

	var insert_row := HFlowContainer.new()
	insert_row.add_theme_constant_override("h_separation", 4)
	insert_row.add_theme_constant_override("v_separation", 4)
	center.add_child(insert_row)
	for entry in [
		{"key": "line", "text_key": "story.insert.line"},
		{"key": "choice", "text_key": "story.insert.choice"},
		{"key": "condition", "text_key": "story.insert.condition"},
		{"key": "switch", "text_key": "story.insert.switch"},
		{"key": "variable", "text_key": "story.insert.variable"},
	]:
		var button := Button.new()
		button.text = L10n.ui(str(entry["text_key"]))
		button.pressed.connect(_on_insert_quick.bind(str(entry["key"])))
		insert_row.add_child(button)
	_insert_ids.clear()
	var command_menu := MenuButton.new()
	command_menu.text = L10n.ui("story.insert.command")
	command_menu.about_to_popup.connect(_fill_insert_menu)
	command_menu.get_popup().id_pressed.connect(_on_insert_command_pressed)
	_command_menu_button = command_menu
	insert_row.add_child(command_menu)

	_insert_label = Label.new()
	_insert_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_insert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_insert_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_insert_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.95))
	insert_row.add_child(_insert_label)

	var center_split := VSplitContainer.new()
	center_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_split.split_offset = 200
	center.add_child(center_split)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.custom_minimum_size = Vector2(0, 220)
	center_split.add_child(list_scroll)

	_script_list = VBoxContainer.new()
	_script_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_list.add_theme_constant_override("separation", 2)
	list_scroll.add_child(_script_list)

	var editor_scroll := ScrollContainer.new()
	editor_scroll.custom_minimum_size = Vector2(0, 190)
	center_split.add_child(editor_scroll)

	_editor_box = VBoxContainer.new()
	_editor_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_box.add_theme_constant_override("separation", 4)
	editor_scroll.add_child(_editor_box)

	_preview_panel = _build_preview_section()
	body.add_child(_preview_panel)

	resized.connect(_update_responsive_panels)
	call_deferred("_update_responsive_panels")

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)

## 窄窗口默认收起角色/预览两栏，把宽度让给台词编辑；用户可从「面板」菜单重新打开。
func _update_responsive_panels() -> void:
	if size.x <= 1.0:
		return
	if not _panels_user_set:
		var available := get_parent_area_size().x
		if available <= 1.0:
			available = size.x
		var narrow := available < 860.0
		_roster_visible = not narrow
		_preview_visible = not narrow
		if _panels_menu != null:
			var popup := _panels_menu.get_popup()
			popup.set_item_checked(0, _roster_visible)
			popup.set_item_checked(1, _preview_visible)
	if _roster_panel != null:
		_roster_panel.visible = _roster_visible
	if _preview_panel != null:
		_preview_panel.visible = _preview_visible
	if _body_split != null:
		_body_split.split_offset = -560 if _preview_visible else 0

func _on_panels_menu(id: int) -> void:
	_panels_user_set = true
	var popup := _panels_menu.get_popup()
	var available := get_parent_area_size().x
	if available <= 1.0:
		available = size.x
	var narrow := available < 860.0
	if id == 0:
		_roster_visible = not _roster_visible
		if narrow and _roster_visible:
			_preview_visible = false
	if id == 1:
		_preview_visible = not _preview_visible
		if narrow and _preview_visible:
			_roster_visible = false
	popup.set_item_checked(0, _roster_visible)
	popup.set_item_checked(1, _preview_visible)
	_update_responsive_panels()

func _build_roster_section() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	panel.add_theme_constant_override("separation", 4)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = L10n.ui("story.roster.title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	header.add_child(title)
	var add := Button.new()
	add.text = "＋"
	add.tooltip_text = L10n.ui("story.roster.add")
	add.pressed.connect(_on_roster_add)
	header.add_child(add)
	var save := Button.new()
	save.text = L10n.ui("story.roster.save")
	save.tooltip_text = L10n.ui("story.roster.save_tip")
	save.pressed.connect(_persist_roster)
	header.add_child(save)
	panel.add_child(header)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(0, 130)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(list_scroll)
	_roster_list = VBoxContainer.new()
	_roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_list.add_theme_constant_override("separation", 2)
	list_scroll.add_child(_roster_list)

	_roster_fields = VBoxContainer.new()
	_roster_fields.add_theme_constant_override("separation", 3)
	panel.add_child(_roster_fields)

	var hint := Label.new()
	hint.text = L10n.ui("story.roster.hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", UiFonts.NOTE)
	hint.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68))
	panel.add_child(hint)
	return panel

func _build_preview_section() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = L10n.ui("story.preview.title")
	title.add_theme_font_size_override("font_size", 13)
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	_preview_label = RichTextLabel.new()
	_preview_label.bbcode_enabled = true
	_preview_label.fit_content = true
	_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_label.custom_minimum_size = Vector2(300, 0)
	_preview_label.add_theme_font_size_override("normal_font_size", 14)
	_preview_label.add_theme_constant_override("line_separation", 4)
	_preview_label.add_theme_color_override("default_color", Color(0.90, 0.92, 0.96))
	scroll.add_child(_preview_label)

	var issues_title := Label.new()
	issues_title.text = L10n.ui("story.preview.issues_title")
	issues_title.add_theme_font_size_override("font_size", UiFonts.NOTE)
	issues_title.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	panel.add_child(issues_title)

	_preview_issues = Label.new()
	_preview_issues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_issues.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_preview_issues.add_theme_color_override("font_color", Color(0.98, 0.68, 0.42))
	panel.add_child(_preview_issues)
	return panel

func _show_placeholder(text: String) -> void:
	_title_label.text = L10n.ui("story.title")
	_clear_children(_pages_box)
	_clear_children(_script_list)
	_clear_children(_editor_box)
	_clear_children(_roster_list)
	_clear_children(_roster_fields)
	_preview_label.text = ""
	_preview_issues.text = ""
	_insert_label.text = ""
	_status_label.text = text

# ── 刷新 ─────────────────────────────────────────────────

func _refresh_all() -> void:
	if _definition == null:
		return
	_building = true
	_title_label.text = "%s　[%s]" % [_definition.display_name, String(_definition.event_id)]
	_document = StoryDocument.new(_current_page())
	_document.undo_provider = _editor_undo
	_document.changed.connect(_on_document_changed.bind(_definition))
	_rebuild_pages()
	_rebuild_roster_list()
	_rebuild_script_list()
	_rebuild_editor()
	_rebuild_preview()
	_show_status()
	_building = false

func _on_document_changed(changed_definition: EventDefinition = null) -> void:
	if changed_definition != null and changed_definition != _definition:
		changed_definition.emit_changed()
		return
	if _building or _definition == null:
		return
	_building = true
	_definition.emit_changed()
	_building = false
	if _live_editing:
		# 打字过程中只更新行摘要与预览，不重建正在输入的控件。
		_update_selected_row()
		_rebuild_preview()
		return
	_building = true
	_rebuild_script_list()
	_rebuild_editor()
	_rebuild_preview()
	_show_status()
	_building = false

func _on_definition_changed() -> void:
	if _building or _refresh_queued:
		return
	_refresh_queued = true
	_refresh_external.call_deferred()

func _refresh_external() -> void:
	_refresh_queued = false
	if _definition != null:
		_page_index = clampi(_page_index, 0, maxi(0, _definition.pages.size() - 1))
		_refresh_all()

func _current_page() -> EventPage:
	if _definition == null or _definition.pages.is_empty():
		return null
	_page_index = clampi(_page_index, 0, _definition.pages.size() - 1)
	return _definition.pages[_page_index]

func _rebuild_pages() -> void:
	_clear_children(_pages_box)
	if _definition == null:
		return
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

# ── 台词列表 ─────────────────────────────────────────────

func _rebuild_script_list() -> void:
	_clear_children(_script_list)
	_rows.clear()
	if _document == null:
		return
	_items = _document.build_items()
	_render_items(_items, 0)
	if _items.is_empty():
		var hint := Label.new()
		hint.text = "  " + L10n.ui("story.list.empty")
		hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
		_script_list.add_child(hint)
	_update_insert_label()
	_sync_row_selection()

func _render_items(items: Array, depth: int) -> void:
	for item in items:
		match str(item.get("kind", "")):
			"line":
				_script_list.add_child(_make_line_row(item, depth))
			"choice":
				_script_list.add_child(_make_choice_row(item, depth))
				_render_choice_options(item)
			"condition":
				_script_list.add_child(_make_condition_row(item, depth))
				_render_branch(_render_label_then(depth, L10n.ui("editor.branch.then")), item, "children_view")
				_render_branch(_render_label_then(depth, L10n.ui("editor.branch.else")), item, "else_view")
			"state":
				_script_list.add_child(_make_state_row(item, depth))
			"command":
				_script_list.add_child(_make_command_row(item, depth))

func _render_label_then(depth: int, title: String) -> int:
	var label := Label.new()
	label.text = _indent(depth + 1) + "├ " + title + "："
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_script_list.add_child(label)
	return depth + 1

func _render_branch(branch_depth: int, item: Dictionary, view_key: String) -> void:
	var view: Array = item[view_key]
	if view.is_empty():
		var empty := Label.new()
		empty.text = _indent(branch_depth) + L10n.ui("editor.branch.empty")
		empty.add_theme_font_size_override("font_size", UiFonts.NOTE)
		empty.add_theme_color_override("font_color", Color(0.55, 0.57, 0.62))
		_script_list.add_child(empty)
		return
	_render_items(view, branch_depth)

func _render_choice_options(item: Dictionary) -> void:
	var options: Array = item["options"]
	var views: Array = item["option_views"]
	for option_index in options.size():
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 4)
		var label := Label.new()
		label.text = "%s▸ %s" % [_indent(int(item["depth"]) + 1), L10n.ui("story.option.header", {
			"number": option_index + 1,
			"text": str(options[option_index]),
		})]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.94, 0.78, 0.48))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_child(label)
		var branch: Variant = item["branches"][option_index] if option_index < (item["branches"] as Array).size() else null
		if branch != null:
			var add := Button.new()
			add.text = "＋"
			add.tooltip_text = L10n.ui("story.option.add_line")
			add.pressed.connect(_on_add_line_into.bind(item, option_index))
			header.add_child(add)
		else:
			var missing := Label.new()
			missing.text = L10n.ui("story.option.no_branch")
			missing.add_theme_font_size_override("font_size", UiFonts.NOTE)
			missing.add_theme_color_override("font_color", Color(0.72, 0.6, 0.45))
			header.add_child(missing)
		_script_list.add_child(header)
		if branch != null:
			_render_items(views[option_index], int(item["depth"]) + 2)

func _make_action_buttons(row: HBoxContainer, item: Dictionary) -> void:
	var up := Button.new()
	up.text = "↑"
	up.tooltip_text = L10n.ui("editor.commands.up")
	up.pressed.connect(func() -> void: _document.move_item(item, -1))
	row.add_child(up)
	var down := Button.new()
	down.text = "↓"
	down.tooltip_text = L10n.ui("editor.commands.down")
	down.pressed.connect(func() -> void: _document.move_item(item, 1))
	row.add_child(down)
	var copy := Button.new()
	copy.text = "⧉"
	copy.tooltip_text = L10n.ui("story.row.duplicate")
	copy.pressed.connect(func() -> void: _document.duplicate_item(item))
	row.add_child(copy)
	var delete := Button.new()
	delete.text = "×"
	delete.tooltip_text = L10n.ui("editor.commands.delete")
	delete.pressed.connect(func() -> void:
		_forget_selection(item["command"])
		_document.delete_item(item)
	)
	row.add_child(delete)

func _make_select_button(row: HBoxContainer, item: Dictionary, text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = false
	button.pressed.connect(_on_row_pressed.bind(item))
	if color.a > 0.0:
		button.add_theme_color_override("font_color", color)
	row.add_child(button)
	return button

func _make_line_row(item: Dictionary, depth: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	_make_select_button(row, item, _indent(depth) + _line_text(item), _speaker_color(item))
	_make_action_buttons(row, item)
	_remember_row(item, row)
	return row

func _line_text(item: Dictionary) -> String:
	var speaker := str(item["command"].params.get("speaker", ""))
	var body := str(item["command"].params.get("text", "")).replace("\n", " ")
	if body.length() > 42:
		body = body.substr(0, 42) + "…"
	if speaker.strip_edges() == "":
		return "%s %s" % [L10n.ui("story.row.narration"), body]
	return "%s：%s" % [speaker, body]

func _speaker_color(item: Dictionary) -> Color:
	var speaker := str(item["command"].params.get("speaker", ""))
	if speaker.strip_edges() != "" and _roster != null:
		var character := _roster.find_by_display_name(speaker)
		if character != null:
			return character.color
	return Color(0.88, 0.9, 0.94)

func _make_choice_row(item: Dictionary, depth: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var prompt := str(item["command"].params.get("prompt", ""))
	var count := (item["options"] as Array).size()
	var text := L10n.ui("story.row.choice", {"count": count, "prompt": prompt})
	_make_select_button(row, item, _indent(depth) + text, Color(0.96, 0.72, 0.4))
	_make_action_buttons(row, item)
	_remember_row(item, row)
	return row

func _make_condition_row(item: Dictionary, depth: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var text := "%s◇ %s" % [_indent(depth), _condition_summary(item["command"])]
	_make_select_button(row, item, text, Color(0.93, 0.87, 0.55))
	_make_action_buttons(row, item)
	_remember_row(item, row)
	return row

func _condition_summary(command: EventCommand) -> String:
	var key := str(command.params.get("key", ""))
	if key.strip_edges() == "":
		return CommandRegistry.summary(command)
	return L10n.ui("story.row.condition", {"expr": StoryPreview._condition_text(command)})

func _make_state_row(item: Dictionary, depth: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var text := "%s◇ %s" % [_indent(depth), CommandRegistry.summary(item["command"])]
	_make_select_button(row, item, text, Color(0.78, 0.7, 0.95))
	_make_action_buttons(row, item)
	_remember_row(item, row)
	return row

func _make_command_row(item: Dictionary, depth: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var text := "%s◆ %s" % [_indent(depth), CommandRegistry.summary(item["command"])]
	_make_select_button(row, item, text, Color(0.62, 0.66, 0.74))
	_make_action_buttons(row, item)
	_remember_row(item, row)
	return row

func _remember_row(item: Dictionary, row: Control) -> void:
	_rows[item["command"].get_instance_id()] = row

func _update_selected_row() -> void:
	if _selected_item.is_empty():
		return
	var row: Control = _rows.get(_selected_item["command"].get_instance_id(), null)
	if row == null:
		return
	var button := row.get_child(0) as Button
	if button == null:
		return
	match str(_selected_item.get("kind", "")):
		"line":
			button.text = _indent(int(_selected_item["depth"])) + _line_text(_selected_item)
			button.add_theme_color_override("font_color", _speaker_color(_selected_item))

func _sync_row_selection() -> void:
	_selected_item = {}
	_locate_item(_items)
	for key in _rows.keys():
		var row: Control = _rows[key]
		var button := row.get_child(0) as Button
		if button != null:
			button.button_pressed = key == _selected_command.get_instance_id() if _selected_command != null else false

func _locate_item(items: Array) -> void:
	if _selected_command == null:
		return
	for item in items:
		if item["command"] == _selected_command:
			_selected_item = item
			return
		match str(item.get("kind", "")):
			"choice":
				for view in item["option_views"]:
					_locate_item(view)
			"condition":
				_locate_item(item["children_view"])
				_locate_item(item["else_view"])
		if not _selected_item.is_empty():
			return

func _on_row_pressed(item: Dictionary) -> void:
	_selected_command = item["command"]
	_selected_item = item
	_sync_row_selection()
	_rebuild_editor()

func _forget_selection(command: EventCommand) -> void:
	if _selected_command == command:
		_selected_command = null
		_selected_item = {}

func _update_insert_label() -> void:
	_insert_label.text = L10n.ui("story.insert_target", {"target": _insert_where_text()})

func _insert_where_text() -> String:
	if _selected_item.is_empty():
		return L10n.ui("story.where.page", {"page": _page_index + 1})
	return str(_selected_item.get("where", L10n.ui("story.where.page", {"page": _page_index + 1})))

## 选中条目之后（同一条列表）；没有选中就是当前页末尾。
## 选项块占 1 + N 条连续指令（show_choices + N 条 if），选中它时必须插到整块之后，
## 否则会插进 show_choices 与第一条 if 之间，把分支配对拆断。
func _insert_target() -> Dictionary:
	if not _selected_item.is_empty():
		var index := int(_selected_item["index"])
		if str(_selected_item.get("kind", "")) == "choice":
			index += int(_selected_item.get("consumed", 1))
		else:
			index += 1
		return {"list": _selected_item["list"], "index": index}
	var page := _current_page()
	return {"list": page.commands, "index": page.commands.size()}

# ── 条目编辑区 ───────────────────────────────────────────

func _rebuild_editor() -> void:
	_clear_children(_editor_box)
	if _selected_item.is_empty():
		var hint := Label.new()
		hint.text = L10n.ui("story.editor.empty")
		hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
		_editor_box.add_child(hint)
		return
	match str(_selected_item.get("kind", "")):
		"line":
			_build_line_editor(_selected_item)
		"choice":
			_build_choice_editor(_selected_item)
		"condition":
			_build_condition_editor(_selected_item)
		"state":
			_build_state_editor(_selected_item)
		"command":
			_build_command_editor(_selected_item)

func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	return label

func _build_line_editor(item: Dictionary) -> void:
	var command: EventCommand = item["command"]
	_editor_box.add_child(_field_label(L10n.ui("param.speaker")))
	var speaker_row := HBoxContainer.new()
	speaker_row.add_theme_constant_override("separation", 4)
	_editor_box.add_child(speaker_row)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_item(L10n.ui("story.editor.speaker_none"))
	var current := str(command.params.get("speaker", ""))
	var selected := 0 if current.strip_edges() == "" else -1
	if _roster != null:
		for character in _roster.characters:
			if character == null:
				continue
			option.add_item(character.label())
			if character.display_name != "" and character.display_name == current:
				selected = option.item_count - 1
	if selected < 0 and current.strip_edges() != "":
		# 不在花名册里的旧说话人原样列出，选中后保持不变
		option.add_separator()
		option.add_item(current)
		selected = option.item_count - 1
	option.selected = max(0, selected)
	option.item_selected.connect(func(index: int) -> void:
		var value := "" if index == 0 else option.get_item_text(index)
		_live_editing = true
		_document.set_line_param(item, "speaker", value)
		_live_editing = false
		_update_selected_row()
		_rebuild_preview()
	)
	speaker_row.add_child(option)

	var advance := SpinBox.new()
	advance.min_value = 0.0
	advance.max_value = 60.0
	advance.step = 0.1
	advance.suffix = "s"
	advance.tooltip_text = L10n.ui("param.auto_advance")
	advance.value = float(command.params.get("auto_advance", 0.0))
	advance.value_changed.connect(func(value: float) -> void:
		_document.set_line_param(item, "auto_advance", value)
	)
	speaker_row.add_child(advance)

	_editor_box.add_child(_field_label(L10n.ui("param.text")))
	var text := TextEdit.new()
	text.custom_minimum_size = Vector2(0, 110)
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.text = str(command.params.get("text", ""))
	_editor_box.add_child(text)

	var warning := Label.new()
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_size_override("font_size", UiFonts.NOTE)
	warning.add_theme_color_override("font_color", Color(0.98, 0.68, 0.42))
	warning.visible = false
	_editor_box.add_child(warning)
	_refresh_line_warning(text.text, warning)

	text.text_changed.connect(func() -> void:
		_live_editing = true
		_document.set_line_param(item, "text", text.text)
		_live_editing = false
		_update_selected_row()
		_rebuild_preview()
		_refresh_line_warning(text.text, warning)
	)

	var hint := Label.new()
	hint.text = L10n.ui("editor.bbcode.hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", UiFonts.NOTE)
	hint.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68))
	_editor_box.add_child(hint)

func _refresh_line_warning(source: String, warning: Label) -> void:
	var issues := Bbcode.analyze(source)
	var has := Bbcode.has_issues(issues)
	warning.visible = has
	warning.text = Bbcode.describe(issues, true) if has else ""

func _build_choice_editor(item: Dictionary) -> void:
	var command: EventCommand = item["command"]
	_editor_box.add_child(_field_label(L10n.ui("param.prompt")))
	var prompt := LineEdit.new()
	prompt.text = str(command.params.get("prompt", ""))
	_editor_box.add_child(prompt)

	_editor_box.add_child(_field_label(L10n.ui("param.options")))
	var options: Array = item["options"]
	for option_index in options.size():
		_editor_box.add_child(_make_option_row(item, option_index, str(options[option_index])))

	var add := Button.new()
	add.text = L10n.ui("story.editor.option_add")
	add.pressed.connect(func() -> void:
		var ok := _document.choice_add_option(item, L10n.ui("story.editor.option_default"))
		if not ok:
			_toast(L10n.ui("story.toast.not_well_formed"))
	)
	_editor_box.add_child(add)

	if not bool(item.get("well_formed", false)):
		var note := Label.new()
		note.text = L10n.ui("story.editor.choice_not_well_formed")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", UiFonts.NOTE)
		note.add_theme_color_override("font_color", Color(0.98, 0.68, 0.42))
		_editor_box.add_child(note)
	elif (item["ifs"] as Array).is_empty():
		var ensure := Button.new()
		ensure.text = L10n.ui("story.editor.option_branches_generate")
		ensure.pressed.connect(func() -> void: _document.choice_ensure_branches(item))
		_editor_box.add_child(ensure)

	prompt.text_changed.connect(func(value: String) -> void:
		_live_editing = true
		_document.choice_set_prompt(item, value)
		_live_editing = false
		_rebuild_preview()
	)

func _make_option_row(item: Dictionary, option_index: int, value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(text: String) -> void:
		_live_editing = true
		_document.choice_rename_option(item, option_index, text)
		_live_editing = false
		_rebuild_preview()
	)
	row.add_child(edit)
	var up := Button.new()
	up.text = "↑"
	up.pressed.connect(func() -> void: _document.choice_move_option(item, option_index, -1))
	row.add_child(up)
	var down := Button.new()
	down.text = "↓"
	down.pressed.connect(func() -> void: _document.choice_move_option(item, option_index, 1))
	row.add_child(down)
	var remove := Button.new()
	remove.text = "×"
	remove.tooltip_text = L10n.ui("story.editor.option_remove")
	remove.pressed.connect(func() -> void: _document.choice_remove_option(item, option_index))
	row.add_child(remove)
	return row

func _build_condition_editor(item: Dictionary) -> void:
	var command: EventCommand = item["command"]
	_editor_box.add_child(_field_label(L10n.ui("param.state")))
	var selector := StateSelector.new()
	selector.set_key(str(command.params.get("key", "")))
	selector.state_changed.connect(func(value: String) -> void:
		_live_editing = true
		_document.set_condition_param(item, "key", value)
		_live_editing = false
		_update_selected_row()
		_rebuild_preview()
	)
	_editor_box.add_child(selector)

	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 4)
	_editor_box.add_child(value_row)

	var ops := ["==", "!=", ">", ">=", "<", "<="]
	var op_option := OptionButton.new()
	for op in ops:
		op_option.add_item(op)
	op_option.selected = max(0, ops.find(str(command.params.get("op", "=="))))
	op_option.item_selected.connect(func(index: int) -> void:
		_document.set_condition_param(item, "op", ops[index])
	)
	value_row.add_child(op_option)

	var key_type := StateCatalogStore.type_of(str(command.params.get("key", "")))
	if key_type == "bool":
		var choice := OptionButton.new()
		choice.add_item(L10n.ui("debug.value_true"))
		choice.add_item(L10n.ui("debug.value_false"))
		var want := false
		if command.params.get("value", "true") is bool:
			want = command.params.get("value", "true")
		else:
			want = ValueParser.parse(str(command.params.get("value", "true"))) == true
		choice.selected = 0 if want else 1
		choice.item_selected.connect(func(index: int) -> void:
			_document.set_condition_param(item, "value", index == 0)
		)
		value_row.add_child(choice)
	else:
		var value_edit := LineEdit.new()
		value_edit.text = str(command.params.get("value", ""))
		value_edit.placeholder_text = L10n.ui("editor.condition.value")
		value_edit.text_changed.connect(func(text: String) -> void:
			_live_editing = true
			_document.set_condition_param(item, "value", ValueParser.parse(text))
			_live_editing = false
			_update_selected_row()
			_rebuild_preview()
		)
		value_row.add_child(value_edit)

	var note := Label.new()
	note.text = L10n.ui("editor.params.block_note")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", UiFonts.NOTE)
	note.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	_editor_box.add_child(note)

func _build_state_editor(item: Dictionary) -> void:
	var command: EventCommand = item["command"]
	var type := String(command.type)
	_editor_box.add_child(_field_label(L10n.ui("param.state" if type != "set_variable" else "param.variable")))
	var selector := StateSelector.new()
	selector.set_key(str(command.params.get("key", "")))
	selector.state_changed.connect(func(value: String) -> void:
		_live_editing = true
		_document.set_state_param(item, "key", value)
		_live_editing = false
		_update_selected_row()
		_rebuild_preview()
	)
	_editor_box.add_child(selector)

	if type == "set_switch":
		var check := CheckBox.new()
		check.text = L10n.ui("param.switch_on")
		check.button_pressed = bool(command.params.get("value", true))
		check.toggled.connect(func(pressed: bool) -> void:
			_document.set_state_param(item, "value", pressed)
		)
		_editor_box.add_child(check)
	elif type == "set_variable":
		var edit := LineEdit.new()
		edit.text = str(command.params.get("value", ""))
		edit.text_changed.connect(func(text: String) -> void:
			_document.set_state_param(item, "value", text)
		)
		_editor_box.add_child(edit)
	elif type == "variable_op":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var ops := ["+", "-", "*", "/"]
		var op_option := OptionButton.new()
		for op in ops:
			op_option.add_item(op)
		op_option.selected = max(0, ops.find(str(command.params.get("op", "+"))))
		op_option.item_selected.connect(func(index: int) -> void:
			_document.set_state_param(item, "op", ops[index])
		)
		row.add_child(op_option)
		var spin := SpinBox.new()
		spin.min_value = -999999
		spin.max_value = 999999
		spin.step = 0.1
		spin.value = float(command.params.get("value", 1.0)) if command.params.get("value", 1.0) is float or command.params.get("value", 1.0) is int else 1.0
		spin.value_changed.connect(func(value: float) -> void:
			_document.set_state_param(item, "value", value)
		)
		row.add_child(spin)
		_editor_box.add_child(row)

func _build_command_editor(item: Dictionary) -> void:
	var command: EventCommand = item["command"]
	var title := Label.new()
	title.text = "%s（%s）" % [CommandRegistry.display_name(command.type), String(command.type)]
	title.add_theme_font_size_override("font_size", 13)
	_editor_box.add_child(title)
	var hint := Label.new()
	hint.text = L10n.ui("story.editor.command_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", UiFonts.NOTE)
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	_editor_box.add_child(hint)

func _indent(depth: int) -> String:
	var text := ""
	for i in depth:
		text += "   "
	return text

# ── 插入 ─────────────────────────────────────────────────

func _on_insert_quick(kind: String) -> void:
	if _document == null:
		return
	var target := _insert_target()
	match kind:
		"line":
			var command := CommandRegistry.create_command(&"show_text")
			command.params["speaker"] = _default_speaker()
			_document.insert_command(target["list"], int(target["index"]), command)
			_after_insert(command)
		"choice":
			var commands: Array = []
			var show := CommandRegistry.create_command(&"show_choices")
			var options := PackedStringArray()
			for i in INSERT_DEFAULT_CHOICE_OPTIONS:
				options.append(L10n.ui("story.editor.option_default"))
			show.params["options"] = Array(options)
			commands.append(show)
			for i in INSERT_DEFAULT_CHOICE_OPTIONS:
				var branch := CommandRegistry.create_command(&"if")
				branch.params["key"] = StoryDocument.CHOICE_STATE
				branch.params["op"] = "=="
				branch.params["value"] = str(i)
				commands.append(branch)
			_document.insert_commands(target["list"], int(target["index"]), commands)
			_after_insert(show)
		"condition":
			var command := CommandRegistry.create_command(&"if")
			_document.insert_command(target["list"], int(target["index"]), command)
			_after_insert(command)
		"switch":
			var command := CommandRegistry.create_command(&"set_switch")
			_document.insert_command(target["list"], int(target["index"]), command)
			_after_insert(command)
		"variable":
			var command := CommandRegistry.create_command(&"set_variable")
			_document.insert_command(target["list"], int(target["index"]), command)
			_after_insert(command)

## 在某个选项分支末尾加一句台词。
func _on_add_line_into(item: Dictionary, option_index: int) -> void:
	var branches: Array = item["branches"]
	if option_index >= branches.size() or branches[option_index] == null:
		return
	var command := CommandRegistry.create_command(&"show_text")
	command.params["speaker"] = _default_speaker()
	var branch: Array = branches[option_index]
	_document.insert_command(branch, branch.size(), command)
	_after_insert(command)

func _after_insert(command: EventCommand) -> void:
	_selected_command = command
	_rebuild_script_list()
	_locate_item(_items)
	_sync_row_selection()
	_rebuild_editor()

func _editor_undo() -> Object:
	return EditorInterface.get_editor_undo_redo()

func _default_speaker() -> String:
	if not _selected_item.is_empty() and str(_selected_item.get("kind", "")) == "line":
		return str(_selected_item["command"].params.get("speaker", ""))
	return ""

func _fill_template_menu() -> void:
	var popup := _template_button.get_popup()
	popup.clear()
	_template_ids.clear()
	var id := 0
	for template in StoryTemplates.all():
		popup.add_item(str(template["name"]), id)
		popup.set_item_tooltip(id, str(template["hint"]))
		_template_ids[id] = str(template["id"])
		id += 1
	if not popup.id_pressed.is_connected(_on_template_pressed):
		popup.id_pressed.connect(_on_template_pressed)

func _on_template_pressed(id: int) -> void:
	var template_id := str(_template_ids.get(id, ""))
	if template_id == "":
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "res://")
	dialog.title = L10n.ui("story.template_menu")
	dialog.file_selected.connect(func(path: String) -> void:
		_create_from_template(template_id, path)
		dialog.queue_free()
	)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(760, 520))

func _create_from_template(template_id: String, path: String) -> void:
	var definition := StoryTemplates.build(template_id)
	if definition == null:
		return
	definition.event_id = StringName(path.get_file().get_basename())
	definition.display_name = String(definition.event_id)
	var error := ResourceSaver.save(definition, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		_status_label.text = L10n.ui("editor.status.save_failed", {"code": error})
		return
	definition.take_over_path(path)
	var loaded := load(path) as EventDefinition
	if loaded != null:
		open_definition(loaded, null)
	_toast(L10n.ui("story.toast.template_created"))

# ── 事件页 / 打开 / 保存 ─────────────────────────────────

func _on_page_selected(index: int) -> void:
	_page_index = index
	_selected_command = null
	_selected_item = {}
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
	var edits := ResourceEdits.new()
	undo.add_do_method(edits, "replace_pages", _definition, pages, selected, weakref(self))
	undo.add_undo_method(edits, "replace_pages", _definition, _definition.pages.duplicate(), _page_index, weakref(self))
	undo.commit_action()

func _apply_pages(definition: EventDefinition, pages: Array, selected: int) -> void:
	definition._replace_pages(pages)
	if definition != _definition:
		return
	_page_index = clampi(selected, 0, maxi(0, pages.size() - 1))
	_selected_command = null
	_refresh_all()

func _on_open_file_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "res://")
	dialog.title = L10n.ui("story.open_button")
	dialog.file_selected.connect(func(path: String) -> void:
		var loaded := load(path) as EventDefinition
		if loaded != null:
			open_definition(loaded, null)
		else:
			_status_label.text = L10n.ui("story.toast.not_event")
		dialog.queue_free()
	)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(760, 520))

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

func _on_undo_pressed() -> void:
	if _live_editing:
		return
	var undo := _undo_redo()
	if undo != null:
		var history := undo.get_history_undo_redo(undo.get_object_history_id(_current_page()))
		if history.has_undo():
			history.undo()

func _on_redo_pressed() -> void:
	if _live_editing:
		return
	var undo := _undo_redo()
	if undo != null:
		var history := undo.get_history_undo_redo(undo.get_object_history_id(_current_page()))
		if history.has_redo():
			history.redo()

func _undo_redo() -> EditorUndoRedoManager:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_editor_undo_redo()

func _show_status() -> void:
	if _definition == null:
		return
	var path := _definition.resource_path
	if path == "":
		_status_label.text = L10n.ui("editor.status.no_path")
	else:
		_status_label.text = L10n.ui("editor.status.resource", {"path": path})

# ── 预览 ─────────────────────────────────────────────────

func _rebuild_preview() -> void:
	if _document == null:
		return
	_preview_label.text = StoryPreview.build(_items, _roster)
	var issues := StoryPreview.collect_issues(_items)
	if Bbcode.has_issues(issues):
		_preview_issues.text = L10n.ui("story.preview.unsupported_hint") + "\n" + Bbcode.describe(issues, true)
	else:
		_preview_issues.text = L10n.ui("story.preview.clean")

# ── 角色花名册 ───────────────────────────────────────────

func _rebuild_roster_list() -> void:
	_clear_children(_roster_list)
	_clear_children(_roster_fields)
	if _roster == null:
		return
	for character in _roster.characters:
		if character == null:
			continue
		_roster_list.add_child(_make_roster_row(character))
	if _roster.characters.is_empty():
		var hint := Label.new()
		hint.text = L10n.ui("story.roster.empty")
		hint.add_theme_font_size_override("font_size", UiFonts.NOTE)
		hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
		_roster_list.add_child(hint)
	_rebuild_roster_fields()

func _make_roster_row(character: StoryCharacter) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(12, 12)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.color = character.color
	row.add_child(chip)
	var button := Button.new()
	button.text = character.label()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.button_pressed = character == _selected_character
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		_selected_character = character
		_rebuild_roster_list()
	)
	row.add_child(button)
	return row

func _rebuild_roster_fields() -> void:
	_clear_children(_roster_fields)
	if _selected_character == null or _roster == null or not _roster.characters.has(_selected_character):
		return
	var character := _selected_character

	_roster_id_edit = LineEdit.new()
	_roster_id_edit.text = character.character_id
	_roster_id_edit.placeholder_text = L10n.ui("story.roster.id")
	_roster_id_edit.text_submitted.connect(func(value: String) -> void:
		if character.character_id == value.strip_edges():
			return
		character.character_id = value.strip_edges()
		_persist_roster()
		_rebuild_roster_list()
	)
	var id_input := _roster_id_edit
	id_input.focus_exited.connect(func():
		id_input.text_submitted.emit(id_input.text)
	)
	_roster_fields.add_child(_roster_id_edit)

	_roster_name_edit = LineEdit.new()
	_roster_name_edit.text = character.display_name
	_roster_name_edit.placeholder_text = L10n.ui("story.roster.name")
	_roster_name_edit.text_submitted.connect(func(value: String) -> void:
		if character.display_name == value:
			return
		character.display_name = value
		_persist_roster()
		_rebuild_roster_list()
		_rebuild_preview()
	)
	var name_input := _roster_name_edit
	name_input.focus_exited.connect(func():
		name_input.text_submitted.emit(name_input.text)
	)
	_roster_fields.add_child(_roster_name_edit)

	var avatar_row := HBoxContainer.new()
	avatar_row.add_theme_constant_override("separation", 3)
	_roster_avatar_edit = LineEdit.new()
	_roster_avatar_edit.text = character.avatar_path
	_roster_avatar_edit.editable = false
	_roster_avatar_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_avatar_edit.tooltip_text = character.avatar_path
	avatar_row.add_child(_roster_avatar_edit)
	var pick := Button.new()
	pick.text = "…"
	pick.tooltip_text = L10n.ui("story.roster.avatar")
	pick.pressed.connect(func() -> void: _open_avatar_dialog(character))
	avatar_row.add_child(pick)
	var clear := Button.new()
	clear.text = "×"
	clear.pressed.connect(func() -> void:
		character.avatar_path = ""
		_persist_roster()
		_rebuild_roster_fields()
	)
	avatar_row.add_child(clear)
	_roster_fields.add_child(avatar_row)

	_roster_color_picker = ColorPickerButton.new()
	_roster_color_picker.color = character.color
	_roster_color_picker.custom_minimum_size = Vector2(0, 24)
	_roster_color_picker.color_changed.connect(func(color: Color) -> void:
		character.color = color
		_roster_save_timer.start()
		_rebuild_preview()
	)
	_roster_fields.add_child(_roster_color_picker)

	_roster_notes_edit = LineEdit.new()
	_roster_notes_edit.text = character.notes
	_roster_notes_edit.placeholder_text = L10n.ui("story.roster.notes")
	_roster_notes_edit.text_submitted.connect(func(value: String) -> void:
		if character.notes == value:
			return
		character.notes = value
		_persist_roster()
	)
	var notes_input := _roster_notes_edit
	notes_input.focus_exited.connect(func():
		notes_input.text_submitted.emit(notes_input.text)
	)
	_roster_fields.add_child(_roster_notes_edit)

	var remove := Button.new()
	remove.text = L10n.ui("story.roster.remove")
	remove.pressed.connect(func() -> void:
		_roster.remove_character(character)
		_selected_character = null
		_persist_roster()
		_rebuild_roster_list()
	)
	_roster_fields.add_child(remove)

func _on_roster_add() -> void:
	if _roster == null:
		_roster = StoryCharacters.new()
	var id := _roster.unique_id("character")
	var character := _roster.add_character(id, L10n.ui("story.roster.default_name"))
	_selected_character = character
	_persist_roster()
	_rebuild_roster_list()

func _open_avatar_dialog(character: StoryCharacter) -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.png;*.jpg;*.jpeg;*.webp;*.svg", "res://")
	dialog.title = L10n.ui("story.roster.avatar")
	dialog.file_selected.connect(func(path: String) -> void:
		character.avatar_path = path
		_persist_roster()
		_rebuild_roster_fields()
		dialog.queue_free()
	)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(720, 480))

func _persist_roster() -> void:
	if _roster_save_timer != null:
		_roster_save_timer.stop()
	if _roster == null:
		return
	var ok := StoryCharacters.save_roster(_roster)
	_status_label.text = L10n.ui("story.roster.saved") if ok else L10n.ui("story.roster.save_failed")

# ── 指令插入菜单 ─────────────────────────────────────────

func _fill_insert_menu() -> void:
	# 找到工具栏上的指令 MenuButton（插入行最后一个 MenuButton 是模板菜单，
	# 指令菜单通过 _build_ui 里保存的引用访问）
	var popup := _insert_menu_popup()
	if popup == null:
		return
	popup.clear()
	_insert_ids.clear()
	var id := 0
	for category in CommandRegistry.categories():
		popup.add_separator(CommandRegistry.category_label(category))
		for type in CommandRegistry.types_in_category(category):
			popup.add_item(CommandRegistry.display_name(type), id)
			_insert_ids[id] = type
			id += 1

var _command_menu_button: MenuButton

func _insert_menu_popup() -> PopupMenu:
	if _command_menu_button == null:
		return null
	return _command_menu_button.get_popup()

func _on_insert_command_pressed(id: int) -> void:
	var type: StringName = _insert_ids.get(id, &"")
	if type == &"" or _document == null:
		return
	var target := _insert_target()
	var command := CommandRegistry.create_command(type)
	_document.insert_command(target["list"], int(target["index"]), command)
	_after_insert(command)

# ── 杂项 ─────────────────────────────────────────────────

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _toast(message: String) -> void:
	if not Engine.is_editor_hint():
		return
	var toaster := EditorInterface.get_editor_toaster()
	if toaster != null:
		toaster.push_toast(message, EditorToaster.SEVERITY_INFO)

func _exit_tree() -> void:
	if _roster_save_timer != null and not _roster_save_timer.is_stopped():
		_persist_roster()
