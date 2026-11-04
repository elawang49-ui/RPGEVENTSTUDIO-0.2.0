@tool
class_name StateLibraryDialog
extends AcceptDialog
## 状态库：管理「内部标识 → 显示名称」的映射。
## 改显示名称不影响任何事件/图数据（它们存的始终是内部标识）。

signal state_saved(key: String)

const TYPES := ["bool", "int", "float", "string"]

var _catalog: StateCatalog
var _bulk_dialog: StateBulkRegisterDialog
var _search: LineEdit
var _list: ItemList
var _key_value: Label
var _display_edit: LineEdit
var _type_option: OptionButton
var _default_edit: LineEdit
var _category_edit: LineEdit
var _description_edit: TextEdit
var _hint: Label
var _current: StateDefinition
var _building := false
var _save_timer: Timer
var _pending_saved_key := ""

func _ready() -> void:
	title = L10n.ui("state.library.title")
	min_size = Vector2i(780, 520)
	_build()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.35
	_save_timer.timeout.connect(_flush)
	add_child(_save_timer)
	confirmed.connect(_flush)
	canceled.connect(_flush)
	close_requested.connect(_flush)

func open_catalog() -> void:
	_catalog = StateCatalogStore.ensure_file()
	_rebuild()
	popup_centered(Vector2i(780, 520))

## seed_key 用于把「未登记」的旧状态一次性登记进来。
func open_new(seed_key: String = "") -> void:
	open_catalog()
	new_state(seed_key)

func new_state(seed_key: String = "") -> void:
	if _catalog == null:
		_catalog = StateCatalogStore.ensure_file()
	var key := seed_key.strip_edges()
	if key == "":
		key = "Global.New.State"
	var base := key
	var index := 2
	while _catalog.find(key) != null:
		key = "%s_%d" % [base, index]
		index += 1

	var definition := _catalog.ensure(key, "bool", false, "剧情")
	if seed_key != "":
		definition.display_name = seed_key
	else:
		definition.display_name = L10n.ui("state.library.default_name")
	_building = true
	_flush()
	_building = false
	_rebuild()
	_select(key)
	state_saved.emit(key)

# ── 界面 ─────────────────────────────────────────────────

func _build() -> void:
	var root := HSplitContainer.new()
	root.custom_minimum_size = Vector2(760, 440)
	add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	root.add_child(left)

	_search = LineEdit.new()
	_search.placeholder_text = L10n.ui("state.library.search")
	_search.text_changed.connect(func(_text: String) -> void:
		_rebuild()
	)
	left.add_child(_search)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(280, 0)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_item_selected)
	left.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)

	_key_value = Label.new()
	_key_value.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_key_value.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
	right.add_child(_key_value)

	right.add_child(_label_for("state.library.display"))
	_display_edit = LineEdit.new()
	_display_edit.text_changed.connect(func(text: String) -> void:
		if _building or _current == null:
			return
		_current.display_name = text
		_queue_flush()
		_refresh_item_text(_current)
		_pending_saved_key = _current.key
	)
	right.add_child(_display_edit)

	var type_row := HBoxContainer.new()
	right.add_child(type_row)
	type_row.add_child(_label_for("state.library.type"))
	_type_option = OptionButton.new()
	for type in TYPES:
		_type_option.add_item(L10n.ui("state.type." + type))
	_type_option.item_selected.connect(func(index: int) -> void:
		if _building or _current == null:
			return
		_current.type = TYPES[index]
		_queue_flush()
	)
	type_row.add_child(_type_option)

	right.add_child(_label_for("state.library.default"))
	_default_edit = LineEdit.new()
	_default_edit.text_changed.connect(func(text: String) -> void:
		if _building or _current == null:
			return
		_current.default_value = ValueParser.parse(text)
		_queue_flush()
	)
	right.add_child(_default_edit)

	right.add_child(_label_for("state.library.category"))
	_category_edit = LineEdit.new()
	_category_edit.text_changed.connect(func(text: String) -> void:
		if _building or _current == null:
			return
		_current.category = text
		_queue_flush()
		_refresh_item_text(_current)
	)
	right.add_child(_category_edit)

	right.add_child(_label_for("state.library.description"))
	_description_edit = TextEdit.new()
	_description_edit.custom_minimum_size = Vector2(0, 90)
	_description_edit.text_changed.connect(func() -> void:
		if _building or _current == null:
			return
		_current.description = _description_edit.text
		_queue_flush()
	)
	right.add_child(_description_edit)

	_hint = Label.new()
	_hint.text = L10n.ui("state.library.hint")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_hint.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	right.add_child(_hint)

	var buttons := HBoxContainer.new()
	right.add_child(buttons)

	var add := Button.new()
	add.text = L10n.ui("state.library.new")
	add.pressed.connect(func() -> void:
		new_state("")
	)
	buttons.add_child(add)

	var remove := Button.new()
	remove.text = L10n.ui("state.library.delete")
	remove.pressed.connect(_on_delete)
	buttons.add_child(remove)

	var bulk := Button.new()
	bulk.text = L10n.ui("state.library.bulk")
	bulk.tooltip_text = L10n.ui("state.library.bulk_tip")
	bulk.pressed.connect(_on_bulk_pressed)
	buttons.add_child(bulk)

## 打开批量登记：扫描全工程未登记的状态，勾选后一次性写入总表。
func _on_bulk_pressed() -> void:
	if _bulk_dialog == null:
		_bulk_dialog = StateBulkRegisterDialog.new()
		add_child(_bulk_dialog)
		_bulk_dialog.registered.connect(_on_bulk_registered)
	_bulk_dialog.open_dialog()

func _on_bulk_registered(_keys: PackedStringArray) -> void:
	StateCatalogStore.reset_cache()
	_catalog = StateCatalogStore.catalog()
	_rebuild()

func _label_for(key: String) -> Label:
	var label := Label.new()
	label.text = L10n.ui(key)
	label.add_theme_font_size_override("font_size", UiFonts.NOTE)
	label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	return label

# ── 列表 ─────────────────────────────────────────────────

func _rebuild() -> void:
	if _list == null:
		return
	_list.clear()
	if _catalog == null:
		return
	var filter := _search.text.strip_edges().to_lower() if _search != null else ""
	for definition in _catalog.definitions:
		if definition == null or definition.key == "":
			continue
		if filter != "" and not (definition.label().to_lower().contains(filter) or definition.key.to_lower().contains(filter) or definition.category.to_lower().contains(filter)):
			continue
		_list.add_item(_item_text(definition))
		_list.set_item_metadata(_list.get_item_count() - 1, definition.key)
		if _current != null and _current.key == definition.key:
			_list.select(_list.get_item_count() - 1)

func _item_text(definition: StateDefinition) -> String:
	var suffix := " · " + definition.category if definition.category != "" else ""
	return definition.label() + suffix

func _refresh_item_text(definition: StateDefinition) -> void:
	for index in _list.get_item_count():
		if str(_list.get_item_metadata(index)) == definition.key:
			_list.set_item_text(index, _item_text(definition))
			return

func _select(key: String) -> void:
	for index in _list.get_item_count():
		if str(_list.get_item_metadata(index)) == key:
			_list.select(index)
			_on_item_selected(index)
			return

func _on_item_selected(index: int) -> void:
	if _catalog == null:
		return
	var key := str(_list.get_item_metadata(index))
	var definition := _catalog.find(key)
	if definition == null:
		return
	_current = definition
	_building = true
	_key_value.text = L10n.ui("state.library.key_value", {"key": definition.key})
	_display_edit.text = definition.display_name
	_type_option.selected = max(0, TYPES.find(definition.type))
	_default_edit.text = str(definition.default_value)
	_category_edit.text = definition.category
	_description_edit.text = definition.description
	_building = false

func _on_delete() -> void:
	if _catalog == null or _current == null:
		return
	_catalog.remove(_current.key)
	_flush()
	_current = null
	_building = true
	_display_edit.text = ""
	_key_value.text = ""
	_description_edit.text = ""
	_building = false
	_rebuild()

# ── 保存 ─────────────────────────────────────────────────

func _queue_flush() -> void:
	if _save_timer != null:
		_save_timer.start()

func _exit_tree() -> void:
	# Persist pending input without rebuilding a panel that is leaving the tree.
	_pending_saved_key = ""
	if _save_timer != null and not _save_timer.is_stopped():
		_flush()

func _flush() -> void:
	if _save_timer != null:
		_save_timer.stop()
	if _catalog == null:
		return
	var error := StateCatalogStore.save()
	if error != OK:
		push_warning("[RPGEventStudio] 状态库保存失败：%d" % error)

	elif _pending_saved_key != "":
		var key := _pending_saved_key
		_pending_saved_key = ""
		state_saved.emit(key)
