extends SceneTree
## 场景对象引用测试：同场景解析、同名区分、跨场景、失效、选择器、指令执行、保存重载。

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := PackedScene.new()
	var scene_root := Node2D.new()
	scene_root.name = "RefScene"
	var npc := Node2D.new()
	npc.name = "NPC"
	scene_root.add_child(npc)
	var group := Node2D.new()
	group.name = "Group"
	scene_root.add_child(group)
	var npc2 := Node2D.new()
	npc2.name = "NPC"
	group.add_child(npc2)
	_set_owner(scene_root, scene_root)
	packed.pack(scene_root)
	var scene_path := "res://.godot/ref_scene.tscn"
	ResourceSaver.save(packed, scene_path)
	scene_root.queue_free()

	var scene: Node = load(scene_path).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame

	var host := Node.new()
	root.add_child(host)
	var ctx := EventContext.new()
	ctx.host = host

	_check(ctx.resolve_scene_object(scene_path, "NPC").get("node") != null, "同一场景内能解析对象")
	_check(ctx.resolve_scene_object(scene_path, "Group/NPC").get("node") != null, "同名对象可用路径区分")
	_check(ctx.resolve_scene_object("res://.godot/other.tscn", "NPC").get("node") == null, "跨场景引用应失败而不是解析成别的对象")
	_check(str(ctx.resolve_scene_object(scene_path, "Missing").get("error", "")).begins_with("not_found"), "失效引用应给出明确错误")
	_check(ctx.resolve_scene_object("", "Group/NPC").get("node") != null, "不带场景绑定时按当前场景解析")

	# 重命名后失效
	scene.get_node("NPC").name = "Renamed"
	_check(ctx.resolve_scene_object(scene_path, "NPC").get("node") == null, "节点改名后引用应失效")

	# 选择器
	var picker := SceneObjectPicker.new()
	root.add_child(picker)
	picker.open_for(scene, "")
	_check(picker.select_path("Group/NPC"), "选择器能按路径选中节点")
	var picked := {}
	picker.picked.connect(func(node_path: String, scene_file: String) -> void:
		picked["path"] = node_path
		picked["scene"] = scene_file
	)
	picker.call("_on_confirm")
	_check(str(picked.get("path", "")) == "Group/NPC", "选择器返回相对场景根的路径")
	_check(str(picked.get("scene", "")) == scene_path, "选择器同时返回场景文件")
	picker.queue_free()

	# 指令执行 + 保存重载
	var definition := EventDefinition.new()
	definition.event_id = &"ref_test"
	var page := EventPage.new()
	page.trigger = "interact"
	var move := CommandRegistry.create_command(&"move_actor")
	move.params["actor"] = "Group/NPC"
	move.params["actor_scene"] = scene_path
	move.params["offset_y"] = -40.0
	move.params["duration"] = 0.05
	move.params["wait"] = true
	page.commands = [move]
	definition.pages = [page]

	var state := StateStore.new()
	var bus := EventBus.new()
	var runner := EventRunner.new()
	runner.host = host
	runner.state = state
	runner.bus = bus
	runner.registry = CommandRegistry.new()
	var before: float = (scene.get_node("Group/NPC") as Node2D).global_position.y
	runner.start(definition, {}, ["interact"])
	var waited := 0
	while waited < 240 and not state_done(runner):
		await process_frame
		waited += 1
	var after: float = (scene.get_node("Group/NPC") as Node2D).global_position.y
	_check(after < before - 20.0, "move_actor 用选中的对象执行成功（%.0f → %.0f）" % [before, after])

	var event_path := "res://.godot/ref_event.tres"
	ResourceSaver.save(definition, event_path)
	var reloaded: EventDefinition = load(event_path)
	_check(str(reloaded.pages[0].commands[0].params.get("actor", "")) == "Group/NPC", "保存重载后对象路径保留")
	_check(str(reloaded.pages[0].commands[0].params.get("actor_scene", "")) == scene_path, "保存重载后场景绑定保留")

	DirAccess.remove_absolute(event_path)
	DirAccess.remove_absolute(scene_path)
	_report()
	quit(0 if _failures.is_empty() else 1)

func state_done(runner: EventRunner) -> bool:
	return runner.active_count() == 0

func _set_owner(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner(child, owner_node)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 场景对象引用测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
