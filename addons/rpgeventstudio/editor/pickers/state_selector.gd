@tool
class_name StateSelector
extends VBoxContainer
## 状态选择器：显示「创作者看得懂的名字」，存的是稳定的内部标识。
## 未登记的状态会标成「⚠ 未登记」，点右侧「+」即可登记并改名。

signal state_changed(key: String)

var key: String = ""
var show_internal := false

var _option: OptionButton
var _new_button: Button
var _key_label: Label
var _dialog: StateLibraryDialog
var _loading := false

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)

	_option = OptionButton.new()
	_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option.tooltip_text = L10n.ui("state.selector.tooltip")
	_option.item_selected.connect(_on_selected)
	row.add_child(_option)

	_new_button = Button.new()
	_new_button.text = "+"
	_new_button.tooltip_text = L10n.ui("state.selector.new")
	_new_button.pressed.connect(_on_new_pressed)
	row.add_child(_new_button)

	_key_label = Label.new()
	_key_label.add_theme_font_size_override("font_size", 10)
	_key_label.add_theme_color_override("font_color", Color(0.55, 0.7, 0.9))
	_key_label.visible = show_internal
	add_child(_key_label)

func refresh() -> void:
	if _option == null:
		return
	_loading = true
	_option.clear()
	var catalog := StateCatalogStore.catalog()
	for group in catalog.grouped():
		_option.add_separator(str(group["category"]))
		for item in group["items"]:
			var definition: StateDefinition = item
			var text: String = definition.label()
			if show_internal:
				text += "（%s）" % definition.key
			_option.add_item(text)
			_option.set_item_metadata(_option.get_item_count() - 1, definition.key)

	if key != "" and not StateCatalogStore.is_known(key):
		_option.add_separator()
		_option.add_item(L10n.ui("state.selector.unknown", {"key": key}))
		_option.set_item_metadata(_option.get_item_count() - 1, key)
	_loading = false
	_sync()

func set_key(value: String) -> void:
	key = value
	refresh()

func set_show_internal(value: bool) -> void:
	show_internal = value
	if _key_label != null:
		_key_label.visible = value
	refresh()

func _sync() -> void:
	if _key_label != null:
		_key_label.text = key
	if _option == null:
		return
	if key == "":
		_option.select(-1)
		return
	for index in _option.get_item_count():
		if str(_option.get_item_metadata(index)) == key:
			_option.select(index)
			return
	_option.select(-1)

func _on_selected(index: int) -> void:
	if _loading:
		return
	var value: Variant = _option.get_item_metadata(index)
	if not (value is String) or String(value) == "":
		return
	key = String(value)
	_sync()
	state_changed.emit(key)

func _on_new_pressed() -> void:
	if _dialog == null:
		_dialog = StateLibraryDialog.new()
		add_child(_dialog)
		_dialog.state_saved.connect(_on_dialog_saved)
	_dialog.open_new(key if key != "" and not StateCatalogStore.is_known(key) else "")

func _on_dialog_saved(saved_key: String) -> void:
	refresh()
	if saved_key != "":
		key = saved_key
		_sync()
		state_changed.emit(key)
