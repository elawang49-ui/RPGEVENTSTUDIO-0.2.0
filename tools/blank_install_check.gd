extends SceneTree
## 空白工程独立安装验证：在只复制 addons/rpgeventstudio 的新项目里运行。
##   godot --headless --path <blank_project> --script res://check_story.gd
## 覆盖：插件加载、Autoload 注册、默认状态库/花名册/主题缺失降级、
##       新建事件与关卡图、最小剧情真实执行。
## 本脚本只依赖插件 addon，不依赖宿主工程。

var _fails := 0
var _checks := 0

class MiniPresenter:
	extends Node
	var finished := true
	func show_text(_s, _t, _a = 0.0): finished = true
	func is_text_finished() -> bool: return finished
	func show_choices(_p, _o): pass
	func get_choice() -> int: return -1
	func close_all(): finished = true

func _init() -> void:
	_run.call_deferred()

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond: print("  ✓ ", msg)
	else: print("  ✗ ", msg); _fails += 1

func _run() -> void:
	_check(StateCatalogStore.catalog() != null, "状态库文件缺失时返回空表")
	var roster := StoryCharacters.new()
	var roster_saved: bool = StoryCharacters.save_roster(roster)
	_check(roster_saved, "角色花名册缺失时可保存（自动建目录）")

	var runtime := root.get_node_or_null("RPGEventStudio")
	_check(runtime is StudioRuntime, "Autoload 已注册且类型正确")
	var theme = runtime.get("dialogue_theme") if runtime != null else null
	_check(theme != null, "UI 主题文件缺失时使用默认主题")

	var host := Node.new()
	root.add_child(host)
	var presenter := MiniPresenter.new()
	host.add_child(presenter)
	var state := StateStore.new()
	var bus := EventBus.new()
	var runner := EventRunner.new()
	runner.host = host
	runner.state = state
	runner.bus = bus
	runner.presenter = presenter
	runner.registry = CommandRegistry.new()

	var definition := EventDefinition.new()
	definition.event_id = &"blank_test"
	definition.display_name = "空白工程测试"
	var page := EventPage.new()
	var setter := CommandRegistry.create_command(&"set_switch")
	setter.params["key"] = "Global.Blank.Flag"
	setter.params["value"] = true
	var commands: Array[EventCommand] = [setter, CommandRegistry.create_command(&"end")]
	page.commands = commands
	definition.pages = [page]

	DirAccess.make_dir_recursive_absolute("res://events")
	_check(ResourceSaver.save(definition, "res://events/blank_test.tres") == OK, "可以新建并保存事件资源")
	var reloaded := ResourceLoader.load("res://events/blank_test.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as EventDefinition
	_check(reloaded != null and reloaded != definition and reloaded.pages[0].commands[0].params["key"] == "Global.Blank.Flag", "事件资源绕开缓存反序列化一致")
	runner.start(reloaded)
	for i in 120:
		if runner.active_count() == 0: break
		await process_frame
	_check(state.get_bool("Global.Blank.Flag"), "最小剧情真实执行并写入状态")

	var graph := LevelGraph.new()
	graph.graph_id = &"blank_graph"
	var start := LevelNode.new()
	start.node_id = &"start_1"
	start.type = "start"
	graph.nodes.append(start)
	graph.entry_node = &"start_1"
	_check(ResourceSaver.save(graph, "res://events/blank_graph.tres") == OK, "可以新建并保存关卡图资源")

	if OS.get_environment("RPGEVENTSTUDIO_BLANK_TEST_FAULT") == "1":
		_check(false, "expected injected failure")
	host.queue_free()
	await process_frame
	print("检查项：%d，失败：%d" % [_checks, _fails])
	print("")
	print("BLANK RESULT: %s (failures=%d)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)
