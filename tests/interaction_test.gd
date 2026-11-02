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
	await _test_parallel_and_tool_gates(librarian)

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
	# 屏幕坐标 → 世界坐标的往返必须对任意世界位都成立：
	# 点在目标「屏幕位置」（用正确的正变换 canvas_transform * 世界位 构造）应触发；
	# 点偏 400px 不应触发。原点场景保留作基线（历史实现只在原点凑巧成立）。
	var librarian_node: Node2D = librarian
	var camera: Camera2D = _scene.get_node("Camera")
	var original := librarian_node.global_position

	# 场景 1：目标在世界原点，点击原点的屏幕位置应触发
	_move_player(Vector2(8, 0))
	librarian_node.global_position = Vector2.ZERO
	_settle_camera(camera, Vector2(8, 0))
	await _frames(2)
	_check(_manager.active == librarian, "原点处的对象应成为目标")

	await _wait_idle()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = librarian_node.get_viewport().get_canvas_transform() * librarian_node.global_position
	_manager.call("_unhandled_input", click)
	await _frames(2)
	_check(_runtime.get("runner").active_count() > 0, "鼠标点在目标的屏幕位置应触发交互（原点）")
	_runtime.call("cancel_all", "测试")
	await _wait_idle()

	# 场景 2：目标在非原点世界位 (900,600)，点击它的屏幕位置同样应触发
	librarian_node.global_position = Vector2(900, 600)
	_move_player(Vector2(908, 600))
	_settle_camera(camera, Vector2(908, 600))
	await _frames(2)
	_check(_manager.active == librarian, "非原点世界位的目标应成为当前目标")

	await _wait_idle()
	click.position = librarian_node.get_viewport().get_canvas_transform() * librarian_node.global_position
	_manager.call("_unhandled_input", click)
	await _frames(2)
	_check(_runtime.get("runner").active_count() > 0, "鼠标点在非原点目标的屏幕位置应触发交互")
	_runtime.call("cancel_all", "测试")
	await _wait_idle()

	# 场景 3：同一目标位置，点击点在屏幕上偏离 400px——不应触发
	var miss := InputEventMouseButton.new()
	miss.button_index = MOUSE_BUTTON_LEFT
	miss.pressed = true
	miss.position = librarian_node.get_viewport().get_canvas_transform() * librarian_node.global_position + Vector2(400, 0)
	_manager.call("_unhandled_input", miss)
	await _frames(2)
	_check(_runtime.get("runner").active_count() == 0, "点击点偏离目标 400px 时不应触发交互")

	librarian_node.global_position = original
	await process_frame

# ── 工具 ─────────────────────────────────────────────────

func _move_player(target: Vector2) -> void:
	_player.global_position = target

func _settle_camera(camera: Camera2D, target: Vector2) -> void:
	# 演示相机靠 lerp 平滑跟随，无头模式下收敛速度依赖真实 delta。
	# 这里直接把相机对齐到跟随目标，等价于跟随收敛后的稳定画面，
	# 保证被点击的世界点确实落在屏幕内、canvas_transform 可预测。
	camera.global_position = target

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

func _test_parallel_and_tool_gates(librarian: Node) -> void:
	await _wait_idle()
	var definition := EventDefinition.new(); definition.event_id = &"background_probe"
	var page := definition.add_page(); page.trigger = "parallel"
	var wait := CommandRegistry.create_command(&"wait"); wait.params["seconds"] = 5.0
	page.commands = [wait]
	_runtime.call("start_event", definition); await _frames(3)
	_check(_runtime.get("runner").active_count() > 0, "后台parallel真实等待中")
	_check(librarian.can_interact(), "不展示UI的parallel等待不占玩家交互锁")
	_move_player(librarian.global_position); await _frames(2)
	_check(_manager.resolve_target() != null, "后台parallel时仍可解析玩家交互目标")
	_runtime.call("cancel_all"); await _wait_idle()
	page.commands = [CommandRegistry.create_command(&"show_text")]
	page.commands[0].params["text"] = "Parallel presentation"
	_runtime.call("start_event", definition); await _frames(3)
	_check(not librarian.can_interact(), "parallel取得展示层后正常阻塞交互")
	_runtime.call("cancel_all"); await _wait_idle()
	for kind in ["auto", "area"]:
		var event := EventDefinition.new(); event.event_id = StringName("tool_gate_" + kind)
		var p := event.add_page(); p.trigger = "autorun" if kind == "auto" else "region_enter"
		var setter := CommandRegistry.create_command(&"set_switch"); setter.params = {"key": "ToolGate." + kind, "value": true}; p.commands = [setter]
		_runtime.call("open_input_settings")
		var trigger: Node = EventAutoRun2D.new() if kind == "auto" else EventTriggerArea2D.new()
		trigger.set("event", event)
		if kind == "area": trigger.set("radius", 100000.0)
		_scene.add_child(trigger); await _frames(4)
		_check(not _runtime.get("state").get_bool("ToolGate." + kind), "工具面板打开时延后自动/区域触发：" + kind)
		_runtime.call("close_input_settings"); await _frames(5)
		_check(_runtime.get("state").get_bool("ToolGate." + kind), "关闭工具面板后保留触发沿：" + kind)
		trigger.queue_free(); await _frames(1)
