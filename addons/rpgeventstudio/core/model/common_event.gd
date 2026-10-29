@tool
class_name CommonEvent
extends Resource
## 可复用的公共事件：通用开门、任务提示、BGM 切换等。

@export var common_id: StringName = &"common"
@export var display_name: String = "公共事件"
@export var commands: Array[EventCommand] = []
@export var notes: String = ""
