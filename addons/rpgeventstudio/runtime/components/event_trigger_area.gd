class_name EventTriggerArea2D
extends Node2D
## 触发区域：玩家进入 / 离开区域时执行事件（适合机关、剧情触发点、地图入口）。

@export var event: EventDefinition
@export_file("*.tres") var event_path: String = ""
@export var radius: float = 80.0
@export var show_debug_circle: bool = false

var _runtime: Node
var _player: Node2D
var _inside := false

func _ready() -> void:
	if event == null and event_path != "":
		event = load(event_path) as EventDefinition
	_runtime = get_node_or_null("/root/" + StudioRuntime.AUTOLOAD_NAME)
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var inside_now := global_position.distance_to(_player.global_position) <= radius
	if inside_now == _inside:
		return
	_inside = inside_now
	if _runtime == null or event == null:
		return
	if _inside:
		_runtime.call("start_event", event, {}, [&"touch", &"region_enter"])
	else:
		_runtime.call("start_event", event, {}, [&"region_exit"])

func _draw() -> void:
	if show_debug_circle:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.4, 0.8, 1.0, 0.45), 2.0)
