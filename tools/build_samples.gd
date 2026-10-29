extends SceneTree
## 生成演示用的示例事件与演示场景（一次性的构建脚本，可重复运行）。
## 用法：godot --headless --path . --script res://tools/build_samples.gd

const EVENTS_DIR := "res://addons/rpgeventstudio/samples/events/"
const SCENES_DIR := "res://addons/rpgeventstudio/samples/scenes/"
const GRAPHS_DIR := "res://addons/rpgeventstudio/samples/graphs/"
const AUDIO_DIR := "res://addons/rpgeventstudio/samples/audio/"
const THEME_PATH := "res://addons/rpgeventstudio/samples/demo_theme.tres"

func _init() -> void:
	_build.call_deferred()

func _build() -> void:
	_ensure_dir(EVENTS_DIR)
	_ensure_dir(SCENES_DIR)

	var librarian := _make_librarian()
	var key_pickup := _make_key_pickup()
	var door := _make_door()
	var office := _make_office_desk()
	var board := _make_classroom_board()
	var cutscene := _make_basement_cutscene()
	_save(librarian, EVENTS_DIR + "librarian.tres")
	_save(key_pickup, EVENTS_DIR + "key_pickup.tres")
	_save(door, EVENTS_DIR + "locked_door.tres")
	_save(office, EVENTS_DIR + "office_desk.tres")
	_save(board, EVENTS_DIR + "classroom_board.tres")
	_save(cutscene, EVENTS_DIR + "basement_cutscene.tres")

	_ensure_dir(AUDIO_DIR)
	_save(_make_beep(), AUDIO_DIR + "beep.tres")

	_ensure_dir(GRAPHS_DIR)
	var graph := _make_school_graph()
	_save(graph, GRAPHS_DIR + "school_graph.tres")

	_ensure_dir("res://state/")
	_save(_make_state_catalog(), "res://state/state_catalog.tres")

	var theme := _make_theme()
	_save(theme, THEME_PATH)

	_build_demo_scene(librarian, key_pickup, door, office, board, theme)
	print("[build_samples] 完成：6 个事件 + 1 张关卡图 + 1 个演示场景")
	quit()

# ── 事件：图书管理员 ─────────────────────────────────────

func _make_librarian() -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = &"librarian"
	definition.display_name = "图书管理员"

	# 第 1 页：还没拿钥匙
	var page_default := EventPage.new()
	page_default.trigger = &"interact"
	page_default.repeat_policy = &"every_time"
	page_default.commands = [
		_cmd(&"show_text", {"speaker": "图书管理员", "text": "你看起来在找什么？", "auto_advance": 0.0}),
		_cmd(&"show_choices", {"prompt": "要问点什么吗？", "options": ["询问钥匙", "离开"]}),
		_cmd(&"if", {"key": "@@self.choice", "op": "==", "value": "0"}, [
			_cmd(&"show_text", {"speaker": "图书管理员", "text": "这把钥匙给你，别弄丢了。", "auto_advance": 0.0}),
			_cmd(&"set_switch", {"key": "Global.Player.HasKey", "value": true}),
			_cmd(&"show_text", {"speaker": "", "text": "获得【教室钥匙】！", "auto_advance": 0.0}),
		], [
			_cmd(&"show_text", {"speaker": "图书管理员", "text": "那就随便看看吧。", "auto_advance": 0.0}),
		]),
		_cmd(&"end", {}),
	]

	# 第 2 页：已经拿到钥匙（序号更大，条件满足时优先）
	var page_has_key := EventPage.new()
	page_has_key.trigger = &"interact"
	page_has_key.repeat_policy = &"every_time"
	page_has_key.conditions = [_cond("Global.Player.HasKey", "==", true)]
	page_has_key.commands = [
		_cmd(&"show_text", {"speaker": "图书管理员", "text": "钥匙要收好，教室门就在右边。", "auto_advance": 0.0}),
		_cmd(&"end", {}),
	]

	definition.pages = [page_default, page_has_key]
	return definition

# ── 事件：抽屉里的钥匙 ───────────────────────────────────

func _make_key_pickup() -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = &"key_pickup"
	definition.display_name = "抽屉"

	var page_empty := EventPage.new()
	page_empty.trigger = &"interact"
	page_empty.conditions = [_cond("Global.Player.HasKey", "==", false)]
	page_empty.commands = [
		_cmd(&"show_text", {"speaker": "", "text": "抽屉里有一把生锈的钥匙。", "auto_advance": 0.0}),
		_cmd(&"set_switch", {"key": "Global.Player.HasKey", "value": true}),
		_cmd(&"show_text", {"speaker": "", "text": "获得【教室钥匙】！", "auto_advance": 0.0}),
		_cmd(&"end", {}),
	]

	var page_taken := EventPage.new()
	page_taken.trigger = &"interact"
	page_taken.conditions = [_cond("Global.Player.HasKey", "==", true)]
	page_taken.commands = [
		_cmd(&"show_text", {"speaker": "", "text": "抽屉已经空了。", "auto_advance": 0.0}),
		_cmd(&"end", {}),
	]

	definition.pages = [page_empty, page_taken]
	return definition

# ── 事件：教室门 ─────────────────────────────────────────

func _make_door() -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = &"locked_door"
	definition.display_name = "教室门"

	var page_open := EventPage.new()
	page_open.trigger = &"interact"
	page_open.conditions = [_cond("Global.Player.HasKey", "==", true)]
	page_open.commands = [
		_cmd(&"show_text", {"speaker": "", "text": "你用钥匙打开了教室的门。", "auto_advance": 0.0}),
		_cmd(&"set_switch", {"key": "School.ClassroomUnlocked", "value": true}),
		_cmd(&"end", {}),
	]

	var page_locked := EventPage.new()
	page_locked.trigger = &"interact"
	page_locked.conditions = [_cond("Global.Player.HasKey", "==", false)]
	page_locked.commands = [
		_cmd(&"show_text", {"speaker": "", "text": "门被锁住了，需要一把钥匙。", "auto_advance": 0.0}),
		_cmd(&"end", {}),
	]

	definition.pages = [page_open, page_locked]
	return definition

# ── 事件：办公室桌子 / 教室黑板 / 地下室提示 ─────────────

func _make_office_desk() -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = &"office_desk"
	definition.display_name = "办公室桌子"

	var page_first := EventPage.new()
	page_first.trigger = "interact"
	page_first.conditions = [_cond("School.Office.DiaryFound", "==", false)]
	page_first.commands = [
		_cmd(&"show_text", {"speaker": "", "text": "桌上摊着一本教师日志，最后一页写着：地下室的门需要两把钥匙。", "auto_advance": 0.0}),
		_cmd(&"set_switch", {"key": "School.Office.DiaryFound", "value": true}),
		_cmd(&"show_text", {"speaker": "", "text": "获得线索：教师日志", "auto_advance": 0.0}),
		_cmd(&"end", {}),
	]

	var page_done := EventPage.new()
	page_done.trigger = "interact"
	page_done.conditions = [_cond("School.Office.DiaryFound", "==", true)]
	page_done.commands = [
		_cmd(&"show_text", {"speaker": "", "text": "日志已经翻完了。", "auto_advance": 0.0}),
		_cmd(&"end", {}),
	]

	definition.pages = [page_first, page_done]
	return definition

func _make_classroom_board() -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = &"classroom_board"
	definition.display_name = "教室黑板"

	var page_first := EventPage.new()
	page_first.trigger = "interact"
	page_first.conditions = [_cond("School.Classroom.ClueFound", "==", false)]
	page_first.commands = [
		_cmd(&"show_text", {"speaker": "", "text": "黑板上留着奇怪的粉笔痕，像是某种开门顺序。", "auto_advance": 0.0}),
		_cmd(&"set_switch", {"key": "School.Classroom.ClueFound", "value": true}),
		_cmd(&"show_text", {"speaker": "", "text": "获得线索：异常的粉笔痕", "auto_advance": 0.0}),
		_cmd(&"end", {}),
	]

	var page_done := EventPage.new()
	page_done.trigger = "interact"
	page_done.conditions = [_cond("School.Classroom.ClueFound", "==", true)]
	page_done.commands = [
		_cmd(&"show_text", {"speaker": "", "text": "粉笔痕已经被记下来了。", "auto_advance": 0.0}),
		_cmd(&"end", {}),
	]

	definition.pages = [page_first, page_done]
	return definition

func _make_basement_cutscene() -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = &"basement_cutscene"
	definition.display_name = "地下室剧情"

	var page := EventPage.new()
	page.trigger = "interact"
	page.commands = [
		_cmd(&"fade", {"mode": "out", "duration": 0.4, "wait": true}),
		_cmd(&"show_text", {"speaker": "", "text": "地下室的门缓缓打开……", "auto_advance": 0.0}),
		_cmd(&"fade", {"mode": "in", "duration": 0.5, "wait": true}),
		_cmd(&"camera_focus", {"target": "Librarian", "target_scene": "res://addons/rpgeventstudio/samples/scenes/school_demo.tscn", "offset_x": 0.0, "offset_y": -40.0, "duration": 0.8, "wait": true}),
		_cmd(&"move_actor", {"actor": "Librarian", "actor_scene": "res://addons/rpgeventstudio/samples/scenes/school_demo.tscn", "offset_x": 0.0, "offset_y": -70.0, "duration": 0.8, "wait": true}),
		_cmd(&"play_sfx", {"sound_path": "res://addons/rpgeventstudio/samples/audio/beep.tres", "volume_db": -6.0, "wait": false}),
		_cmd(&"show_text", {"speaker": "图书管理员", "text": "你终于来了。", "auto_advance": 0.0}),
		_cmd(&"camera_restore", {"duration": 0.8, "wait": true}),
		_cmd(&"end", {}),
	]
	definition.pages = [page]
	return definition

func _make_beep() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.28
	var samples := int(rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for index in samples:
		var t := float(index) / rate
		var attack := minf(1.0, float(index) / (rate * 0.01))
		var release := minf(1.0, float(samples - index) / (rate * 0.05))
		var value := int(sin(TAU * 660.0 * t) * 12000.0 * minf(attack, release))
		data.encode_s16(index * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

# ── 状态库 ───────────────────────────────────────────────

func _make_state_catalog() -> StateCatalog:
	var catalog := StateCatalog.new()
	_add_state(catalog, "Global.Player.HasKey", "教室钥匙", "bool", false, "玩家", "从图书管理员或抽屉处拿到钥匙后为真")
	_add_state(catalog, "School.ClassroomUnlocked", "教室门已打开", "bool", false, "学校", "用钥匙打开教室门后为真")
	_add_state(catalog, "School.Office.DiaryFound", "办公室日记已调查", "bool", false, "调查", "调查办公室桌子后为真")
	_add_state(catalog, "School.Classroom.ClueFound", "教室线索已找到", "bool", false, "调查", "调查教室黑板后为真")
	_add_state(catalog, "School.BasementUnlocked", "地下室已解锁", "bool", false, "调查", "两条调查线索都齐了由关卡图置为真")
	_add_state(catalog, "School.Stage", "关卡阶段", "string", "exploration", "学校", "当前关卡阶段：exploration / basement")
	return catalog

func _add_state(catalog: StateCatalog, key: String, display_name: String, type: String, default_value: Variant, category: String, description: String) -> void:
	var definition := StateDefinition.new()
	definition.key = key
	definition.display_name = display_name
	definition.type = type
	definition.default_value = default_value
	definition.category = category
	definition.description = description
	catalog.definitions.append(definition)

# ── 关卡总控图 ───────────────────────────────────────────

func _make_school_graph() -> LevelGraph:
	var graph := LevelGraph.new()
	graph.graph_id = &"school"
	graph.level_id = &"school"

	var start := _graph_node(graph, "start", Vector2(40, 60), {})
	var exploration := _graph_node(graph, "stage", Vector2(280, 60), {"stage_id": "exploration"})
	var office := _graph_node(graph, "condition", Vector2(40, 220), {
		"key": "School.Office.DiaryFound", "op": "==", "value": "true", "monitor": true,
	})
	var classroom := _graph_node(graph, "condition", Vector2(40, 360), {
		"key": "School.Classroom.ClueFound", "op": "==", "value": "true", "monitor": true,
	})
	var merge := _graph_node(graph, "merge_and", Vector2(320, 290), {"required": 2})
	var unlock := _graph_node(graph, "action", Vector2(540, 290), {
		"key": "School.BasementUnlocked", "op": "set", "value": "true",
	})
	var hint := _graph_node(graph, "event", Vector2(760, 290), {
		"event_path": "res://addons/rpgeventstudio/samples/events/basement_cutscene.tres",
		"trigger": "interact",
		"wait": true,
	})
	var basement := _graph_node(graph, "stage", Vector2(980, 290), {"stage_id": "basement"})

	graph.connect_nodes(start.node_id, "out", exploration.node_id, "in")
	graph.connect_nodes(office.node_id, "true", merge.node_id, "in")
	graph.connect_nodes(classroom.node_id, "true", merge.node_id, "in")
	graph.connect_nodes(merge.node_id, "out", unlock.node_id, "in")
	graph.connect_nodes(unlock.node_id, "out", hint.node_id, "in")
	graph.connect_nodes(hint.node_id, "done", basement.node_id, "in")
	return graph

func _graph_node(graph: LevelGraph, type: String, position: Vector2, params: Dictionary) -> LevelNode:
	var node := LevelNode.new()
	node.node_id = graph.next_node_id(type)
	node.type = type
	node.params = params
	node.position = position
	graph.nodes.append(node)
	return node

# ── 演示场景 ─────────────────────────────────────────────

func _build_demo_scene(librarian: EventDefinition, key_pickup: EventDefinition, door: EventDefinition, office: EventDefinition, board: EventDefinition, theme: Theme) -> void:
	var holder := Node2D.new()
	holder.name = "SchoolDemo"
	root.add_child(holder)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.09, 0.10, 0.13)
	background.size = Vector2(1152, 648)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(background)

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UI"
	holder.add_child(ui_layer)

	var hint := _label("", theme, 16, Color(0.75, 0.78, 0.85))
	hint.name = "Hint"
	hint.position = Vector2(32, 20)
	hint.size = Vector2(1050, 28)
	hint.set_script(load("res://addons/rpgeventstudio/samples/demo_hint.gd"))
	ui_layer.add_child(hint)

	var hud_script := load("res://addons/rpgeventstudio/samples/demo_hud.gd")
	var hud := _label("", theme, 16, Color(0.95, 0.87, 0.6))
	hud.name = "HUD"
	hud.position = Vector2(32, 52)
	hud.size = Vector2(760, 52)
	hud.set_script(hud_script)
	ui_layer.add_child(hud)

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(320, 430)
	player.set_script(load("res://addons/rpgeventstudio/samples/player.gd"))
	player.add_to_group("player", true)
	_add_box(player, Vector2(26, 26), Color(0.42, 0.68, 0.95))
	holder.add_child(player)

	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(560, 360)
	camera.set_script(load("res://addons/rpgeventstudio/samples/demo_camera.gd"))
	holder.add_child(camera)

	var npc := _make_entity(holder, "Librarian", Vector2(640, 330), Vector2(34, 46), Color(0.93, 0.62, 0.35), "图书管理员", theme)
	_add_interactor(npc, librarian, "res://addons/rpgeventstudio/samples/events/librarian.tres", 78.0)

	var drawer := _make_entity(holder, "Drawer", Vector2(260, 250), Vector2(48, 30), Color(0.66, 0.48, 0.30), "抽屉", theme)
	_add_interactor(drawer, key_pickup, "res://addons/rpgeventstudio/samples/events/key_pickup.tres", 70.0)

	var door_node := _make_entity(holder, "ClassroomDoor", Vector2(900, 300), Vector2(40, 76), Color(0.45, 0.80, 0.55), "教室门", theme)
	_add_interactor(door_node, door, "res://addons/rpgeventstudio/samples/events/locked_door.tres", 78.0)

	var office_node := _make_entity(holder, "OfficeDesk", Vector2(430, 170), Vector2(56, 34), Color(0.74, 0.56, 0.34), "办公室桌子", theme)
	_add_interactor(office_node, office, "res://addons/rpgeventstudio/samples/events/office_desk.tres", 78.0)

	var board_node := _make_entity(holder, "ClassroomBoard", Vector2(120, 300), Vector2(84, 40), Color(0.36, 0.56, 0.62), "教室黑板", theme)
	_add_interactor(board_node, board, "res://addons/rpgeventstudio/samples/events/classroom_board.tres", 78.0)

	var graph_runner := Node.new()
	graph_runner.name = "GraphRunner"
	graph_runner.set_script(load("res://addons/rpgeventstudio/runtime/components/level_graph_runner.gd"))
	graph_runner.set("graph_path", "res://addons/rpgeventstudio/samples/graphs/school_graph.tres")
	holder.add_child(graph_runner)

	_set_owner_recursive(holder, holder)
	var packed := PackedScene.new()
	packed.pack(holder)
	var scene_result := SafeFile.write_resource(packed, SCENES_DIR + "school_demo.tscn")
	if not bool(scene_result.get("ok", false)):
		push_error("[build_samples] 保存场景失败：%s" % str(scene_result.get("error", "")))
	holder.queue_free()

func _make_entity(parent: Node, node_name: String, position: Vector2, size: Vector2, color: Color, label_text: String, theme: Theme) -> Node2D:
	var entity := Node2D.new()
	entity.name = node_name
	entity.position = position
	parent.add_child(entity)
	_add_box(entity, size, color)

	var label := _label(label_text, theme, 14, Color(0.85, 0.87, 0.92))
	label.position = Vector2(-60, size.y * 0.5 + 6)
	label.size = Vector2(120, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entity.add_child(label)
	return entity

func _add_box(parent: Node, size: Vector2, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.name = "Body"
	polygon.color = color
	var half := size * 0.5
	polygon.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	parent.add_child(polygon)

func _add_interactor(parent: Node2D, definition: EventDefinition, path: String, radius: float) -> void:
	var interactor := Node2D.new()
	interactor.name = "EventInteractor"
	interactor.set_script(load("res://addons/rpgeventstudio/runtime/components/event_interactor.gd"))
	# 只存路径，不内嵌资源：这样改 .tres 立刻生效，也避免场景里出现重复副本
	interactor.set("event_path", path)
	interactor.set("interaction_radius", radius)
	parent.add_child(interactor)

func _label(text: String, theme: Theme, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme = theme
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

# ── 通用 ─────────────────────────────────────────────────

func _cmd(type: StringName, params: Dictionary, children: Array = [], else_children: Array = []) -> EventCommand:
	var command := CommandRegistry.create_command(type)
	for key in params.keys():
		command.params[key] = params[key]
	if not children.is_empty():
		command.children.assign(children)
	if not else_children.is_empty():
		command.else_children.assign(else_children)
	return command

func _cond(key: String, op: String, value: Variant) -> EventCondition:
	var condition := EventCondition.new()
	condition.key = key
	condition.op = op
	condition.value = value
	return condition

func _make_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
		"Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "sans-serif",
	])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	return theme

func _save(resource: Resource, path: String) -> void:
	var result := SafeFile.write_resource(resource, path)
	if not bool(result.get("ok", false)):
		push_error("[build_samples] 保存失败 %s：%s" % [path, str(result.get("error", ""))])
	else:
		print("[build_samples] 已保存 ", path)

func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)

func _ensure_dir(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		return
	DirAccess.make_dir_recursive_absolute(path)
