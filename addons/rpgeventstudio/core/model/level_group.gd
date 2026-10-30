@tool
class_name LevelGroup
extends Resource
## 关卡图上的节点分组框：只记录成员与外观，不影响运行时执行语义。
## 成员存 node_id（引用），移动分组时由编辑器保证成员跟随。

@export var group_id: StringName = &"group"
@export var title: String = ""
@export var color: Color = Color(0.35, 0.55, 0.85, 0.14)
@export var position: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2(420, 280)
@export var member_ids: Array[StringName] = []

func contains(node_id: StringName) -> bool:
	return member_ids.has(node_id)

func add_member(node_id: StringName) -> void:
	if node_id != &"" and not member_ids.has(node_id):
		member_ids.append(node_id)
	emit_changed()

func remove_member(node_id: StringName) -> void:
	var index := member_ids.find(node_id)
	if index >= 0:
		member_ids.remove_at(index)
		emit_changed()
