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
const RUNTIME_SCRIPT := "res://addons/rpgeventstudio/runtime/autoload/studio_runtime.gd"
const AUTOLOAD_NAME := "RPGEventStudio"
const EDITOR_LANGUAGE_SETTING := "rpg_event_studio/editor_language"

var _panel: Control
var _main_screen: Control
var _list_panel: Control
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

func _exit_tree() -> void:
	if _selection != null and _selection.selection_changed.is_connected(_on_selection_changed):
		_selection.selection_changed.disconnect(_on_selection_changed)
	_selection = null

	if _panel != null:
		remove_control_from_docks(_panel)
		_panel.queue_free()
		_panel = null

	if _main_screen != null:
		_main_screen.queue_free()
		_main_screen = null

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
	if _main_screen != null:
		_main_screen.call("open_graph", graph)

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
	_main_screen = script.new()
	_main_screen.name = "LevelGraph"
	_main_screen.call("bind_plugin", self)
	EditorInterface.get_editor_main_screen().add_child(_main_screen)
	_main_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	if _main_screen != null:
		_main_screen.visible = visible

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
