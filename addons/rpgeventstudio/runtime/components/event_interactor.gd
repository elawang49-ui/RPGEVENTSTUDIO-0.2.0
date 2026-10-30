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
	if _runtime != null and _runtime.has_signal("dialogue_theme_changed"):
		_runtime.connect("dialogue_theme_changed", _on_dialogue_theme_changed)
	if _runtime != null:
		var input = _runtime.get("input")
		if input != null and input.has_signal("bindings_changed"):
			input.bindings_changed.connect(_on_bindings_changed)

func _on_bindings_changed() -> void:
	if _prompt != null:
		_prompt.text = _prompt_text()

func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-100, -interaction_radius - 52.0)
	_prompt.size = Vector2(200, 44)
	_prompt.visible = false
	_apply_prompt_style()
	_prompt.text = _prompt_text()
	add_child(_prompt)

func _on_language_changed(_locale: String) -> void:
	if _prompt != null:
		_prompt.text = _prompt_text()

func _on_dialogue_theme_changed(_theme: RpgEventStudioTheme) -> void:
	_apply_prompt_style()
	if _prompt != null:
		_prompt.text = _prompt_text()

func _apply_prompt_style() -> void:
	if _prompt == null:
		return
	var theme: RpgEventStudioTheme = null
	if _runtime != null:
		var value = _runtime.get("dialogue_theme")
		if value is RpgEventStudioTheme:
			theme = value
	var font_size := 13
	var color := Color(1.0, 0.95, 0.72)
	var outline_color := Color(0, 0, 0, 0.9)
	var outline_size := 4
	var offset_y := -52.0
	if theme != null:
		font_size = theme.prompt_font_size
		color = theme.prompt_color
		outline_color = theme.prompt_outline_color
		outline_size = theme.prompt_outline_size
		offset_y = theme.prompt_offset_y
	_prompt.position = Vector2(-100, -interaction_radius + offset_y)
	_prompt.add_theme_font_size_override("font_size", font_size)
	_prompt.add_theme_color_override("font_color", color)
	_prompt.add_theme_color_override("font_outline_color", outline_color)
	_prompt.add_theme_constant_override("outline_size", outline_size)

func _prompt_text() -> String:
	if prompt_text.strip_edges() != "":
		return prompt_text
	var title := display_name()
	var hint := _interact_hint()
	return "%s\n%s" % [title, hint] if hint != "" else title

## 提示跟随当前交互绑定；F1 改键后样例场景里的“空格 / 鼠标左键 / 手柄 A”会同步变化。
func _interact_hint() -> String:
	if _runtime != null:
		var input = _runtime.get("input")
		if input != null and input.has_method("describe"):
			var described: Dictionary = input.describe(InputService.ACTION_INTERACT)
			var parts: PackedStringArray = []
			for device in ["keyboard", "mouse", "gamepad"]:
				for label in described.get(device, []):
					var text_value := str(label)
					if text_value != "" and not parts.has(text_value):
						parts.append(text_value)
			if not parts.is_empty():
				return " / ".join(parts)
	var hint := L10n.game("game.prompt.hint")
	return "" if hint.begins_with("game.") else hint

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
	_runtime.call("start_event", event, {}, [&"interact"],
		{"kind": "interactor", "node": str(get_path()), "node_name": name})

func _draw() -> void:
	if not _active:
		return
	draw_arc(Vector2.ZERO, interaction_radius, 0.0, TAU, 48, Color(1.0, 0.9, 0.55, 0.45), 2.0)

func event_id() -> StringName:
	return event.event_id if event != null else &""
