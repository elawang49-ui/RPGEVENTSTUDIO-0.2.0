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
	_test_bbcode()
	_test_nested_serialization()
	await _test_graph_flow()
	await _test_graph_merge_or()
	await _test_graph_event_node()
	await _test_give_key_flow()
	await _test_choice_branch()
	await _test_cancel()
	await _test_presenter_injection()
	await _test_bbcode_presenter()
	await _test_map_event()
	await _test_dialogue_theme()
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

# ── 地图事件对象 ────────────────────────────────────────# ── 地图事件对象 ────────────────────────────────────────

func _test_map_event() -> void:
	var librarian: EventDefinition = load("res://addons/rpgeventstudio/samples/events/librarian.tres")
	_check(librarian != null, "地图事件测试需要示例事件资源")
	if librarian == null:
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
	_check(not bool(runtime.call("set_presenter", broken)), "缺少协议方法的对象应被拒绝")
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
