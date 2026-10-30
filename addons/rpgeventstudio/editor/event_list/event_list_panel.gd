@tool
class_name EventListPanel
extends VBoxContainer
## 事件列表：把工程里的事件与关卡图列出来，搜索 + 双击直接打开。
## 解决「事件一多就找不到刚才做的那个」。

signal event_activated(definition: EventDefinition)
signal graph_activated(graph: LevelGraph)

var _search: LineEdit
var _tree: Tree
var _status: Label
var _details: RichTextLabel
var _only_unreferenced: CheckBox

var _events: Array[EventDefinition] = []
var _graphs: Array[LevelGraph] = []
var _refs: Dictionary = {}

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	add_theme_constant_override("separation", 4)

	var header := HBoxContainer.new()
	add_child(header)

	_search = LineEdit.new()
	_search.placeholder_text = L10n.ui("eventlist.search")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void:
		_fill()
	)
	header.add_child(_search)

	var refresh_button := Button.new()
	refresh_button.text = L10n.ui("eventlist.refresh")
	refresh_button.pressed.connect(refresh)
	header.add_child(refresh_button)

	_only_unreferenced = CheckBox.new()
	_only_unreferenced.text = L10n.ui("eventlist.only_unreferenced")
	_only_unreferenced.toggled.connect(func(_pressed: bool) -> void:
		_fill()
	)
	add_child(_only_unreferenced)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 1
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(0, 240)
	_tree.item_activated.connect(_on_item_activated)
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_collapsed.connect(func(_item: TreeItem) -> void:
		_tree.queue_redraw()
	)
	add_child(_tree)

	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = false
	_details.scroll_active = true
	_details.custom_minimum_size = Vector2(0, 110)
	_details.add_theme_font_size_override("normal_font_size", UiFonts.NOTE)
	_details.text = L10n.ui("eventlist.details.hint")
	add_child(_details)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_status.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	add_child(_status)

# ── 扫描 ─────────────────────────────────────────────────

func refresh() -> void:
	_events.clear()
	_graphs.clear()
	_scan("res://")
	var reference_data := EventReferences.scan()
	_refs = reference_data.get("by_path", {})

	_events.sort_custom(func(a: EventDefinition, b: EventDefinition) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	_graphs.sort_custom(func(a: LevelGraph, b: LevelGraph) -> bool:
		return String(a.graph_id).naturalnocasecmp_to(String(b.graph_id)) < 0
	)
	_fill()

func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if entry != ".godot":
				_scan(path)
		elif entry.ends_with(".tres"):
			_collect(path)
		entry = dir.get_next()
	dir.list_dir_end()

func _collect(path: String) -> void:
	# 先读文件头判断类型，避免把工程里所有 .tres 都实例化一遍
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var head := file.get_buffer(240).get_string_from_utf8()
	file.close()
	if not (head.contains("EventDefinition") or head.contains("LevelGraph")):
		return
	var resource := load(path)
	if resource is EventDefinition:
		_events.append(resource)
	elif resource is LevelGraph:
		_graphs.append(resource)

# ── 列表 ─────────────────────────────────────────────────

func _fill() -> void:
	if _tree == null:
		return
	_tree.clear()
	var root := _tree.create_item()
	var filter := _search.text.strip_edges().to_lower() if _search != null else ""

	var events_item := _tree.create_item(root)
	events_item.set_text(0, "%s（%d）" % [L10n.ui("eventlist.events"), _events.size()])
	events_item.set_selectable(0, false)

	var shown_events := 0
	for definition in _events:
		if not _matches(filter, definition.display_name, String(definition.event_id), definition.resource_path):
			continue
		if _only_unreferenced != null and _only_unreferenced.button_pressed and _has_scene_reference(definition.resource_path):
			continue
		var item := _tree.create_item(events_item)
		var label := definition.display_name
		if not _has_scene_reference(definition.resource_path):
			label += "  " + L10n.ui("eventlist.unmounted_mark")
			item.set_custom_color(0, Color(0.85, 0.7, 0.5))
			item.set_tooltip_text(0, "%s\n%s" % [definition.resource_path, L10n.ui("eventlist.refs.none")])
		else:
			item.set_tooltip_text(0, definition.resource_path)
		item.set_text(0, label)
		item.set_metadata(0, definition)
		shown_events += 1

	var graphs_item := _tree.create_item(root)
	graphs_item.set_text(0, "%s（%d）" % [L10n.ui("eventlist.graphs"), _graphs.size()])
	graphs_item.set_selectable(0, false)

	var shown_graphs := 0
	for graph in _graphs:
		if not _matches(filter, String(graph.graph_id), String(graph.level_id), graph.resource_path):
			continue
		if _only_unreferenced != null and _only_unreferenced.button_pressed and _has_scene_reference(graph.resource_path):
			continue
		var item := _tree.create_item(graphs_item)
		item.set_text(0, String(graph.graph_id))
		item.set_tooltip_text(0, graph.resource_path)
		item.set_metadata(0, graph)
		shown_graphs += 1

	events_item.collapsed = false
	graphs_item.collapsed = false
	_status.text = L10n.ui("eventlist.status", {
		"events": shown_events,
		"graphs": shown_graphs,
	})

func _matches(filter: String, name: String, extra: String, path: String) -> bool:
	if filter == "":
		return true
	return name.to_lower().contains(filter) or extra.to_lower().contains(filter) or path.to_lower().contains(filter)

func _has_scene_reference(path: String) -> bool:
	for entry in _refs.get(path, []):
		if str(entry.get("kind", "")) == "scene":
			return true
	return false

func _on_item_selected() -> void:
	if _details == null:
		return
	var item := _tree.get_selected()
	if item == null:
		_details.text = L10n.ui("eventlist.details.hint")
		return
	var value: Variant = item.get_metadata(0)
	if value == null:
		_details.text = L10n.ui("eventlist.details.hint")
		return
	var path := ""
	if value is EventDefinition:
		path = value.resource_path
	elif value is LevelGraph:
		path = value.resource_path

	var scene_refs: Array = []
	var graph_refs: Array = []
	for entry in _refs.get(path, []):
		if str(entry.get("kind", "")) == "scene":
			scene_refs.append(entry)
		else:
			graph_refs.append(entry)

	var lines: PackedStringArray = []
	if scene_refs.is_empty():
		lines.append(L10n.ui("eventlist.refs.none"))
		lines.append("[color=#8a8f99]%s[/color]" % L10n.ui("eventlist.refs.none_hint"))
	else:
		lines.append(L10n.ui("eventlist.refs.scene", {"count": scene_refs.size()}))
		for entry in scene_refs:
			lines.append("  • %s › %s" % [str(entry["source"]).get_file(), str(entry["node"])])
	if not graph_refs.is_empty():
		lines.append(L10n.ui("eventlist.refs.graph", {"count": graph_refs.size()}))
		for entry in graph_refs:
			lines.append("  • %s" % str(entry["source"]).get_file())
	_details.text = "\n".join(lines)

func _on_item_activated() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var value: Variant = item.get_metadata(0)
	if value is EventDefinition:
		event_activated.emit(value)
	elif value is LevelGraph:
		graph_activated.emit(value)
