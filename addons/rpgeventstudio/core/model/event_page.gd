@tool
class_name EventPage
extends Resource
## 事件的一页：什么时候出现、怎么触发、执行什么。
## 多个事件页同时满足条件时，取序号最大的一页（和 RPG Maker 一致）。

@export_enum("interact", "touch", "region_enter", "region_exit", "autorun", "parallel", "call") var trigger: String = "interact"
@export var trigger_params: Dictionary = {}
@export var conditions: Array[EventCondition] = []
@export var commands: Array[EventCommand] = []
@export_enum("every_time", "once", "on_change") var repeat_policy: String = "every_time"
@export var priority: int = 0

func is_active(store: StateStore) -> bool:
	for condition in conditions:
		if condition != null and not condition.evaluate(store):
			return false
	return true

func trigger_label() -> String:
	match trigger:
		"interact": return L10n.ui("trigger.interact" if L10n.has_key("trigger.interact") else "input.action.interact")
		"touch": return L10n.ui("trigger.touch")
		"region_enter": return L10n.ui("trigger.region_enter")
		"region_exit": return L10n.ui("trigger.region_exit")
		"autorun": return L10n.ui("trigger.autorun")
		"parallel": return L10n.ui("trigger.parallel")
		"call": return L10n.ui("trigger.call")
	return trigger

# ── 供编辑器撤销/重做调用的原子操作 ────────────────────────────

func insert_command(index: int, command: EventCommand) -> void:
	index = clampi(index, 0, commands.size())
	commands.insert(index, command)
	emit_changed()

func remove_command(index: int) -> void:
	if index < 0 or index >= commands.size():
		return
	commands.remove_at(index)
	emit_changed()

func move_command(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= commands.size():
		return
	var command := commands[from_index]
	commands.remove_at(from_index)
	to_index = clampi(to_index, 0, commands.size())
	commands.insert(to_index, command)
	emit_changed()
