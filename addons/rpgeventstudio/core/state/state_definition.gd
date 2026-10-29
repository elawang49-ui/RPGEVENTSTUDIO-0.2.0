@tool
class_name StateDefinition
extends Resource
## 一条状态定义：稳定的内部标识 + 创作者看得懂的名字。
## 事件与关卡图里存的始终是 key，改显示名不会影响任何数据。

@export var key: String = ""
@export var display_name: String = ""
@export_enum("bool", "int", "float", "string") var type: String = "bool"
@export var default_value: Variant = false
@export var category: String = "剧情"
@export_multiline var description: String = ""

func label() -> String:
	return display_name if display_name.strip_edges() != "" else key

func default_of_type() -> Variant:
	match type:
		"int":
			return int(default_value) if default_value is int or default_value is float else 0
		"float":
			return float(default_value) if default_value is int or default_value is float else 0.0
		"string":
			return str(default_value)
		_:
			return bool(default_value)
