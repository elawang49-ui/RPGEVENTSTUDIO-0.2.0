@tool
class_name MapEvent2D
extends Node2D
## 地编用地图事件对象：在 2D 场景里直接摆放、拖动、设置层级与触发方式。
##
## 它不重新实现事件逻辑：运行时按 trigger_mode 自动挂上现有的
## EventInteractor2D / EventTriggerArea2D / EventAutoRun2D。
## 编辑器里只在 2D 视口画占位图标、交互/触发范围和配置警告。

enum Kind { NPC, INSPECT, CHEST, DOOR, MECHANISM, TRIGGER }
enum TriggerMode { INTERACT, REGION_ENTER, REGION_EXIT, AUTORUN, PARALLEL }
enum LayerMode { BELOW_PLAYER, SAME_LAYER, ABOVE_PLAYER, CUSTOM }

const LINK_OK := 0
const LINK_MISSING := 1
const LINK_BROKEN := 2
const LINK_NOT_EVENT := 3

const RUNTIME_INTERACTOR := "__MapEventInteractor"
const RUNTIME_TRIGGER := "__MapEventTrigger"
const RUNTIME_AUTORUN := "__MapEventAutorun"

const KIND_COLORS := [
	Color(0.96, 0.72, 0.38),  # NPC
	Color(0.45, 0.80, 0.95),  # Inspect
	Color(0.98, 0.82, 0.35),  # Chest
	Color(0.72, 0.62, 0.95),  # Door
	Color(0.55, 0.90, 0.65),  # Mechanism
	Color(0.95, 0.48, 0.55),  # Trigger
]

@export_group("事件")
@export_enum("NPC", "Inspect Point", "Chest", "Door", "Mechanism", "Trigger Area")
var kind: int = Kind.NPC:
	set(value):
		kind = clampi(value, Kind.NPC, Kind.TRIGGER)
		_changed()

## 直接引用事件资源（推荐）。未设置时回退到 event_path。
@export var event: EventDefinition:
	set(value):
		event = value
		_changed()

## 备用文件引用：适合只在运行时 load 的场景，或在 Inspector 里拖入 .tres。
@export_file("*.tres") var event_path: String = "":
	set(value):
		event_path = value
		_changed()

@export_group("触发")
@export_enum("Interact", "Region Enter", "Region Exit", "Autorun", "Parallel")
var trigger_mode: int = TriggerMode.INTERACT:
	set(value):
		trigger_mode = clampi(value, TriggerMode.INTERACT, TriggerMode.PARALLEL)
		_changed()
		notify_property_list_changed()

@export_range(8.0, 512.0, 1.0) var interaction_radius: float = 72.0:
	set(value):
		interaction_radius = maxf(value, 1.0)
		_changed()

@export_range(8.0, 1024.0, 1.0) var trigger_radius: float = 80.0:
	set(value):
		trigger_radius = maxf(value, 1.0)
		_changed()

@export var prompt_text: String = "":
	set(value):
		prompt_text = value
		queue_redraw()

@export var allow_mouse_click: bool = true

@export_group("显示层级")
## 便捷预设：角色下方/同层/上方映射到相对 z_index；自定义时直接使用 custom_z_index。
## 同层仍受父节点 YSort 影响；Godot 原生 z_index 依旧可以在 Inspector 里继续调整。
@export_enum("Below Player", "Same Layer", "Above Player", "Custom z_index")
var layer_mode: int = LayerMode.SAME_LAYER:
	set(value):
		layer_mode = clampi(value, LayerMode.BELOW_PLAYER, LayerMode.CUSTOM)
		_apply_layer()
		_changed()
		notify_property_list_changed()

@export_range(-4096, 4096, 1) var custom_z_index: int = 0:
	set(value):
		custom_z_index = value
		if layer_mode == LayerMode.CUSTOM:
			z_index = value
		_changed()

func _ready() -> void:
	_apply_layer()
	if Engine.is_editor_hint():
		queue_redraw()
		update_configuration_warnings()
	else:
		_setup_runtime()

# ── 事件关联 ─────────────────────────────────────────────

func resolved_event() -> EventDefinition:
	if event != null:
		return event
	if event_path.strip_edges() == "":
		return null
	if not ResourceLoader.exists(event_path):
		return null
	return load(event_path) as EventDefinition

func event_link_status() -> int:
	if event != null:
		return LINK_OK
	if event_path.strip_edges() == "":
		return LINK_MISSING
	if not ResourceLoader.exists(event_path):
		return LINK_BROKEN
	var resource := load(event_path)
	if not (resource is EventDefinition):
		return LINK_NOT_EVENT
	return LINK_OK

func event_resource_path() -> String:
	if event != null:
		return event.resource_path
	return event_path

func event_display_name() -> String:
	var definition := resolved_event()
	if definition != null:
		if definition.display_name.strip_edges() != "":
			return definition.display_name
		return String(definition.event_id)
	var path := event_resource_path()
	if path != "":
		return path.get_file().get_basename()
	return L10n.ui("map.event.none")

func status_text() -> String:
	match event_link_status():
		LINK_MISSING:
			return L10n.ui("map.status.missing")
		LINK_BROKEN:
			return L10n.ui("map.status.invalid")
		LINK_NOT_EVENT:
			return L10n.ui("map.status.not_event")
	return ""

func is_valid() -> bool:
	if event_link_status() != LINK_OK:
		return false
	var definition := resolved_event()
	if definition == null:
		return false
	return _has_matching_page(definition)

# ── 展示标签 ─────────────────────────────────────────────

func kind_label() -> String:
	var keys := [
		"map.kind.npc", "map.kind.inspect", "map.kind.chest",
		"map.kind.door", "map.kind.mechanism", "map.kind.trigger",
	]
	return L10n.ui(keys[clampi(kind, 0, keys.size() - 1)])

func trigger_label() -> String:
	var keys := [
		"map.trigger.interact", "map.trigger.region_enter", "map.trigger.region_exit",
		"map.trigger.autorun", "map.trigger.parallel",
	]
	return L10n.ui(keys[clampi(trigger_mode, 0, keys.size() - 1)])

func layer_label() -> String:
	var keys := [
		"map.layer.below", "map.layer.same", "map.layer.above", "map.layer.custom",
	]
	return L10n.ui(keys[clampi(layer_mode, 0, keys.size() - 1)])

func accepted_triggers() -> PackedStringArray:
	match trigger_mode:
		TriggerMode.INTERACT:
			return PackedStringArray(["interact"])
		TriggerMode.REGION_ENTER:
			# EventTriggerArea2D 进入时同时带 touch + region_enter，兼容原有的玩家接触页。
			return PackedStringArray(["region_enter", "touch"])
		TriggerMode.REGION_EXIT:
			return PackedStringArray(["region_exit"])
		TriggerMode.AUTORUN:
			return PackedStringArray(["autorun"])
		TriggerMode.PARALLEL:
			return PackedStringArray(["parallel"])
	return PackedStringArray()

func _has_matching_page(definition: EventDefinition) -> bool:
	var wanted := accepted_triggers()
	for page in definition.pages:
		if page != null and wanted.has(String(page.trigger)):
			return true
	return false

# ── 显示层级 ─────────────────────────────────────────────

func _apply_layer() -> void:
	match layer_mode:
		LayerMode.BELOW_PLAYER:
			z_as_relative = true
			z_index = -1
		LayerMode.SAME_LAYER:
			z_as_relative = true
			z_index = 0
		LayerMode.ABOVE_PLAYER:
			z_as_relative = true
			z_index = 1
		LayerMode.CUSTOM:
			z_index = custom_z_index

# ── 运行时：复用已有组件 ─────────────────────────────────

func _setup_runtime() -> void:
	_remove_runtime_children()
	var definition := resolved_event()
	# 失效路径不要交给运行时组件重复 load；编辑器已经给出配置警告。
	var runtime_path := event_path if definition == null and event_link_status() == LINK_OK else ""
	match trigger_mode:
		TriggerMode.INTERACT:
			var interactor := EventInteractor2D.new()
			interactor.name = RUNTIME_INTERACTOR
			interactor.event = definition
			interactor.event_path = runtime_path
			interactor.interaction_radius = interaction_radius
			interactor.prompt_text = prompt_text
			interactor.allow_mouse_click = allow_mouse_click
			add_child(interactor)
		TriggerMode.REGION_ENTER, TriggerMode.REGION_EXIT:
			var area := EventTriggerArea2D.new()
			area.name = RUNTIME_TRIGGER
			area.event = definition
			area.event_path = runtime_path
			area.radius = trigger_radius
			area.trigger_on_enter = trigger_mode == TriggerMode.REGION_ENTER
			area.trigger_on_exit = trigger_mode == TriggerMode.REGION_EXIT
			add_child(area)
		TriggerMode.AUTORUN, TriggerMode.PARALLEL:
			var autorun := EventAutoRun2D.new()
			autorun.name = RUNTIME_AUTORUN
			autorun.event = definition
			autorun.event_path = runtime_path
			autorun.is_parallel = trigger_mode == TriggerMode.PARALLEL
			add_child(autorun)

func _remove_runtime_children() -> void:
	for child_name in [RUNTIME_INTERACTOR, RUNTIME_TRIGGER, RUNTIME_AUTORUN]:
		var child := get_node_or_null(child_name)
		if child != null:
			remove_child(child)
			child.queue_free()

# ── 编辑器可视化 ─────────────────────────────────────────

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := _kind_color()
	var status := event_link_status()
	var draw_color := color if status == LINK_OK else Color(0.98, 0.38, 0.34)

	if trigger_mode == TriggerMode.INTERACT:
		draw_circle(Vector2.ZERO, interaction_radius, Color(color, 0.07))
		draw_arc(Vector2.ZERO, interaction_radius, 0.0, TAU, 64, Color(color, 0.55), 1.5)
	elif trigger_mode == TriggerMode.REGION_ENTER or trigger_mode == TriggerMode.REGION_EXIT:
		draw_circle(Vector2.ZERO, trigger_radius, Color(color, 0.06))
		draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 64, Color(color, 0.55), 1.5)

	# 标记本体：菱形 + 中心点；未关联/失效时变红。
	var diamond := PackedVector2Array([
		Vector2(0, -11), Vector2(11, 0), Vector2(0, 11), Vector2(-11, 0),
	])
	draw_colored_polygon(diamond, Color(draw_color, 0.22))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), draw_color, 2.0)
	draw_circle(Vector2.ZERO, 3.0, draw_color)

	var font := ThemeDB.fallback_font
	if font != null:
		var title := "%s · %s" % [kind_label(), trigger_label()]
		draw_string(font, Vector2(-80, -20), title, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, draw_color)
		var name_text := event_display_name()
		draw_string(font, Vector2(-80, 28), name_text, HORIZONTAL_ALIGNMENT_CENTER, 160, 11, Color(0.88, 0.91, 0.96))
		var layer_text := layer_label()
		draw_string(font, Vector2(-80, 42), layer_text, HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.62, 0.68, 0.78))
		if status != LINK_OK:
			draw_string(font, Vector2(-80, 56), status_text(), HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.98, 0.45, 0.40))

func _kind_color() -> Color:
	return KIND_COLORS[clampi(kind, 0, KIND_COLORS.size() - 1)]

func _changed() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		notify_property_list_changed()
		if is_inside_tree():
			update_configuration_warnings()

func _validate_property(property: Dictionary) -> void:
	var hidden: bool = false
	match str(property.get("name", "")):
		"interaction_radius", "prompt_text", "allow_mouse_click":
			hidden = trigger_mode != TriggerMode.INTERACT
		"trigger_radius":
			hidden = trigger_mode != TriggerMode.REGION_ENTER and trigger_mode != TriggerMode.REGION_EXIT
		"custom_z_index":
			hidden = layer_mode != LayerMode.CUSTOM
		"event_path":
			hidden = event != null
	if hidden:
		property["usage"] = int(property.get("usage", 0)) & ~PROPERTY_USAGE_EDITOR

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	match event_link_status():
		LINK_MISSING:
			warnings.append(L10n.ui("map.warning.no_event"))
		LINK_BROKEN:
			warnings.append(L10n.ui("map.warning.invalid_path", {"path": event_path}))
		LINK_NOT_EVENT:
			warnings.append(L10n.ui("map.warning.not_event", {"path": event_path}))
	var definition := resolved_event()
	if definition != null and not _has_matching_page(definition):
		warnings.append(L10n.ui("map.warning.trigger_mismatch", {"trigger": trigger_label()}))
	return warnings

# ── 总览扫描（编辑器面板与测试共用） ─────────────────────

static func collect_in(root: Node) -> Array[MapEvent2D]:
	var out: Array[MapEvent2D] = []
	if root == null:
		return out
	for node in root.find_children("*", "Node2D", true, false):
		if node is MapEvent2D:
			out.append(node)
	return out
