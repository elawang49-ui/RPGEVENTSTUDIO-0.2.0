extends SceneTree
## 交互目标验证：用真实演示场景里真实的 NPC / 门 / 抽屉组件，
## 验证「提示的目标 = 实际触发的目标」，以及重叠、切换、平手、无目标、鼠标点击。
##   godot --headless --path . --script res://tests/interaction_test.gd

var _checks := 0
var _failures: PackedStringArray = []

var _scene: Node
var _runtime: Node
var _manager: InteractionManager
var _player: Node2D

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_scene = load("res://addons/rpgeventstudio/samples/scenes/school_demo.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	_runtime = root.get_node_or_null("RPGEventStudio")
	_manager = _runtime.get("interaction")
	_player = _scene.get_node("Player")
	_player.set_physics_process(false)
	_check(_manager != null, "运行时里有交互管理器")

	var librarian: Node = _scene.get_node("Librarian/EventInteractor")
	var door: Node = _scene.get_node("ClassroomDoor/EventInteractor")
	var drawer: Node = _scene.get_node("Drawer/EventInteractor")

	await _test_nearest(librarian, door)
	await _test_switch(librarian, door)
	await _test_tie_is_stable(librarian, door)
	await _test_no_target(drawer)
	await _test_mouse(librarian)

	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 用例 ─────────────────────────────────────────────────

func _test_nearest(librarian: Node, door: Node) -> void:
	_move_player(librarian.global_position)
	(door as Node2D).global_position = (librarian as Node2D).global_position + Vector2(40, 0)
	await _frames(2)

	_check(_manager.active == librarian, "更近的 NPC 应成为当前目标")
	_check(_prompt_visible(librarian), "目标应显示提示")
	_check(not _prompt_visible(door), "非目标不显示提示")
	_check(String(_prompt_text(librarian)).contains("图书管理员"), "提示里应有对象名字")

	await _wait_idle()
	var before: int = _runtime.get("runner").active_count()
	_manager.call("_trigger_active")
	await _frames(2)
	_check(_runtime.get("runner").active_count() > before, "按键应触发当前显示的目标")
	_check(bool(_runtime.call("is_event_running", &"librarian")), "触发的确实是图书管理员事件")
	_runtime.call("cancel_all", "测试")
	await _wait_idle()

func _test_switch(librarian: Node, door: Node) -> void:
	_move_player((door as Node2D).global_position)
	await _frames(2)
	_check(_manager.active == door, "玩家走近门后目标应切换成门")
	_check(_prompt_visible(door) and not _prompt_visible(librarian), "提示应跟着切换")

	await _wait_idle()
	var before: int = _runtime.get("runner").active_count()
	_manager.call("_trigger_active")
	await _frames(2)
	_check(_runtime.get("runner").active_count() > before, "切换后按键应触发门的事件")
	_check(bool(_runtime.call("is_event_running", &"locked_door")), "触发的确实是门事件，而不是 NPC")
	_runtime.call("cancel_all", "测试")
	await _wait_idle()

func _test_tie_is_stable(librarian: Node, door: Node) -> void:
	# 两个对象与玩家距离完全相同：按节点路径排序，结果必须稳定
	var center: Vector2 = (librarian as Node2D).global_position + Vector2(0, 200)
	_move_player(center)
	(librarian as Node2D).global_position = center + Vector2(-10, 0)
	(door as Node2D).global_position = center + Vector2(10, 0)
	await _frames(3)

	var first = _manager.active
	_check(first != null, "平手时也应有确定的目标")
	var stayed := true
	for _i in 20:
		await process_frame
		if _manager.active != first:
			stayed = false
			break
	_check(stayed, "距离相同时目标不应来回跳动")
	_check(first == door, "平手规则应按节点路径稳定选中（这里是门）")

func _test_no_target(drawer: Node) -> void:
	_move_player(Vector2(1100, 620))
	await _frames(3)
	_check(_manager.active == null, "附近没有对象时应清空目标")
	_check(not _prompt_visible(drawer), "没有目标时提示应消失")

func _test_mouse(librarian: Node) -> void:
	# 无头模式下鼠标停在 (0,0)：把目标挪到原点附近，点击应触发；
	# 目标在远处时同样点击不应触发。
	var librarian_node: Node2D = librarian
	var original := librarian_node.global_position
	_move_player(Vector2(8, 0))
	librarian_node.global_position = Vector2.ZERO
	await _frames(2)
	_check(_manager.active == librarian, "原点处的对象应成为目标")

	await _wait_idle()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = librarian_node.get_global_transform_with_canvas() * librarian_node.global_position
	_manager.call("_unhandled_input", click)
	await _frames(2)
	_check(_runtime.get("runner").active_count() > 0, "鼠标点在目标附近应触发交互")
	_runtime.call("cancel_all", "测试")
	await _wait_idle()

	librarian_node.global_position = Vector2(900, 600)
	await _frames(2)
	_manager.call("_unhandled_input", click)
	await _frames(2)
	_check(_runtime.get("runner").active_count() == 0, "目标不在鼠标位置时点击不应触发")

	librarian_node.global_position = original
	await process_frame

# ── 工具 ─────────────────────────────────────────────────

func _move_player(target: Vector2) -> void:
	_player.global_position = target

func _prompt_visible(interactor: Node) -> bool:
	var prompt: Label = interactor.get("_prompt")
	return prompt != null and prompt.visible

func _prompt_text(interactor: Node) -> String:
	var prompt: Label = interactor.get("_prompt")
	return prompt.text if prompt != null else ""

func _wait_idle() -> void:
	var runner: EventRunner = _runtime.get("runner")
	var waited := 0
	while runner.active_count() > 0 and waited < 120:
		await process_frame
		waited += 1

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 交互目标测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
