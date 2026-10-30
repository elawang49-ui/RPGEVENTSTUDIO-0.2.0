@tool
class_name LevelGraph
extends Resource
## 关卡总控图：节点 + 连线。运行时由 GraphRunner 解释执行，编辑器只是视图。

@export var graph_id: StringName = &"school"
@export var level_id: StringName = &"school"
@export var nodes: Array[LevelNode] = []
@export var connections: Array[LevelConnection] = []
@export var entry_node: StringName = &""
@export var schema_version: int = 1
## 节点分组框（纯编辑器视觉信息，运行时忽略）。
@export var groups: Array[LevelGroup] = []

func group_by_id(group_id: StringName) -> LevelGroup:
	for group in groups:
		if group != null and group.group_id == group_id:
			return group
	return null

## 节点所在的分组（节点可以同时被多个分组框套住，返回第一个）。
func group_of(node_id: StringName) -> LevelGroup:
	for group in groups:
		if group != null and group.contains(node_id):
			return group
	return null

func add_group(group: LevelGroup) -> void:
	groups.append(group)
	emit_changed()

func remove_group(group_id: StringName) -> LevelGroup:
	for index in range(groups.size() - 1, -1, -1):
		var group: LevelGroup = groups[index]
		if group != null and group.group_id == group_id:
			groups.remove_at(index)
			emit_changed()
			return group
	return null

func next_group_id() -> StringName:
	var index := 1
	while true:
		var candidate := StringName("group_%d" % index)
		if group_by_id(candidate) == null and node_by_id(candidate) == null:
			return candidate
		index += 1
	return &"group_1"

func node_by_id(node_id: StringName) -> LevelNode:
	for node in nodes:
		if node != null and node.node_id == node_id:
			return node
	return null

func entry() -> LevelNode:
	if entry_node != &"":
		var found := node_by_id(entry_node)
		if found != null and found.type == "start":
			return found
	for node in nodes:
		if node != null and node.type == "start" and node.enabled:
			return node
	return null

func outgoing(node_id: StringName, port: String = "") -> Array[LevelConnection]:
	var result: Array[LevelConnection] = []
	for connection in connections:
		if connection == null or connection.from_node != node_id:
			continue
		if port != "" and connection.from_port != port:
			continue
		result.append(connection)
	return result

func incoming_count(node_id: StringName) -> int:
	var count := 0
	for connection in connections:
		if connection != null and connection.to_node == node_id:
			count += 1
	return count

func add_node(node: LevelNode) -> void:
	nodes.append(node)
	emit_changed()

func remove_node(node_id: StringName) -> void:
	for index in range(nodes.size() - 1, -1, -1):
		if nodes[index] != null and nodes[index].node_id == node_id:
			nodes.remove_at(index)
	for index in range(connections.size() - 1, -1, -1):
		var connection: LevelConnection = connections[index]
		if connection != null and (connection.from_node == node_id or connection.to_node == node_id):
			connections.remove_at(index)
	for group in groups:
		if group != null:
			group.remove_member(node_id)
	if entry_node == node_id:
		entry_node = &""
	emit_changed()

func connect_nodes(from_node: StringName, from_port: String, to_node: StringName, to_port: String) -> void:
	for connection in connections:
		if connection == null:
			continue
		if connection.from_node == from_node and connection.from_port == from_port \
				and connection.to_node == to_node and connection.to_port == to_port:
			return
	var connection := LevelConnection.new()
	connection.from_node = from_node
	connection.from_port = from_port
	connection.to_node = to_node
	connection.to_port = to_port
	connections.append(connection)
	emit_changed()

func disconnect_nodes(from_node: StringName, from_port: String, to_node: StringName, to_port: String) -> void:
	for index in range(connections.size() - 1, -1, -1):
		var connection: LevelConnection = connections[index]
		if connection == null:
			continue
		if connection.from_node == from_node and connection.from_port == from_port \
				and connection.to_node == to_node and connection.to_port == to_port:
			connections.remove_at(index)
	emit_changed()

func next_node_id(prefix: String = "node") -> StringName:
	var index := 1
	while true:
		var candidate := StringName("%s_%d" % [prefix, index])
		if node_by_id(candidate) == null:
			return candidate
		index += 1
	return &"node_1"
