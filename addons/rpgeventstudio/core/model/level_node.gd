@tool
class_name LevelNode
extends Resource
## 关卡总控图上的一个节点。

@export var node_id: StringName = &"node"
@export_enum("start", "stage", "condition", "action", "event", "merge_and", "merge_or", "end") var type: String = "action"
@export var title: String = ""
@export var params: Dictionary = {}
@export var position: Vector2 = Vector2.ZERO
@export_enum("drop", "queue", "restart") var reentry: String = "drop"
@export var enabled: bool = true

func get_param(key: String, default_value: Variant = null) -> Variant:
	return params.get(key, default_value)

func describe() -> String:
	match type:
		"stage":
			return str(params.get("stage_id", ""))
		"condition":
			var key := str(params.get("key", ""))
			if key == "":
				return ""
			return "%s %s %s" % [StateCatalogStore.display(key), params.get("op", "=="), params.get("value", "")]
		"action":
			var key := str(params.get("key", ""))
			if key == "":
				return ""
			return "%s = %s" % [StateCatalogStore.display(key), params.get("value", "")]
		"event":
			var path := str(params.get("event_path", ""))
			return path.get_file() if path != "" else ""
		"merge_and":
			return str(params.get("required", 0))
		"end":
			return str(params.get("completed_key", ""))
	return ""

func duplicate_node() -> LevelNode:
	var copy: LevelNode = duplicate(true)
	return copy
