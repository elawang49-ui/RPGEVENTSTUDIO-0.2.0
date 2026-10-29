extends Camera2D
## 演示用摄像机：平滑跟随玩家，演出指令通过 focus_offset 把镜头引到别处。

@export var smoothing: float = 4.0
@export var follow_group: String = "player"

var focus_offset := Vector2.ZERO
var _player: Node2D

func _ready() -> void:
	add_to_group("camera")
	_player = get_tree().get_first_node_in_group(follow_group) as Node2D
	if _player != null:
		global_position = _player.global_position

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(follow_group) as Node2D
		if _player == null:
			return
	var target := _player.global_position + focus_offset
	global_position = global_position.lerp(target, clampf(delta * smoothing, 0.0, 1.0))
