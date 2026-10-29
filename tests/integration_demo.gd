extends SceneTree
## 集成测试：加载真实演示场景，用真实对话界面把整段流程跑完，并验证改键与语言切换。
##   godot --headless --path . --script res://tests/integration_demo.gd

var _failures: PackedStringArray = []
var _checks := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://addons/rpgeventstudio/samples/scenes/school_demo.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame

	L10n.reset_missing()
	var runtime := root.get_node_or_null("RPGEventStudio")
	_check(runtime != null, "运行时 Autoload 已加载")
	if runtime == null:
		_report()
		quit(1)
		return

	var interactor := scene.get_node_or_null("Librarian/EventInteractor")
	_check(interactor != null, "NPC 上挂着交互组件")
	_check(interactor != null and interactor.get("event") is EventDefinition, "组件从路径加载到了事件资源")
	if interactor == null:
		_report()
		quit(1)
		return

	# 1. 第一次交互：选「询问钥匙」，应拿到钥匙
	interactor.call("trigger")
	await _drive_dialogue(runtime, 0)
	var has_key: bool = runtime.call("get_state", "Global.Player.HasKey", false)
	_check(has_key, "第一次交互后应获得钥匙")

	var presenter: Node = runtime.get("presenter")
	var seen := " ".join(presenter.get("shown_texts"))
	_check(seen.contains("这把钥匙给你"), "应播到「给钥匙」的台词")

	# 2. 第二次交互：应走第 2 页的不同台词
	interactor.call("trigger")
	await _drive_dialogue(runtime, 0)
	var last := str(presenter.get("last_text"))
	_check(last == "钥匙要收好，教室门就在右边。", "第二次对话应不同（实际：%s）" % last)

	# 3. 开门
	var door := scene.get_node_or_null("ClassroomDoor/EventInteractor")
	_check(door != null, "教室门上也挂着交互组件")
	if door != null:
		door.call("trigger")
		await _drive_dialogue(runtime, 0)
		_check(runtime.call("get_state", "School.ClassroomUnlocked", false), "开门后状态应变为已解锁")

	# 4. 改键后能用新按键触发交互
	await _test_rebind_triggers(runtime, interactor)

	# 5. 切换语言：HUD 与对话提示应变成英文
	await _test_language_switch(runtime, scene, interactor)

	# 6. 一次确认只推进一段对话（不会重复触发）
	await _test_no_double_advance(runtime, presenter)

	# 7. 关卡总控图：调查两处 → 自动解锁地下室
	await _test_basement_unlock(scene, runtime)

	_check(L10n.missing_keys().is_empty(), "运行期文案不应缺翻译：%s" % str(L10n.missing_keys().slice(0, 5)))

	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 改键 ─────────────────────────────────────────────────

func _test_rebind_triggers(runtime: Node, interactor: Node) -> void:
	var input: InputService = runtime.get("input")
	var runner: EventRunner = runtime.get("runner")
	runner.cancel_all("测试前清理")
	await _wait_until_idle(runner)

	var player: Node2D = root.get_node_or_null("SchoolDemo/Player")
	_check(player != null, "演示场景里有玩家节点")
	if player == null:
		return
	# 无头模式下视口只有 64x64，玩家脚本会把位置夹回角落；测试里先停掉它的物理处理
	player.set_physics_process(false)
	player.global_position = (interactor as Node2D).global_position + Vector2(24, 0)
	await process_frame
	await process_frame

	var new_key := InputEventKey.new()
	new_key.physical_keycode = KEY_K
	var result: Dictionary = input.rebind(InputService.ACTION_INTERACT, new_key)
	_check(bool(result.get("ok", false)), "把「交互」改绑到 K 应成功")

	# 按下 K：应触发交互
	var before_count := runner.active_count()
	await _press_key(KEY_K)
	var started := await _wait_for_event_start(runner, before_count, 60)
	_check(started, "按新按键 K 应触发交互")

	runner.cancel_all("改键测试结束")
	await _wait_until_idle(runner)

	# 按下旧键（空格）：改键后不应再触发
	var before_old := runner.active_count()
	await _press_key(KEY_SPACE)
	var still_idle := not await _wait_for_event_start(runner, before_old, 20)
	_check(still_idle, "改键后旧按键空格不应再触发交互")

	runner.cancel_all("改键测试结束")
	await process_frame
	input.restore_defaults()

# ── 语言 ─────────────────────────────────────────────────

func _test_language_switch(runtime: Node, scene: Node, interactor: Node) -> void:
	runtime.call("set_game_locale", "en")
	await process_frame

	var hud: Label = scene.get_node_or_null("UI/HUD")
	_check(hud != null, "演示场景里有状态 HUD")
	if hud != null:
		_check(hud.text.begins_with("Key"), "切到英文后 HUD 应显示英文（实际：%s）" % hud.text)

	var hint: Label = scene.get_node_or_null("UI/Hint")
	if hint != null:
		_check(hint.text.contains("Interact"), "顶部操作提示应跟着切换语言")

	_check(L10n.get_editor_locale() == "zh_CN", "切换游戏语言不应改变编辑器语言")

	# 对话提示也要跟着语言走
	interactor.call("trigger")
	var presenter: Node = runtime.get("presenter")
	var waited := 0
	while not bool(presenter.get("_waiting_confirm")) and waited < 400:
		await process_frame
		waited += 1
	var hint_label: Label = presenter.get("_hint_label")
	_check(hint_label.text.contains("Space"), "英文下对话提示应为英文（实际：%s）" % hint_label.text)
	runtime.call("cancel_all", "语言测试结束")
	await process_frame

	runtime.call("set_game_locale", "zh_CN")
	await process_frame
	if hud != null:
		_check(hud.text.begins_with("钥匙"), "切回中文后 HUD 应恢复中文")

# ── 不重复触发 ───────────────────────────────────────────

func _test_no_double_advance(runtime: Node, presenter: Node) -> void:
	runtime.call("cancel_all", "测试前清理")
	await _wait_until_idle(runtime.get("runner"))

	# 用一段独立的三连对话，避免受前面页面条件影响
	var definition := EventDefinition.new()
	definition.event_id = &"double_advance_test"
	definition.display_name = "测试对话"
	var page := EventPage.new()
	page.trigger = "interact"
	for text in ["第一段", "第二段", "第三段"]:
		var command := CommandRegistry.create_command(&"show_text")
		command.params["text"] = text
		page.commands.append(command)
	definition.pages = [page]

	runtime.call("start_event", definition, {}, ["interact"])

	var waited := 0
	while not bool(presenter.get("_waiting_confirm")) and waited < 400:
		await process_frame
		waited += 1
	_check(bool(presenter.get("_waiting_confirm")), "对话应停在等待确认状态")
	await create_timer(0.3).timeout

	var before: int = presenter.get("shown_texts").size()
	var text_before := str(presenter.get("last_text"))
	_check(text_before == "第一段", "应显示第一段（实际：%s）" % text_before)

	await _press_key(KEY_SPACE)
	var advanced := 0
	while presenter.get("shown_texts").size() == before and advanced < 60:
		await process_frame
		advanced += 1
	_check(advanced < 60, "一次按键应推进对话")
	await create_timer(0.25).timeout

	var after: int = presenter.get("shown_texts").size()
	_check(after == before + 1, "一次按键只应推进一段（%d → %d，当前：%s）" % [before, after, presenter.get("last_text")])
	_check(str(presenter.get("last_text")) == "第二段", "应停在第 second 段（实际：%s）" % presenter.get("last_text"))
	_check(int(presenter.get("_choice_result")) == -1, "推进时不应顺带选定某个选项")

	runtime.call("cancel_all", "测试结束")

# ── 输入辅助 ─────────────────────────────────────────────

func _press_key(keycode: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame

	var up := InputEventKey.new()
	up.physical_keycode = keycode
	up.keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame

func _wait_for_event_start(runner: EventRunner, before_count: int, max_frames: int) -> bool:
	var waited := 0
	while runner.active_count() <= before_count and waited < max_frames:
		await process_frame
		waited += 1
	return runner.active_count() > before_count

func _wait_until_idle(runner: EventRunner) -> void:
	var waited := 0
	while runner.active_count() > 0 and waited < 120:
		await process_frame
		waited += 1

# ── 关卡总控图：两处调查 → 解锁地下室 ────────────────────

func _test_basement_unlock(scene: Node, runtime: Node) -> void:
	runtime.call("cancel_all", "准备关卡图测试")
	await _wait_until_idle(runtime.get("runner"))

	var office: Node = scene.get_node_or_null("OfficeDesk/EventInteractor")
	var board: Node = scene.get_node_or_null("ClassroomBoard/EventInteractor")
	_check(office != null and board != null, "办公室桌子和教室黑板都挂好了交互组件")
	if office == null or board == null:
		return

	_check(str(runtime.call("current_stage")) == "exploration", "关卡开始时总控图应把阶段设为探索")

	# 多个交互对象重叠时只有最近的会响应，测试里把玩家挪到目标旁边
	_move_player_to(scene, office)
	office.call("trigger")
	await _drive_dialogue(runtime, 0)
	_check(runtime.call("get_state", "School.Office.DiaryFound", false), "调查办公室后应获得教师日志")
	_check(not runtime.call("get_state", "School.BasementUnlocked", false), "只完成一处时地下室应仍然锁着")

	_move_player_to(scene, board)
	var presenter: Node = runtime.get("presenter")
	var librarian: Node2D = scene.get_node("Librarian")
	var librarian_start := librarian.global_position
	board.call("trigger")
	await _drive_dialogue(runtime, 0)
	# 解锁后关卡图会紧接着播放过场（淡入淡出 / 镜头 / 移动 / 音效 / 对白），继续把它走完
	await _drive_dialogue(runtime, 0)
	_check(runtime.call("get_state", "School.Classroom.ClueFound", false), "调查教室后应发现线索")

	var waited := 0
	while not bool(runtime.call("get_state", "School.BasementUnlocked", false)) and waited < 180:
		await process_frame
		waited += 1

	_check(runtime.call("get_state", "School.BasementUnlocked", false), "两处都完成后地下室应自动解锁")
	_check(str(runtime.call("current_stage")) == "basement", "解锁后总控图应把阶段切到地下室")

	var hud: Label = scene.get_node_or_null("UI/HUD")
	if hud != null:
		_check(hud.text.contains(L10n.game("game.hud.unlocked_short")), "HUD 应显示地下室已解锁（实际：%s）" % hud.text.replace("\n", " / "))

	# 演出指令的效果
	_check(librarian.global_position.y < librarian_start.y - 40.0, "过场里的移动指令应真的移动了 NPC")
	var fade_rect: ColorRect = presenter.get("_fade_rect")
	_check(fade_rect != null and fade_rect.modulate.a < 0.05, "过场结束后画面应恢复（不是黑屏）")
	var camera: Camera2D = scene.get_node_or_null("Camera")
	_check(camera != null, "演示场景里应有摄像机")
	if camera != null:
		_check((camera.get("focus_offset") as Vector2).length() < 5.0, "镜头应已恢复跟随玩家")

	runtime.call("cancel_all", "关卡图测试结束")
	await _wait_until_idle(runtime.get("runner"))

func _move_player_to(scene: Node, target: Node) -> void:
	var player: Node2D = scene.get_node_or_null("Player")
	if player == null or target == null:
		return
	player.set_physics_process(false)
	player.global_position = (target as Node2D).global_position + Vector2(20, 0)

# ── 对话驱动 ─────────────────────────────────────────────

## 一路点击推进：文字点掉，选项选第 choice 个。
func _drive_dialogue(runtime: Node, choice: int) -> void:
	var presenter: Node = runtime.get("presenter")
	var frames := 0
	var idle := 0
	while frames < 1500:
		frames += 1
		await process_frame
		var runner: EventRunner = runtime.get("runner")
		if runner != null and runner.active_count() == 0 and not presenter.get("_panel").visible:
			idle += 1
			if idle > 4:
				return
			continue
		idle = 0
		if presenter.get("_choices_panel").visible:
			var box: VBoxContainer = presenter.get("_choices_box")
			if box.get_child_count() > choice:
				var button := box.get_child(choice) as Button
				if button != null:
					button.pressed.emit()
					await process_frame
					continue
		if not bool(presenter.call("is_text_finished")):
			presenter.set("_mouse_click", true)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 集成测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
