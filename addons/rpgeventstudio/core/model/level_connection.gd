@tool
class_name LevelConnection
extends Resource
## 关卡总控图上的一条连线。端口用名字而不是下标，改端口顺序不会断线。

@export var from_node: StringName = &""
@export var from_port: String = "out"
@export var to_node: StringName = &""
@export var to_port: String = "in"
