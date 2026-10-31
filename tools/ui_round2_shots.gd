extends SceneTree
## 第二批 UI 验收截图（真实窗口渲染，支持固定 1152×648 / 1280×820）：
##   godot --path . --script res://tools/ui_round2_shots.gd -- 1152 648
## 输出：docs/images/ui-polish-round2/after/<name>_<w>x<h>.png
## 说明：关卡图/主题/地图事件页使用真实编辑器控件实例，不依赖编辑器停靠布局；
##       地图事件通过 scene_root_override 注入示例场景，保证在非编辑器环境也能截到真实数据。

const DEFAULT_OUT_DIR := "res://docs/images/ui-polish-round2/after"
var _out_dir := DEFAULT_OUT_DIR

var _w := 1152
var _h := 648
var _ui_layer: CanvasLayer
var _ui_root: Control

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		_w = int(args[0])
		_h = int(args[1])
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	var env_dir := OS.get_environment("ROUND2_SHOT_DIR").strip_edges()
	if env_dir != "":
		_out_dir = env_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	await create_timer(0.4).timeout

	var scene: Node = load("res://addons/rpgeventstudio/samples/scenes/school_demo.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.8).timeout
	var runtime := root.get_node_or_null("RPGEventStudio")
	if runtime == null:
		quit(1)
		return

	await _shot_trace(runtime)
	await _shot_dialogue(runtime)
	if OS.get_environment("ROUND2_SHOT_ONLY") == "game":
		await _shot_input(runtime)
		quit()
		return
	# 后面是编辑器页截图：隐藏游戏场景，避免 2D 世界/CanvasLayer 盖住编辑器控件。
	scene.visible = false
	await create_timer(0.2).timeout
	await _shot_graph()
	await _shot_theme()
	await _shot_map(scene)
	await _shot_input(runtime)
	quit()

func _shot_name(name: String) -> String:
	return "%s/%s_%dx%d.png" % [_out_dir, name, _w, _h]

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		return
	image.save_png(path)
	print("[ROUND2] ", path, " ", image.get_size())

## 编辑器页放到高层 CanvasLayer，避免被示例场景的 Camera2D/CanvasLayer 变换。
func _overlay() -> Control:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 100
	root.add_child(_ui_layer)
	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_ui_root)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(bg)
	return _ui_root

func _drop_overlay() -> void:
	if _ui_layer != null:
		_ui_layer.queue_free()
	_ui_layer = null
	_ui_root = null

# ── A：运行追踪自然/专业视图 ──────────────────────────────

func _shot_trace(runtime: Node) -> void:
	runtime.call("set_trace_enabled", true)
	runtime.call("clear_trace")
	runtime.call("set_state", "School.Office.DiaryFound", true)
	runtime.call("set_state", "School.Classroom.ClueFound", false)
	var librarian: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	runtime.call("start_event", librarian, {}, [], {"kind": "interactor", "node": "Librarian/EventInteractor"})
	await create_timer(0.7).timeout
	runtime.call("cancel_all", "shot")
	await create_timer(0.3).timeout
	var basement: EventDefinition = load("res://addons/rpgeventstudio/samples/events/basement_cutscene.tres")
	runtime.call("start_event", basement, {}, ["autorun"], {"kind": "autorun", "node": "Shot"})
	await create_timer(0.4).timeout
	runtime.call("cancel_all", "shot")
	await create_timer(0.3).timeout

	runtime.call("open_state_debug")
	var panel: Node = runtime.get("debug_panel")
	if panel == null:
		return
	panel.call("_show_trace", true)
	await create_timer(0.6).timeout
	var view: Node = panel.get("_trace_view")
	if view == null:
		return
	view.call("refresh", true)
	await create_timer(0.2).timeout
	_select_trace_row(view, "condition")
	await create_timer(0.2).timeout

	var mode: OptionButton = view.get("_detail_mode")
	if mode != null:
		mode.select(0)
	view.call("refresh", true)
	view.call("_on_selected")
	await create_timer(0.2).timeout
	await _shot(_shot_name("a_trace_natural"))

	if mode != null:
		mode.select(1)
	view.call("refresh", true)
	view.call("_on_selected")
	await create_timer(0.2).timeout
	await _shot(_shot_name("a_trace_raw"))

	panel.call("close_panel")
	await create_timer(0.2).timeout
	runtime.call("cancel_all", "shot")

func _select_trace_row(view: Node, kind: String) -> void:
	var tree: Tree = view.get("_tree")
	if tree == null or tree.get_root() == null:
		return
	var fallback: TreeItem = null
	for index in tree.get_root().get_child_count():
		var item := tree.get_root().get_child(index)
		if fallback == null:
			fallback = item
		var record: Dictionary = item.get_metadata(0)
		if str(record.get("kind", "")) == kind:
			tree.set_selected(item, 0)
			view.call("_on_selected")
			return
	if fallback != null:
		tree.set_selected(fallback, 0)
		view.call("_on_selected")

# ── C：对话框长短文本/选项 ────────────────────────────────

func _shot_dialogue(runtime: Node) -> void:
	runtime.call("cancel_all", "shot")
	var presenter: Node = runtime.get("presenter")
	if presenter == null:
		return
	presenter.call("close_all")
	var long_text := "这是一段用于验收的较长正文。对话框的底边固定、顶边随内容伸缩：文本越长，面板越高；文本很短时，面板保持最小高度，不会在两句台词之间跳动。当正文超过窗口可用高度时，正文区域出现滚动条，面板不会被顶出屏幕之外。这一行继续补充长度，用来验证多行文本下的排版与滚动行为。最后再补一段，确保在两种验收分辨率下都能看到自适应与滚动的效果。"
	presenter.call("show_text", "验收旁白", long_text)
	presenter.call("_finish_typing")
	await create_timer(0.6).timeout
	await _shot(_shot_name("c_dialogue_long"))

	presenter.call("show_text", "验收旁白", "短句。")
	presenter.call("_finish_typing")
	await create_timer(0.4).timeout
	await _shot(_shot_name("c_dialogue_short"))

	presenter.call("show_choices", "要问点什么吗？", ["询问钥匙", "离开"])
	await create_timer(0.5).timeout
	await _shot(_shot_name("c_dialogue_choices"))
	presenter.call("close_all")
	await create_timer(0.2).timeout

# ── E：关卡总控图 ─────────────────────────────────────────

func _shot_graph() -> void:
	var ui := _overlay()
	var view: Control = load("res://addons/rpgeventstudio/editor/level_graph/level_graph_view.gd").new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(view)
	await create_timer(0.3).timeout
	view.call("open_graph", load("res://addons/rpgeventstudio/samples/graphs/school_graph.tres"))
	await create_timer(1.0).timeout
	await _shot(_shot_name("e_graph"))
	_drop_overlay()
	await create_timer(0.3).timeout

# ── G：UI 主题编辑器 ──────────────────────────────────────

func _shot_theme() -> void:
	var ui := _overlay()
	var view: Control = load("res://addons/rpgeventstudio/editor/theme/dialogue_theme_view.gd").new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(view)
	await create_timer(1.0).timeout
	var sample: OptionButton = view.get("_sample")
	if sample != null:
		sample.selected = 1
		sample.item_selected.emit(1)
	await create_timer(0.6).timeout
	await _shot(_shot_name("g_theme"))
	_drop_overlay()
	await create_timer(0.3).timeout

# ── F：地图事件编辑器 ─────────────────────────────────────

func _shot_map(_scene: Node) -> void:
	var map_scene: Node = load("res://addons/rpgeventstudio/samples/scenes/map_events_demo.tscn").instantiate()
	map_scene.visible = false
	root.add_child(map_scene)
	await create_timer(0.5).timeout
	var ui := _overlay()
	var panel: Control = load("res://addons/rpgeventstudio/editor/map_events/map_event_panel.gd").new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.set("scene_root_override", map_scene)
	ui.add_child(panel)
	await create_timer(0.4).timeout
	panel.call("refresh")
	var target: Node = map_scene.get_node_or_null("Trigger_Region")
	if target != null:
		panel.call("on_selection_changed", [target])
	await create_timer(0.4).timeout
	await _shot(_shot_name("f_map_events"))
	_drop_overlay()
	map_scene.queue_free()
	await create_timer(0.3).timeout

# ── H：F1 按键设置小窗口 ─────────────────────────────────

func _shot_input(runtime: Node) -> void:
	runtime.call("open_input_settings")
	await create_timer(0.6).timeout
	await _shot(_shot_name("h_input_settings"))
	runtime.call("close_input_settings")
	await create_timer(0.2).timeout
