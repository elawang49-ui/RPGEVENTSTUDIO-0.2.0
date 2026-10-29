extends SceneTree
## 事件列表冒烟测试：
##   godot --headless --path . --script res://tests/event_list_smoke.gd

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Node.new()
	host.name = "EventListHost"
	root.add_child(host)

	var panel: Control = load("res://addons/rpgeventstudio/editor/event_list/event_list_panel.gd").new()
	host.add_child(panel)
	await process_frame
	panel.call("refresh")
	await process_frame

	var events: Array = panel.get("_events")
	var graphs: Array = panel.get("_graphs")
	_check(events.size() >= 6, "应扫描到演示事件（实际 %d）" % events.size())
	_check(graphs.size() >= 1, "应扫描到演示关卡图（实际 %d）" % graphs.size())
	_check(String(panel.get("_status").text).contains(str(events.size())), "状态栏应显示数量")

	# 搜索过滤
	panel.get("_search").text = "办公"
	panel.call("_fill")
	_check(_count_items(panel) < events.size() + graphs.size(), "搜索应减少显示数量")

	panel.get("_search").text = ""
	panel.call("_fill")
	_check(_count_items(panel) == events.size() + graphs.size(), "清空搜索后应恢复全部")

	# 引用查询
	var refs: Dictionary = panel.get("_refs")
	var librarian_path := "res://addons/rpgeventstudio/samples/events/librarian.tres"
	var librarian_refs: Array = refs.get(librarian_path, [])
	_check(not librarian_refs.is_empty(), "能查到事件被哪些场景对象引用")
	if not librarian_refs.is_empty():
		_check(str(librarian_refs[0].get("node", "")).contains("Librarian/EventInteractor"), "引用里带具体节点路径")

	var hint_path := "res://addons/rpgeventstudio/samples/events/basement_cutscene.tres"
	var hint_refs: Array = refs.get(hint_path, [])
	var has_graph_ref := false
	for entry in hint_refs:
		if str(entry.get("kind", "")) == "graph":
			has_graph_ref = true
	_check(has_graph_ref, "只在关卡图里调用的事件应记成「图引用」而不是场景引用")

	# 未挂到场景的事件
	var temp_path := "res://tests/tmp_unmounted_event.tres"
	var temp := EventDefinition.new()
	temp.event_id = &"tmp_unmounted"
	temp.display_name = "临时未挂事件"
	temp.pages = [EventPage.new()]
	ResourceSaver.save(temp, temp_path)
	panel.call("refresh")
	var filter_box: CheckBox = panel.get("_only_unreferenced")
	filter_box.button_pressed = true
	panel.call("_fill")
	var found_temp := false
	for item in _all_items(panel):
		var value: Variant = item.get_metadata(0)
		if value is EventDefinition and str(value.resource_path) == temp_path:
			found_temp = true
	_check(found_temp, "「只看未挂到场景」应筛出没有场景引用的事件")
	filter_box.button_pressed = false
	panel.call("_fill")
	DirAccess.remove_absolute(temp_path)
	panel.call("refresh")

	# 详情里能看到挂载位置
	var librarian_item := _first_item_with_path(panel, librarian_path)
	if librarian_item != null:
		librarian_item.select(0)
		var details: RichTextLabel = panel.get("_details")
		_check(details != null and details.text.contains("Librarian/EventInteractor"), "选中事件后详情显示挂载节点")

	# 双击打开：选中第一个事件并触发
	var activated: Array = []
	panel.event_activated.connect(func(definition: EventDefinition) -> void:
		activated.append(definition.event_id)
	)
	var item := _first_item_with_metadata(panel, "EventDefinition")
	_check(item != null, "列表里应能选中一个事件")
	if item != null:
		item.select(0)
		panel.call("_on_item_activated")
		_check(not activated.is_empty(), "双击事件应发出打开信号")

	# 关卡图也能双击打开
	var graph_activated: Array = []
	panel.graph_activated.connect(func(graph: LevelGraph) -> void:
		graph_activated.append(graph.graph_id)
	)
	var graph_item := _first_item_with_metadata(panel, "LevelGraph")
	if graph_item != null:
		graph_item.select(0)
		panel.call("_on_item_activated")
		_check(not graph_activated.is_empty(), "双击关卡图应发出打开信号")

	_report()
	quit(0 if _failures.is_empty() else 1)

func _first_item_with_path(panel: Control, path: String) -> TreeItem:
	for item in _all_items(panel):
		var value: Variant = item.get_metadata(0)
		if value == null:
			continue
		if value is EventDefinition or value is LevelGraph:
			if str(value.resource_path) == path:
				return item
	return null

func _count_items(panel: Control) -> int:
	var total := 0
	for item in _all_items(panel):
		if item.get_metadata(0) != null:
			total += 1
	return total

func _first_item_with_metadata(panel: Control, class_name_hint: String) -> TreeItem:
	for item in _all_items(panel):
		var value: Variant = item.get_metadata(0)
		if value == null:
			continue
		if class_name_hint == "EventDefinition" and value is EventDefinition:
			return item
		if class_name_hint == "LevelGraph" and value is LevelGraph:
			return item
	return null

func _all_items(panel: Control) -> Array:
	var out: Array = []
	var tree: Tree = panel.get("_tree")
	if tree == null:
		return out
	var root := tree.get_root()
	if root == null:
		return out
	_collect_items(root, out)
	return out

func _collect_items(item: TreeItem, out: Array) -> void:
	var child := item.get_first_child()
	while child != null:
		out.append(child)
		_collect_items(child, out)
		child = child.get_next()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 事件列表测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
