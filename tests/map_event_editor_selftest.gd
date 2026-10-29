extends Node
## 编辑器内地编功能自测：真实 EditorInterface / 场景树 / UndoRedo。
## 由 plugin.gd 在 RPGEVENTSTUDIO_MAP_SELFTEST=1 时启动：
##   RPGEVENTSTUDIO_MAP_SELFTEST=1 godot --headless --editor --path .

const DEMO_SCENE := "res://addons/rpgeventstudio/samples/scenes/map_events_demo.tscn"

var _checks := 0
var _failures: PackedStringArray = []
var _plugin: EditorPlugin
var _panel: Control
var _root: Node

func start(plugin: EditorPlugin) -> void:
	_plugin = plugin
	L10n.set_editor_locale("zh_CN")
	await get_tree().create_timer(1.2).timeout

	if not EditorInterface.has_method("open_scene_from_path"):
		_fail("当前 Godot 没有 EditorInterface.open_scene_from_path")
		_finish()
		return
	EditorInterface.open_scene_from_path(DEMO_SCENE)
	for _i in 30:
		await get_tree().process_frame
		_root = EditorInterface.get_edited_scene_root()
		if _root != null and _root.scene_file_path == DEMO_SCENE:
			break
		await get_tree().create_timer(0.1).timeout
	_check(_root != null and _root.scene_file_path == DEMO_SCENE, "能在编辑器打开地图事件示例场景")
	if _root == null:
		_finish()
		return

	var events := MapEvent2D.collect_in(_root)
	_check(events.size() == 7, "示例场景有 7 个地图事件（实际 %d）" % events.size())

	_panel = _plugin.get("_map_panel")
	_check(_panel != null, "编辑器创建了地图事件面板")
	if _panel == null:
		_finish()
		return
	_panel.call("refresh")
	await get_tree().process_frame
	var tree: Tree = _panel.get("_tree")
	_check(tree != null and tree.get_root() != null, "地图事件总览已填充")
	if tree == null or tree.get_root() == null:
		_finish()
		return

	var trigger_row := _tree_item_for(tree, _root.get_node("Trigger_Region"))
	_check(trigger_row != null and trigger_row.get_text(0).contains("(650, 390)"), "总览显示触发区位置")
	_check(trigger_row != null and trigger_row.get_text(0).contains(L10n.ui("map.trigger.region_enter")), "总览显示触发方式")
	_check(trigger_row != null and trigger_row.get_text(0).contains("区域触发示例"), "总览显示关联事件")

	var unlinked := _tree_item_for(tree, _root.get_node("Inspect_Unlinked"))
	_check(unlinked != null, "总览能找到未关联对象")
	if unlinked != null:
		_check(unlinked.get_text(0).contains("(820, 270)"), "总览显示场景位置（实际：%s）" % unlinked.get_text(0))
		_check(unlinked.get_text(0).contains(L10n.ui("map.status.missing")), "未关联对象显示「未关联」（实际：%s）" % unlinked.get_text(0))

	# 选中对象 → 面板同步；打开事件 → 事件编辑器
	var trigger: MapEvent2D = _root.get_node("Trigger_Region")
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(trigger)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_panel.get("_selected_node") == trigger, "选中地图事件后面板同步")
	var details: Label = _panel.get("_details")
	_check(details != null and details.text.contains(L10n.ui("map.layer.same")), "详情显示显示层级")

	var opened: Array = [null]
	_panel.event_activated.connect(func(definition: EventDefinition) -> void:
		opened[0] = definition
	)
	_panel.call("_on_item_activated")
	await get_tree().process_frame
	_check(opened[0] == trigger.resolved_event(), "双击总览行打开关联事件")
	var editor_panel: Control = _plugin.get("_panel")
	_check(editor_panel != null and editor_panel.get("_definition") == trigger.resolved_event(), "事件编辑器切换到该事件")

	# 从面板信号放置对象（走插件 UndoRedo 路径）
	var before := MapEvent2D.collect_in(_root).size()
	_panel.place_requested.emit(MapEvent2D.Kind.CHEST)
	await get_tree().process_frame
	await get_tree().process_frame
	var placed: MapEvent2D = null
	var selected_nodes := selection.get_selected_nodes()
	if not selected_nodes.is_empty() and selected_nodes[0] is MapEvent2D:
		placed = selected_nodes[0]
	_check(placed != null, "面板放置按钮生成地图事件并选中")
	_check(MapEvent2D.collect_in(_root).size() == before + 1, "放置后场景事件数 +1")
	if placed != null:
		_check(placed.get_parent() == _root, "新事件挂在场景根节点下")
		_check(placed.owner == _root, "新事件 owner 设为场景根，能随场景保存")
		_check(placed.trigger_mode == MapEvent2D.TriggerMode.INTERACT, "宝箱默认使用玩家交互")
		_check(placed.z_index == 0, "默认同层 z_index = 0")

	# Undo / Redo
	var undo := EditorInterface.get_editor_undo_redo()
	_check(undo != null, "能取得编辑器 UndoRedo")
	if undo != null:
		var history_id := undo.get_object_history_id(_root)
		var history := undo.get_history_undo_redo(history_id)
		_check(history != null, "场景有对应的 UndoRedo 历史")
		if history != null:
			history.undo()
			await get_tree().process_frame
			_check(placed != null and placed.get_parent() == null, "撤销放置后对象离开场景")
			history.redo()
			await get_tree().process_frame
			_check(placed != null and placed.get_parent() == _root, "重做放置后对象回到场景")
			_check(placed.owner == _root, "重做后 owner 仍正确")

	# 失效引用
	var invalid := MapEvent2D.new()
	invalid.name = "InvalidRefProbe"
	invalid.event_path = "res://does_not_exist_map_event.tres"
	_root.add_child(invalid)
	invalid.owner = _root
	_panel.call("refresh")
	await get_tree().process_frame
	tree = _panel.get("_tree")
	var invalid_item := _tree_item_for(tree, invalid)
	_check(invalid_item != null and invalid_item.get_text(0).contains(L10n.ui("map.status.invalid")), "总览识别失效引用")
	_root.remove_child(invalid)
	invalid.queue_free()

	# 定位按钮
	selection.clear()
	selection.add_node(trigger)
	await get_tree().process_frame
	_panel.call("_on_focus")
	await get_tree().process_frame
	_check(selection.get_selected_nodes().has(trigger), "定位按钮重新选中场景对象")

	_finish()

func _tree_item_for(tree: Tree, node: Node) -> TreeItem:
	if tree == null or tree.get_root() == null:
		return null
	return _find_item(tree.get_root(), node)

func _find_item(item: TreeItem, node: Node) -> TreeItem:
	if item.get_metadata(0) == node:
		return item
	var child := item.get_first_child()
	while child != null:
		var found := _find_item(child, node)
		if found != null:
			return found
		child = child.get_next()
	return null

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	print("  ✗ ", message)

func _finish() -> void:
	print("")
	print("[MAP_SELFTEST] 检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
