@tool
class_name SceneObjectPicker
extends ConfirmationDialog
## 场景对象选择器：列出当前编辑场景里的节点，选中后返回「相对场景根的路径 + 场景文件」。
## 同名节点靠第二列完整路径区分。

signal picked(node_path: String, scene_path: String)

var _scene_root: Node
var _tree: Tree
var _search: LineEdit
var _status: Label

func _ready() -> void:
	title = L10n.ui("picker.title")
	min_size = Vector2i(720, 520)
	confirmed.connect(_on_confirm)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(700, 440)
	add_child(root)

	_search = LineEdit.new()
	_search.placeholder_text = L10n.ui("picker.search")
	_search.text_changed.connect(func(_text: String) -> void:
		_fill()
	)
	root.add_child(_search)

	_tree = Tree.new()
	_tree.hide_root = false
	_tree.columns = 2
	_tree.set_column_title(0, L10n.ui("picker.column_name"))
	_tree.set_column_title(1, L10n.ui("picker.column_path"))
	_tree.set_column_expand(1, true)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tree)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	root.add_child(_status)

func open_for(scene_root: Node, current_path: String = "") -> void:
	_scene_root = scene_root
	_fill()
	if current_path != "":
		select_path(current_path)
	popup_centered(Vector2i(720, 520))

func select_path(node_path: String) -> bool:
	var root := _tree.get_root()
	if root == null:
		return false
	return _select_recursive(root, node_path)

func _select_recursive(item: TreeItem, node_path: String) -> bool:
	if str(item.get_metadata(0)) == node_path:
		item.select(0)
		return true
	var child := item.get_first_child()
	while child != null:
		if _select_recursive(child, node_path):
			return true
		child = child.get_next()
	return false

func _fill() -> void:
	if _tree == null:
		return
	_tree.clear()
	if _scene_root == null:
		_status.text = L10n.ui("picker.no_scene")
		return
	_status.text = "%s：%s" % [L10n.ui("picker.scene"), String(_scene_root.scene_file_path)]
	var filter := _search.text.strip_edges().to_lower()
	var root_item := _tree.create_item()
	root_item.set_text(0, _scene_root.name)
	root_item.set_text(1, ".")
	root_item.set_metadata(0, ".")
	_add_children(_scene_root, root_item, "", filter)
	root_item.set_collapsed(false)

func _add_children(node: Node, parent_item: TreeItem, base: String, filter: String) -> void:
	for child in node.get_children():
		if child.owner != null and child.owner != _scene_root:
			continue
		var path := child.name if base == "" else base + "/" + String(child.name)
		var item := _tree.create_item(parent_item)
		item.set_text(0, String(child.name))
		item.set_text(1, path)
		item.set_tooltip_text(0, path)
		item.set_metadata(0, path)
		if filter != "" and not (String(child.name).to_lower().contains(filter) or path.to_lower().contains(filter)):
			item.set_custom_color(0, Color(0.55, 0.57, 0.62))
		_add_children(child, item, path, filter)

func _on_confirm() -> void:
	var item := _tree.get_selected()
	if item == null or _scene_root == null:
		return
	var path := str(item.get_metadata(0))
	if path == "" or path == ".":
		return
	picked.emit(path, String(_scene_root.scene_file_path))
