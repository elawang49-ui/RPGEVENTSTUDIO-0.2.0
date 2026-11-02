@tool
class_name MapEventPanel
extends VBoxContainer
## 地图事件总览：当前场景里的 MapEvent2D、位置、触发方式、关联事件与失效引用。
## 双击事件行直接打开事件编辑器；选中对象后可在 2D 视图里直接拖动。

signal event_activated(definition: EventDefinition)
signal place_requested(kind: int)

const REFRESH_INTERVAL := 0.6

var _place_menu: MenuButton
var _refresh_button: Button
var _tree: Tree
var _details: Label
var _focus_button: Button
var _open_button: Button
var _status: Label

var _selected_node: MapEvent2D
var _items_by_node: Dictionary = {}
var _signature := ""
var _refresh_clock := 0.0
var _wide_columns := true
## 截图/测试用：非编辑器环境注入场景根，避免依赖 EditorInterface。
var scene_root_override: Node = null

func _ready() -> void:
	_build()
	set_process(true)
	refresh()

func _build() -> void:
	add_theme_constant_override("separation", 4)

	var header := HBoxContainer.new()
	add_child(header)

	_place_menu = MenuButton.new()
	_place_menu.text = L10n.ui("map.place")
	_place_menu.tooltip_text = L10n.ui("map.place")
	var popup := _place_menu.get_popup()
	for kind in 6:
		popup.add_item(kind_label(kind), kind)
	popup.id_pressed.connect(func(id: int) -> void:
		place_requested.emit(id)
	)
	header.add_child(_place_menu)

	_refresh_button = Button.new()
	_refresh_button.text = L10n.ui("map.button.refresh")
	_refresh_button.pressed.connect(refresh)
	header.add_child(_refresh_button)

	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_details.max_lines_visible = 5
	_details.custom_minimum_size = Vector2(0, 54)
	_details.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_details.add_theme_color_override("font_color", Color(0.80, 0.84, 0.90))
	_details.text = L10n.ui("map.details.hint")
	add_child(_details)

	var actions := HBoxContainer.new()
	add_child(actions)
	_focus_button = Button.new()
	_focus_button.text = L10n.ui("map.button.focus")
	_focus_button.tooltip_text = L10n.ui("map.hint.focus")
	_focus_button.disabled = true
	_focus_button.pressed.connect(_on_focus)
	actions.add_child(_focus_button)

	_open_button = Button.new()
	_open_button.text = L10n.ui("map.button.open")
	_open_button.disabled = true
	_open_button.pressed.connect(_on_open)
	actions.add_child(_open_button)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_status.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	add_child(_status)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 2
	_tree.column_titles_visible = true
	_tree.set_column_title(0, L10n.ui("map.col.event"))
	_tree.set_column_title(1, L10n.ui("map.col.trigger"))
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 72)
	_tree.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_tree.custom_minimum_size = Vector2(0, 140)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	add_child(_tree)
	resized.connect(_apply_columns)
	call_deferred("_apply_columns")

## 窄 dock 只显示「名称」一列，触发方式/位置/事件放进详情与 tooltip；
## 全宽主屏标签页才启用第二列，避免列被裁切。
func _apply_columns() -> void:
	if _tree == null:
		return
	var wide := size.x >= 360.0
	if wide == _wide_columns and _tree.columns == (2 if wide else 1):
		return
	_wide_columns = wide
	_tree.columns = 2 if wide else 1
	_tree.column_titles_visible = true
	_tree.set_column_title(0, L10n.ui("map.col.event"))
	_tree.set_column_expand(0, true)
	if wide:
		_tree.set_column_title(1, L10n.ui("map.col.trigger"))
		_tree.set_column_expand(1, false)
		_tree.set_column_custom_minimum_width(1, 72)
	refresh()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or not is_visible_in_tree():
		return
	_refresh_clock += delta
	if _refresh_clock < REFRESH_INTERVAL:
		return
	_refresh_clock = 0.0
	if _scan_signature() != _signature:
		refresh()

# ── 总览 ─────────────────────────────────────────────────

func refresh() -> void:
	if _tree == null:
		return
	var selected_path := ""
	if _selected_node != null and is_instance_valid(_selected_node):
		selected_path = str(_selected_node.get_path())
	_tree.columns = 2 if _wide_columns else 1
	var wide := _tree.columns > 1
	_tree.clear()
	_items_by_node.clear()

	var root := _scene_root()
	if root == null:
		_selected_node = null
		_details.text = L10n.ui("map.details.hint")
		_focus_button.disabled = true
		_open_button.disabled = true
		_status.text = L10n.ui("map.status.no_scene")
		_signature = "<no-scene>"
		return

	var events := MapEvent2D.collect_in(root)
	events.sort_custom(func(a: MapEvent2D, b: MapEvent2D) -> bool:
		if not is_equal_approx(a.position.y, b.position.y):
			return a.position.y < b.position.y
		if not is_equal_approx(a.position.x, b.position.x):
			return a.position.x < b.position.x
		return String(a.name) < String(b.name)
	)

	var tree_root := _tree.create_item()
	var select_item: TreeItem = null
	for node in events:
		var item := _tree.create_item(tree_root)
		var status := node.status_text()
		var event_text := node.event_display_name() if status == "" else status
		var marker := "⚠ " if status != "" else "● "
		item.set_text(0, marker + String(node.name))
		if wide:
			item.set_text(1, node.trigger_label())
		var tooltip := "%s\n(%d, %d)\n%s · %s\n%s" % [
			str(node.get_path()), int(node.global_position.x), int(node.global_position.y),
			node.kind_label(), node.trigger_label(), event_text,
		]
		var event_path := node.event_resource_path()
		if status != "":
			tooltip += "\n" + status
		if event_path != "":
			tooltip += "\n" + event_path
		item.set_tooltip_text(0, tooltip)
		if wide:
			item.set_tooltip_text(1, tooltip)
		item.set_custom_color(0, Color(0.98, 0.65, 0.38) if status != "" else Color(0.84, 0.87, 0.93))
		if wide:
			item.set_custom_color(1, Color(0.70, 0.75, 0.82))
		item.set_metadata(0, node)
		_items_by_node[node] = item
		if selected_path != "" and str(node.get_path()) == selected_path:
			select_item = item

	if events.is_empty():
		_status.text = L10n.ui("map.status.empty")
	else:
		_status.text = L10n.ui("map.status.count", {"count": events.size()})

	if select_item != null:
		select_item.select(0)
		_selected_node = select_item.get_metadata(0)
	else:
		_selected_node = null
	_show_details(_selected_node)
	_signature = _scan_signature()

func _scene_root() -> Node:
	if scene_root_override != null:
		return scene_root_override
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_edited_scene_root()

func _scan_signature() -> String:
	var root := _scene_root()
	if root == null:
		return "<no-scene>"
	var parts: PackedStringArray = []
	for node in MapEvent2D.collect_in(root):
		parts.append("%s|%s|%d|%d|%s|%s" % [
			str(node.get_path()),
			str(node.global_position),
			node.trigger_mode,
			node.layer_mode,
			node.event_resource_path(),
			node.status_text(),
		])
	return "\n".join(parts)

# ── 选择 / 操作 ──────────────────────────────────────────

func on_selection_changed(nodes: Array) -> void:
	var found: MapEvent2D = null
	for node in nodes:
		if node is MapEvent2D:
			found = node
			break
	if found == null:
		_selected_node = null
		_show_details(null)
		return
	_selected_node = found
	var item: TreeItem = _items_by_node.get(found, null)
	if item != null:
		item.select(0)
	_show_details(found)

func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var node = item.get_metadata(0)
	if node is MapEvent2D:
		_selected_node = node
		_show_details(node)

func _on_item_activated() -> void:
	_on_open()

func _show_details(node: MapEvent2D) -> void:
	if node == null or not is_instance_valid(node):
		_details.text = L10n.ui("map.details.hint")
		_focus_button.disabled = true
		_open_button.disabled = true
		return
	var lines: PackedStringArray = []
	var status := node.status_text()
	if status != "":
		lines.append("⚠ " + status)
	lines.append(L10n.ui("map.details.kind", {"kind": node.kind_label()}))
	lines.append(L10n.ui("map.details.trigger", {"trigger": node.trigger_label()}))
	lines.append(L10n.ui("map.details.position", {
		"pos": "(%d, %d)" % [int(node.global_position.x), int(node.global_position.y)],
	}))
	lines.append(L10n.ui("map.details.event", {"event": node.event_display_name()}))
	_details.text = "\n".join(lines)
	_details.tooltip_text = "%s\n%s\n%s" % [
		str(node.get_path()),
		L10n.ui("map.details.layer", {"layer": node.layer_label()}),
		status,
	]
	_focus_button.disabled = false
	_open_button.disabled = node.resolved_event() == null

func _on_focus() -> void:
	if _selected_node == null or not is_instance_valid(_selected_node):
		return
	var selection := EditorInterface.get_selection()
	if selection == null:
		return
	selection.clear()
	selection.add_node(_selected_node)
	if EditorInterface.has_method("edit_node"):
		EditorInterface.edit_node(_selected_node)

func _on_open() -> void:
	if _selected_node == null or not is_instance_valid(_selected_node):
		return
	var definition := _selected_node.resolved_event()
	if definition != null:
		event_activated.emit(definition)
	else:
		_status.text = _selected_node.status_text()

# ── 供外部生成菜单 / 测试 ────────────────────────────────

static func kind_label(kind: int) -> String:
	var keys := [
		"map.kind.npc", "map.kind.inspect", "map.kind.chest",
		"map.kind.door", "map.kind.mechanism", "map.kind.trigger",
	]
	return L10n.ui(keys[clampi(kind, 0, keys.size() - 1)])
