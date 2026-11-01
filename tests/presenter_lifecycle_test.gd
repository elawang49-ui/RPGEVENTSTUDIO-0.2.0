extends SceneTree
## Presenter 生命周期回归测试（P0-2）：
##   godot --headless --path . --script res://tests/presenter_lifecycle_test.gd
## 覆盖：自定义 presenter 在事件等待中被释放 / 离树（模拟切场景）时，
##       事件必须尽快收尾、active_count 归零、全场交互锁恢复，
##       且全程不产生 SCRIPT ERROR；Node / 非 Node（RefCounted）两种 presenter 都要正确。

var _checks := 0
var _failures: PackedStringArray = []

var _runtime: Node
var _interactor: EventInteractor2D
var _last_finish: Dictionary = {}
var _capture_finish := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_runtime = root.get_node_or_null("RPGEventStudio")
	_check(_runtime != null, "运行时 Autoload 应可用于 presenter 生命周期测试")
	if _runtime == null:
		_report()
		quit(1)
		return
	_runtime.call("restore_default_presenter")
	var bus: EventBus = _runtime.get("bus")
	bus.event_finished.connect(_on_event_finished)

	# 交互探针：can_interact 只看事件是否运行 / UI 是否阻塞，不依赖玩家位置
	_interactor = EventInteractor2D.new()
	_interactor.name = "LifecycleInteractor"
	_interactor.event = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	_interactor.interaction_radius = 72.0
	root.add_child(_interactor)
	await process_frame
	_check(bool(_interactor.can_interact()), "空闲时交互探针应可用")

	await _test_normal_dialogue()
	await _test_queue_free_during_text()
	await _test_remove_subtree_during_text()
	await _test_queue_free_during_choices()
	await _test_queue_free_during_fade()
	await _test_ref_counted_presenter()
	await _test_release_after_finish()
	await _test_event_with_dangling_presenter()

	_interactor.queue_free()
	_runtime.call("restore_default_presenter")
	await process_frame
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 用例 ─────────────────────────────────────────────────

## 1) 正常对话不回归：MockPresenter 注入后事件正常完成、active_count 归零。
func _test_normal_dialogue() -> void:
	var mock := MockPresenter.new()
	mock.name = "LifecycleNormalMock"
	root.add_child(mock)
	_check(bool(_runtime.call("set_presenter", mock)), "注入正常 MockPresenter 应成功")
	var finished := await _run_event(_make_text_event(&"presenter_normal", "正常对话"), 90)
	_check(finished, "正常对话事件应完成")
	_check(int(_last_finish.get("result", -1)) == EventRunner.Result.COMPLETED,
		"正常对话应以 COMPLETED 结束（实际 %d）" % int(_last_finish.get("result", -1)))
	_check(int(_runner().active_count()) == 0, "正常完成后 active_count 应归零")
	_check(bool(_interactor.can_interact()), "正常完成后交互应可用")
	_runtime.call("restore_default_presenter")
	mock.queue_free()
	await process_frame

## 2) 对话等待中 queue_free presenter：事件应尽快以 CANCELLED 结束，交互锁恢复，无脚本错误。
func _test_queue_free_during_text() -> void:
	var mock := MockPresenter.new()
	mock.name = "LifecycleFreedMock"
	mock.never_finish = true
	root.add_child(mock)
	_check(bool(_runtime.call("set_presenter", mock)), "注入等待型 MockPresenter 应成功")
	_capture_on()
	_runtime.call("start_event", _make_text_event(&"presenter_freed", "等待中释放"), {}, [])
	await _frames(3)
	_check(int(_runner().active_count()) == 1, "事件应正在等待对话")
	_check(not bool(_interactor.can_interact()), "对话等待中交互应被锁")
	mock.queue_free()
	_check(await _wait_idle(120), "释放 presenter 后事件应在有限帧内结束")
	_check(int(_runner().active_count()) == 0, "释放 presenter 后 active_count 应归零")
	_check(bool(_interactor.can_interact()), "释放 presenter 后交互锁应恢复（can_interact 为 true）")
	_check(int(_last_finish.get("result", -1)) == EventRunner.Result.CANCELLED,
		"释放 presenter 应以 CANCELLED 结束（实际 %d）" % int(_last_finish.get("result", -1)))
	_capture_off()
	_runtime.call("restore_default_presenter")
	await process_frame

## 3) 对话等待中把 presenter 所在子树从树上移除（模拟切场景）：同上。
func _test_remove_subtree_during_text() -> void:
	var host := Node.new()
	host.name = "LifecycleSceneHost"
	root.add_child(host)
	var mock := MockPresenter.new()
	mock.name = "LifecycleDetachedMock"
	mock.never_finish = true
	host.add_child(mock)
	_check(bool(_runtime.call("set_presenter", mock)), "注入场景内展示层应成功")
	_capture_on()
	_runtime.call("start_event", _make_text_event(&"presenter_detached", "切场景释放"), {}, [])
	await _frames(3)
	_check(int(_runner().active_count()) == 1, "切场景前事件应正在等待")
	root.remove_child(host)
	_check(await _wait_idle(120), "presenter 离树后事件应在有限帧内结束")
	_check(int(_runner().active_count()) == 0, "presenter 离树后 active_count 应归零")
	_check(bool(_interactor.can_interact()), "presenter 离树后交互锁应恢复")
	_check(int(_last_finish.get("result", -1)) == EventRunner.Result.CANCELLED,
		"presenter 离树应以 CANCELLED 结束（实际 %d）" % int(_last_finish.get("result", -1)))
	_capture_off()
	_runtime.call("restore_default_presenter")
	host.queue_free()
	await process_frame

## 4) 选项等待中释放 presenter：事件应取消收尾，且不给 @@self.choice 写入悬空值。
func _test_queue_free_during_choices() -> void:
	var mock := MockPresenter.new()
	mock.name = "LifecycleChoicesMock"
	mock.auto_choice = -1
	mock.never_finish = true
	root.add_child(mock)
	_check(bool(_runtime.call("set_presenter", mock)), "注入选项型 MockPresenter 应成功")
	_capture_on()
	_runtime.call("start_event", _make_choices_event(&"presenter_choices_freed"), {}, [])
	await _frames(3)
	_check(int(_runner().active_count()) == 1, "事件应正在等待选择")
	mock.queue_free()
	_check(await _wait_idle(120), "选项等待中释放 presenter 后事件应结束")
	_check(int(_runner().active_count()) == 0, "选项路径释放后 active_count 应归零")
	_check(bool(_interactor.can_interact()), "选项路径释放后交互锁应恢复")
	_check(int(_last_finish.get("result", -1)) == EventRunner.Result.CANCELLED,
		"选项路径释放应以 CANCELLED 结束（实际 %d）" % int(_last_finish.get("result", -1)))
	_capture_off()
	_runtime.call("restore_default_presenter")
	await process_frame

## 5) 淡入淡出等待中释放 presenter：tween 随节点失效，事件也应取消收尾。
func _test_queue_free_during_fade() -> void:
	var mock := FadeMockPresenter.new()
	mock.name = "LifecycleFadeMock"
	root.add_child(mock)
	_check(bool(_runtime.call("set_presenter", mock)), "注入支持淡入淡出的展示层应成功")
	_capture_on()
	_runtime.call("start_event", _make_fade_event(&"presenter_fade_freed"), {}, [])
	await _frames(3)
	_check(int(_runner().active_count()) == 1, "事件应正在等待淡入淡出")
	_check(int(mock.fade_count) == 1, "展示层应收到 fade_to")
	mock.queue_free()
	_check(await _wait_idle(120), "淡入淡出等待中释放 presenter 后事件应结束")
	_check(int(_runner().active_count()) == 0, "淡入淡出路径释放后 active_count 应归零")
	_check(bool(_interactor.can_interact()), "淡入淡出路径释放后交互锁应恢复")
	_check(int(_last_finish.get("result", -1)) == EventRunner.Result.CANCELLED,
		"淡入淡出路径释放应以 CANCELLED 结束（实际 %d）" % int(_last_finish.get("result", -1)))
	_capture_off()
	_runtime.call("restore_default_presenter")
	await process_frame

## 6) 非 Node 的 RefCounted presenter：协议照常工作，不接 tree_exited、不报错。
func _test_ref_counted_presenter() -> void:
	var mock := RefPresenter.new()
	_check(bool(_runtime.call("set_presenter", mock)), "注入 RefCounted 展示层应成功")
	var finished := await _run_event(_make_text_event(&"presenter_ref_counted", "RefCounted 对话"), 90)
	_check(finished, "RefCounted 展示层事件应正常完成")
	_check(int(_last_finish.get("result", -1)) == EventRunner.Result.COMPLETED,
		"RefCounted 展示层事件应以 COMPLETED 结束（实际 %d）" % int(_last_finish.get("result", -1)))
	var presenter_now: Variant = _runtime.get("presenter")
	_check(presenter_now is RefPresenter, "事件期间应使用 RefCounted 展示层")
	_check(not (presenter_now as RefPresenter).shown.is_empty(), "RefCounted 展示层应收到文本")
	_check(int(_runner().active_count()) == 0, "RefCounted 展示层事件完成后 active_count 应归零")
	_runtime.call("restore_default_presenter")
	await _frames(3)
	_check(int(_runner().active_count()) == 0, "RefCounted 展示层替换回默认后无残留事件")

## 7) 事件正常结束后再释放 presenter：不应产生任何脚本错误。
func _test_release_after_finish() -> void:
	var mock := MockPresenter.new()
	mock.name = "LifecycleAfterFinishMock"
	root.add_child(mock)
	_check(bool(_runtime.call("set_presenter", mock)), "注入展示层（完成后释放用例）应成功")
	var finished := await _run_event(_make_text_event(&"presenter_after_finish", "完成后释放"), 90)
	_check(finished, "完成后释放用例的事件应正常完成")
	mock.queue_free()
	await _frames(5)
	_check(int(_runner().active_count()) == 0, "完成后释放 presenter，active_count 应保持为零")
	_check(bool(_interactor.can_interact()), "完成后释放 presenter，交互应保持可用")
	_runtime.call("restore_default_presenter")
	await process_frame

## 8) presenter 已悬空时再启动事件：指令应按「无展示层」处理，事件正常结束、无脚本错误。
func _test_event_with_dangling_presenter() -> void:
	var mock := MockPresenter.new()
	mock.name = "LifecycleDanglingMock"
	root.add_child(mock)
	_check(bool(_runtime.call("set_presenter", mock)), "注入展示层（悬空启动用例）应成功")
	mock.queue_free()
	await _frames(2)
	var finished := await _run_event(_make_text_event(&"presenter_dangling", "悬空启动"), 90)
	_check(finished, "presenter 悬空时事件应按无展示层路径正常结束")
	_check(int(_runner().active_count()) == 0, "悬空启动后 active_count 应归零")
	_check(bool(_interactor.can_interact()), "悬空启动后交互应保持可用")
	_runtime.call("restore_default_presenter")
	await process_frame

# ── 测试替身 ─────────────────────────────────────────────

## 支持 fade 协议的测试替身：fade_to 返回带真实时长的 tween，等待期间可被释放。
class FadeMockPresenter extends MockPresenter:
	var fade_count := 0

	func fade_to(_alpha: float, duration: float) -> Tween:
		fade_count += 1
		var tween := create_tween()
		tween.tween_interval(maxf(duration, 0.01))
		return tween

## 非 Node（RefCounted）展示层：只实现协议方法，不继承 Node。
class RefPresenter extends RefCounted:
	var shown: PackedStringArray = []

	func show_text(_speaker: String, text: String, _auto_advance: float = 0.0) -> void:
		shown.append(text)

	func is_text_finished() -> bool:
		return true

	func show_choices(_prompt: String, _options: Array) -> void:
		pass

	func get_choice() -> int:
		return 0

	func close_all() -> void:
		pass

# ── 工具 ─────────────────────────────────────────────────

func _on_event_finished(value: Dictionary) -> void:
	if _capture_finish:
		_last_finish = {"result": int(value.get("result", -1))}

func _capture_on() -> void:
	_capture_finish = true
	_last_finish = {}

func _capture_off() -> void:
	_capture_finish = false

func _runner() -> EventRunner:
	return _runtime.get("runner")

func _make_text_event(id: StringName, text: String) -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = id
	var page := EventPage.new()
	page.trigger = "interact"
	var command := CommandRegistry.create_command(&"show_text")
	command.params["text"] = text
	page.commands = [command]
	definition.pages = [page]
	return definition

func _make_choices_event(id: StringName) -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = id
	var page := EventPage.new()
	page.trigger = "interact"
	var command := CommandRegistry.create_command(&"show_choices")
	command.params["prompt"] = "选一个"
	command.params["options"] = ["甲", "乙"]
	page.commands = [command]
	definition.pages = [page]
	return definition

func _make_fade_event(id: StringName) -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = id
	var page := EventPage.new()
	page.trigger = "interact"
	var command := CommandRegistry.create_command(&"fade")
	command.params["mode"] = "out"
	command.params["duration"] = 5.0
	command.params["wait"] = true
	page.commands = [command]
	definition.pages = [page]
	return definition

## 启动事件并等待 event_finished；返回是否在限定帧内收到结束且 active_count 归零。
func _run_event(definition: EventDefinition, max_frames: int) -> bool:
	_capture_finish = true
	_last_finish = {}
	_runtime.call("start_event", definition, {}, [])
	var done := await _wait_idle(max_frames)
	_capture_finish = false
	return done and _last_finish.has("result")

## 等当前运行中的事件全部结束；返回是否在限定帧内归零。
func _wait_idle(max_frames: int) -> bool:
	var waited := 0
	while int(_runner().active_count()) > 0 and waited < max_frames:
		await process_frame
		waited += 1
	return waited < max_frames

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
	print("──── presenter 生命周期测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
