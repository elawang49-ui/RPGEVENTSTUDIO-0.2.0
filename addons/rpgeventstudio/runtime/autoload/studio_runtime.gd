extends Node
class_name StudioRuntime
## 运行时宿主（Autoload 名：RPGEventStudio）。
## 组装状态服务、事件运行时、对话界面、按键设置面板，并处理游戏语言。

signal language_changed(locale: String)
signal dialogue_theme_changed(theme: RpgEventStudioTheme)

const AUTOLOAD_NAME := "RPGEventStudio"
const DIALOGUE_THEME_PATH := "res://ui/rpgeventstudio_theme.tres"
const INTERACT_ACTION := &"interact"

var state: StateStore
## 运行时剧情追踪（F2 面板使用；可通过 RPG_EVENT_STUDIO_TRACE=0/1 覆盖）。
var trace: RuntimeTrace
var bus: EventBus
var registry: CommandRegistry
var runner: EventRunner
## 当前展示层。默认是插件的 DialoguePresenter，游戏可通过 set_presenter() 换成自己的实现。
var presenter
var default_presenter: DialoguePresenter
var dialogue_theme: RpgEventStudioTheme
var input: InputService
var interaction: InteractionManager
var settings_panel: InputSettingsPanel
var debug_panel: StateDebugPanel

## 最近一次「事件没执行」的诊断（调试面板显示）
var last_rejections: Array = []

var current_level: StringName = &"school"
var level_prefix: String = "School"

## 正在运行的关卡图（进入关卡时由 LevelGraphRunner2D 注册）
var graphs: Array = []
## 每个注册图对应的编辑器转发连接（图停止随注销一并断开）
var _graph_forwards: Dictionary = {}

var _scene_scope: Node = null
var _scene_bind_queued := false
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# 语言：先注册翻译，再应用玩家上次选择的语言
	L10n.register_runtime_translations()
	L10n.set_game_locale(L10n.load_game_locale(), false)

	registry = CommandRegistry.new()
	state = StateStore.new()
	state.level_prefix = level_prefix
	trace = RuntimeTrace.new()
	trace.configure(_trace_enabled_by_default(), _trace_capacity())
	state.write_observer = func(key: String, old_value: Variant, new_value: Variant, existed: bool) -> void:
		if trace != null:
			trace.state_changed(key, old_value, new_value, existed)
	bus = EventBus.new()
	bus.event_rejected.connect(_on_event_rejected)

	input = InputService.new()

	interaction = InteractionManager.new()
	interaction.name = "Interaction"
	interaction.runtime = self
	add_child(interaction)

	default_presenter = DialoguePresenter.new()
	default_presenter.name = "Presenter"
	default_presenter.input = input
	add_child(default_presenter)
	presenter = default_presenter

	dialogue_theme = _load_dialogue_theme()
	default_presenter.set_dialogue_theme(dialogue_theme)

	settings_panel = InputSettingsPanel.new()
	settings_panel.name = "InputSettings"
	settings_panel.input = input
	settings_panel.presenter = default_presenter
	settings_panel.locale_changed.connect(_on_locale_changed)
	add_child(settings_panel)

	debug_panel = StateDebugPanel.new()
	debug_panel.name = "StateDebug"
	debug_panel.runtime = self
	add_child(debug_panel)

	runner = EventRunner.new()
	runner.host = self
	runner.state = state
	runner.bus = bus
	runner.presenter = presenter
	runner.registry = registry
	runner.trace = trace

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPlayer"
	add_child(_sfx_player)
	get_tree().scene_changed.connect(_bind_scene_scope)
	get_tree().node_added.connect(_queue_scene_bind)
	_bind_scene_scope.call_deferred()

func _queue_scene_bind(_node: Node) -> void:
	if _scene_bind_queued or (is_instance_valid(_scene_scope) and _scene_scope == get_tree().current_scene):
		return
	_scene_bind_queued = true
	_bind_scene_scope.call_deferred()

func _bind_scene_scope() -> void:
	_scene_bind_queued = false
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene == _scene_scope:
		return
	if is_instance_valid(_scene_scope):
		if _scene_scope.tree_exiting.is_connected(_on_scene_scope_exiting):
			_scene_scope.tree_exiting.disconnect(_on_scene_scope_exiting)
		_on_scene_scope_exiting()
	_scene_scope = scene
	if is_instance_valid(scene):
		scene.tree_exiting.connect(_on_scene_scope_exiting)

func _on_scene_scope_exiting() -> void:
	cancel_all("scene scope ended")
	for graph in graphs.duplicate():
		graph.stop()
	last_rejections.clear()

# ── 事件 API（游戏脚本可以直接用） ───────────────────────

func start_event(definition: EventDefinition, args: Dictionary = {}, trigger_filter: Array = [],
		source: Dictionary = {}) -> void:
	if runner == null or definition == null:
		return
	runner.start(definition, args, trigger_filter, source)

func cancel_all(reason: String = "手动取消") -> void:
	if runner != null:
		runner.cancel_all(reason)

func is_event_running(event_id: StringName) -> bool:
	return runner != null and runner.is_busy(event_id)

# ── 展示层注入 ───────────────────────────────────────────
#
# 事件指令只依赖展示协议，不依赖具体 UI：
#   show_text(speaker, text, auto_advance)
#   is_text_finished() -> bool
#   show_choices(prompt, options)
#   get_choice() -> int          # 0 起，未选择时 -1
#   close_all()                  # 可选
#   fade_to(alpha, duration)     # 可选
#
# 默认展示层永远不会被替换掉；注入自定义展示层后可随时 restore_default_presenter()。

## 注入游戏自己的展示层。传 null 等价于恢复插件默认 UI。
## 返回 false 表示对象不满足展示协议（会保持当前展示层不变）。
func set_presenter(custom) -> bool:
	if custom == null:
		return restore_default_presenter()
	if not _is_valid_presenter(custom):
		push_error("[RPGEventStudio] 自定义 presenter 缺少协议方法：%s" % str(custom))
		return false
	if presenter != null and not is_instance_valid(presenter):
		# 上一个展示层随场景被释放了：先断开，避免保留悬空引用。
		presenter = null
		if runner != null:
			runner.presenter = null
	if custom == presenter:
		return true
	_cancel_running_events("presenter 已替换")
	_close_current_presenter()
	presenter = custom
	if custom is Node and not (custom as Node).is_inside_tree():
		add_child(custom)
	_apply_presenter()
	_sync_default_presenter_activity()
	return true

## 恢复插件默认 UI（不影响游戏自己的节点）。
func restore_default_presenter() -> bool:
	if default_presenter == null:
		return false
	if presenter == default_presenter:
		_sync_default_presenter_activity()
		return true
	_cancel_running_events("恢复插件默认 UI")
	_close_current_presenter()
	presenter = default_presenter
	_apply_presenter()
	_sync_default_presenter_activity()
	return true

func is_using_default_presenter() -> bool:
	return presenter == default_presenter

# ── 主题 ─────────────────────────────────────────────────

func reload_dialogue_theme() -> RpgEventStudioTheme:
	dialogue_theme = _load_dialogue_theme()
	if default_presenter != null:
		default_presenter.set_dialogue_theme(dialogue_theme)
	dialogue_theme_changed.emit(dialogue_theme)
	return dialogue_theme

func apply_dialogue_theme(theme: RpgEventStudioTheme) -> void:
	dialogue_theme = theme if theme != null else RpgEventStudioTheme.new()
	if default_presenter != null:
		default_presenter.set_dialogue_theme(dialogue_theme)
	dialogue_theme_changed.emit(dialogue_theme)

func _load_dialogue_theme() -> RpgEventStudioTheme:
	if ResourceLoader.exists(DIALOGUE_THEME_PATH):
		var loaded := load(DIALOGUE_THEME_PATH)
		if loaded is RpgEventStudioTheme:
			return loaded
		push_warning("[RPGEventStudio] 主题文件不是 RpgEventStudioTheme：%s" % DIALOGUE_THEME_PATH)
	return RpgEventStudioTheme.new()

func _is_valid_presenter(candidate) -> bool:
	if candidate == null or not (candidate is Object):
		return false
	for method in [&"show_text", &"is_text_finished", &"show_choices", &"get_choice"]:
		if not candidate.has_method(method):
			return false
	return true

func _cancel_running_events(reason: String) -> void:
	if runner != null and runner.active_count() > 0:
		runner.cancel_all(reason)

func _close_current_presenter() -> void:
	if presenter == null or not is_instance_valid(presenter):
		return
	if presenter.has_method("close_all"):
		presenter.close_all()

func _apply_presenter() -> void:
	if runner != null:
		runner.presenter = presenter
	if settings_panel != null:
		settings_panel.presenter = presenter

## 自定义展示层生效时，默认 UI 不再显示、也不再接收输入；
## 恢复默认时再打开。这样两套 UI 不会同时抢输入。
func _sync_default_presenter_activity() -> void:
	if default_presenter == null:
		return
	var active: bool = presenter == default_presenter
	default_presenter.visible = active
	default_presenter.set_process(active)
	default_presenter.set_process_input(active)

func _trace_enabled_by_default() -> bool:
	var env := OS.get_environment("RPG_EVENT_STUDIO_TRACE")
	if env == "1":
		return true
	if env == "0":
		return false
	return OS.is_debug_build()

func _trace_capacity() -> int:
	var raw := OS.get_environment("RPG_EVENT_STUDIO_TRACE_CAPACITY")
	return int(raw) if raw.is_valid_int() else RuntimeTrace.DEFAULT_CAPACITY

func set_trace_enabled(value: bool) -> void:
	if trace != null:
		trace.enabled = value

func clear_trace() -> void:
	if trace != null:
		trace.clear()

func trace_json() -> String:
	return trace.export_json() if trace != null else ""

## 从 F2 面板定位：发给编辑器调试器（未从编辑器启动时无副作用）。
func trace_focus_node(graph_id: String, node_id: String, graph_path: String = "") -> void:
	_debug_send("trace_node", [graph_id, node_id, graph_path])

func trace_focus_event(event_id: String, event_path: String = "") -> void:
	_debug_send("trace_event", [event_id, event_path])

func register_graph(graph_runner: GraphRunner) -> void:
	if graph_runner == null:
		return
	if graph_runner.trace == null:
		graph_runner.trace = trace
	if not graphs.has(graph_runner):
		graphs.append(graph_runner)
		# 把执行进度发给编辑器（只在从编辑器启动时生效，导出后没有成本）
		var graph_id := String(graph_runner.graph.graph_id) if graph_runner.graph != null else ""
		var node_forward: Callable = func(node_id: StringName, state: int) -> void:
			_debug_send("node", [graph_id, String(node_id), state])
		var stage_forward: Callable = func(_level_id: StringName, stage: String) -> void:
			_debug_send("stage", [graph_id, stage])
		graph_runner.node_state_changed.connect(node_forward)
		graph_runner.stage_changed.connect(stage_forward)
		_graph_forwards[graph_runner] = {"node": node_forward, "stage": stage_forward}
		# 图停止时（关卡场景释放 / 手动 stop_graph）自动注销
		graph_runner.stopped.connect(_on_graph_stopped)

## 图停止广播：从 graphs 注销，转发与广播连接一并清掉。
func _on_graph_stopped(graph_runner: GraphRunner) -> void:
	_unregister_graph(graph_runner)

func _unregister_graph(graph_runner: GraphRunner) -> void:
	if graph_runner == null:
		return
	graphs.erase(graph_runner)
	var forwards: Dictionary = _graph_forwards.get(graph_runner, {})
	_graph_forwards.erase(graph_runner)
	if forwards.has("node") and graph_runner.node_state_changed.is_connected(forwards["node"]):
		graph_runner.node_state_changed.disconnect(forwards["node"])
	if forwards.has("stage") and graph_runner.stage_changed.is_connected(forwards["stage"]):
		graph_runner.stage_changed.disconnect(forwards["stage"])
	if graph_runner.stopped.is_connected(_on_graph_stopped):
		graph_runner.stopped.disconnect(_on_graph_stopped)

func _debug_send(kind: String, payload: Array) -> void:
	if EngineDebugger.is_active():
		EngineDebugger.send_message("rpg_event_studio:" + kind, payload)

func get_graph_runner(graph_id: StringName = &"") -> GraphRunner:
	for item in graphs:
		var runner: GraphRunner = item
		if runner == null or not is_instance_valid(runner):
			continue
		if graph_id == &"" or (runner.graph != null and runner.graph.graph_id == graph_id):
			return runner
	return null

func current_stage() -> String:
	return str(state.get_value("%s.Stage" % level_prefix, ""))

func is_ui_blocking() -> bool:
	return (settings_panel != null and settings_panel.is_open()) or (debug_panel != null and debug_panel.is_open())

func get_state(key: String, fallback: Variant = null) -> Variant:
	return state.get_value(key, fallback)

func set_state(key: String, value: Variant) -> int:
	return state.set_value(key, value)

func state_dump() -> String:
	return state.dump()

# ── 按键设置 ─────────────────────────────────────────────

func open_input_settings() -> void:
	if settings_panel == null:
		return
	settings_panel.open()

func close_input_settings() -> void:
	if settings_panel == null:
		return
	settings_panel.close()

func open_state_debug() -> void:
	if debug_panel != null:
		debug_panel.open()

func close_state_debug() -> void:
	if debug_panel != null:
		debug_panel.close_panel()

func toggle_state_debug() -> void:
	if debug_panel == null:
		return
	if debug_panel.is_open():
		debug_panel.close_panel()
	else:
		debug_panel.open()

func _on_event_rejected(event_id: StringName, diagnosis: Dictionary) -> void:
	last_rejections.push_front({
		"event_id": event_id,
		"diagnosis": diagnosis,
		"at": Time.get_ticks_msec(),
	})
	while last_rejections.size() > 5:
		last_rejections.pop_back()

func toggle_input_settings() -> void:
	if settings_panel == null:
		return
	if settings_panel.is_open():
		settings_panel.close()
	else:
		settings_panel.open()

# ── 语言 ─────────────────────────────────────────────────

func set_game_locale(locale: String) -> void:
	L10n.set_game_locale(locale)
	language_changed.emit(locale)

func get_game_locale() -> String:
	return L10n.get_game_locale()

func _on_locale_changed(locale: String) -> void:
	language_changed.emit(locale)

# ── 输入 ─────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if settings_panel != null and settings_panel.is_listening():
		return
	if event.is_action_pressed(InputService.ACTION_TOGGLE_SETTINGS):
		toggle_input_settings()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(InputService.ACTION_TOGGLE_DEBUG):
		toggle_state_debug()
		get_viewport().set_input_as_handled()

# ── 声音 ─────────────────────────────────────────────────

func is_sfx_playing() -> bool:
	return _sfx_player != null and _sfx_player.playing

func play_sfx(path: String, volume_db: float = 0.0) -> void:
	if _sfx_player == null:
		return
	var stream := load(path)
	if stream is AudioStream:
		_sfx_player.stream = stream
		_sfx_player.volume_db = volume_db
		_sfx_player.play()

func _exit_tree() -> void:
	for graph in graphs.duplicate():
		graph.stop()
	# 游戏关闭 / 运行时被释放：先让等待中的事件结束，再收掉两套 UI。
	if runner != null:
		runner.cancel_all("运行时退出")
	for candidate in [presenter, default_presenter]:
		if candidate != null and is_instance_valid(candidate) and candidate.has_method("close_all"):
			candidate.close_all()
