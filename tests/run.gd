extends SceneTree
## 自建测试入口（不依赖任何第三方插件）：
##   godot --headless --path . --script res://tests/run.gd
## 退出码 0 = 全部通过。

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_state_store()
	_test_page_selection()
	_test_condition_defaults()
	_test_state_catalog()
	_test_event_diagnosis()
	_test_input_service()
	_test_input_settings_panel()
	_test_l10n()
	_test_nested_serialization()
	await _test_graph_flow()
	await _test_graph_merge_or()
	await _test_graph_event_node()
	await _test_give_key_flow()
	await _test_choice_branch()
	await _test_cancel()
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
	_check(service.describe(InputService.ACTION_INTERACT)["keyboard"].has("K"), "设置界面应显示新的键盘绑定")

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

func _has_event(events: Array, target: InputEvent) -> bool:
	for event in events:
		if InputService.same_event(event, target):
			return true
	return false

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

	# CSV 是翻译的源文件：逐行确认两种语言都能取到
	var file := FileAccess.open("res://addons/rpgeventstudio/i18n/ui.csv", FileAccess.READ)
	_check(file != null, "应能读取翻译源文件 ui.csv")
	if file == null:
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

# ── 工具 ─────────────────────────────────────────────────

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
