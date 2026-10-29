extends Node
class_name StudioRuntime
## 运行时宿主（Autoload 名：RPGEventStudio）。
## 组装状态服务、事件运行时、对话界面、按键设置面板，并处理游戏语言。

signal language_changed(locale: String)

const AUTOLOAD_NAME := "RPGEventStudio"
const INTERACT_ACTION := &"interact"

var state: StateStore
var bus: EventBus
var registry: CommandRegistry
var runner: EventRunner
var presenter: DialoguePresenter
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

var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 语言：先注册翻译，再应用玩家上次选择的语言
	L10n.register_runtime_translations()
	L10n.set_game_locale(L10n.load_game_locale(), false)

	registry = CommandRegistry.new()
	state = StateStore.new()
	state.level_prefix = level_prefix
	bus = EventBus.new()
	bus.event_rejected.connect(_on_event_rejected)

	input = InputService.new()

	interaction = InteractionManager.new()
	interaction.name = "Interaction"
	interaction.runtime = self
	add_child(interaction)

	presenter = DialoguePresenter.new()
	presenter.name = "Presenter"
	presenter.input = input
	add_child(presenter)

	settings_panel = InputSettingsPanel.new()
	settings_panel.name = "InputSettings"
	settings_panel.input = input
	settings_panel.presenter = presenter
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

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPlayer"
	add_child(_sfx_player)

# ── 事件 API（游戏脚本可以直接用） ───────────────────────

func start_event(definition: EventDefinition, args: Dictionary = {}, trigger_filter: Array = []) -> void:
	if runner == null or definition == null:
		return
	runner.start(definition, args, trigger_filter)

func cancel_all(reason: String = "手动取消") -> void:
	if runner != null:
		runner.cancel_all(reason)

func is_event_running(event_id: StringName) -> bool:
	return runner != null and runner.is_busy(event_id)

func register_graph(graph_runner: GraphRunner) -> void:
	if graph_runner == null:
		return
	if not graphs.has(graph_runner):
		graphs.append(graph_runner)
		# 把执行进度发给编辑器（只在从编辑器启动时生效，导出后没有成本）
		var graph_id := String(graph_runner.graph.graph_id) if graph_runner.graph != null else ""
		graph_runner.node_state_changed.connect(func(node_id: StringName, state: int) -> void:
			_debug_send("node", [graph_id, String(node_id), state])
		)
		graph_runner.stage_changed.connect(func(_level_id: StringName, stage: String) -> void:
			_debug_send("stage", [graph_id, stage])
		)

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
