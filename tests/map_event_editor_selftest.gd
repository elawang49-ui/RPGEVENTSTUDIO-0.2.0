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
	_check(trigger_row != null and trigger_row.get_tooltip_text(0).contains("(650, 390)"), "总览 tooltip 显示触发区位置")
	var trigger_ok := trigger_row != null and trigger_row.get_tooltip_text(0).contains(L10n.ui("map.trigger.region_enter"))
	if trigger_row != null and tree.columns > 1:
		trigger_ok = trigger_ok or trigger_row.get_text(1) == L10n.ui("map.trigger.region_enter")
	_check(trigger_ok, "总览显示触发方式")
	_check(trigger_row != null and trigger_row.get_tooltip_text(0).contains("区域触发示例"), "总览 tooltip 显示关联事件")

	var unlinked := _tree_item_for(tree, _root.get_node("Inspect_Unlinked"))
	_check(unlinked != null, "总览能找到未关联对象")
	if unlinked != null:
		_check(unlinked.get_tooltip_text(0).contains("(820, 270)"), "总览 tooltip 显示场景位置")
		_check(unlinked.get_text(0).contains("⚠") and unlinked.get_tooltip_text(0).contains(L10n.ui("map.status.missing")),
			"未关联对象用警示标记并显示「未关联」")

	# 选中对象 → 面板同步；打开事件 → 事件编辑器
	var trigger: MapEvent2D = _root.get_node("Trigger_Region")
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(trigger)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_panel.get("_selected_node") == trigger, "选中地图事件后面板同步")
	var details: Label = _panel.get("_details")
	_check(details != null and details.tooltip_text.contains(L10n.ui("map.layer.same")), "详情 tooltip 显示层级")

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

	# 其余常见类型都能从地编入口创建，并带默认触发方式
	for kind in [MapEvent2D.Kind.NPC, MapEvent2D.Kind.INSPECT, MapEvent2D.Kind.DOOR, MapEvent2D.Kind.TRIGGER]:
		var created: MapEvent2D = _plugin.call("place_map_event", kind)
		_check(created != null and created.kind == kind, "可从地编入口创建类型 %d" % kind)
		if created != null:
			var want_trigger := MapEvent2D.TriggerMode.REGION_ENTER if kind == MapEvent2D.Kind.TRIGGER else MapEvent2D.TriggerMode.INTERACT
			_check(created.trigger_mode == want_trigger, "类型 %d 使用正确默认触发" % kind)
			_check(created.owner == _root, "类型 %d 的 owner 正确" % kind)

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
	_check(invalid_item != null and invalid_item.get_text(0).contains("⚠")
		and invalid_item.get_tooltip_text(0).contains(L10n.ui("map.status.invalid")), "总览识别失效引用")
	_root.remove_child(invalid)
	invalid.queue_free()

	# 定位按钮
	selection.clear()
	selection.add_node(trigger)
	await get_tree().process_frame
	_panel.call("_on_focus")
	await get_tree().process_frame
	_check(selection.get_selected_nodes().has(trigger), "定位按钮重新选中场景对象")

	# UI 主题页（主屏标签）
	_plugin.call("open_theme_page")
	await get_tree().process_frame
	var main_tabs: TabContainer = _plugin.get("_main_tabs")
	var theme_view: Control = _plugin.get("_theme_view")
	_check(main_tabs != null and main_tabs.current_tab == 1, "能切换到 UI 主题页")
	_check(theme_view != null, "UI 主题页已创建")
	if theme_view != null:
		var preview: Node = theme_view.get("_preview")
		var sample: OptionButton = theme_view.get("_sample")
		_check(preview != null and preview is DialoguePresenter, "主题页有真实 DialoguePresenter 预览")
		_check(sample != null and sample.item_count == 4, "主题预览支持普通/BBCode/多行/选项")
		var sections: Array = theme_view.get("_section_anchors")
		var themed_fields := 0
		for section in sections:
			themed_fields += (section as Control).get_child_count()
		_check(sections.size() == 7 and themed_fields > 80, "主题页控件完整（7 个分区）")
		var jump: OptionButton = theme_view.get("_section_jump")
		_check(jump != null and jump.item_count == sections.size(), "主题页分区跳转覆盖全部分区")
		var preset_select: OptionButton = theme_view.get("_preset_select")
		_check(preset_select != null and preset_select.item_count == DialogueThemePresets.ids().size() + 1,
			"主题页提供插件默认 + 全部预设")
		if preset_select != null:
			theme_view.call("_on_preset_selected", 1)
			var preset_theme: RpgEventStudioTheme = theme_view.get("_theme")
			_check(preset_theme != null and preset_theme.preset_id == "sacred", "选择预设后载入对应主题")
			var portrait_toggle: CheckButton = theme_view.get("_portrait_toggle")
			_check(portrait_toggle != null and portrait_toggle.button_pressed == preset_theme.portrait_enabled,
				"立绘框开关与预设同步")
			# 切换预设后再切回：未被保存的修改不能带到另一套预设
			preset_theme.choice_selected_bg = Color(1, 0, 1, 1)
			theme_view.call("_on_preset_selected", 5)
			var other: RpgEventStudioTheme = theme_view.get("_theme")
			_check(other != null and other.preset_id == "biscuit" and other.choice_selected_bg != Color(1, 0, 1, 1),
				"切换预设不会共享可变配置")
			theme_view.call("_on_preset_selected", 1)
			var again: RpgEventStudioTheme = theme_view.get("_theme")
			_check(again != null and again.choice_selected_bg != Color(1, 0, 1, 1),
				"重新载入预设得到出厂值")

		var temp_path := "res://.godot/test_theme_editor.tres"
		theme_view.set("theme_path", temp_path)
		var theme: RpgEventStudioTheme = theme_view.get("_theme")
		theme.text_speed = 77.0
		theme.panel_bg_color = Color(0.2, 0.05, 0.05, 0.95)
		theme_view.call("_save_theme")
		_check(FileAccess.file_exists(temp_path), "主题页能保存项目主题资源")
		theme.text_speed = 1.0
		theme_view.call("_reload_theme")
		var reloaded: RpgEventStudioTheme = theme_view.get("_theme")
		_check(reloaded != null and is_equal_approx(reloaded.text_speed, 77.0), "重新加载主题后设置仍在")

		# 重新创建一个主题页实例，模拟关闭/重新打开编辑器后从磁盘读取
		var reopened := DialogueThemeView.new()
		reopened.set("theme_path", temp_path)
		EditorInterface.get_base_control().add_child(reopened)
		await get_tree().process_frame
		var reopened_theme: RpgEventStudioTheme = reopened.get("_theme")
		_check(reopened_theme != null and is_equal_approx(reopened_theme.text_speed, 77.0), "重新打开主题页仍读取已保存设置")
		reopened.queue_free()
		theme_view.call("_restore_defaults")
		var restored: RpgEventStudioTheme = theme_view.get("_theme")
		_check(restored != null and is_equal_approx(restored.text_speed, 42.0), "恢复默认主题生效")
		DirAccess.remove_absolute(temp_path)

	# 自定义 UI 项目声明：只显示能力，不显示插件主题的假配置
	var old_mode = ProjectSettings.get_setting("rpg_event_studio/ui_mode", null)
	var old_caps = ProjectSettings.get_setting("rpg_event_studio/custom_ui_capabilities", null)
	ProjectSettings.set_setting("rpg_event_studio/ui_mode", "custom")
	ProjectSettings.set_setting("rpg_event_studio/custom_ui_capabilities", PackedStringArray(["text", "choices", "bbcode"]))
	var custom_view := DialogueThemeView.new()
	EditorInterface.get_base_control().add_child(custom_view)
	await get_tree().process_frame
	_check(bool(custom_view.get("_custom_mode")), "自定义 UI 项目进入只读能力模式")
	_check(custom_view.get("_preview") == null and custom_view.get("_controls_box") == null, "自定义 UI 项目不显示插件主题配置")
	custom_view.queue_free()
	if old_mode == null:
		ProjectSettings.clear("rpg_event_studio/ui_mode")
	else:
		ProjectSettings.set_setting("rpg_event_studio/ui_mode", old_mode)
	if old_caps == null:
		ProjectSettings.clear("rpg_event_studio/custom_ui_capabilities")
	else:
		ProjectSettings.set_setting("rpg_event_studio/custom_ui_capabilities", old_caps)

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
