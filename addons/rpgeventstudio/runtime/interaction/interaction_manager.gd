class_name InteractionManager
extends Node
## 统一决定「现在能交互谁」：只显示一个目标，按键/鼠标/手柄都打给同一个目标。
## 规则：距离最近者优先；距离差小于 0.5 像素时按节点路径排序，保证不会来回跳。

var runtime: Node

var active: EventInteractor2D = null
var _player: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(_delta: float) -> void:
	var target := resolve_target()
	if target == active:
		return
	if active != null and is_instance_valid(active):
		active.set_active(false)
	active = target
	if active != null:
		active.set_active(true)

## 供输入与测试共用：返回当前应该交互的对象。
func resolve_target() -> EventInteractor2D:
	if is_inside_tree() and get_tree().paused:
		return null
	if runtime != null:
		if runtime.has_method("is_ui_blocking") and bool(runtime.call("is_ui_blocking")):
			return null
		var runner: EventRunner = runtime.get("runner")
		if runner != null and runner.active_count() > 0:
			return null

	_player = _resolve_player()
	if _player == null:
		return null

	var best: EventInteractor2D = null
	var best_distance := INF
	var best_key := ""
	for node in get_tree().get_nodes_in_group("rpg_event_interactors"):
		var interactor := node as EventInteractor2D
		if interactor == null or not interactor.can_interact():
			continue
		var distance := interactor.global_position.distance_to(_player.global_position)
		if distance > interactor.interaction_radius:
			continue
		var key := String(interactor.get_path())
		if best == null:
			best = interactor
			best_distance = distance
			best_key = key
			continue
		# 距离明显更近 → 切换；距离几乎相同 → 用路径做稳定的平手规则
		if distance < best_distance - 0.5:
			best = interactor
			best_distance = distance
			best_key = key
		elif absf(distance - best_distance) <= 0.5 and key < best_key:
			best = interactor
			best_distance = distance
			best_key = key
	return best

func _unhandled_input(event: InputEvent) -> void:
	if active == null or not is_instance_valid(active):
		return
	if not active.can_interact():
		return
	if not event.is_action_pressed(InputService.ACTION_INTERACT):
		return
	if event is InputEventMouseButton:
		if not active.allow_mouse_click:
			return
		# 用事件自带的点击坐标（而不是全局鼠标位置），这样摄像头移动、注入事件时都正确
		var click_position: Vector2 = (event as InputEventMouseButton).position
		# 屏幕 → 世界：canvas_transform 把世界坐标画到屏幕上（含相机位移/缩放），
		# 其逆变换把屏幕点还原为世界坐标，才能与 active.global_position（世界系）比距离。
		# 不能用 get_global_transform_with_canvas().affine_inverse()：那是「节点局部 → 屏幕」
		# 的逆，得到的是相对 active 的局部坐标，与世界坐标比距离维度就错了。
		# 局限：get_canvas_transform() 只反映当前 viewport 主画布（相机）的变换；
		# 若交互对象挂在带自身变换的 CanvasLayer 里，需按该层的变换另行换算，
		# SubViewport 内的对象则由 get_viewport() 取到对应 viewport，天然正确。
		var world := active.get_viewport().get_canvas_transform().affine_inverse() * click_position
		if world.distance_to(active.global_position) > active.interaction_radius + 24.0:
			return
	_trigger_active()
	get_viewport().set_input_as_handled()

## 测试与调试可以直接调用：触发当前显示的目标。
func _trigger_active() -> bool:
	if active == null or not is_instance_valid(active) or not active.can_interact():
		return false
	active.trigger()
	return true

func _resolve_player() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	var found := get_tree().get_first_node_in_group("player")
	return found as Node2D
