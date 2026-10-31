extends Node
## 关卡图编辑器自测：静态校验面板、双击定位、保存拦截、节点分组、布局辅助、撤销重做。
## 只在环境变量 RPGEVENTSTUDIO_GVL_SELFTEST=1 时由 plugin.gd 启动（真实编辑器环境）：
##   RPGEVENTSTUDIO_GVL_SELFTEST=1 godot --path .（带窗口）
## 结果打印 [GVL]，全部通过退出码 0。

var _checks := 0
var _failures: PackedStringArray = []
var _panel: Control
var _graph: LevelGraph
var _temp_path := "res://.godot/gvl_selftest_graph.tres"

func start(_plugin: EditorPlugin, _main_screen: Control) -> void:
	# 与 editor_selftest 相同的做法：自己建一个同脚本的面板，不受 dock 生命周期影响。
	await get_tree().create_timer(1.0).timeout
	var base := EditorInterface.get_base_control()
	if base == null:
		_fail("拿不到编辑器根节点")
		_finish()
		return
	_panel = load("res://addons/rpgeventstudio/editor/level_graph/level_graph_view.gd").new()
	base.add_child(_panel)
	# 自测面板必须铺满编辑器，否则 GraphEdit 只有最小高度，滚动/拖动等坐标断言全部失真。
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame

	var source: LevelGraph = load("res://addons/rpgeventstudio/samples/graphs/school_graph.tres")
	if source == null:
		_fail("无法加载示例关卡图")
		_finish()
		return
	_graph = source.duplicate(true)
	_graph.take_over_path(_temp_path)
	_panel.call("open_graph", _graph)
	await get_tree().process_frame

	_test_sample_has_no_errors()
	await _test_toolbar_and_node_title()
	await _test_validation_panel_and_locate()
	await _test_save_guard()
	await _test_groups_and_undo()
	await _test_group_persistence()
	await _test_layout_and_undo()
	_test_node_badge()

	_panel.queue_free()
	_finish()

# ── 校验 ─────────────────────────────────────────────────

func _test_toolbar_and_node_title() -> void:
	var fit: Button = _panel.get("_fit_button")
	_check(fit != null and fit.text == L10n.ui("graph.fit"), "工具栏有「适配」视图按钮")
	_check(_panel.get_child(0) is HFlowContainer, "工具栏使用流式布局，窄窗口可换行")
	var probe := LevelNode.new()
	probe.node_id = &"probe_title"
	probe.type = "action"
	probe.title = "自定义标题"
	var view: GraphNode = _panel.call("_make_node_view", probe)
	_check(view != null and view.title == "自定义标题", "节点卡片优先显示自定义标题")
	if view != null:
		var labels: Dictionary = _panel.get("_summary_labels")
		_check(labels.has(probe.node_id), "自定义标题节点仍有摘要标签")
		view.queue_free()
	_panel.call("fit_view")
	await get_tree().process_frame
	var zoom: float = _panel.get("_graph_edit").zoom
	_check(zoom > 0.0 and zoom <= 1.0, "适配视图后的缩放有效（%.2f）" % zoom)

func _test_sample_has_no_errors() -> void:
	var issues: Array = _panel.get("_issues")
	_check(issues != null and not GraphValidator.has_errors(issues), "示例关卡图不应有错误（剩余提示可接受）")

func _test_validation_panel_and_locate() -> void:
	# 制造错误：删开始节点 + 留一个没填 key 的动作 + 一条断裂连线
	var start := _graph.entry()
	var action := _first_of_type("action")
	if action == null:
		_fail("示例图里应有动作节点")
		return
	_panel.call("_do_remove_nodes", [start])
	var ghost := LevelConnection.new()
	ghost.from_node = &"ghost_node"
	ghost.to_node = action.node_id
	_graph.connections.append(ghost)
	_panel.call("_rebuild_view")
	await get_tree().process_frame

	_panel.call("_on_check_pressed")
	await get_tree().process_frame
	var issues: Array = _panel.get("_issues")
	_check(GraphValidator.has_errors(issues), "破坏后的图应检出错误")
	_check(_has_code(issues, "start_missing"), "应报「缺少开始节点」")
	_check(_has_code(issues, "conn_broken"), "应报「断裂引用」")
	_check(_panel.get("_check_panel").visible, "点「检查」后结果面板应展开")
	var tree: Tree = _panel.get("_check_tree")
	_check(tree.get_root().get_child_count() == issues.size(), "结果行数应与问题数一致")

	# 双击定位：模拟 item_activated
	var target := action.node_id
	_panel.call("_locate_node", target)
	await get_tree().process_frame
	var views: Dictionary = _panel.get("_node_views")
	var view: GraphNode = views.get(target, null)
	_check(view != null and view.selected, "定位后目标节点应被选中")
	_check(_panel.get("_selected") == _graph.node_by_id(target), "定位后右侧参数应显示该节点")
	var scroll: Vector2 = _panel.get("_graph_edit").scroll_offset
	var center: Vector2 = view.position_offset + view.size * 0.5
	var zoom: float = _panel.get("_graph_edit").zoom
	var canvas: Vector2 = _panel.get("_graph_edit").size
	_check((scroll + center * zoom - canvas * 0.5).length() < 80.0,
		"画布应滚到节点附近正中（scroll=%s center=%s zoom=%.2f size=%s）" % [scroll, center, zoom, canvas])

	# 保存拦截
	_panel.call("_on_save_pressed")
	await get_tree().process_frame
	var confirm: ConfirmationDialog = _panel.get("_save_confirm")
	_check(confirm != null and confirm.visible, "有错误保存时应弹出确认对话框（不得静默保存）")
	_check(not FileAccess.file_exists(_temp_path), "确认前不应写文件")
	confirm.hide()

	# 修复后重新检查：错误消失
	_panel.call("_do_disconnect", ghost)
	var new_start := LevelNode.new()
	new_start.node_id = _graph.next_node_id("start")
	new_start.type = "start"
	new_start.position = Vector2(40, 40)
	_graph.nodes.append(new_start)
	_graph.entry_node = new_start.node_id
	_panel.call("_rebuild_view")
	await get_tree().process_frame
	_panel.call("_on_check_pressed")
	await get_tree().process_frame
	var fixed: Array = _panel.get("_issues")
	_check(not GraphValidator.has_errors(fixed), "修复后重新检查应无错误")

func _test_save_guard() -> void:
	_panel.call("_do_save")
	var reloaded := load(_temp_path) as LevelGraph
	_check(reloaded != null and reloaded.nodes.size() == _graph.nodes.size(), "无错误时保存应成功并可重新读取")

# ── 分组 ─────────────────────────────────────────────────

func _test_groups_and_undo() -> void:
	var nodes := _graph.nodes
	_check(nodes.size() >= 4, "图里至少应有 4 个节点")
	var first: LevelNode = nodes[0]
	var second: LevelNode = nodes[1]
	var third: LevelNode = nodes[2]
	_mark_selected([first.node_id, second.node_id])

	_panel.call("_create_group", true)
	await get_tree().process_frame
	var groups: Array = _graph.groups
	_check(groups.size() == 1, "新建分组后模型应有 1 个分组")
	var frames: Dictionary = _panel.get("_frame_views")
	_check(frames.size() == 1, "新建分组后应有 1 个 GraphFrame 视图")
	var group: LevelGroup = groups[0]
	_check(group.member_ids.size() == 2, "分组应含 2 个选中节点")
	var attached: Array = _panel.get("_graph_edit").get_attached_nodes_of_frame(String(group.group_id))
	_check(attached.size() == 2, "GraphFrame 应挂接 2 个成员")

	# 改名 + 改色（带撤销）
	_panel.call("_change_group_property", group, "title", "主线剧情")
	_check(group.title == "主线剧情", "分组改名应写入模型")
	var frame: GraphFrame = _panel.get("_frame_views").get(group.group_id)
	_check(frame.title == "主线剧情", "分组改名应同步视图")
	_panel.call("_change_group_property", group, "color", Color(0.9, 0.2, 0.2, 0.2))
	_check(group.color == Color(0.9, 0.2, 0.2, 0.2), "分组改色应写入模型")
	_history().undo()
	_check(group.color != Color(0.9, 0.2, 0.2, 0.2), "撤销改色应还原")
	_history().redo()
	_check(group.color == Color(0.9, 0.2, 0.2, 0.2), "重做改色应生效")
	_history().undo()   # 撤销改名
	_history().redo()   # 恢复改名
	_check(group.title == "主线剧情", "改名撤销重做后应保持新名")

	# 加成员 + 撤销
	var new_members := group.member_ids.duplicate()
	new_members.append(third.node_id)
	_panel.call("_commit_group_members", group, new_members)
	await get_tree().process_frame
	var attached3: Array = _panel.get("_graph_edit").get_attached_nodes_of_frame(String(group.group_id))
	_check(group.member_ids.size() == 3 and attached3.size() == 3, "加入节点后成员应为 3")
	_history().undo()
	_check(group.member_ids.size() == 2, "撤销加成员应还原为 2")
	var attached_after_undo: Array = _panel.get("_graph_edit").get_attached_nodes_of_frame(String(group.group_id))
	_check(attached_after_undo.size() == 2, "撤销加成员后挂接也应还原")
	_history().redo()
	_check(group.member_ids.size() == 3, "重做加成员应再次为 3")

	# 拖出分组（引擎侧摘除 → 协调回模型）
	_panel.get("_graph_edit").detach_graph_element_from_frame(String(third.node_id))
	_panel.call("_reconcile_group_members")
	_check(group.member_ids.size() == 2, "拖出分组后模型成员应同步为 2")

	# 删除分组不删节点
	var node_count := _graph.nodes.size()
	_panel.call("_delete_groups", [group.group_id])
	await get_tree().process_frame
	_check(_graph.groups.is_empty(), "删除分组后模型应为空")
	_check(_graph.nodes.size() == node_count, "删除分组不应删除内部节点")
	_check(_panel.get("_frame_views").is_empty(), "删除分组后视图应移除")
	_history().undo()
	_check(_graph.groups.size() == 1, "撤销删除分组应恢复")
	var restored: LevelGroup = _graph.groups[0]
	_check(restored.member_ids.size() == 2, "恢复的分组应保留成员")

func _test_group_persistence() -> void:
	var group := _graph.groups[0] if not _graph.groups.is_empty() else null
	if group == null:
		_fail("持久化测试前应有分组")
		return
	group.position = Vector2(123, 456)
	group.size = Vector2(321, 654)
	_panel.call("_do_save")
	var reloaded := load(_temp_path) as LevelGraph
	_check(reloaded != null and reloaded.groups.size() == 1, "重新读取后分组应保留")
	if reloaded != null and reloaded.groups.size() == 1:
		var saved: LevelGroup = reloaded.groups[0]
		_check(saved.group_id == group.group_id, "分组 id 一致")
		_check(saved.title == group.title, "分组名一致")
		_check(saved.member_ids == group.member_ids, "分组成员一致")
		_check(saved.position == group.position and saved.size == group.size, "分组位置与大小一致")
		_check(saved.color.is_equal_approx(group.color), "分组颜色一致")
	# 重新打开后视图里应重建分组框
	_panel.call("open_graph", reloaded)
	await get_tree().process_frame
	_check(_panel.get("_frame_views").size() == 1, "重新打开后分组框应重建")
	var attached: Array = _panel.get("_graph_edit").get_attached_nodes_of_frame(String(group.group_id))
	_check(attached.size() == group.member_ids.size(), "重新打开后成员挂接应恢复")
	_graph = reloaded

# ── 布局 ─────────────────────────────────────────────────

func _test_layout_and_undo() -> void:
	var nodes := _graph.nodes
	if nodes.size() < 3:
		_fail("布局测试至少需要 3 个节点")
		return
	var ids: Array[StringName] = [nodes[0].node_id, nodes[1].node_id, nodes[2].node_id]
	var views: Dictionary = _panel.get("_node_views")
	var before: Dictionary = _panel.call("_capture_positions")

	# 左对齐
	_mark_selected(ids)
	_panel.call("_apply_layout", "left")
	var same_x := true
	for id in ids:
		if (views[id] as GraphNode).position_offset.x != (views[ids[0]] as GraphNode).position_offset.x:
			same_x = false
	_check(same_x, "左对齐后 x 应一致")
	_check(_graph.node_by_id(ids[0]).position == (views[ids[0]] as GraphNode).position_offset, "对齐应写回模型")
	_history().undo()
	for id in ids:
		_check((views[id] as GraphNode).position_offset == before[id], "撤销左对齐应还原位置（%s）" % id)
	_check(_graph.node_by_id(ids[0]).position == before[ids[0]], "撤销左对齐应还原模型")
	_history().redo()
	_check((views[ids[1]] as GraphNode).position_offset.x == (views[ids[0]] as GraphNode).position_offset.x, "重做左对齐应再次生效")
	_history().undo()   # 还原，便于后续用例

	# 水平等距分布
	_mark_selected(ids)
	_panel.call("_apply_layout", "h_dist")
	var centers: Array[float] = []
	for id in ids:
		var view: GraphNode = views[id]
		centers.append(view.position_offset.x + view.size.x * 0.5)
	centers.sort()
	var gap_a := centers[1] - centers[0]
	var gap_b := centers[2] - centers[1]
	_check(absf(gap_a - gap_b) < 1.0, "水平等距分布后中心间距应相等")
	_history().undo()
	_check((views[ids[0]] as GraphNode).position_offset == before[ids[0]], "撤销分布应还原")
	_history().redo()
	_history().undo()

	# 自动排列
	var changed_before: Vector2 = (views[ids[0]] as GraphNode).position_offset
	_panel.call("_layout_auto")
	_check(_graph.node_by_id(ids[0]).position == (views[ids[0]] as GraphNode).position_offset, "自动排列应写回模型")
	_history().undo()
	_check((views[ids[0]] as GraphNode).position_offset == before[ids[0]], "撤销自动排列应还原")
	_check(changed_before == before[ids[0]], "撤销自动排列后应回到初始位置")
	_history().redo()
	_history().undo()

	# 拖动节点（begin/end_node_move 通道）也应可撤销
	_panel.call("_on_begin_node_move")
	var drag_view: GraphNode = views[ids[0]]
	drag_view.position_offset = (before[ids[0]] as Vector2) + Vector2(77, 55)
	_panel.call("_on_end_node_move")
	_check(_graph.node_by_id(ids[0]).position == drag_view.position_offset, "拖动结束应写回模型")
	_history().undo()
	_check(drag_view.position_offset == before[ids[0]], "撤销拖动应还原位置")
	_check(_graph.node_by_id(ids[0]).position == before[ids[0]], "撤销拖动应还原模型")
	_history().redo()
	_check(drag_view.position_offset == (before[ids[0]] as Vector2) + Vector2(77, 55), "重做拖动应生效")
	_history().undo()

func _test_node_badge() -> void:
	# 有警告/错误的节点摘要应带 ⚠
	var broken := LevelNode.new()
	broken.node_id = _graph.next_node_id("action")
	broken.type = "action"
	broken.position = Vector2(900, 60)
	_graph.nodes.append(broken)
	_panel.call("_rebuild_view")
	_panel.call("_run_validation")
	var labels: Dictionary = _panel.get("_summary_labels")
	var label: Label = labels.get(broken.node_id)
	_check(label != null and label.text.begins_with("⚠"), "有问题节点的摘要应带 ⚠ 标记")
	_panel.call("_do_remove_nodes", [broken])

# ── 工具 ─────────────────────────────────────────────────

func _mark_selected(ids: Array) -> void:
	var views: Dictionary = _panel.get("_node_views")
	for id in ids:
		var view: GraphNode = views.get(id, null)
		if view != null:
			view.selected = true
	for id in views:
		if not ids.has(id):
			(views[id] as GraphNode).selected = false

func _first_of_type(type: String) -> LevelNode:
	for node in _graph.nodes:
		if node != null and node.type == type:
			return node
	return null

func _has_code(issues: Array, code: String) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false

func _history() -> UndoRedo:
	var manager := EditorInterface.get_editor_undo_redo()
	var id := manager.get_object_history_id(_graph)
	return manager.get_history_undo_redo(id)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[GVL] ✓ ", message)
	else:
		_fail(message)

func _fail(message: String) -> void:
	_checks += 1
	_failures.append(message)
	print("[GVL] ✗ ", message)

func _finish() -> void:
	print("[GVL] ===== 检查 %d 项，失败 %d 项 =====" % [_checks, _failures.size()])
	for failure in _failures:
		print("[GVL] ✗ ", failure)
	DirAccess.remove_absolute(_temp_path)
	var tree := get_tree()
	if tree != null:
		tree.quit(0 if _failures.is_empty() else 1)
