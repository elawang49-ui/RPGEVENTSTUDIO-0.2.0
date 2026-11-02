@tool
extends EditorPlugin
## Godot RPG Event Studio —— 编辑器插件入口。
##
## 职责：
##   1. 保证运行时 Autoload 存在
##   2. 注册右侧「事件」面板
##   3. 同步编辑器选中对象
##   4. 记住编辑器界面语言（与游戏语言分开保存）

const PANEL_SCRIPT := "res://addons/rpgeventstudio/editor/event_editor/event_editor_panel.gd"
const GRAPH_SCRIPT := "res://addons/rpgeventstudio/editor/level_graph/level_graph_view.gd"
const LIST_SCRIPT := "res://addons/rpgeventstudio/editor/event_list/event_list_panel.gd"
const THEME_SCRIPT := "res://addons/rpgeventstudio/editor/theme/dialogue_theme_view.gd"
const MAP_SCRIPT := "res://addons/rpgeventstudio/editor/map_events/map_event_panel.gd"
const STORY_SCRIPT := "res://addons/rpgeventstudio/editor/story/story_editor_panel.gd"
const AUDIT_SCRIPT := "res://addons/rpgeventstudio/editor/audit/story_audit_panel.gd"
const RUNTIME_SCRIPT := "res://addons/rpgeventstudio/runtime/autoload/studio_runtime.gd"
const AUTOLOAD_NAME := "RPGEventStudio"
const EDITOR_LANGUAGE_SETTING := "rpg_event_studio/editor_language"

var _panel: Control
var _panel_scroll: ScrollContainer
var _main_tabs: TabContainer
var _main_screen: Control
var _theme_view: Control
var _list_panel: Control
var _map_panel: Control
var _map_view: Control
var _story_view: Control
var _audit_view: Control
var _debugger_plugin: StudioDebuggerPlugin
var _filesystem: EditorFileSystem
var _refresh_timer: SceneTreeTimer
var _selection: EditorSelection

func _enter_tree() -> void:
	_load_editor_language()
	_ensure_autoload()
	_create_dock()
	_create_main_screen()
	_create_list_dock()
	_create_debugger()
	_connect_selection()

	if OS.get_environment("RPGEVENTSTUDIO_SELFTEST") == "1":
		_start_selftest.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_SHOT") == "1":
		_capture_graph_screen.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_GVL_SELFTEST") == "1":
		_start_gvl_selftest.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_GVL_SHOT") == "1":
		_capture_gvl_screen.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_MAP_SELFTEST") == "1":
		_start_map_selftest.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_MAP_SHOT") == "1":
		_capture_map_screen.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_THEME_SHOT") == "1":
		_capture_theme_screen.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_BULK_SHOT") == "1":
		_capture_bulk_screen.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_STORY_SELFTEST") == "1" or OS.get_environment("RPGEVENTSTUDIO_STORY_SHOT") == "1":
		_start_story_test.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_AUDIT_SELFTEST") == "1":
		_start_audit_selftest.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_TRACE_SELFTEST") == "1":
		_start_trace_selftest.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_MAIN_TAB_SHOT") == "1":
		_capture_main_tab_screen.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_DOCK_SHOT") == "1":
		_capture_dock_screen.call_deferred()

func _exit_tree() -> void:
	if _selection != null and _selection.selection_changed.is_connected(_on_selection_changed):
		_selection.selection_changed.disconnect(_on_selection_changed)
	_selection = null

	if _panel_scroll != null:
		remove_control_from_docks(_panel_scroll)
		_panel_scroll.queue_free()
		_panel_scroll = null
		_panel = null

	if _main_tabs != null:
		_main_tabs.queue_free()
		_main_tabs = null
	_main_screen = null
	_theme_view = null
	_story_view = null
	_audit_view = null
	_map_view = null
	_map_panel = null

	if _filesystem != null and _filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		_filesystem.filesystem_changed.disconnect(_on_filesystem_changed)
	_filesystem = null

	if _list_panel != null:
		remove_control_from_docks(_list_panel)
		_list_panel.queue_free()
		_list_panel = null

	if _debugger_plugin != null:
		remove_debugger_plugin(_debugger_plugin)
		_debugger_plugin = null


# ── 面板 ─────────────────────────────────────────────────

func _create_dock() -> void:
	var script := load(PANEL_SCRIPT)
	if script == null:
		push_error("[RPGEventStudio] " + L10n.ui("diag.panel_missing"))
		return
	_panel = script.new()
	_panel.name = L10n.ui("editor.title")
	_panel.call("bind_plugin", self)
	# 事件编辑器内容很高；直接放进 Dock 会把整条右侧栏撑到 2000+，
	# 进而把主屏（关卡图/主题/剧情/审计）也按超高画布布局。外层滚动切断这个最小高度。
	_panel_scroll = ScrollContainer.new()
	_panel_scroll.name = L10n.ui("editor.title")
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_scroll.add_child(_panel)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _panel_scroll)

# ── 事件列表 ─────────────────────────────────────────────

func _create_list_dock() -> void:
	var script := load(LIST_SCRIPT)
	if script == null:
		push_error("[RPGEventStudio] 找不到事件列表面板脚本")
		return
	_list_panel = script.new()
	_list_panel.name = L10n.ui("eventlist.title")
	_list_panel.event_activated.connect(_open_event)
	_list_panel.graph_activated.connect(_open_graph)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _list_panel)

	_filesystem = EditorInterface.get_resource_filesystem()
	if _filesystem != null and not _filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		_filesystem.filesystem_changed.connect(_on_filesystem_changed)

# ── 地图事件 ─────────────────────────────────────────────

func refresh_map_events() -> void:
	if _map_view != null:
		_map_view.call("refresh")

func _on_place_map_event(kind: int) -> void:
	place_map_event(kind)

## 在当前编辑场景里生成一个 MapEvent2D，并登记到 UndoRedo。
func place_map_event(kind: int) -> MapEvent2D:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_warning("[RPGEventStudio] 请先打开一个 2D 场景再放置地图事件")
		return null
	var parent := _map_event_parent(root)
	var node := MapEvent2D.new()
	node.kind = kind
	node.trigger_mode = MapEvent2D.TriggerMode.REGION_ENTER if kind == MapEvent2D.Kind.TRIGGER else MapEvent2D.TriggerMode.INTERACT
	node.layer_mode = MapEvent2D.LayerMode.SAME_LAYER
	node.name = _unique_map_event_name(parent, kind)
	node.position = _map_event_spawn_position(parent)

	var undo := get_undo_redo()
	if undo != null:
		undo.create_action("Place Map Event", UndoRedo.MERGE_DISABLE, root)
		undo.add_do_method(parent, "add_child", node)
		undo.add_do_method(node, "set_owner", root)
		undo.add_do_reference(node)
		undo.add_undo_method(parent, "remove_child", node)
		undo.commit_action()
	else:
		parent.add_child(node)
		node.owner = root

	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()
	var selection := EditorInterface.get_selection()
	if selection != null:
		selection.clear()
		selection.add_node(node)
	refresh_map_events()
	return node

func _map_event_parent(root: Node) -> Node:
	var selection := EditorInterface.get_selection()
	if selection != null:
		var nodes := selection.get_selected_nodes()
		if nodes.size() == 1:
			var selected := nodes[0]
			if selected is Node2D and selected != root and root.is_ancestor_of(selected):
				# 不要把新事件塞进已有 MapEvent2D（或它的美术子节点）里。
				var ancestor := selected
				while ancestor != null and ancestor != root:
					if ancestor is MapEvent2D and ancestor.get_parent() != null:
						return ancestor.get_parent()
					ancestor = ancestor.get_parent()
				return selected
	return root

func _map_event_spawn_position(parent: Node) -> Vector2:
	var world := Vector2.ZERO
	if EditorInterface.has_method("get_editor_viewport_2d"):
		var viewport = EditorInterface.get_editor_viewport_2d()
		if viewport is SubViewport:
			var sub := viewport as SubViewport
			world = sub.get_canvas_transform().affine_inverse() * (Vector2(sub.size) * 0.5)
	if parent is Node2D:
		return (parent as Node2D).to_local(world)
	return world

func _unique_map_event_name(parent: Node, kind: int) -> String:
	var bases := ["NPCEvent", "InspectEvent", "ChestEvent", "DoorEvent", "MechanismEvent", "TriggerEvent"]
	var base: String = bases[clampi(kind, 0, bases.size() - 1)]
	if not parent.has_node(NodePath(base)):
		return base
	var index := 2
	while parent.has_node(NodePath(base + str(index))):
		index += 1
	return base + str(index)

func _on_filesystem_changed() -> void:
	# 导入/保存会连续触发，做个简单防抖
	if _refresh_timer != null and _refresh_timer.time_left > 0.0:
		return
	_refresh_timer = get_tree().create_timer(0.6)
	_refresh_timer.timeout.connect(func() -> void:
		if _list_panel != null:
			_list_panel.call("refresh")
	)

func refresh_event_list() -> void:
	if _list_panel != null:
		_list_panel.call("refresh")

func _open_event(definition: EventDefinition) -> void:
	if _panel != null and definition != null:
		_panel.call("open_definition", definition, null)
	if _story_view != null and definition != null:
		_story_view.call("open_definition", definition, null)

## 打开「剧情」标签页（剧情创作工作台）。
func open_story_tab() -> void:
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	if _main_tabs != null:
		_main_tabs.current_tab = 2

## 打开「审计」标签页（全工程剧情资源审计）。
func open_audit_tab() -> void:
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	if _main_tabs != null:
		_main_tabs.current_tab = 3

func _open_graph(graph: LevelGraph) -> void:
	if graph == null:
		return
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	if _main_tabs != null:
		_main_tabs.current_tab = 0
	if _main_screen != null:
		_main_screen.call("open_graph", graph)

## 审计结果双击：事件/关卡图直接打开，场景问题定位到对应场景。
func _on_audit_issue(issue: Dictionary) -> void:
	var path := str(issue.get("path", ""))
	if path == "":
		return
	if path.ends_with(".tscn"):
		EditorInterface.open_scene_from_path(path)
		return
	var resource := load(path)
	if resource is EventDefinition:
		_open_event(resource)
	elif resource is LevelGraph:
		_open_graph(resource)

## 打开「UI 主题」页（主屏内标签）。
func open_theme_page() -> void:
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	if _main_tabs != null:
		_main_tabs.current_tab = 1

# ── 运行高亮（调试器通道） ───────────────────────────────

func _create_debugger() -> void:
	_debugger_plugin = StudioDebuggerPlugin.new()
	_debugger_plugin.graph_node.connect(_on_debug_node)
	_debugger_plugin.graph_stage.connect(_on_debug_stage)
	_debugger_plugin.trace_node.connect(_on_trace_node)
	_debugger_plugin.trace_event.connect(_on_trace_event)
	add_debugger_plugin(_debugger_plugin)

func _on_debug_node(graph_id: String, node_id: String, state: int) -> void:
	if _main_screen != null and _main_screen.has_method("apply_debug_node"):
		_main_screen.call("apply_debug_node", graph_id, node_id, state)

func _on_debug_stage(graph_id: String, stage: String) -> void:
	if _main_screen != null and _main_screen.has_method("apply_debug_stage"):
		_main_screen.call("apply_debug_stage", graph_id, stage)

## F2 追踪面板点击图节点：只定位当前打开的同 id 图，不伪造跨图定位。
func _on_trace_node(graph_id: String, node_id: String, graph_path: String = "") -> void:
	if _main_screen == null:
		return
	var graph = _main_screen.call("current_graph")
	if graph == null or String(graph.graph_id) != graph_id:
		if graph_path == "" or not ResourceLoader.exists(graph_path):
			return
		var loaded := load(graph_path)
		if not (loaded is LevelGraph):
			return
		_open_graph(loaded)
		graph = loaded
	_main_screen.call("_locate_node", StringName(node_id))

## F2 追踪面板双击事件：按事件资源路径打开；没有路径时只能显示记录详情。
func _on_trace_event(_event_id: String, event_path: String) -> void:
	if event_path == "" or not ResourceLoader.exists(event_path):
		return
	var resource := load(event_path)
	if resource is EventDefinition:
		_open_event(resource)

# ── 主屏：关卡图 ─────────────────────────────────────────

## 剧情工作台/审计页内容很高（最小尺寸可达 1400×1900），直接放进 TabContainer
## 会把整个主屏撑出窗口。外包一层滚动容器，页面按自身尺寸渲染，主屏不越界。
func _wrap_page_in_scroll(page: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = page.name + "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	return scroll

func _create_main_screen() -> void:
	var script := load(GRAPH_SCRIPT)
	if script == null:
		push_error("[RPGEventStudio] 找不到关卡图编辑器脚本")
		return
	_main_tabs = TabContainer.new()
	_main_tabs.name = "EventStudioMainTabs"
	_main_tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(_main_tabs)

	_main_screen = script.new()
	_main_screen.name = "LevelGraph"
	_main_screen.call("bind_plugin", self)
	_main_tabs.add_child(_main_screen)
	_main_tabs.set_tab_title(0, L10n.ui("graph.title"))

	var theme_script := load(THEME_SCRIPT)
	if theme_script != null:
		_theme_view = theme_script.new()
		_theme_view.name = "ThemeView"
		_main_tabs.add_child(_theme_view)
		_main_tabs.set_tab_title(1, L10n.ui("theme.title"))
	else:
		push_error("[RPGEventStudio] 找不到 UI 主题页脚本")

	var story_script := load(STORY_SCRIPT)
	if story_script != null:
		_story_view = story_script.new()
		_story_view.name = "StoryWorkbench"
		_story_view.call("bind_plugin", self)
		_main_tabs.add_child(_wrap_page_in_scroll(_story_view))
		_main_tabs.set_tab_title(2, L10n.ui("story.title"))
	else:
		push_error("[RPGEventStudio] 找不到剧情工作台脚本")

	var audit_script := load(AUDIT_SCRIPT)
	if audit_script != null:
		_audit_view = audit_script.new()
		_audit_view.name = "StoryAudit"
		_audit_view.issue_activated.connect(_on_audit_issue)
		_main_tabs.add_child(_wrap_page_in_scroll(_audit_view))
		_main_tabs.set_tab_title(3, L10n.ui("audit.title"))
	else:
		push_error("[RPGEventStudio] 找不到剧情审计面板脚本")

	# 地图事件也需要一个全宽入口：小窗口下右侧 dock 会被挤到屏幕外，
	# 主屏标签页保证 1152×648 仍能查看/打开地图事件。
	var map_script := load(MAP_SCRIPT)
	if map_script != null:
		_map_view = map_script.new()
		_map_view.name = "MapEventsView"
		_map_view.event_activated.connect(_open_event)
		_map_view.place_requested.connect(_on_place_map_event)
		_main_tabs.add_child(_map_view)
		_main_tabs.set_tab_title(4, L10n.ui("map.title"))
		# 兼容旧测试/截图钩子：地图事件只有一个真实实例（主屏页），不再占独立 Dock。
		_map_panel = _map_view
	else:
		push_error("[RPGEventStudio] 找不到地图事件面板脚本")
	_make_visible(false)

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return L10n.ui("graph.title")

func _get_plugin_icon() -> Texture2D:
	if not Engine.is_editor_hint():
		return null
	var theme := EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon("GraphEdit", "EditorIcons"):
		return theme.get_icon("GraphEdit", "EditorIcons")
	return null

func _make_visible(visible: bool) -> void:
	if _main_tabs != null:
		_main_tabs.visible = visible

func _connect_selection() -> void:
	_selection = get_editor_interface().get_selection()
	if _selection == null:
		return
	if not _selection.selection_changed.is_connected(_on_selection_changed):
		_selection.selection_changed.connect(_on_selection_changed)
	_on_selection_changed()

func refresh_dock_title() -> void:
	if _panel != null:
		_panel.name = L10n.ui("editor.title")

func _on_selection_changed() -> void:
	if _selection == null:
		return
	var nodes := _selection.get_selected_nodes()
	if _panel != null:
		_panel.call("open_from_selection", nodes)
	if _main_screen != null:
		_main_screen.call("open_from_selection", nodes)
	if _map_view != null:
		_map_view.call("on_selection_changed", nodes)
	if _story_view != null and _main_tabs != null and _main_tabs.current_tab == 2:
		_story_view.call("open_from_selection", nodes)

# ── 语言 ─────────────────────────────────────────────────

func _load_editor_language() -> void:
	var locale := "zh_CN"
	var settings := _editor_settings()
	if settings != null and settings.has_setting(EDITOR_LANGUAGE_SETTING):
		locale = str(settings.get_setting(EDITOR_LANGUAGE_SETTING))
	L10n.set_editor_locale(locale)

func save_editor_language(locale: String) -> void:
	L10n.set_editor_locale(locale)
	var settings := _editor_settings()
	if settings != null:
		settings.set_setting(EDITOR_LANGUAGE_SETTING, locale)

func _editor_settings() -> EditorSettings:
	if not Engine.is_editor_hint():
		return null
	return get_editor_interface().get_editor_settings()

# ── Autoload ─────────────────────────────────────────────

func _enable_plugin() -> void:
	_ensure_autoload()

func _disable_plugin() -> void:
	_release_autoload()
	ProjectSettings.save.call_deferred()

func _ensure_autoload() -> void:
	var key := "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.has_setting(key):
		return
	add_autoload_singleton(AUTOLOAD_NAME, RUNTIME_SCRIPT)
	ProjectSettings.save.call_deferred()

func _release_autoload() -> void:
	var key := "autoload/" + AUTOLOAD_NAME
	if not ProjectSettings.has_setting(key):
		return
	var value := str(ProjectSettings.get_setting(key)).trim_prefix("*")
	if value.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(value)
		if ResourceUID.has_id(uid):
			value = ResourceUID.get_id_path(uid)
	if value == RUNTIME_SCRIPT:
		remove_autoload_singleton(AUTOLOAD_NAME)

# ── 测试钩子（仅 RPGEVENTSTUDIO_SELFTEST=1 时启用） ─────

## 仅开发截图：用 RPGEVENTSTUDIO_SHOT_SIZE=1152x648 固定窗口内容尺寸；
## 截图后缩放到该尺寸，保证双分辨率验收图是真实布局而不是事后裁切。
func _shot_target_size() -> Vector2i:
	var raw := OS.get_environment("RPGEVENTSTUDIO_SHOT_SIZE").strip_edges()
	if raw == "":
		return Vector2i.ZERO
	var parts := raw.split("x")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

## 截图钩子：直接触发编辑器顶栏的主屏按钮。
## set_main_screen_editor() 在部分编辑器布局下对插件名不生效，但按钮本身可用。
func _focus_main_screen() -> void:
	var base := EditorInterface.get_base_control()
	if base == null:
		return
	for node in base.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or button.text != L10n.ui("graph.title"):
			continue
		var viewport := button.get_viewport()
		var pos := button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = pos
		motion.global_position = pos
		viewport.push_input(motion)
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = pos
		down.global_position = pos
		viewport.push_input(down)
		await get_tree().process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = pos
		up.global_position = pos
		viewport.push_input(up)
		await get_tree().process_frame
		return

func _apply_shot_window_size() -> void:
	var target := _shot_target_size()
	if target.x <= 0 or target.y <= 0:
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_MAXIMIZED or mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(target)

## 编辑器加载布局后会把窗口恢复到屏幕尺寸；截图前再强制一次目标尺寸。
func _enforce_shot_size() -> void:
	_apply_shot_window_size()
	await get_tree().create_timer(0.5).timeout
	_apply_shot_window_size()
	await get_tree().create_timer(0.3).timeout

func _save_shot(path: String, image: Image) -> void:
	if image == null:
		return
	var target := _shot_target_size()
	if target.x > 0 and target.y > 0 and (image.get_width() != target.x or image.get_height() != target.y):
		image.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(path)
	print("[SHOT] 已保存 ", path, " ", image.get_size())

func _capture_viewport(path: String) -> void:
	var base := EditorInterface.get_base_control()
	if base == null:
		return
	var image := base.get_viewport().get_texture().get_image()
	if image != null:
		_save_shot(path, image)

func _capture_graph_screen() -> void:
	_apply_shot_window_size()
	await get_tree().create_timer(3.0).timeout
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	await _focus_main_screen()
	if _main_tabs != null:
		_main_tabs.current_tab = 0
	await get_tree().create_timer(0.5).timeout
	if _main_screen != null and _main_screen.has_method("open_graph"):
		var graph := load("res://addons/rpgeventstudio/samples/graphs/school_graph.tres")
		if graph != null:
			_main_screen.call("open_graph", graph)
			await get_tree().create_timer(0.4).timeout
			# 演示运行高亮：已完成的条件 + 正在执行的汇合 + 当前阶段
			for node in graph.nodes:
				if node == null:
					continue
				if node.type == "condition":
					_main_screen.call("apply_debug_node", "school", String(node.node_id), 2)
				elif node.type == "merge_and":
					_main_screen.call("apply_debug_node", "school", String(node.node_id), 1)
				elif node.type == "stage" and str(node.params.get("stage_id", "")) == "exploration":
					_main_screen.call("apply_debug_stage", "school", "exploration")
			await get_tree().create_timer(0.4).timeout
			_capture_viewport("res://docs/images/graph_editor_running.png")
	await get_tree().create_timer(0.8).timeout
	await _enforce_shot_size()
	var base := EditorInterface.get_base_control()
	if base != null:
		var image := base.get_viewport().get_texture().get_image()
		if image != null:
			var path := OS.get_environment("GRAPH_SHOT_PATH").strip_edges()
			if path == "":
				path = "res://docs/images/graph_editor.png"
			_save_shot(path, image)
	get_tree().quit()

func _start_map_selftest() -> void:
	if Engine.has_meta("rpg_eventstudio_map_selftest_started"):
		return
	Engine.set_meta("rpg_eventstudio_map_selftest_started", true)
	var script := load("res://tests/map_event_editor_selftest.gd")
	if script == null:
		push_error("[RPGEventStudio] 找不到地图事件自测脚本")
		get_tree().quit(2)
		return
	var runner: Node = script.new()
	runner.name = "MapEventSelfTest"
	add_child(runner)
	runner.call_deferred("start", self)

## RC 验收：打开右侧 Dock（事件编辑器 / 事件列表）并截图。
func _capture_dock_screen() -> void:
	_apply_shot_window_size()
	await get_tree().create_timer(6.0).timeout
	EditorInterface.open_scene_from_path("res://addons/rpgeventstudio/samples/scenes/school_demo.tscn")
	await get_tree().create_timer(1.5).timeout
	EditorInterface.set_main_screen_editor("2D")
	await get_tree().create_timer(0.6).timeout
	var kind := OS.get_environment("DOCK_KIND").strip_edges()
	if kind == "event":
		var root := EditorInterface.get_edited_scene_root()
		if root != null:
			var interactor := root.get_node_or_null("Librarian/EventInteractor")
			if interactor != null:
				var selection := EditorInterface.get_selection()
				selection.clear()
				selection.add_node(interactor)
		_select_dock_tab(L10n.ui("editor.title"))
	else:
		_select_dock_tab(L10n.ui("eventlist.title"))
	await get_tree().create_timer(1.2).timeout
	await _enforce_shot_size()
	var base := EditorInterface.get_base_control()
	if base != null:
		var image := base.get_viewport().get_texture().get_image()
		if image != null:
			var path := OS.get_environment("DOCK_SHOT_PATH").strip_edges()
			if path == "":
				path = "user://dock_shot.png"
			_save_shot(path, image)
	get_tree().quit()

## 在编辑器 Dock 的 TabBar/TabContainer 中按标题选中标签。
func _select_dock_tab(title: String) -> void:
	var base := EditorInterface.get_base_control()
	if base == null:
		return
	for node in base.find_children("*", "TabBar", true, false):
		var bar := node as TabBar
		for i in bar.tab_count:
			if bar.get_tab_title(i) == title:
				bar.current_tab = i
				return
	for node in base.find_children("*", "TabContainer", true, false):
		var tabs := node as TabContainer
		for i in tabs.get_tab_count():
			if tabs.get_tab_title(i) == title:
				tabs.current_tab = i
				return

## RC 验收：打开主屏指定标签页并截图（0 关卡图 / 1 主题 / 2 剧情 / 3 审计 / 4 地图事件）。
func _capture_main_tab_screen() -> void:
	_apply_shot_window_size()
	await get_tree().create_timer(6.0).timeout
	var tab := clampi(int(OS.get_environment("MAIN_TAB_INDEX")), 0, 4)
	var scene_path := "res://addons/rpgeventstudio/samples/scenes/map_events_demo.tscn" if tab == 4 else "res://addons/rpgeventstudio/samples/scenes/school_demo.tscn"
	EditorInterface.open_scene_from_path(scene_path)
	await get_tree().create_timer(1.5).timeout
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	await _focus_main_screen()
	await get_tree().create_timer(0.8).timeout
	if _main_tabs != null:
		_main_tabs.current_tab = tab
	match tab:
		0:
			if _main_screen != null:
				_main_screen.call("open_graph", load("res://addons/rpgeventstudio/samples/graphs/school_graph.tres"))
		2:
			if _story_view != null:
				_story_view.call("open_definition", load("res://addons/rpgeventstudio/samples/events/librarian.tres"), null)
		3:
			if _audit_view != null:
				_audit_view.call("_on_scan_pressed")
		4:
			if _map_view != null:
				_map_view.call("refresh")
	if tab == 1 and OS.get_environment("MAIN_TAB_PREVIEW") == "1" and _theme_view != null:
		var toggle = _theme_view.get("_preview_toggle")
		if toggle is Button:
			(toggle as Button).button_pressed = true
			(toggle as Button).toggled.emit(true)
	await get_tree().create_timer(1.8).timeout
	await _enforce_shot_size()
	var base := EditorInterface.get_base_control()
	if base != null:
		var image := base.get_viewport().get_texture().get_image()
		if image != null:
			var path := OS.get_environment("MAIN_TAB_SHOT_PATH").strip_edges()
			if path == "":
				path = "user://main_tab_shot.png"
			_save_shot(path, image)
	get_tree().quit()

func _capture_theme_screen() -> void:
	_apply_shot_window_size()
	await get_tree().create_timer(8.0).timeout
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	await _focus_main_screen()
	await get_tree().create_timer(0.8).timeout
	if _main_tabs != null:
		_main_tabs.current_tab = 1
		print("[SHOT] theme tab=", _main_tabs.current_tab, " visible=", _main_tabs.visible)
	if _theme_view != null:
		var sample = _theme_view.get("_sample")
		if sample is OptionButton:
			(sample as OptionButton).selected = 1
			(sample as OptionButton).item_selected.emit(1)
		_theme_view.call("_play_preview")
	await get_tree().create_timer(1.0).timeout
	await _enforce_shot_size()
	var base := EditorInterface.get_base_control()
	if base != null:
		var image := base.get_viewport().get_texture().get_image()
		if image != null:
			var path := OS.get_environment("THEME_SHOT_PATH")
			if path.strip_edges() == "":
				path = "user://theme_editor.png"
			_save_shot(path, image)
	get_tree().quit()

func _capture_map_screen() -> void:
	_apply_shot_window_size()
	await get_tree().create_timer(2.0).timeout
	EditorInterface.open_scene_from_path("res://addons/rpgeventstudio/samples/scenes/map_events_demo.tscn")
	await get_tree().create_timer(1.2).timeout
	EditorInterface.set_main_screen_editor("2D")
	await get_tree().create_timer(0.6).timeout
	var root := EditorInterface.get_edited_scene_root()
	if root != null:
		var node := root.get_node_or_null("Trigger_Region")
		if node != null:
			var selection := EditorInterface.get_selection()
			selection.clear()
			selection.add_node(node)
	if _map_panel != null:
		_map_panel.call("refresh")
	if _map_view != null:
		_map_view.call("refresh")
	if OS.get_environment("MAP_SHOT_TAB") == "1":
		EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
		await _focus_main_screen()
		if _main_tabs != null:
			_main_tabs.current_tab = 4
	await get_tree().create_timer(0.5).timeout
	await _enforce_shot_size()
	var base := EditorInterface.get_base_control()
	if base != null:
		var image := base.get_viewport().get_texture().get_image()
		if image != null:
			var path := OS.get_environment("MAP_SHOT_PATH").strip_edges()
			if path == "":
				path = "res://docs/images/map_events_editor.png"
			_save_shot(path, image)
	get_tree().quit()

## 状态库批量登记：RPGEVENTSTUDIO_BULK_SHOT=1 打开批量登记对话框并保存一张图。
func _capture_bulk_screen() -> void:
	await get_tree().create_timer(3.0).timeout
	var bulk := StateBulkRegisterDialog.new()
	var base := EditorInterface.get_base_control()
	if base == null:
		get_tree().quit(2)
		return
	base.add_child(bulk)
	bulk.open_dialog()
	await get_tree().create_timer(0.8).timeout
	await bulk.call("_on_scan_pressed")
	await get_tree().create_timer(1.0).timeout
	var image := base.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("res://docs/images/state_bulk_register.png")
		print("[SHOT] 已保存 docs/images/state_bulk_register.png")
	# 第二张：预览确认界面
	if bulk.get("_preview") != null:
		bulk.call("_on_register_pressed")
		await get_tree().create_timer(0.6).timeout
		image = base.get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("res://docs/images/state_bulk_register_preview.png")
			print("[SHOT] 已保存 docs/images/state_bulk_register_preview.png")
	get_tree().quit()

func _start_selftest() -> void:
	# 编辑器可能在启动时重载插件，这里保证一个进程里只跑一次
	if Engine.has_meta("rpg_eventstudio_selftest_started"):
		return
	Engine.set_meta("rpg_eventstudio_selftest_started", true)

	var script := load("res://tests/editor_selftest.gd")
	if script == null:
		push_error("[RPGEventStudio] " + L10n.ui("diag.selftest_missing"))
		return
	var runner: Node = script.new()
	runner.name = "EditorSelfTest"
	add_child(runner)
	runner.call_deferred("start", _panel)

## 关卡图校验 / 分组 / 布局的编辑器内自测（真实编辑器环境）。
func _start_gvl_selftest() -> void:
	if Engine.has_meta("rpg_eventstudio_gvl_selftest_started"):
		return
	Engine.set_meta("rpg_eventstudio_gvl_selftest_started", true)
	var script := load("res://tests/graph_editor_gvl_selftest.gd")
	if script == null:
		push_error("[RPGEventStudio] 找不到关卡图编辑器自测脚本")
		get_tree().quit(2)
		return
	var runner: Node = script.new()
	runner.name = "GraphEditorGvlSelfTest"
	add_child(runner)
	runner.call_deferred("start", self, _main_screen)

## 开发截图：打开关卡图主屏，展示检查结果面板与分组框。
func _capture_gvl_screen() -> void:
	_apply_shot_window_size()
	await get_tree().create_timer(3.0).timeout
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	await _focus_main_screen()
	if _main_tabs != null:
		_main_tabs.current_tab = 0
	await get_tree().create_timer(0.5).timeout
	if _main_screen != null and _main_screen.has_method("open_graph"):
		var graph := load("res://addons/rpgeventstudio/samples/graphs/school_graph.tres")
		if graph != null:
			_main_screen.call("open_graph", graph)
			await get_tree().create_timer(0.4).timeout
			if _main_screen.has_method("gvl_acceptance_setup"):
				await _main_screen.call("gvl_acceptance_setup")
			await get_tree().create_timer(0.6).timeout
			await _enforce_shot_size()
			_capture_viewport("res://docs/images/graph_editor_validation.png")
	await get_tree().create_timer(0.8).timeout
	get_tree().quit()

## 剧情工作台自测 / 截图（RPGEVENTSTUDIO_STORY_SELFTEST=1 / RPGEVENTSTUDIO_STORY_SHOT=1）。
func _start_story_test() -> void:
	if Engine.has_meta("rpg_eventstudio_story_test_started"):
		return
	Engine.set_meta("rpg_eventstudio_story_test_started", true)
	var script := load("res://tests/story_editor_selftest.gd")
	if script == null:
		push_error("[RPGEventStudio] 找不到剧情工作台自测脚本")
		get_tree().quit(2)
		return
	var runner: Node = script.new()
	runner.name = "StorySelfTest"
	add_child(runner)
	runner.call_deferred("start", self, _story_view)

## 剧情资源审计自测（真实编辑器环境）：RPGEVENTSTUDIO_AUDIT_SELFTEST=1。
func _start_audit_selftest() -> void:
	if Engine.has_meta("rpg_eventstudio_audit_selftest_started"):
		return
	Engine.set_meta("rpg_eventstudio_audit_selftest_started", true)
	var script := load("res://tests/story_audit_editor_selftest.gd")
	if script == null:
		push_error("[RPGEventStudio] 找不到剧情审计自测脚本")
		get_tree().quit(2)
		return
	var runner: Node = script.new()
	runner.name = "StoryAuditSelfTest"
	add_child(runner)
	runner.call_deferred("start", self, _audit_view)


## 运行时追踪视图的编辑器验收：RPGEVENTSTUDIO_TRACE_SELFTEST=1。
func _start_trace_selftest() -> void:
	if Engine.has_meta("rpg_eventstudio_trace_selftest_started"):
		return
	Engine.set_meta("rpg_eventstudio_trace_selftest_started", true)
	var script := load("res://tests/trace_editor_selftest.gd")
	if script == null:
		push_error("[RPGEventStudio] 找不到追踪编辑器自测脚本")
		get_tree().quit(2)
		return
	var runner: Node = script.new()
	runner.name = "TraceEditorSelfTest"
	add_child(runner)
	runner.call_deferred("start", self)
