@tool
class_name StudioDebuggerPlugin
extends EditorDebuggerPlugin
## 接收运行中的游戏发来的「关卡图执行」消息，交给编辑器高亮。

signal graph_node(graph_id: String, node_id: String, state: int)
signal graph_stage(graph_id: String, stage: String)

func _has_capture(prefix: String) -> bool:
	return prefix == "rpg_event_studio"

func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message == "rpg_event_studio:node" and data.size() >= 3:
		graph_node.emit(str(data[0]), str(data[1]), int(data[2]))
		return true
	if message == "rpg_event_studio:stage" and data.size() >= 2:
		graph_stage.emit(str(data[0]), str(data[1]))
		return true
	return false
