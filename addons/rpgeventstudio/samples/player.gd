extends CharacterBody2D
## 演示用角色控制：只用 InputService 的动作名，不写死按键。
## 默认动作：WASD / 方向键 / 手柄十字键与左摇杆（可在 F1 里改）。

@export var speed: float = 220.0

func _physics_process(_delta: float) -> void:
	var input := _input_service()
	if input == null:
		return
	if _ui_blocking():
		velocity = Vector2.ZERO
		return

	var direction := input.get_vector(
		InputService.ACTION_MOVE_LEFT,
		InputService.ACTION_MOVE_RIGHT,
		InputService.ACTION_MOVE_UP,
		InputService.ACTION_MOVE_DOWN
	)
	velocity = direction * speed
	move_and_slide()

	var viewport_size := get_viewport_rect().size
	global_position = global_position.clamp(Vector2(32, 48), viewport_size - Vector2(32, 32))

func _input_service() -> InputService:
	var runtime := get_node_or_null("/root/RPGEventStudio")
	if runtime == null:
		return null
	return runtime.get("input") as InputService

func _ui_blocking() -> bool:
	var runtime := get_node_or_null("/root/RPGEventStudio")
	if runtime == null:
		return false
	return runtime.has_method("is_ui_blocking") and bool(runtime.call("is_ui_blocking"))
