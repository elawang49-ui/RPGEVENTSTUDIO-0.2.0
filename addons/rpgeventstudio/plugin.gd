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
const RUNTIME_SCRIPT := "res://addons/rpgeventstudio/runtime/autoload/studio_runtime.gd"
const AUTOLOAD_NAME := "RPGEventStudio"
const EDITOR_LANGUAGE_SETTING := "rpg_event_studio/editor_language"

var _panel: Control
var _main_tabs: TabContainer
var _main_screen: Control
var _theme_view: Control
var _list_panel: Control
var _map_panel: Control
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
	_create_map_dock()
	_create_debugger()
	_connect_selection()

	if OS.get_environment("RPGEVENTSTUDIO_SELFTEST") == "1":
		_start_selftest.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_SHOT") == "1":
		_capture_graph_screen.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_MAP_SELFTEST") == "1":
		_start_map_selftest.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_MAP_SHOT") == "1":
		_capture_map_screen.call_deferred()
	if OS.get_environment("RPGEVENTSTUDIO_THEME_SHOT") == "1":
		_capture_theme_screen.call_deferred()

func _exit_tree() -> void:
	if _selection != null and _selection.selection_changed.is_connected(_on_selection_changed):
		_selection.selection_changed.disconnect(_on_selection_changed)
	_selection = null

	if _panel != null:
		remove_control_from_docks(_panel)
		_panel.queue_free()
		_panel = null

	if _main_tabs != null:
		_main_tabs.queue_free()
		_main_tabs = null
	_main_screen = null
	_theme_view = null

	if _filesystem != null and _filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		_filesystem.filesystem_changed.disconnect(_on_filesystem_changed)
	_filesystem = null

	if _list_panel != null:
		remove_control_from_docks(_list_panel)
		_list_panel.queue_free()
		_list_panel = null

	if _map_panel != null:
		remove_control_from_docks(_map_panel)
		_map_panel.queue_free()
		_map_panel = null

	if _debugger_plugin != null:
		remove_debugger_plugin(_debugger_plugin)
		_debugger_plugin = null

	_release_autoload()

# ── 面板 ─────────────────────────────────────────────────

func _create_dock() -> void:
	var script := load(PANEL_SCRIPT)
	if script == null:
		push_error("[RPGEventStudio] " + L10n.ui("diag.panel_missing"))
		return
	_panel = script.new()
	_panel.name = L10n.ui("editor.title")
	_panel.call("bind_plugin", self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _panel)

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
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _list_panel)

	_filesystem = EditorInterface.get_resource_filesystem()
	if _filesystem != null and not _filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		_filesystem.filesystem_changed.connect(_on_filesystem_changed)

# ── 地图事件 ─────────────────────────────────────────────

func _create_map_dock() -> void:
	var script := load(MAP_SCRIPT)
	if script == null:
		push_error("[RPGEventStudio] 找不到地图事件面板脚本")
		return
	_map_panel = script.new()
	_map_panel.name = L10n.ui("map.title")
	_map_panel.custom_minimum_size = Vector2(300, 0)
	_map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_panel.event_activated.connect(_open_event)
	_map_panel.place_requested.connect(_on_place_map_event)
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, _map_panel)

func refresh_map_events() -> void:
	if _map_panel != null:
		_map_panel.call("refresh")

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

func _open_graph(graph: LevelGraph) -> void:
	if graph == null:
		return
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	if _main_tabs != null:
		_main_tabs.current_tab = 0
	if _main_screen != null:
		_main_screen.call("open_graph", graph)

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
	add_debugger_plugin(_debugger_plugin)

func _on_debug_node(graph_id: String, node_id: String, state: int) -> void:
	if _main_screen != null and _main_screen.has_method("apply_debug_node"):
		_main_screen.call("apply_debug_node", graph_id, node_id, state)

func _on_debug_stage(graph_id: String, stage: String) -> void:
	if _main_screen != null and _main_screen.has_method("apply_debug_stage"):
		_main_screen.call("apply_debug_stage", graph_id, stage)

# ── 主屏：关卡图 ─────────────────────────────────────────

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
	if _map_panel != null:
		_map_panel.call("on_selection_changed", nodes)

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

func _ensure_autoload() -> void:
	var key := "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.has_setting(key):
		return
	add_autoload_singleton(AUTOLOAD_NAME, RUNTIME_SCRIPT)

func _release_autoload() -> void:
	var key := "autoload/" + AUTOLOAD_NAME
	if not ProjectSettings.has_setting(key):
		return
	var value := str(ProjectSettings.get_setting(key)).trim_prefix("*")
	if value == RUNTIME_SCRIPT:
		remove_autoload_singleton(AUTOLOAD_NAME)

# ── 测试钩子（仅 RPGEVENTSTUDIO_SELFTEST=1 时启用） ─────

## 仅用于开发截图：RPGEVENTSTUDIO_SHOT=1 打开关卡图主屏并保存一张图。
func _capture_viewport(path: String) -> void:
	var base := EditorInterface.get_base_control()
	if base == null:
		return
	var image := base.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(path)
		print("[SHOT] 已保存 ", path)

func _capture_graph_screen() -> void:
	await get_tree().create_timer(3.0).timeout
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
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
	var base := EditorInterface.get_base_control()
	if base != null:
		var image := base.get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("res://docs/images/graph_editor.png")
			print("[SHOT] 已保存 docs/images/graph_editor.png")
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

func _capture_theme_screen() -> void:
	await get_tree().create_timer(4.0).timeout
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	await get_tree().create_timer(0.8).timeout
	EditorInterface.set_main_screen_editor(L10n.ui("graph.title"))
	if _main_tabs != null:
		_main_tabs.current_tab = 1
		print("[SHOT] theme tab=", _main_tabs.current_tab, " visible=", _main_tabs.visible)
	if _theme_view != null:
		var sample = _theme_view.get("_sample")
		if sample is OptionButton:
			(sample as OptionButton).selected = 1
			(sample as OptionButton).item_selected.emit(1)
		_theme_view.call("_play_preview")
	await get_tree().create_timer(1.5).timeout
	var base := EditorInterface.get_base_control()
	if base != null:
		var image := base.get_viewport().get_texture().get_image()
		if image != null:
			var path := OS.get_environment("THEME_SHOT_PATH")
			if path.strip_edges() == "":
				path = "user://theme_editor.png"
			image.save_png(path)
			print("[SHOT] 已保存 ", path)
	get_tree().quit()

func _capture_map_screen() -> void:
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
	await get_tree().create_timer(0.5).timeout
	var base := EditorInterface.get_base_control()
	if base != null:
		var image := base.get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("res://docs/images/map_events_editor.png")
			print("[SHOT] 已保存 docs/images/map_events_editor.png")
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
