class_name EventAutoRun2D
extends Node
## 自动事件 / 并行事件：条件满足时自动执行，不需要玩家操作。
## 只在「从未满足变成满足」时触发一次，避免每帧重复启动造成死循环。

@export var event: EventDefinition
@export_file("*.tres") var event_path: String = ""
@export var is_parallel: bool = false

var _runtime: Node
var _was_active := false
var _last_revision := -1

func _ready() -> void:
	if event == null and event_path != "":
		event = load(event_path) as EventDefinition
	_runtime = get_node_or_null("/root/" + StudioRuntime.AUTOLOAD_NAME)

func _process(_delta: float) -> void:
	if event == null or _runtime == null:
		return
	if _runtime.has_method("is_ui_blocking") and bool(_runtime.call("is_ui_blocking")):
		return
	var triggers: Array = []
	if is_parallel:
		triggers.append(&"parallel")
	else:
		triggers.append(&"autorun")
	var page_index: int = event.get_active_page(_runtime.get("state"), triggers)
	var active := page_index >= 0

	if active and not _was_active:
		_trigger()
	elif active and _runtime.get("state").revision != _last_revision:
		var page: EventPage = event.pages[page_index]
		if page != null and page.repeat_policy == "on_change":
			_trigger()

	_was_active = active

func _trigger() -> void:
	_last_revision = _runtime.get("state").revision
	var triggers: Array = []
	if is_parallel:
		triggers.append(&"parallel")
	else:
		triggers.append(&"autorun")
	_runtime.call("start_event", event, {}, triggers,
		{"kind": "autorun", "node": str(get_path()), "node_name": name})
