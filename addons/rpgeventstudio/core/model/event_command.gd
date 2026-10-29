@tool
class_name EventCommand
extends Resource
## 一条事件指令。type 对应 CommandRegistry 里注册的 id，params 由该指令的 schema 约束。

@export var type: StringName = &""
@export var params: Dictionary = {}
@export var children: Array[EventCommand] = []        ## 条件成立 / 循环体
@export var else_children: Array[EventCommand] = []   ## 条件不成立
@export var enabled: bool = true
@export var comment: String = ""

func get_param(key: String, default_value: Variant = null) -> Variant:
	return params.get(key, default_value)

func set_param(key: String, value: Variant) -> void:
	params[key] = value
	emit_changed()

func duplicate_command() -> EventCommand:
	return duplicate(true) as EventCommand
