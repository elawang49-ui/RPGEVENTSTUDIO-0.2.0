class_name EventInteractor2D
extends Node2D
## 挂在 NPC / 宝箱 / 门上的交互组件。
## 只负责「我有事件、我离玩家多远、我显示什么提示」；
## 谁才是当前目标由 InteractionManager 统一决定，保证提示与实际触发一致。

signal triggered

@export var event: EventDefinition
@export_file("*.tres") var event_path: String = ""
@export var interaction_radius: float = 72.0
@export var prompt_text: String = ""   ## 留空则用事件名 + 按键提示
@export var allow_mouse_click: bool = true

var _runtime: Node
var _prompt: Label
var _active := false

func _ready() -> void:
	add_to_group("rpg_event_interactors")
	if event == null and event_path != "":
		event = load(event_path) as EventDefinition
	_runtime = get_node_or_null("/root/" + StudioRuntime.AUTOLOAD_NAME)
	_build_prompt()
	if _runtime != null and _runtime.has_signal("language_changed"):
		_runtime.connect("language_changed", _on_language_changed)

func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-100, -interaction_radius - 52.0)
	_prompt.size = Vector2(200, 44)
	_prompt.visible = false
	_prompt.add_theme_font_size_override("font_size", 13)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.text = _prompt_text()
	add_child(_prompt)

func _on_language_changed(_locale: String) -> void:
	if _prompt != null:
		_prompt.text = _prompt_text()

func _prompt_text() -> String:
	if prompt_text.strip_edges() != "":
		return prompt_text
	var title := display_name()
	var hint := L10n.game("game.prompt.hint")
	if hint.begins_with("game."):
		hint = ""
	return "%s\n%s" % [title, hint] if hint != "" else title

func display_name() -> String:
	if event != null and event.display_name.strip_edges() != "":
		return event.display_name
	var parent := get_parent()
	if parent != null:
		return parent.name
	return event_id()

func can_interact() -> bool:
	if event == null or _runtime == null:
		return false
	if _runtime.has_method("is_ui_blocking") and bool(_runtime.call("is_ui_blocking")):
		return false
	var runner: EventRunner = _runtime.get("runner")
	if runner != null and runner.active_count() > 0:
		return false
	return true

func is_active() -> bool:
	return _active

func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	if _prompt != null:
		_prompt.visible = value
		_prompt.text = _prompt_text()
	queue_redraw()

func trigger() -> void:
	if not can_interact():
		return
	triggered.emit()
	_runtime.call("start_event", event, {}, [&"interact"])

func _draw() -> void:
	if not _active:
		return
	draw_arc(Vector2.ZERO, interaction_radius, 0.0, TAU, 48, Color(1.0, 0.9, 0.55, 0.45), 2.0)

func event_id() -> StringName:
	return event.event_id if event != null else &""
