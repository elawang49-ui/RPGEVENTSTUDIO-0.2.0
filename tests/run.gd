extends SceneTree
## 自建测试入口（不依赖任何第三方插件）：
##   godot --headless --path . --script res://tests/run.gd
## 退出码 0 = 全部通过。

var _checks := 0
var _failures: PackedStringArray = []
var _case_name := ""
var _case_start_checks := 0
var _case_expected: Array[String] = []
var _case_done: Dictionary = {}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_case_begin("state_store")
	_test_state_store()
	_case_verify("state_store")
	_case_begin("page_selection")
	_test_page_selection()
	_case_verify("page_selection")
	_case_begin("condition_defaults")
	_test_condition_defaults()
	_case_verify("condition_defaults")
	_case_begin("state_catalog")
	_test_state_catalog()
	_case_verify("state_catalog")
	_case_begin("event_diagnosis")
	_test_event_diagnosis()
	_case_verify("event_diagnosis")
	_case_begin("input_service")
	_test_input_service()
	_case_verify("input_service")
	_case_begin("input_registry")
	_test_input_registry()
	_case_verify("input_registry")
	_case_begin("gamepad_input")
	await _test_gamepad_input()
	_case_verify("gamepad_input")
	_case_begin("input_settings_panel")
	_test_input_settings_panel()
	_case_verify("input_settings_panel")
	_case_begin("l10n")
	_test_l10n()
	_case_verify("l10n")
	_case_begin("bbcode")
	_test_bbcode()
	_case_verify("bbcode")
	_case_begin("nested_serialization")
	_test_nested_serialization()
	_case_verify("nested_serialization")
	_case_begin("graph_validator")
	_test_graph_validator()
	_case_verify("graph_validator")
	_case_begin("group_persistence")
	_test_group_persistence()
	_case_verify("group_persistence")
	_case_begin("story_audit")
	_test_story_audit()
	_case_verify("story_audit")
	_case_begin("story_document_mapping")
	_test_story_document_mapping()
	_case_verify("story_document_mapping")
	_case_begin("story_document_edits")
	_test_story_document_edits()
	_case_verify("story_document_edits")
	_case_begin("story_document_choice_ops")
	_test_story_document_choice_ops()
	_case_verify("story_document_choice_ops")
	_case_begin("story_templates")
	_test_story_templates()
	_case_verify("story_templates")
	_case_begin("story_characters")
	_test_story_characters()
	_case_verify("story_characters")
	_case_begin("story_preview")
	_test_story_preview()
	_case_verify("story_preview")
	_case_begin("graph_flow")
	await _test_graph_flow()
	_case_verify("graph_flow")
	_case_begin("graph_merge_or")
	await _test_graph_merge_or()
	_case_verify("graph_merge_or")
	_case_begin("graph_event_node")
	await _test_graph_event_node()
	_case_verify("graph_event_node")
	_case_begin("give_key_flow")
	await _test_give_key_flow()
	_case_verify("give_key_flow")
	_case_begin("choice_branch")
	await _test_choice_branch()
	_case_verify("choice_branch")
	_case_begin("cancel")
	await _test_cancel()
	_case_verify("cancel")
	_case_begin("presenter_injection")
	await _test_presenter_injection()
	_case_verify("presenter_injection")
	_case_begin("bbcode_presenter")
	await _test_bbcode_presenter()
	_case_verify("bbcode_presenter")
	_case_begin("map_event")
	await _test_map_event()
	_case_verify("map_event")
	_case_begin("dialogue_theme")
	await _test_dialogue_theme()
	_case_verify("dialogue_theme")
	var fault := OS.get_environment("RPGEVENTSTUDIO_TEST_FAULT")
	if fault != "":
		_case_begin("__injected_fault__")
		_inject_fault(fault)
		_case_verify("__injected_fault__")
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 状态 ─────────────────────────────────────────────────

func _test_state_store() -> void:
	var store := StateStore.new()
	store.define("Global.Player.HasKey", TYPE_BOOL, false)

	_check(store.get_value("Global.Player.HasKey") == false, "默认值应为 false")
	store.set_value("Global.Player.HasKey", true)
	_check(store.get_value("Global.Player.HasKey") == true, "写入后应为 true")
	_check(store.compare("Global.Player.HasKey", "==", true), "布尔比较应成立")
	_check(not store.compare("Global.Player.HasKey", "==", false), "布尔比较应不成立")

	store.set_value("Global.Counter", 5)
	store.add("Global.Counter", 3)
	_check(store.get_int("Global.Counter") == 8, "变量加法应得到 8")

	store.set_value("School.ClassroomUnlocked", true)
	var snapshot := store.snapshot()
	var restored := StateStore.new()
	restored.restore(snapshot)
	_check(restored.get_value("School.ClassroomUnlocked") == true, "快照恢复后状态应保留")
	_case_end()

# ── 状态库 ───────────────────────────────────────────────

func _test_state_catalog() -> void:
	var test_path := "res://.godot/test_state_catalog.tres"
	var catalog := StateCatalogStore.read(test_path)
	var definition := catalog.ensure("Test.Office.Clue", "bool", false, "测试")
	definition.display_name = "办公室线索已找到"
	var error := StateCatalogStore.write(catalog, test_path)
	_check(error == OK, "状态库应能保存")

	var loaded := StateCatalogStore.read(test_path)
	_check(loaded.display_name("Test.Office.Clue") == "办公室线索已找到", "状态库应返回显示名称")
	_check(loaded.find("Test.Office.Clue") != null, "已登记的状态应被识别")
	_check(loaded.display_name("Test.Not.Registered") == "Test.Not.Registered", "未登记状态回退为内部标识")

	# 改名不影响内部标识
	loaded.find("Test.Office.Clue").display_name = "改名后的线索"
	StateCatalogStore.write(loaded, test_path)
	var reloaded := StateCatalogStore.read(test_path)
	_check(reloaded.find("Test.Office.Clue").key == "Test.Office.Clue", "改名后内部标识不变")
	_check(reloaded.display_name("Test.Office.Clue") == "改名后的线索", "改名后显示新名字")

	# 指令摘要用工程里真实的状态库
	var command := CommandRegistry.create_command(&"set_switch")
	command.params["key"] = "School.Office.DiaryFound"
	command.params["value"] = true
	_check(CommandRegistry.summary(command).contains("办公室日记已调查"), "指令摘要应显示可读名字（实际：%s）" % CommandRegistry.summary(command))

	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)
	_case_end()

# ── 事件未执行诊断 ───────────────────────────────────────

func _test_event_diagnosis() -> void:
	var host := Node.new()
	host.name = "DiagHost"
	root.add_child(host)
	var state := StateStore.new()
	var bus := EventBus.new()
	var runner := EventRunner.new()
	runner.host = host
	runner.state = state
	runner.bus = bus

	var definition := EventDefinition.new()
	definition.event_id = &"diag_test"
	var page := EventPage.new()
	page.trigger = "interact"
	var condition := EventCondition.new()
	condition.key = "School.Office.DiaryFound"
	condition.op = "=="
	condition.value = true
	page.conditions = [condition]
	definition.pages = [page]

	var captured := {}
	bus.event_rejected.connect(func(event_id: StringName, diagnosis: Dictionary) -> void:
		captured["event_id"] = event_id
		captured["diagnosis"] = diagnosis
	)
	runner.start(definition, {}, ["interact"])

	_check(captured.has("event_id"), "没触发的事件应发出诊断")
	if captured.has("diagnosis"):
		var pages: Array = captured["diagnosis"].get("pages", [])
		_check(pages.size() == 1, "诊断应包含每一页")
		var conditions: Array = pages[0].get("conditions", [])
		_check(conditions.size() == 1, "诊断应包含每条条件")
		_check(not bool(conditions[0].get("ok", true)), "未满足的条件应标为 false")
		_check(bool(pages[0].get("trigger_ok", false)), "触发方式匹配时应标为 true")

	# 触发方式不匹配
	captured.clear()
	page.trigger = "autorun"
	runner.start(definition, {}, ["interact"])
	if captured.has("diagnosis"):
		var pages2: Array = captured["diagnosis"].get("pages", [])
		_check(pages2.size() == 1 and not bool(pages2[0].get("trigger_ok", true)), "触发方式不匹配应被诊断出来")

	host.queue_free()
	_case_end()

# ── 条件默认值 ───────────────────────────────────────────

func _test_condition_defaults() -> void:
	var store := StateStore.new()
	var page := EventPage.new()
	var condition := EventCondition.new()
	condition.key = "School.Office.DiaryFound"
	condition.op = "=="
	condition.value = false
	page.conditions = [condition]
	_check(page.is_active(store), "没写过的状态按 false 参与比较（== false 应成立）")

	condition.value = true
	_check(not page.is_active(store), "没写过的状态不应等于 true")

	condition.op = "!="
	_check(page.is_active(store), "!= true 在未定义时也应成立")
	_case_end()

# ── 事件页 ───────────────────────────────────────────────

func _test_page_selection() -> void:
	var definition: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	var store := StateStore.new()

	var index_default := definition.get_active_page(store, [&"interact"])
	_check(index_default == 0, "没钥匙时应选第 1 页（实际 %d）" % index_default)

	store.set_value("Global.Player.HasKey", true)
	var index_key := definition.get_active_page(store, [&"interact"])
	_check(index_key == 1, "有钥匙时应选第 2 页（实际 %d）" % index_key)

	var index_other := definition.get_active_page(store, [&"autorun"])
	_check(index_other == -1, "自动事件过滤时不应选中交互页")
	_case_end()

# ── 输入服务 ─────────────────────────────────────────────

func _test_input_service() -> void:
	var save_path := "res://.godot/test_input.cfg"
	var service := InputService.new()
	service.save_path = save_path
	service.restore_defaults()

	var described: Dictionary = service.describe("interact")
	_check(not described["keyboard"].is_empty(), "交互应有键盘绑定")
	_check(not described["mouse"].is_empty(), "交互应有鼠标绑定")
	_check(not described["gamepad"].is_empty(), "交互应有手柄绑定")

	var new_key := InputEventKey.new()
	new_key.physical_keycode = KEY_K
	var result: Dictionary = service.rebind(InputService.ACTION_INTERACT, new_key)
	_check(bool(result.get("ok", false)), "重新绑定应成功")
	_check(InputMap.event_is_action(new_key, "interact"), "改键后 K 应触发交互动作")
	var rebound_keyboard: Array = service.describe(InputService.ACTION_INTERACT)["keyboard"]
	_check(rebound_keyboard.size() == 1 and str(rebound_keyboard[0]) == "K",
		"改键应替换同设备的全部旧绑定（不能残留回车/空格）")

	var reloaded := InputService.new()
	reloaded.save_path = save_path
	reloaded.load_bindings()
	_check(_has_event(reloaded.events_of(InputService.ACTION_INTERACT), new_key), "重新加载后自定义按键应保留")

	var conflict_result: Dictionary = reloaded.rebind(InputService.ACTION_CONFIRM, new_key)
	_check(not bool(conflict_result.get("ok", true)), "绑定到已被占用的键应被拒绝")
	_check(str(conflict_result.get("conflict", "")) == "interact", "冲突应指向占用的动作")

	var shared_result: Dictionary = reloaded.rebind(InputService.ACTION_CONFIRM, new_key, true)
	_check(bool(shared_result.get("ok", false)), "允许共享后应绑定成功")

	reloaded.clear_device(InputService.ACTION_CONFIRM, "keyboard")
	_check(reloaded.describe(InputService.ACTION_CONFIRM)["keyboard"].is_empty(), "解除键盘绑定后应为空")

	reloaded.restore_defaults()
	_check(not InputMap.event_is_action(new_key, "interact"), "恢复默认后 K 不应再触发交互")

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	_case_end()

func _has_event(events: Array, target: InputEvent) -> bool:
	for event in events:
		if InputService.same_event(event, target):
			return true
	return false

# ── 输入注册（宿主动作 / 默认键补充 / 旧存档兼容） ──────

func _test_input_registry() -> void:
	InputService.unregister_action("toggle_journal")
	InputService.clear_default_extensions()
	var save_path := "res://.godot/test_input_registry.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

	# 1) 宿主注册自己的动作：进入统一动作表，可改键、可冲突检测。
	var service := InputService.new()
	service.save_path = save_path
	service.restore_defaults()
	service.register_action({
		"id": "toggle_journal",
		"label": "input.action.toggle_journal",
		"defaults": [{"type": "key", "keycode": KEY_TAB}],
	})
	_check(InputService.action_ids().has("toggle_journal"), "注册后动作表应包含 toggle_journal")
	_check(InputMap.event_is_action(_key(KEY_TAB), "toggle_journal"), "注册动作应立即生效")
	_check(service.describe("toggle_journal")["keyboard"].has("Tab"), "设置界面应显示注册动作")

	# 重复注册无副作用
	service.register_action({"id": "toggle_journal", "label": "x", "defaults": []})
	_check(service.describe("toggle_journal")["keyboard"].has("Tab"), "重复注册不应改变绑定")

	# 注册动作与内置动作冲突检测互通
	var conflict: Dictionary = service.rebind("toggle_journal", _key(KEY_F1))
	_check(not bool(conflict.get("ok", true)) and str(conflict.get("conflict", "")) == "toggle_settings",
		"注册动作应与内置动作互相检测冲突")

	# 2) 宿主补充默认键：未改过的动作补进 E，用户改过的不动。
	service.extend_action_defaults(InputService.ACTION_DIALOGUE_ADVANCE, [
		{"type": "key", "keycode": KEY_E},
	])
	# 界面标签随语言变化（中文是“空格”），这里按真实按键事件断言。
	_check(_has_event(service.events_of(InputService.ACTION_DIALOGUE_ADVANCE), _key(KEY_E)),
		"未改键时补充默认键应生效")
	_check(_has_event(service.events_of(InputService.ACTION_DIALOGUE_ADVANCE), _key(KEY_SPACE)),
		"补充默认键不应挤掉原有绑定")

	# 用户先改键，再补充：自定义绑定不能被覆盖
	service.rebind(InputService.ACTION_DIALOGUE_ADVANCE, _key(KEY_Q))
	service.extend_action_defaults(InputService.ACTION_INTERACT, [{"type": "key", "keycode": KEY_E}])
	var after: Array = service.describe("dialogue_advance")["keyboard"]
	_check(after.has("Q") and not after.has("E"), "用户改过的动作不应被默认键补充覆盖")
	_check(service.describe("interact")["keyboard"].has("E"), "未改过的动作可补键")

	# 3) 旧格式存档（无 meta 区）：绑定与基础默认一致时补键，改过则保留。
	var legacy := ConfigFile.new()
	var advance_ser: Array = []
	for event in service.events_of(InputService.ACTION_DIALOGUE_ADVANCE):
		advance_ser.append(InputService.event_to_dict(event))
	legacy.set_value("actions", "dialogue_advance", advance_ser)
	var interact_ser: Array = []
	for event in service._base_defaults_of("interact"):
		interact_ser.append(InputService.event_to_dict(event))
	legacy.set_value("actions", "interact", interact_ser)
	legacy.save(save_path)

	var migrated := InputService.new()
	migrated.save_path = save_path
	migrated.load_bindings()
	_check(migrated.describe("dialogue_advance")["keyboard"].has("Q"),
		"旧存档里与默认不同的绑定应视为用户自定义")
	migrated.extend_action_defaults(InputService.ACTION_DIALOGUE_ADVANCE, [{"type": "key", "keycode": KEY_E}])
	_check(migrated.describe("dialogue_advance")["keyboard"].has("Q"),
		"旧存档自定义键不应被补充覆盖")
	_check(not migrated.describe("dialogue_advance")["keyboard"].has("E"),
		"旧存档自定义键不应被补进默认键")
	migrated.extend_action_defaults(InputService.ACTION_INTERACT, [{"type": "key", "keycode": KEY_E}])
	_check(migrated.describe("interact")["keyboard"].has("E"),
		"旧存档里保持默认的动作应能补键")

	# 4) 新格式存档：恢复默认后 customized 清空，默认演进跟随代码。
	service.restore_defaults()
	_check(not service.is_customized("interact"), "恢复默认后不应再标记为已改键")

	# 5) 拆分后的动作独立存在：dialogue_advance / confirm / interact 是三个动作。
	_check(InputService.action_ids().has("dialogue_advance"), "应有独立的对话推进动作")
	_check(InputService.action_label_key("dialogue_advance") == "input.action.dialogue_advance",
		"对话推进动作应有自己的翻译键")

	# 清理
	InputService.unregister_action("toggle_journal")
	InputService.clear_default_extensions()
	service.restore_defaults()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	_case_end()

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

# ── 手柄真实事件通道 ─────────────────────────────────────

func _test_gamepad_input() -> void:
	var save_path := "res://.godot/test_gamepad.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var service := InputService.new()
	service.save_path = save_path
	service.restore_defaults()

	# 按键：手柄 A 按下/松开应真实驱动 interact 动作
	_pad_button(JOY_BUTTON_A, true)
	await process_frame
	await process_frame
	_check(Input.is_action_pressed("interact"), "手柄 A 按下应触发交互动作")
	_pad_button(JOY_BUTTON_A, false)
	await process_frame
	await process_frame
	_check(not Input.is_action_pressed("interact"), "手柄 A 松开应释放交互动作")

	# 摇杆：左摇杆左推/回中
	_pad_axis(JOY_AXIS_LEFT_X, -1.0)
	await process_frame
	await process_frame
	_check(Input.is_action_pressed("move_left"), "左摇杆左推应触发左移")
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	await process_frame
	await process_frame
	_check(not Input.is_action_pressed("move_left"), "摇杆回中应释放左移")

	# 改键到手柄 X（B 被「取消」占用，正好验证冲突模型不误报），并确认持久化
	var x := InputEventJoypadButton.new()
	x.button_index = JOY_BUTTON_X
	var result: Dictionary = service.rebind(InputService.ACTION_INTERACT, x)
	_check(bool(result.get("ok", false)), "交互应可改绑到手柄 X")
	var reloaded := InputService.new()
	reloaded.save_path = save_path
	reloaded.load_bindings()
	_check(_has_event(reloaded.events_of(InputService.ACTION_INTERACT), x), "手柄改键应保存并重载")

	service.restore_defaults()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	_case_end()

func _pad_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func _pad_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)

# ── 按键设置面板（改键 / 取消 / 冲突） ───────────────────

func _test_input_settings_panel() -> void:
	var service := InputService.new()
	service.save_path = "res://.godot/test_settings.cfg"
	service.restore_defaults()

	var panel := InputSettingsPanel.new()
	panel.input = service
	root.add_child(panel)
	panel.open()
	_check(panel.is_open(), "按键设置面板应能打开")

	# Esc 取消改键
	panel.call("_start_listen", "interact", "keyboard")
	panel.set("_guard_until", 0)
	_check(panel.is_listening(), "进入改键状态")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	panel.call("_input", esc)
	_check(not panel.is_listening(), "Esc 应取消本次改键")
	_check(InputMap.event_is_action(esc, "interact") == false, "Esc 不应被绑定")

	# 按 K 完成绑定
	panel.call("_start_listen", "interact", "keyboard")
	panel.set("_guard_until", 0)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	k.pressed = true
	panel.call("_input", k)
	_check(not panel.is_listening(), "按下新键后应结束改键状态")
	_check(InputMap.event_is_action(k, "interact"), "新按键应已生效")
	_check(service.describe("interact")["keyboard"].has("K"), "界面应显示新的键盘绑定")

	# 绑到已被占用的键：应提示冲突且不生效
	panel.call("_start_listen", "confirm", "keyboard")
	panel.set("_guard_until", 0)
	panel.call("_input", k)
	_check(bool(panel.get("_conflict_row").visible), "冲突时应显示提示")
	_check(InputMap.event_is_action(k, "confirm") == false, "冲突未确认前不应绑定")
	panel.call("_on_conflict_cancel")
	_check(not panel.is_listening(), "取消冲突后应退出改键状态")

	# 鼠标键也能绑定
	panel.call("_start_listen", "cancel", "mouse")
	panel.set("_guard_until", 0)
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	panel.call("_input", middle)
	_check(service.describe("cancel")["mouse"].has("鼠标中键"), "鼠标按键应能绑定")

	# 恢复默认
	panel.call("_on_restore_defaults")
	_check(service.describe("cancel")["mouse"].has("鼠标右键"), "恢复默认后应回到默认鼠标绑定")

	panel.close()
	_check(not panel.is_open(), "面板应能关闭")
	panel.queue_free()
	service.restore_defaults()
	if FileAccess.file_exists("res://.godot/test_settings.cfg"):
		DirAccess.remove_absolute("res://.godot/test_settings.cfg")
	_case_end()

# ── 本地化 ───────────────────────────────────────────────

func _test_l10n() -> void:
	L10n.set_editor_locale("zh_CN")
	_check(L10n.ui("editor.title") == "事件", "中文标题应为「事件」")

	L10n.set_editor_locale("en")
	_check(L10n.ui("editor.title") == "Events", "英文标题应为 Events")
	_check(L10n.ui("cmd.if") == "Conditional Branch", "英文指令名应翻译")
	L10n.set_editor_locale("zh_CN")

	_check(L10n.lookup("en", "no.such.key") == "no.such.key", "缺失的键应回退为键名本身")
	_check(L10n.ui("editor.path.page", {"page": 3}).contains("3"), "带参数的文案应正确替换")

	L10n.set_game_locale("en", false)
	_check(L10n.game("game.hud.key") == "Key", "运行时语言应独立于编辑器语言")
	L10n.set_game_locale("zh_CN", false)
	_check(L10n.game("game.hud.key") == "钥匙", "运行时可切回中文")

	_check(L10n.translation_of("zh_CN") != null, "中文翻译资源应存在")
	_check(L10n.translation_of("en") != null, "英文翻译资源应存在")

	# 运行时词条注入：宿主游戏给自定义动作补界面文字
	L10n.add_runtime_message("zh_CN", "input.action.toggle_journal", "打开/关闭日志")
	L10n.add_runtime_message("en", "input.action.toggle_journal", "Open/Close Journal")
	L10n.add_runtime_message("zh_CN", "input.action.toggle_journal", "重复注入应被忽略")
	_check(L10n.game("input.action.toggle_journal") == "打开/关闭日志", "运行时注入的词条应可查询")
	L10n.set_game_locale("en", false)
	_check(L10n.game("input.action.toggle_journal") == "Open/Close Journal", "注入词条应分语言")
	L10n.set_game_locale("zh_CN", false)
	L10n.add_runtime_message("zh_CN", "game.advance_hint", "试图覆盖内置词条")
	_check(L10n.game("game.advance_hint") == "空格 / 鼠标左键 / 手柄 A", "运行时注入不应覆盖内置词条")

	# CSV 是翻译的源文件：逐行确认两种语言都能取到
	var file := FileAccess.open("res://addons/rpgeventstudio/i18n/ui.csv", FileAccess.READ)
	_check(file != null, "应能读取翻译源文件 ui.csv")
	if file == null:
		_case_end()
		return
	file.get_csv_line()   # 表头
	var total := 0
	var missing_zh: Array = []
	var missing_en: Array = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 3:
			continue
		var key := row[0]
		if key == "":
			continue
		total += 1
		if not L10n.has_key(key, "zh_CN"):
			missing_zh.append(key)
		if not L10n.has_key(key, "en"):
			missing_en.append(key)
	file.close()

	_check(total >= 150, "翻译条目应覆盖全部界面（实际 %d 条）" % total)
	_check(missing_zh.is_empty(), "中文翻译不应缺条目：%s" % str(missing_zh.slice(0, 5)))
	_check(missing_en.is_empty(), "英文翻译不应缺条目：%s" % str(missing_en.slice(0, 5)))
	_case_end()

# ── BBCode 检查器 ────────────────────────────────────────

func _test_bbcode() -> void:
	var valid := "[b]粗体[/b] [i]斜体[/i] [color=#FFD700]金色[/color]\n[font_size=24]大[/font_size] [center]居中[/center]"
	var clean := Bbcode.analyze(valid)
	_check(not Bbcode.has_issues(clean), "合法 BBCode 不应报警")

	var unclosed := Bbcode.analyze("[b]重点")
	_check((unclosed.get("unclosed", []) as Array).has("b"), "应检测出未闭合的 [b]")
	_check(Bbcode.describe(unclosed, false).contains("[b]"), "未闭合提示应包含标签名")

	var mismatch := Bbcode.analyze("[b]文字[/i]")
	_check((mismatch.get("mismatch", []) as Array).has("i"), "应检测出闭合标签不匹配")
	_check((mismatch.get("unclosed", []) as Array).has("b"), "不匹配时同时报告未闭合的 [b]")

	var unsupported := Bbcode.analyze("[foo]未知[/foo]")
	_check((unsupported.get("unsupported", []) as Array).has("foo"), "应检测出不支持的标签")
	_check(Bbcode.describe(unsupported, false).contains("[foo]"), "不支持提示应包含标签名")

	var malformed := Bbcode.analyze("[color=red]x[/color=red]")
	_check((malformed.get("malformed_close", []) as Array).has("color"), "闭合标签带参数应被提示")

	var code_text := Bbcode.analyze("[code][b]不是标签[/b][/code]")
	_check(not Bbcode.has_issues(code_text), "[code] 里的标签不应被误判")
	_check(not Bbcode.has_issues(Bbcode.analyze("普通文字 [1] 和 [提示]")), "普通方括号不应被误判")
	_case_end()

# ── BBCode 打字机 ────────────────────────────────────────

func _test_bbcode_presenter() -> void:
	var presenter := DialoguePresenter.new()
	presenter.name = "BbcodePresenter"
	root.add_child(presenter)
	await process_frame

	var raw := "[b]粗体[/b] [color=#FFD700]金色[/color]\n第二行"
	presenter.show_text("", raw)
	var parsed := str(presenter.get("last_parsed_text"))
	_check(parsed == "粗体 金色\n第二行", "默认 UI 应解析 BBCode（实际：%s）" % parsed)
	_check(int(presenter.get("_reveal_total")) == parsed.length(), "打字机总长应按可见字符计算")
	_check(not Bbcode.has_issues(presenter.get("last_bbcode_issues")), "合法文本不应记录 BBCode 问题")
	_check(presenter.shown_texts.size() == 1 and presenter.shown_texts[0] == raw, "原始 BBCode 应原样保留")

	presenter.show_choices("[b]选项提示[/b]", ["选项 A", "选项 B"])
	_check(str(presenter.get("last_parsed_text")) == "选项提示", "默认 UI 的选项提示也解析 BBCode")

	presenter.show_text("", "[b]未闭合")
	var issues: Dictionary = presenter.get("last_bbcode_issues")
	_check((issues.get("unclosed", []) as Array).has("b"), "未闭合文本应记录问题供排查")
	_check(str(presenter.get("last_text")) == "[b]未闭合", "未闭合文本也不应被静默改写")

	presenter.close_all()
	presenter.queue_free()
	await process_frame

	# 保存为事件资源再读回，用默认 UI 真正跑一遍
	var runtime: Node = root.get_node_or_null("RPGEventStudio")
	if runtime == null:
		_case_end()
		return
	runtime.call("restore_default_presenter")
	var path := "res://.godot/test_bbcode_default_ui.tres"
	var definition := _make_text_event(&"bbcode_default_ui", raw)
	_check(ResourceSaver.save(definition, path) == OK, "BBCode 事件资源应能保存（默认 UI）")
	var loaded: EventDefinition = load(path)
	var loaded_text := ""
	if loaded != null and not loaded.pages.is_empty() and not loaded.pages[0].commands.is_empty():
		loaded_text = str(loaded.pages[0].commands[0].params.get("text", ""))
	_check(loaded_text == raw, "读回后 BBCode 原文完整（默认 UI）")
	var default_presenter: Node = runtime.get("presenter")
	var finished := await _run_runtime_event_with_default(runtime, loaded, 300)
	_check(finished, "保存后的 BBCode 事件在默认 UI 中能完成")
	_check(str(default_presenter.get("last_parsed_text")) == parsed, "默认 UI 运行时渲染 BBCode")
	_check(default_presenter.shown_texts.size() > 0 and default_presenter.shown_texts[default_presenter.shown_texts.size() - 1] == raw, "默认 UI 保留原始 BBCode")
	DirAccess.remove_absolute(path)
	_case_end()

# ── 嵌套结构：保存 / 读取 / 兼容 ─────────────────────────

func _test_nested_serialization() -> void:
	var definition := EventDefinition.new()
	definition.event_id = &"nested_test"
	definition.display_name = "嵌套测试"

	var page := EventPage.new()
	page.trigger = "interact"

	var outer := CommandRegistry.create_command(&"if")
	outer.params["key"] = "Global.A"
	outer.params["op"] = "=="
	outer.params["value"] = "true"

	var then_text := CommandRegistry.create_command(&"show_text")
	then_text.params["text"] = "外层-是"

	var inner := CommandRegistry.create_command(&"if")
	inner.params["key"] = "Global.B"
	inner.params["op"] = "=="
	inner.params["value"] = "1"

	var inner_then := CommandRegistry.create_command(&"show_text")
	inner_then.params["text"] = "内层-是"
	var inner_else := CommandRegistry.create_command(&"set_switch")
	inner_else.params["key"] = "Local.Test.Switch"
	inner_else.params["value"] = true

	inner.children = [inner_then]
	inner.else_children = [inner_else]

	var else_text := CommandRegistry.create_command(&"show_text")
	else_text.params["text"] = "外层-否"

	outer.children = [then_text, inner]
	outer.else_children = [else_text]
	page.commands = [outer]

	var empty_if := CommandRegistry.create_command(&"if")
	empty_if.params["key"] = ""
	page.commands.append(empty_if)

	definition.pages = [page]

	var path := "res://.godot/test_nested.tres"
	var save_error := ResourceSaver.save(definition, path)
	_check(save_error == OK, "嵌套事件应能保存（错误码 %d）" % save_error)

	var loaded: EventDefinition = load(path)
	_check(loaded != null, "嵌套事件应能重新读取")
	if loaded == null:
		_case_end()
		return

	var loaded_page: EventPage = loaded.pages[0]
	_check(loaded_page.commands.size() == 2, "顶层指令数量应保持")
	var loaded_outer: EventCommand = loaded_page.commands[0]
	_check(loaded_outer.type == &"if", "第一条应是条件分歧")
	_check(loaded_outer.children.size() == 2, "「是」分支应有 2 条指令")
	_check(loaded_outer.else_children.size() == 1, "「否」分支应有 1 条指令")

	var loaded_inner: EventCommand = loaded_outer.children[1]
	_check(loaded_inner.type == &"if", "「是」分支里应还能嵌套条件分歧")
	_check(loaded_inner.children[0].params.get("text", "") == "内层-是", "三层嵌套的文本应保留")
	_check(loaded_inner.else_children[0].params.get("key", "") == "Local.Test.Switch", "三层嵌套的开关名应保留")
	_check(bool(loaded_inner.else_children[0].params.get("value", false)) == true, "三层嵌套的布尔参数应保持类型")
	_check(loaded_outer.children[0].params.get("text", "") == "外层-是", "「是」分支第一条文本应保留")
	_check(loaded_outer.else_children[0].params.get("text", "") == "外层-否", "「否」分支文本应保留")

	var loaded_empty: EventCommand = loaded_page.commands[1]
	_check(loaded_empty.children.is_empty() and loaded_empty.else_children.is_empty(), "空分支应能正确读回")

	# 旧资源仍可读取（第一阶段格式）
	var old_definition: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	_check(old_definition != null and old_definition.pages.size() == 2, "旧事件资源应继续可用")

	DirAccess.remove_absolute(path)
	_case_end()

# ── 剧情工作台：视图映射 ─────────────────────────────────

func _test_story_document_mapping() -> void:
	var definition: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	var document := StoryDocument.new(definition.pages[0])
	var items := document.build_items()

	_check(items.size() == 3, "图书管理员第 1 页应解析为 3 个条目（实际 %d）" % items.size())
	_check(str(items[0]["kind"]) == "line", "第 1 条应是台词")
	_check(str(items[1]["kind"]) == "choice", "第 2 条应是选项块")
	_check(str(items[2]["kind"]) == "command", "第 3 条应是普通指令（end）")

	var choice: Dictionary = items[1]
	_check((choice["options"] as Array).size() == 2, "选项块应有两个选项")
	_check(str(choice["pattern"]) == "nested", "旧样例（单个 if + else）应识别为嵌套式（实际 %s）" % str(choice["pattern"]))
	_check(bool(choice["well_formed"]), "旧样例的选项块应判定为结构完整")
	var views: Array = choice["option_views"]
	_check((views[0] as Array).size() == 3, "选项 1 分支应有 3 个条目")
	_check((views[1] as Array).size() == 1, "选项 2 分支（else）应有 1 个条目")
	var first_branch_line: Dictionary = views[0][0]
	_check(str(first_branch_line["command"].params.get("text", "")) == "这把钥匙给你，别弄丢了。", "选项 1 分支第一条台词应正确映射")
	_check(str(views[1][0]["command"].params.get("text", "")) == "那就随便看看吧。", "选项 2 分支台词应正确映射")

	# 条件分歧与状态指令的映射
	var definition2 := EventDefinition.new()
	var page := EventPage.new()
	var branch := CommandRegistry.create_command(&"if")
	branch.params["key"] = "Global.A"
	branch.children = [CommandRegistry.create_command(&"show_text")]
	branch.else_children = [CommandRegistry.create_command(&"set_switch")]
	var inner := CommandRegistry.create_command(&"if")
	inner.params["key"] = "Global.B"
	inner.children = []
	page.commands = [CommandRegistry.create_command(&"show_text"), branch, inner, CommandRegistry.create_command(&"variable_op")]
	definition2.pages = [page]
	var doc2 := StoryDocument.new(page)
	var items2 := doc2.build_items()
	_check(items2.size() == 4, "应解析出 4 个顶层条目")
	_check(str(items2[1]["kind"]) == "condition" and str(items2[2]["kind"]) == "condition", "两条 if 都应是条件条目")
	_check((items2[1]["children_view"] as Array).size() == 1, "条件的「是」分支应有 1 个条目")
	_check((items2[1]["else_view"] as Array).size() == 1, "条件的「否」分支应有 1 个条目")
	_check(str(items2[3]["kind"]) == "state", "variable_op 应识别为状态条目")
	_case_end()

# ── 剧情工作台：基础编辑 ─────────────────────────────────

func _test_story_document_edits() -> void:
	var definition: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	var page := definition.pages[0]
	var document := StoryDocument.new(page)
	var items := document.build_items()
	var original_first: EventCommand = page.commands[0]

	# 插入台词（在选中条目之后）
	var new_line := CommandRegistry.create_command(&"show_text")
	new_line.params["speaker"] = "测试员"
	new_line.params["text"] = "插入的一句"
	document.insert_command(page.commands, 1, new_line)
	_check(page.commands.size() == 5, "插入后顶层指令应有 5 条")
	_check(page.commands[1] == new_line, "新台词应插在第 2 位")
	_check(page.commands[0] == original_first, "原有命令对象保持不变（零重建）")

	# 修改台词参数
	var items_now := document.build_items()
	var line_item: Dictionary = items_now[1]
	document.set_line_param(line_item, "text", "改过的正文")
	document.set_line_param(line_item, "speaker", "改名角色")
	_check(str(page.commands[1].params.get("text", "")) == "改过的正文", "正文应写进原指令")
	_check(str(page.commands[1].params.get("speaker", "")) == "改名角色", "说话人应写进原指令")

	# 复制 → 移动 → 删除
	document.duplicate_item(items_now[1])
	_check(page.commands.size() == 6, "复制后应有 6 条")
	_check(page.commands[2] != page.commands[1] and str(page.commands[2].params.get("text", "")) == "改过的正文", "复制应得到深拷贝")
	items_now = document.build_items()
	document.move_item(items_now[2], 1)
	_check(str(page.commands[3].params.get("text", "")) == "改过的正文" or str(page.commands[2].params.get("text", "")) == "改过的正文", "移动后台词仍在列表中")
	items_now = document.build_items()
	var target_item: Dictionary = items_now[1]
	document.delete_item(target_item)
	_check(page.commands.size() == 5, "删除后回到 5 条")
	_check(page.commands.find(new_line) == -1, "被删除的指令不再在列表里")
	_case_end()

# ── 剧情工作台：选项块操作 ───────────────────────────────

func _test_story_document_choice_ops() -> void:
	var definition: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	var page := definition.pages[0]
	var document := StoryDocument.new(page)
	var choice: Dictionary = document.build_items()[1]

	# 改选项文字：不动结构
	document.choice_rename_option(choice, 0, "询问钥匙（改）")
	_check((page.commands[1].params.get("options") as Array)[0] == "询问钥匙（改）", "选项文字应更新")
	_check(page.commands.size() == 4, "改选项文字不应改变结构")

	# 增加选项：改写成顺序式，内容原样搬移
	var result := document.choice_add_option(choice, "再问一句")
	_check(result, "结构完整的选项块应允许加选项")
	_check(page.commands.size() == 6, "加选项后应有 1 个 show_choices + 3 个 if + 1 个 end")
	_check(str(page.commands[1].type) == "show_choices" and str(page.commands[2].type) == "if" and str(page.commands[3].type) == "if" and str(page.commands[4].type) == "if", "应改写为顺序式三个分支")
	_check((page.commands[1].params.get("options") as Array).size() == 3, "选项列表应有 3 项")
	var branch0: Array = page.commands[2].children
	_check(branch0.size() == 3 and str(branch0[0].params.get("text", "")) == "这把钥匙给你，别弄丢了。", "原选项 1 分支内容应原样保留")
	var branch1: Array = page.commands[3].children
	_check(branch1.size() == 1 and str(branch1[0].params.get("text", "")) == "那就随便看看吧。", "原选项 2 分支（else）内容应搬移到新位置")
	var branch2: Array = page.commands[4].children
	_check(branch2.is_empty(), "新选项分支应为空")
	_check(str(page.commands[2].params.get("key", "")) == "@@self.choice" and str(page.commands[2].params.get("value", "")) == "0", "分支条件应指向 @@self.choice")

	# 删除选项
	choice = document.build_items()[1]
	_check(document.choice_remove_option(choice, 2), "应能删除最后一个选项")
	_check(page.commands.size() == 5, "删除选项后回到 5 条")
	_check((page.commands[1].params.get("options") as Array).size() == 2, "选项列表应剩 2 项")

	# 交换选项：文字与分支内容一起换
	choice = document.build_items()[1]
	var swap_ok := document.choice_move_option(choice, 0, 1)
	_check(swap_ok, "应能交换选项")
	_check((page.commands[1].params.get("options") as Array)[0] == "离开", "交换后第 1 个选项应是原第 2 个")
	var swapped_first: EventCommand = page.commands[2].children[0]
	_check(str(swapped_first.params.get("text", "")) == "那就随便看看吧。", "交换后第 1 分支内容应跟着选项走")

	# 删除中间选项：后面的分支内容必须前移，不能越界或串位
	var fresh := StoryDocument.new(load("res://addons/rpgeventstudio/samples/events/librarian.tres").pages[0])
	var fresh_choice: Dictionary = fresh.build_items()[1]
	fresh.choice_add_option(fresh_choice, "再问一句")
	fresh_choice = fresh.build_items()[1]
	_check(fresh.choice_remove_option(fresh_choice, 1), "应能删除中间选项")
	var fresh_options: Array = fresh.page.commands[1].params.get("options", [])
	_check(fresh_options.size() == 2 and str(fresh_options[1]) == "再问一句", "删除中间选项后其余选项顺序不变")
	var fresh_branches: Array = fresh.build_items()[1]["branches"]
	_check(fresh_branches[1] is Array and (fresh_branches[1] as Array).is_empty(), "被删选项的分支应移除，新选项分支保持为空")

	# 顺序式：新插入的选项块（show_choices + 2 个空 if）
	var new_commands: Array = []
	var show := CommandRegistry.create_command(&"show_choices")
	show.params["prompt"] = "怎么走？"
	show.params["options"] = ["上楼", "下楼"]
	new_commands.append(show)
	for i in 2:
		var branch := CommandRegistry.create_command(&"if")
		branch.params["key"] = "@@self.choice"
		branch.params["op"] = "=="
		branch.params["value"] = str(i)
		new_commands.append(branch)
	document.insert_commands(page.commands, page.commands.size(), new_commands)
	var items := document.build_items()
	var seq_choice: Dictionary = items[items.size() - 1]
	_check(str(seq_choice.get("kind", "")) == "choice", "新插入的选项块应作为独立条目出现")
	_check(str(seq_choice["pattern"]) == "sequential", "顺序式选项块应被识别（实际 %s）" % str(seq_choice["pattern"]))
	_check(bool(seq_choice["well_formed"]), "顺序式选项块应结构完整")
	_case_end()

# ── 剧情工作台：模板 ─────────────────────────────────────

func _test_story_templates() -> void:
	for id in StoryTemplates.KEYS:
		var definition := StoryTemplates.build(id)
		_check(definition != null, "模板 %s 应能生成事件" % id)
		if definition == null:
			continue
		_check(not definition.pages.is_empty(), "模板 %s 应至少有一页" % id)
		var has_commands := false
		for page in definition.pages:
			if not page.commands.is_empty():
				has_commands = true
		_check(has_commands, "模板 %s 应生成真实指令" % id)

	# 多选项模板：show_choices + 三个顺序 if
	var multi := StoryTemplates.build("multi_choice")
	var commands := multi.pages[0].commands
	_check(commands.size() == 6, "多选项模板应有 6 条指令")
	_check(str(commands[1].type) == "show_choices", "第 2 条应是选项")
	_check((commands[1].params.get("options") as Array).size() == 3, "多选项模板应有三个选项")
	for i in 3:
		_check(str(commands[2 + i].type) == "if" and str(commands[2 + i].params.get("value", "")) == str(i), "第 %d 个分支应指向 @@self.choice == %d" % [i, i])

	# 首次调查 / 重复调查：用状态库真正走一遍页面选择
	var investigate := StoryTemplates.build("investigate")
	var store := StateStore.new()
	_check(investigate.pages.size() == 2, "调查模板应有两页")
	var first_index := investigate.get_active_page(store, [&"interact"])
	_check(first_index == 1, "没调查过时应选中「首次」页（实际 %d）" % first_index)

	# 模拟首次调查：把第一条 show_text 后的开关写上（等价于跑一遍）
	store.set_value("Global.Investigate.DeskChecked", true)
	_check(investigate.get_active_page(store, [&"interact"]) == 0, "调查过后应选中「重复」页")

	# 门锁模板：两页条件互斥
	var door := StoryTemplates.build("door_lock")
	_check(door.get_active_page(store, [&"interact"]) == 1, "没钥匙应选中「锁着」页")
	store.set_value("Global.Player.HasKey", true)
	_check(door.get_active_page(store, [&"interact"]) == 0, "有钥匙应选中「开门」页")

	# 自动触发模板：trigger 应为 autorun
	var autorun := StoryTemplates.build("autorun")
	_check(autorun.pages[0].trigger == "autorun", "自动触发模板应是 autorun 页")

	# 模板资源能保存并读回
	var path := "res://.godot/test_story_template.tres"
	var saved := StoryTemplates.build("npc_dialogue")
	_check(ResourceSaver.save(saved, path) == OK, "模板事件应能保存")
	var loaded := load(path) as EventDefinition
	_check(loaded != null and loaded.pages[0].commands.size() == 4, "模板事件读回后结构一致")
	DirAccess.remove_absolute(path)
	_case_end()

# ── 剧情工作台：角色花名册 ───────────────────────────────

func _test_story_characters() -> void:
	var roster := StoryCharacters.new()
	var lily := roster.add_character("lily", "莉莉")
	lily.color = Color(0.9, 0.6, 0.7)
	lily.avatar_path = "res://addons/rpgeventstudio/samples/audio/beep.tres"
	roster.add_character("ache", "阿澈")
	_check(roster.characters.size() == 2, "应有两个角色")
	_check(roster.find_by_display_name("莉莉") == lily, "按显示名应能找到角色")
	_check(roster.unique_id("lily") == "lily2", "重复标识应自动避开")

	var path := "res://.godot/test_story_characters.tres"
	_check(StoryCharacters.save_roster(roster, path), "花名册应能保存")
	var loaded := StoryCharacters.load_roster(path)
	_check(loaded.characters.size() == 2, "花名册读回后角色数一致")
	_check(loaded.find_by_id("lily").display_name == "莉莉", "读回后显示名一致")
	_check(loaded.find_by_id("lily").color == Color(0.9, 0.6, 0.7), "读回后颜色一致")
	DirAccess.remove_absolute(path)

	# 读取不存在的文件应返回空册而不报错
	var missing := StoryCharacters.load_roster("res://.godot/no_such_roster.tres")
	_check(missing != null and missing.characters.is_empty(), "缺失花名册文件应返回空册")
	_case_end()

# ── 剧情工作台：全文预览 ─────────────────────────────────

func _test_story_preview() -> void:
	var definition: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	var document := StoryDocument.new(definition.pages[0])
	var items := document.build_items()
	var preview := StoryPreview.build(items, null)
	_check(preview.contains("图书管理员"), "预览应包含说话人名字")
	_check(preview.contains("要问点什么吗？"), "预览应包含选项提示")
	_check(preview.contains("▸ 1. 询问钥匙"), "预览应列出选项")

	# 不支持的标签应被明确列出，且预览不改变原始文案
	var line_item: Dictionary = items[0]
	var original_text := str(line_item["command"].params.get("text", ""))
	line_item["command"].params["text"] = "普通文字 [foo]未知[/foo] [b]未闭合"
	var with_bbcode := StoryPreview.build(items, null)
	_check(with_bbcode.contains("[foo]"), "预览应原样保留 BBCode（不改变原始文案）")
	var issues := StoryPreview.collect_issues(items)
	_check((issues.get("unsupported", []) as Array).has("foo"), "预览应汇总出不支持的标签")
	_check((issues.get("unclosed", []) as Array).has("b"), "预览应汇总出未闭合标签")
	var describe := Bbcode.describe(issues, true)
	_check(describe.contains("[foo]"), "问题描述应包含标签名")
	line_item["command"].params["text"] = original_text

	# 预览渲染不影响原文
	_check(str(definition.pages[0].commands[0].params.get("text", "")) == original_text, "预览后原始文案不变")
	_case_end()

# ── 关卡总控图 ───────────────────────────────────────────

func _test_graph_flow() -> void:
	var host := Node.new()
	host.name = "GraphHost1"
	root.add_child(host)
	var state := StateStore.new()
	var bus := EventBus.new()

	var graph := LevelGraph.new()
	graph.graph_id = &"test_flow"
	graph.level_id = &"school"
	var start := _gnode(graph, "start", {})
	var stage1 := _gnode(graph, "stage", {"stage_id": "exploration"})
	var cond_a := _gnode(graph, "condition", {"key": "Global.GraphA", "op": "==", "value": "true", "monitor": true})
	var cond_b := _gnode(graph, "condition", {"key": "Global.GraphB", "op": "==", "value": "true", "monitor": true})
	var merge := _gnode(graph, "merge_and", {"required": 2})
	var unlock := _gnode(graph, "action", {"key": "School.BasementUnlocked", "op": "set", "value": "true"})
	var stage2 := _gnode(graph, "stage", {"stage_id": "basement"})
	graph.connect_nodes(start.node_id, "out", stage1.node_id, "in")
	graph.connect_nodes(cond_a.node_id, "true", merge.node_id, "in")
	graph.connect_nodes(cond_b.node_id, "true", merge.node_id, "in")
	graph.connect_nodes(merge.node_id, "out", unlock.node_id, "in")
	graph.connect_nodes(unlock.node_id, "out", stage2.node_id, "in")

	var runner := GraphRunner.new()
	runner.host = host
	runner.graph = graph
	runner.state = state
	runner.bus = bus
	runner.level_prefix = "School"
	runner.start()
	await _frames(6)
	_check(str(state.get_value("School.Stage")) == "exploration", "关卡开始时应进入探索阶段")

	state.set_value("Global.GraphA", true)
	await _frames(5)
	_check(not state.get_bool("School.BasementUnlocked"), "只完成一处时不应解锁地下室")

	state.set_value("Global.GraphB", true)
	await _frames(8)
	_check(state.get_bool("School.BasementUnlocked"), "两处都完成后应自动解锁地下室")
	_check(str(state.get_value("School.Stage")) == "basement", "解锁后应切到地下室阶段")

	runner.stop()
	host.queue_free()
	_case_end()

func _test_graph_merge_or() -> void:
	var host := Node.new()
	host.name = "GraphHost2"
	root.add_child(host)
	var state := StateStore.new()
	var bus := EventBus.new()

	var graph := LevelGraph.new()
	graph.graph_id = &"test_or"
	var start := _gnode(graph, "start", {})
	var cond := _gnode(graph, "condition", {"key": "Global.GraphC", "op": "==", "value": "true", "monitor": true})
	var merge := _gnode(graph, "merge_or", {})
	var action := _gnode(graph, "action", {"key": "School.AnyOne", "op": "set", "value": "true"})
	graph.connect_nodes(start.node_id, "out", merge.node_id, "in")
	graph.connect_nodes(cond.node_id, "true", merge.node_id, "in")
	graph.connect_nodes(merge.node_id, "out", action.node_id, "in")

	var runner := GraphRunner.new()
	runner.host = host
	runner.graph = graph
	runner.state = state
	runner.bus = bus
	runner.start()
	await _frames(5)
	_check(state.get_bool("School.AnyOne"), "OR 汇合应被开始节点直接触发一次")

	state.set_value("Global.GraphC", true)
	await _frames(5)
	_check(state.get_bool("School.AnyOne"), "OR 汇合在任一条件满足时也应通过")

	runner.stop()
	host.queue_free()
	_case_end()

func _test_graph_event_node() -> void:
	var host := Node.new()
	host.name = "GraphHost3"
	root.add_child(host)
	var state := StateStore.new()
	var bus := EventBus.new()

	# 事件页是「自动执行」，图里的调用事件节点也要选「自动执行」才找得到
	var auto_event := EventDefinition.new()
	auto_event.event_id = &"autorun_probe"
	var auto_page := EventPage.new()
	auto_page.trigger = "autorun"
	auto_event.pages = [auto_page]
	var auto_path := "res://.godot/test_autorun_event.tres"
	ResourceSaver.save(auto_event, auto_path)

	var graph := LevelGraph.new()
	graph.graph_id = &"test_event"
	var start := _gnode(graph, "start", {})
	var event_node := _gnode(graph, "event", {"event_path": auto_path, "trigger": "autorun", "wait": true})
	var action := _gnode(graph, "action", {"key": "School.EventDone", "op": "set", "value": "true"})
	graph.connect_nodes(start.node_id, "out", event_node.node_id, "in")
	graph.connect_nodes(event_node.node_id, "done", action.node_id, "in")

	var started: Array = []
	var runner := GraphRunner.new()
	runner.host = host
	runner.graph = graph
	runner.state = state
	runner.bus = bus
	runner.event_starter = func(definition: EventDefinition, _args: Dictionary, filter: Array) -> void:
		if definition.get_active_page(state, filter) < 0:
			_case_end()
			return
		started.append(definition.event_id)
		_finish_event_later.call_deferred(bus, definition.event_id)
	runner.start()

	await _frames(4)
	_check(not started.is_empty(), "事件节点应调用事件运行时")
	await _frames(8)
	_check(state.get_bool("School.EventDone"), "事件完成后应继续往下传播")

	runner.stop()
	host.queue_free()
	if FileAccess.file_exists(auto_path):
		DirAccess.remove_absolute(auto_path)
	_case_end()

func _finish_event_later(bus: EventBus, event_id: StringName) -> void:
	await process_frame
	await process_frame
	bus.event_finished.emit({"event_id": event_id, "result": 0})

func _gnode(graph: LevelGraph, type: String, params: Dictionary) -> LevelNode:
	var node := LevelNode.new()
	node.node_id = graph.next_node_id(type)
	node.type = type
	node.params = params
	graph.nodes.append(node)
	return node

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

# ── 钥匙流程：两个事件页 ─────────────────────────────────

func _test_give_key_flow() -> void:
	var harness := _make_harness()
	var presenter: MockPresenter = harness["presenter"]
	var runner: EventRunner = harness["runner"]
	var state: StateStore = harness["state"]
	var definition: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")

	presenter.auto_choice = 0
	await _run_event(runner, harness["bus"], definition, [&"interact"], 60)

	_check(state.get_bool("Global.Player.HasKey"), "询问钥匙后应持有钥匙")
	_check(_contains(presenter.shown_texts, "这把钥匙给你，别弄丢了。"), "应走「给钥匙」分支")

	presenter.reset()
	await _run_event(runner, harness["bus"], definition, [&"interact"], 60)
	_check(presenter.last_text == "钥匙要收好，教室门就在右边。", "第二次对话内容应不同（实际：%s）" % presenter.last_text)
	_case_end()

func _test_choice_branch() -> void:
	var harness := _make_harness()
	var presenter: MockPresenter = harness["presenter"]
	var state: StateStore = harness["state"]
	var runner: EventRunner = harness["runner"]
	var definition: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")

	presenter.auto_choice = 1
	await _run_event(runner, harness["bus"], definition, [&"interact"], 60)

	_check(not state.get_bool("Global.Player.HasKey"), "选择「离开」不应获得钥匙")
	_check(_contains(presenter.shown_texts, "那就随便看看吧。"), "应走「离开」分支")
	_case_end()

func _test_cancel() -> void:
	var harness := _make_harness()
	var presenter: MockPresenter = harness["presenter"]
	var runner: EventRunner = harness["runner"]
	var bus: EventBus = harness["bus"]
	var definition: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")

	presenter.never_finish = true
	var result := {"received": false, "result": -1}
	bus.event_finished.connect(func(report: Dictionary) -> void:
		result["received"] = true
		result["result"] = int(report.get("result", -1))
	)

	runner.start(definition, {}, [&"interact"])
	await process_frame
	await process_frame
	runner.cancel_all("测试取消")

	var waited := 0
	while not result["received"] and waited < 120:
		await process_frame
		waited += 1

	_check(result["received"], "取消后应收到事件结束通知")
	_check(int(result["result"]) == EventRunner.Result.CANCELLED, "结果应为 CANCELLED（实际 %d）" % int(result["result"]))
	_case_end()

# ── UI 主题 ──────────────────────────────────────────────

func _test_dialogue_theme() -> void:
	var theme := RpgEventStudioTheme.new()
	theme.panel_bg_color = Color(0.12, 0.02, 0.02, 0.9)
	theme.panel_left = 0.1
	theme.panel_right = 0.9
	theme.panel_top = 0.5
	theme.panel_bottom = 0.88
	theme.text_color = Color(1.0, 0.8, 0.2)
	theme.text_font_size = 31
	theme.speaker_color = Color(0.2, 1.0, 0.4)
	theme.speaker_font_size = 27
	theme.text_speed = 88.0
	theme.fade_color = Color(0.1, 0.2, 0.4, 1)
	theme.appear_duration = 0.25
	theme.choice_selected_bg = Color(0.3, 0.1, 0.1, 1)
	theme.choice_normal_bg = Color(0.1, 0.1, 0.3, 1)

	var presenter := DialoguePresenter.new()
	root.add_child(presenter)
	await process_frame
	presenter.set_dialogue_theme(theme)
	await process_frame

	var panel: PanelContainer = presenter.get("_panel")
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(panel_style != null and panel_style.bg_color == theme.panel_bg_color, "主题背景色应用")
	_check(is_equal_approx(panel.anchor_left, 0.1) and is_equal_approx(panel.anchor_bottom, 0.88), "主题位置锚点应用")
	_check(is_equal_approx(float(presenter.get("_speed")), 88.0), "主题打字速度应用")
	_check((presenter.get("_text_label") as RichTextLabel).get_theme_font_size("normal_font_size") == 31, "主题正文字号应用")
	_check((presenter.get("_name_label") as Label).get_theme_color("font_color") == theme.speaker_color, "主题说话人颜色应用")
	_check((presenter.get("_fade_rect") as ColorRect).color == theme.fade_color, "主题转场颜色应用")

	presenter.show_text("旁白", "[b]主题[/b]")
	_check(str(presenter.get("last_parsed_text")) == "主题", "主题预览/运行时仍解析 BBCode")
	_check(presenter.get("_panel_tween") != null, "出现动画创建 tween")

	presenter.show_choices("请选择", ["甲", "乙"])
	var buttons: Array = presenter.get("_choice_buttons")
	_check(buttons.size() == 2, "主题选项按钮创建")
	if buttons.size() == 2:
		var first_style := (buttons[0] as Button).get_theme_stylebox("normal") as StyleBoxFlat
		var second_style := (buttons[1] as Button).get_theme_stylebox("normal") as StyleBoxFlat
		_check(first_style != null and first_style.bg_color == theme.choice_selected_bg, "选中项使用选中背景")
		_check(second_style != null and second_style.bg_color == theme.choice_normal_bg, "未选中项使用普通背景")
	presenter.close_all()
	presenter.queue_free()
	await process_frame

	# 主题资源保存 / 读取
	var path := "res://.godot/test_dialogue_theme.tres"
	_check(ResourceSaver.save(theme, path) == OK, "主题资源可以保存")
	var loaded := load(path) as RpgEventStudioTheme
	_check(loaded != null and is_equal_approx(loaded.text_speed, 88.0), "主题资源可以重新读取")
	DirAccess.remove_absolute(path)

	# 交互提示也使用同一主题
	var runtime: Node = root.get_node_or_null("RPGEventStudio")
	if runtime != null:
		runtime.call("apply_dialogue_theme", theme)
		var interactor := EventInteractor2D.new()
		interactor.event = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
		interactor.interaction_radius = 70.0
		root.add_child(interactor)
		await process_frame
		var prompt: Label = interactor.get("_prompt")
		_check(prompt != null and prompt.get_theme_font_size("font_size") == theme.prompt_font_size, "交互提示字号应用主题")
		_check(prompt != null and is_equal_approx(prompt.position.y, -70.0 + theme.prompt_offset_y), "交互提示偏移应用主题")
		interactor.queue_free()
		runtime.call("apply_dialogue_theme", RpgEventStudioTheme.new())
	await process_frame
	_case_end()

# ── 地图事件对象 ────────────────────────────────────────# ── 地图事件对象 ────────────────────────────────────────

func _test_map_event() -> void:
	var librarian: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	_check(librarian != null, "地图事件测试需要示例事件资源")
	if librarian == null:
		_case_end()
		return

	# 事件关联 / 状态
	var node := MapEvent2D.new()
	root.add_child(node)
	await process_frame
	_check(node.event_link_status() == MapEvent2D.LINK_MISSING, "新建地图事件默认未关联")
	_check(node.status_text() != "", "未关联时应有状态文案")
	node.event = librarian
	_check(node.event_link_status() == MapEvent2D.LINK_OK, "关联事件后状态正常")
	_check(node.resolved_event() == librarian, "能解析关联事件")
	_check(node.kind_label() != "" and node.trigger_label() != "" and node.layer_label() != "", "地图事件有类型/触发/层级文案")

	# 层级映射到 Godot 原生 z_index
	node.layer_mode = MapEvent2D.LayerMode.BELOW_PLAYER
	_check(node.z_index == -1 and node.z_as_relative, "角色下方映射为相对 z_index = -1")
	node.layer_mode = MapEvent2D.LayerMode.SAME_LAYER
	_check(node.z_index == 0, "角色同层映射为 z_index = 0")
	node.layer_mode = MapEvent2D.LayerMode.ABOVE_PLAYER
	_check(node.z_index == 1, "角色上方映射为 z_index = 1")
	node.layer_mode = MapEvent2D.LayerMode.CUSTOM
	node.custom_z_index = 7
	_check(node.z_index == 7, "自定义层级使用 custom_z_index")

	# 交互组件
	node.trigger_mode = MapEvent2D.TriggerMode.INTERACT
	node.interaction_radius = 96.0
	node._setup_runtime()
	var interactor := node.get_node_or_null(MapEvent2D.RUNTIME_INTERACTOR)
	_check(interactor is EventInteractor2D, "交互模式挂载 EventInteractor2D")
	if interactor is EventInteractor2D:
		_check(interactor.event == librarian, "交互组件拿到事件")
		_check(is_equal_approx(interactor.interaction_radius, 96.0), "交互组件拿到交互半径")

	# 进入区域
	node.trigger_mode = MapEvent2D.TriggerMode.REGION_ENTER
	node.trigger_radius = 140.0
	node._setup_runtime()
	var area := node.get_node_or_null(MapEvent2D.RUNTIME_TRIGGER)
	_check(area is EventTriggerArea2D, "进入区域挂载 EventTriggerArea2D")
	if area is EventTriggerArea2D:
		_check(area.trigger_on_enter and not area.trigger_on_exit, "进入区域只开启进入触发")
		_check(is_equal_approx(area.radius, 140.0), "触发区域拿到半径")

	# 离开区域
	node.trigger_mode = MapEvent2D.TriggerMode.REGION_EXIT
	node._setup_runtime()
	area = node.get_node_or_null(MapEvent2D.RUNTIME_TRIGGER)
	if area is EventTriggerArea2D:
		_check(not area.trigger_on_enter and area.trigger_on_exit, "离开区域只开启离开触发")

	# 自动 / 并行
	node.trigger_mode = MapEvent2D.TriggerMode.AUTORUN
	node._setup_runtime()
	var auto := node.get_node_or_null(MapEvent2D.RUNTIME_AUTORUN)
	_check(auto is EventAutoRun2D and not auto.is_parallel, "自动执行挂载 EventAutoRun2D")
	node.trigger_mode = MapEvent2D.TriggerMode.PARALLEL
	node._setup_runtime()
	auto = node.get_node_or_null(MapEvent2D.RUNTIME_AUTORUN)
	_check(auto is EventAutoRun2D and auto.is_parallel, "并行执行挂载 EventAutoRun2D(is_parallel)")

	# 配置警告
	node.event = null
	node.event_path = ""
	_check(_has_warning(node, "map.warning.no_event"), "未关联事件应产生配置警告")
	node.event_path = "res://no_such_event.tres"
	_check(_has_warning(node, "map.warning.invalid_path", {"path": node.event_path}), "失效路径应产生配置警告")
	node.event_path = "res://addons/rpgeventstudio/samples/demo_theme.tres"
	_check(_has_warning(node, "map.warning.not_event", {"path": node.event_path}), "非事件资源应产生配置警告")
	node.event = librarian
	node.event_path = ""
	node.trigger_mode = MapEvent2D.TriggerMode.REGION_ENTER
	_check(_has_warning(node, "map.warning.trigger_mismatch", {"trigger": node.trigger_label()}), "触发方式没有匹配页时应警告")

	# 示例场景里的事件总览扫描
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	var a := MapEvent2D.new()
	a.name = "A"
	scene_root.add_child(a)
	var b := MapEvent2D.new()
	b.name = "B"
	scene_root.add_child(b)
	_check(MapEvent2D.collect_in(scene_root).size() == 2, "能扫描当前场景里的地图事件")
	scene_root.queue_free()

	# 运行时真正触发：交互 / 进入区域 / 自动 / 并行
	var runtime: Node = root.get_node_or_null("RPGEventStudio")
	if runtime != null:
		runtime.call("restore_default_presenter")
		var interact_node := MapEvent2D.new()
		interact_node.event = _make_switch_event(&"map_event_interact_probe", "interact", "Test.MapEvent.Interact")
		interact_node.trigger_mode = MapEvent2D.TriggerMode.INTERACT
		root.add_child(interact_node)
		await process_frame
		var runtime_interactor := interact_node.get_node_or_null(MapEvent2D.RUNTIME_INTERACTOR)
		_check(runtime_interactor is EventInteractor2D, "运行时交互组件已挂载")
		if runtime_interactor is EventInteractor2D:
			runtime_interactor.trigger()
			await process_frame
			await process_frame
			_check(bool(runtime.call("get_state", "Test.MapEvent.Interact", false)), "交互模式能真正启动事件")
		interact_node.queue_free()

		var player := Node2D.new()
		player.name = "MapEventTestPlayer"
		player.add_to_group("player")
		root.add_child(player)
		var region_node := MapEvent2D.new()
		region_node.event = _make_switch_event(&"map_event_region_probe", "region_enter", "Test.MapEvent.Region")
		region_node.trigger_mode = MapEvent2D.TriggerMode.REGION_ENTER
		region_node.trigger_radius = 40.0
		root.add_child(region_node)
		await process_frame
		await process_frame
		await process_frame
		_check(bool(runtime.call("get_state", "Test.MapEvent.Region", false)), "进入区域能真正启动事件")
		region_node.queue_free()
		player.queue_free()

		var auto_node := MapEvent2D.new()
		auto_node.event = _make_switch_event(&"map_event_autorun_probe", "autorun", "Test.MapEvent.Autorun")
		auto_node.trigger_mode = MapEvent2D.TriggerMode.AUTORUN
		root.add_child(auto_node)
		await process_frame
		await process_frame
		_check(bool(runtime.call("get_state", "Test.MapEvent.Autorun", false)), "自动执行能真正启动事件")
		auto_node.queue_free()

		var parallel_node := MapEvent2D.new()
		parallel_node.event = _make_switch_event(&"map_event_parallel_probe", "parallel", "Test.MapEvent.Parallel")
		parallel_node.trigger_mode = MapEvent2D.TriggerMode.PARALLEL
		root.add_child(parallel_node)
		await process_frame
		await process_frame
		_check(bool(runtime.call("get_state", "Test.MapEvent.Parallel", false)), "并行执行能真正启动事件")
		parallel_node.queue_free()

	await process_frame
	node.queue_free()
	await process_frame
	_case_end()

func _make_switch_event(id: StringName, trigger: String, key: String) -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = id
	var page := EventPage.new()
	page.trigger = trigger
	var command := CommandRegistry.create_command(&"set_switch")
	command.params["key"] = key
	command.params["value"] = true
	page.commands = [command]
	definition.pages = [page]
	return definition

func _has_warning(node: MapEvent2D, key: String, params: Dictionary = {}) -> bool:
	var expected := L10n.ui(key, params)
	for text in node._get_configuration_warnings():
		if String(text).contains(expected):
			return true
	return false

# ── 展示层注入 ───────────────────────────────────────────

func _test_presenter_injection() -> void:
	var runtime: Node = root.get_node_or_null("RPGEventStudio")
	_check(runtime != null, "运行时 Autoload 可用于展示层注入测试")
	if runtime == null:
		_case_end()
		return

	runtime.call("restore_default_presenter")
	var default_presenter: Node = runtime.get("presenter")
	var runner: EventRunner = runtime.get("runner")
	var bus: EventBus = runtime.get("bus")
	_check(default_presenter is DialoguePresenter, "默认展示层应是插件自带的 DialoguePresenter")
	_check(bool(runtime.call("is_using_default_presenter")), "初始状态应使用默认展示层")

	var custom := MockPresenter.new()
	custom.name = "InjectedPresenter"
	root.add_child(custom)
	custom.auto_confirm = true
	_check(bool(runtime.call("set_presenter", custom)), "满足协议的对象应能注入")
	_check(runtime.get("presenter") == custom, "运行时当前展示层应切到注入对象")
	_check(runner.presenter == custom, "事件运行时也应使用注入对象")
	_check(not default_presenter.visible, "注入后默认 UI 应隐藏")
	_check(not default_presenter.is_processing(), "注入后默认 UI 不应继续处理")

	var text_event := _make_text_event(&"injected_text", "注入后的文本")
	_check(await _run_runtime_event(runtime, text_event, 90), "注入展示层后事件应能完成")
	_check(_contains(custom.shown_texts, "注入后的文本"), "事件文本应交给注入的展示层")

	# 不满足协议的对象必须被拒绝，且不能破坏当前展示层
	var broken := Object.new()
	_expect_error_begin("presenter-protocol")
	_check(not bool(runtime.call("set_presenter", broken)), "缺少协议方法的对象应被拒绝")
	_expect_error_end("presenter-protocol")
	_check(runtime.get("presenter") == custom, "拒绝非法对象后展示层应保持不变")

	# 运行中替换展示层：旧事件应被取消、旧 UI 应收到 close_all
	custom.never_finish = true
	var report := {}
	var handler := func(value: Dictionary) -> void:
		report["value"] = value
	bus.event_finished.connect(handler)
	runtime.call("start_event", _make_text_event(&"injected_cancel", "等待替换"), {}, [])
	await process_frame
	await process_frame
	_check(custom.last_text == "等待替换", "替换前应正在显示文本")
	var replacement := MockPresenter.new()
	replacement.name = "ReplacementPresenter"
	root.add_child(replacement)
	_check(bool(runtime.call("set_presenter", replacement)), "运行中应允许替换展示层")
	var waited := 0
	while report.is_empty() and waited < 120:
		await process_frame
		waited += 1
	bus.event_finished.disconnect(handler)
	_check(int((report.get("value", {}) as Dictionary).get("result", -1)) == EventRunner.Result.CANCELLED, "替换展示层应取消旧事件")
	_check(custom.close_count > 0, "旧展示层应收到 close_all")
	_check(runner.presenter == replacement, "替换后运行时指向新展示层")

	# 恢复默认：默认 UI 重新可见，并且仍然能正常工作
	_check(bool(runtime.call("restore_default_presenter")), "应能恢复默认展示层")
	_check(runtime.get("presenter") == default_presenter, "恢复后当前展示层应是默认 UI")
	_check(runner.presenter == default_presenter, "恢复后事件运行时也应回到默认 UI")
	_check(default_presenter.visible and default_presenter.is_processing(), "恢复后默认 UI 应重新工作")
	_check(await _run_runtime_event_with_default(runtime, _make_text_event(&"default_ui_text", "默认界面文本"), 240), "恢复默认 UI 后事件应能完成")
	_check(_contains(default_presenter.shown_texts, "默认界面文本"), "默认 UI 应收到事件文本")

	# 测试收尾：换成新的注入对象，避免影响其它用例
	var cleanup := MockPresenter.new()
	cleanup.name = "CleanupPresenter"
	root.add_child(cleanup)
	runtime.call("set_presenter", cleanup)
	runtime.call("restore_default_presenter")
	cleanup.queue_free()
	custom.queue_free()
	replacement.queue_free()
	_case_end()

func _make_text_event(id: StringName, text: String) -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = id
	definition.display_name = String(text)
	var page := EventPage.new()
	page.trigger = "interact"
	var command := CommandRegistry.create_command(&"show_text")
	command.params["text"] = text
	page.commands = [command]
	definition.pages = [page]
	return definition

func _run_runtime_event(runtime: Node, definition: EventDefinition, max_frames: int) -> bool:
	var finished := {"done": false}
	var callback := func(_report: Dictionary) -> void:
		finished["done"] = true
	var bus: EventBus = runtime.get("bus")
	bus.event_finished.connect(callback)
	runtime.call("start_event", definition, {}, [])
	var frames := 0
	while not finished["done"] and frames < max_frames:
		await process_frame
		frames += 1
	bus.event_finished.disconnect(callback)
	_check(finished["done"], "事件应在 %d 帧内结束（%s）" % [max_frames, definition.event_id])
	return finished["done"]

## 默认 DialoguePresenter 需要真人按键；测试里用“点击推进”把它走完。
func _run_runtime_event_with_default(runtime: Node, definition: EventDefinition, max_frames: int) -> bool:
	var finished := {"done": false}
	var callback := func(_report: Dictionary) -> void:
		finished["done"] = true
	var bus: EventBus = runtime.get("bus")
	var presenter: Node = runtime.get("presenter")
	bus.event_finished.connect(callback)
	runtime.call("start_event", definition, {}, [])
	var frames := 0
	while not finished["done"] and frames < max_frames:
		await process_frame
		if presenter != null and bool(presenter.get("_waiting_confirm")):
			presenter.set("_mouse_click", true)
		frames += 1
	bus.event_finished.disconnect(callback)
	return finished["done"]


func _make_harness() -> Dictionary:
	var host := Node.new()
	host.name = "TestHost"
	root.add_child(host)

	var presenter := MockPresenter.new()
	presenter.name = "MockPresenter"
	host.add_child(presenter)

	var state := StateStore.new()
	var bus := EventBus.new()
	var runner := EventRunner.new()
	runner.host = host
	runner.state = state
	runner.bus = bus
	runner.presenter = presenter
	runner.registry = CommandRegistry.new()

	return {
		"host": host,
		"presenter": presenter,
		"state": state,
		"bus": bus,
		"runner": runner,
	}

func _run_event(runner: EventRunner, bus: EventBus, definition: EventDefinition, trigger_filter: Array, max_frames: int) -> void:
	var finished := {"done": false}
	var callback := func(_report: Dictionary) -> void:
		finished["done"] = true
	bus.event_finished.connect(callback)
	runner.start(definition, {}, trigger_filter)

	var frames := 0
	while not finished["done"] and frames < max_frames:
		await process_frame
		frames += 1
	bus.event_finished.disconnect(callback)
	_check(finished["done"], "事件应在 %d 帧内结束" % max_frames)

func _contains(list: PackedStringArray, needle: String) -> bool:
	for item in list:
		if String(item).contains(needle):
			return true
	return false

func _case_begin(name: String) -> void:
	_case_name = name
	_case_start_checks = _checks
	_case_expected.append(name)
	print("CASE_BEGIN ", name)

func _case_end() -> void:
	if _case_name == "":
		return
	_case_done[_case_name] = true
	print("CASE_END %s checks=%d" % [_case_name, _checks - _case_start_checks])

func _case_verify(name: String) -> void:
	if not _case_done.has(name):
		_checks += 1
		_failures.append("测试函数未正常完成：" + name)
		print("CASE_INCOMPLETE ", name)
		print("  ✗ 测试函数未正常完成：", name)
	_case_name = ""

func _expect_error_begin(label: String) -> void:
	printerr("EXPECTED_ERROR_BEGIN ", label)

func _expect_error_end(label: String) -> void:
	printerr("EXPECTED_ERROR_END ", label)

## 故障注入：只在 RPGEVENTSTUDIO_TEST_FAULT 设置时由 _run 调用。
func _inject_fault(kind: String) -> void:
	match kind:
		"type":
			# JSON.parse_string 返回 Variant，运行时才会暴露 Dictionary 类型不匹配。
			var bad: Dictionary = JSON.parse_string("[]")
			print("unreachable ", bad)
		"null":
			var missing: Node = null
			missing.name = "fault"
		"skip":
			pass
		"expected_error":
			_expect_error_begin("injected")
			push_error("injected expected error")
			_expect_error_end("injected")
			_case_end()
		_:
			_case_end()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──────── 测试结果 ────────")
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
	print("CASES：预期 %d，完成 %d" % [_case_expected.size(), _case_done.size()])
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))

# ── 关卡图静态校验 ────────────────────────────────────────

func _gval(graph: LevelGraph) -> Array:
	return GraphValidator.validate(graph, "School")

func _vcode(issues: Array, code: String) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false

func _vseverity(issues: Array, code: String) -> int:
	for issue in issues:
		if issue.code == code:
			return issue.severity
	return -1

func _test_graph_validator() -> void:
	# 空图：缺开始节点（错误）
	var empty := LevelGraph.new()
	_check(_vseverity(_gval(empty), "start_missing") == GraphIssue.Severity.ERROR, "空图应报「缺开始节点」且为错误")

	# 两个启用开始（错误）+ 一个禁用（提示）
	var two_starts := LevelGraph.new()
	_gnode(two_starts, "start", {})
	_gnode(two_starts, "start", {})
	var disabled_start := _gnode(two_starts, "start", {})
	disabled_start.enabled = false
	var issues := _gval(two_starts)
	_check(_vseverity(issues, "start_duplicate") == GraphIssue.Severity.ERROR, "多个启用开始节点应为错误")
	_check(_vseverity(issues, "start_disabled") == GraphIssue.Severity.INFO, "禁用开始节点应为提示")

	# 断裂引用 / 错误端口 / 连到开始（错误）
	var broken := LevelGraph.new()
	var b_start := _gnode(broken, "start", {})
	var b_action := _gnode(broken, "action", {"key": "School.BasementUnlocked", "op": "set", "value": "true"})
	broken.connect_nodes(&"ghost", "out", b_action.node_id, "in")
	var bad_port := LevelConnection.new()
	bad_port.from_node = b_action.node_id
	bad_port.from_port = "done"
	bad_port.to_node = b_start.node_id
	broken.connections.append(bad_port)
	broken.connect_nodes(b_action.node_id, "out", b_start.node_id, "in")
	issues = _gval(broken)
	_check(_vseverity(issues, "conn_broken") == GraphIssue.Severity.ERROR, "断裂引用应为错误")
	_check(_vseverity(issues, "conn_port") == GraphIssue.Severity.ERROR, "错误端口应为错误")
	_check(_vseverity(issues, "conn_to_start") == GraphIssue.Severity.ERROR, "连到开始节点应为错误")

	# 必填参数（错误）与未登记状态（警告）
	var params := LevelGraph.new()
	_gnode(params, "start", {})
	_gnode(params, "condition", {"key": "", "op": "==", "value": "true"})
	_gnode(params, "action", {"key": "School.NotRegistered", "op": "set", "value": "true"})
	_gnode(params, "stage", {"stage_id": ""})
	_gnode(params, "event", {"event_path": ""})
	_gnode(params, "event", {"event_path": "res://nowhere.tres"})
	var end_node := _gnode(params, "end", {"completed_key": ""})
	_check(_vseverity(_gval(params), "param_missing") == GraphIssue.Severity.ERROR, "条件/动作/阶段/事件缺参数应为错误")
	_check(_vseverity(_gval(params), "state_unregistered") == GraphIssue.Severity.WARNING, "未登记状态应为警告")
	_check(_vseverity(_gval(params), "event_path_missing") == GraphIssue.Severity.ERROR, "事件路径不存在应为错误")
	_check(_vseverity(_gval(params), "end_no_key") == GraphIssue.Severity.INFO, "完成标记未填应为提示")

	# merge_and：required 超过输入（错误）；无输入（警告）
	var merge := LevelGraph.new()
	_gnode(merge, "start", {})
	var m_and := _gnode(merge, "merge_and", {"required": 3})
	_check(_vseverity(_gval(merge), "merge_over_required") == GraphIssue.Severity.ERROR, "required 超过输入应为错误")
	m_and.params["required"] = 0
	_check(_vseverity(_gval(merge), "merge_no_input") == GraphIssue.Severity.WARNING, "汇合无输入应为警告")

	# 不可达节点（警告）；监视条件不需要入边
	var reach := LevelGraph.new()
	var r_start := _gnode(reach, "start", {})
	var r_island := _gnode(reach, "action", {"key": "School.BasementUnlocked", "op": "set", "value": "true"})
	_check(_vseverity(_gval(reach), "reach_unreachable") == GraphIssue.Severity.WARNING, "不可达节点应为警告")

	# 监视条件不靠入边触发：无入边的监视条件不应判为不可达
	var reach2 := LevelGraph.new()
	var r2_start := _gnode(reach2, "start", {})
	var r2_act := _gnode(reach2, "action", {"key": "School.BasementUnlocked", "op": "set", "value": "true"})
	_gnode(reach2, "condition", {"key": "School.Office.DiaryFound", "op": "==", "value": "true", "monitor": true})
	reach2.connect_nodes(r2_start.node_id, "out", r2_act.node_id, "in")
	var reach2_issues := _gval(reach2)
	_check(not _vcode(reach2_issues, "reach_unreachable"), "无入边的监视条件不应判为不可达")
	_check(_vseverity(reach2_issues, "cond_no_branch") == GraphIssue.Severity.WARNING, "监视条件两个出口都没接应为警告")

	# 条件只接了一个出口应为提示
	var one_branch := LevelGraph.new()
	var ob_start := _gnode(one_branch, "start", {})
	var ob_cond := _gnode(one_branch, "condition", {"key": "School.Office.DiaryFound", "op": "==", "value": "true", "monitor": false})
	var ob_act := _gnode(one_branch, "action", {"key": "School.BasementUnlocked", "op": "set", "value": "true"})
	one_branch.connect_nodes(ob_start.node_id, "out", ob_cond.node_id, "in")
	one_branch.connect_nodes(ob_cond.node_id, "true", ob_act.node_id, "in")
	_check(_vseverity(_gval(one_branch), "cond_branch_missing") == GraphIssue.Severity.INFO, "只接 true 出口应为提示")

	# 无闸门令牌环（错误）；带 AND 汇合的环（提示）
	var loop := LevelGraph.new()
	var l_start := _gnode(loop, "start", {})
	var l_a := _gnode(loop, "action", {"key": "School.BasementUnlocked", "op": "set", "value": "true"})
	var l_b := _gnode(loop, "stage", {"stage_id": "exploration"})
	loop.connect_nodes(l_start.node_id, "out", l_a.node_id, "in")
	loop.connect_nodes(l_a.node_id, "out", l_b.node_id, "in")
	loop.connect_nodes(l_b.node_id, "out", l_a.node_id, "in")
	issues = _gval(loop)
	_check(_vseverity(issues, "cycle_unguarded") == GraphIssue.Severity.ERROR, "无闸门令牌环应为错误（运行时会传播到上限中止）")

	var gated := LevelGraph.new()
	var g_start := _gnode(gated, "start", {})
	var g_a := _gnode(gated, "action", {"key": "School.BasementUnlocked", "op": "set", "value": "true"})
	var g_m := _gnode(gated, "merge_and", {"required": 1})
	gated.connect_nodes(g_start.node_id, "out", g_a.node_id, "in")
	gated.connect_nodes(g_a.node_id, "out", g_m.node_id, "in")
	gated.connect_nodes(g_m.node_id, "out", g_a.node_id, "in")
	issues = _gval(gated)
	_check(_vseverity(issues, "cycle_gated") == GraphIssue.Severity.INFO, "经过 AND 汇合的循环应为提示（fired 只放行一次）")
	_check(not _vcode(issues, "cycle_unguarded"), "带闸门的循环不应报错误")

	# 监视条件互相触发的振荡（警告）：A 写入能让 B 成立的值，B 又写回能让 A 成立的值
	var ping := LevelGraph.new()
	_gnode(ping, "start", {})
	var p_a := _gnode(ping, "action", {"key": "School.BasementUnlocked", "op": "set", "value": "true"})
	var p_b := _gnode(ping, "action", {"key": "School.Office.DiaryFound", "op": "set", "value": "true"})
	var m1 := _gnode(ping, "condition", {"key": "School.Office.DiaryFound", "op": "==", "value": "true", "monitor": true})
	var m2 := _gnode(ping, "condition", {"key": "School.BasementUnlocked", "op": "==", "value": "true", "monitor": true})
	ping.connect_nodes(m1.node_id, "true", p_a.node_id, "in")
	ping.connect_nodes(m2.node_id, "true", p_b.node_id, "in")
	issues = _gval(ping)
	_check(_vseverity(issues, "monitor_oscillation") == GraphIssue.Severity.WARNING,
		"监视条件互相写入对方键且取值满足对方条件时应报振荡警告")

	# 单个监视条件写自己的键是合法的阶段推进（不应报振荡）
	var solo := LevelGraph.new()
	_gnode(solo, "start", {})
	var s_stage := _gnode(solo, "stage", {"stage_id": "exploration"})
	var s_m := _gnode(solo, "condition", {"key": "School.Stage", "op": "==", "value": "exploration", "monitor": true})
	var s_act := _gnode(solo, "action", {"key": "School.Stage", "op": "set", "value": "basement"})
	solo.connect_nodes(s_m.node_id, "true", s_act.node_id, "in")
	solo.connect_nodes(s_m.node_id, "false", s_stage.node_id, "in")
	_check(not _vcode(_gval(solo), "monitor_oscillation"), "监视条件写自身键的合法模式不应报振荡")

	# 示例图整体无错误
	var sample: LevelGraph = load("res://addons/rpgeventstudio/samples/graphs/school_graph.tres")
	_check(sample != null and not GraphValidator.has_errors(_gval(sample)), "示例关卡图不应有错误")
	_case_end()

func _test_group_persistence() -> void:
	var graph := LevelGraph.new()
	var n1 := _gnode(graph, "start", {})
	var n2 := _gnode(graph, "stage", {"stage_id": "exploration"})
	var n3 := _gnode(graph, "action", {"key": "School.BasementUnlocked", "op": "set", "value": "true"})

	var group := LevelGroup.new()
	group.group_id = graph.next_group_id()
	group.title = "探索区"
	group.color = Color(0.4, 0.6, 0.9, 0.2)
	group.position = Vector2(10, 20)
	group.size = Vector2(300, 200)
	group.add_member(n1.node_id)
	group.add_member(n2.node_id)
	graph.add_group(group)
	_check(graph.group_of(n1.node_id) == group, "group_of 应找到所在分组")

	var path := "res://.godot/group_roundtrip.tres"
	_check(ResourceSaver.save(graph, path) == OK, "带分组的关卡图应能保存")
	var reloaded := load(path) as LevelGraph
	_check(reloaded != null and reloaded.groups.size() == 1, "重新读取后分组应保留")
	if reloaded != null and reloaded.groups.size() == 1:
		var saved := reloaded.groups[0]
		_check(saved.title == "探索区", "分组名保留")
		_check(saved.member_ids.size() == 2 and saved.member_ids[0] == n1.node_id, "分组成员保留")
		_check(saved.position == Vector2(10, 20) and saved.size == Vector2(300, 200), "分组位置与大小保留")
		_check(saved.color.is_equal_approx(Color(0.4, 0.6, 0.9, 0.2)), "分组颜色保留")

	# 删除节点应自动清理分组成员；删除分组不删节点
	var target_group := reloaded.groups[0]
	reloaded.remove_node(n2.node_id)
	_check(target_group.member_ids.size() == 1, "删除节点应从分组移除成员")
	var kept := reloaded.remove_group(target_group.group_id)
	_check(kept == target_group and reloaded.groups.is_empty(), "删除分组应只移除分组本身")
	_check(reloaded.nodes.size() == 2, "删除分组不应删除节点")
	_check(reloaded.next_group_id() == StringName("group_1"), "分组 id 生成应避开节点 id")

	DirAccess.remove_absolute(path)
	_case_end()

# ── 剧情资源审计 ──────────────────────────────────────────

func _test_story_audit() -> void:
	var report := StoryAudit.scan({
		"roots": PackedStringArray(["res://tests/fixtures/audit"]),
		"excludes": PackedStringArray(),
		"catalog": StateCatalog.new(),
	})
	var issues: Array = report["issues"]
	_check(int(report["stats"]["events"]) == 6, "审计应扫描到 6 个夹具事件")
	_check(_audit_has(issues, "event.empty"), "审计应报告空事件")
	_check(_audit_has(issues, "event.duplicate_id"), "审计应报告重复事件标识")
	_check(_audit_has(issues, "ref.broken"), "审计应报告断裂引用")
	_check(StoryAudit.has_errors(issues), "夹具中应存在错误级问题")
	var sample := StoryAudit.scan({
		"roots": PackedStringArray(["res://addons/rpgeventstudio/samples"]),
		"excludes": PackedStringArray(),
		"catalog": StateCatalogStore.catalog(),
	})
	_check(not StoryAudit.has_errors(sample["issues"]), "样例资源不应有审计错误")
	_case_end()

func _audit_has(issues: Array, code: String) -> bool:
	for issue in issues:
		if str(issue["code"]) == code:
			return true
	return false
