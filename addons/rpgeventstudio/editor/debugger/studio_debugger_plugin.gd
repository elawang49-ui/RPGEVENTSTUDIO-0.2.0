@tool
class_name StudioDebuggerPlugin
extends EditorDebuggerPlugin
## 接收运行中的游戏发来的「关卡图执行」消息，交给编辑器高亮。

signal graph_node(graph_id: String, node_id: String, state: int)
signal graph_stage(graph_id: String, stage: String)
signal trace_node(graph_id: String, node_id: String, graph_path: String)
signal trace_event(event_id: String, event_path: String)

func _has_capture(prefix: String) -> bool:
	return prefix == "rpg_event_studio"

func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message == "rpg_event_studio:node" and data.size() >= 3:
		graph_node.emit(str(data[0]), str(data[1]), int(data[2]))
		return true
	if message == "rpg_event_studio:stage" and data.size() >= 2:
		graph_stage.emit(str(data[0]), str(data[1]))
		return true
	if message == "rpg_event_studio:trace_node" and data.size() >= 2:
		var graph_path := str(data[2]) if data.size() >= 3 else ""
		trace_node.emit(str(data[0]), str(data[1]), graph_path)
		return true
	if message == "rpg_event_studio:trace_event" and data.size() >= 1:
		var event_path := str(data[1]) if data.size() >= 2 else ""
		trace_event.emit(str(data[0]), event_path)
		return true
	return false
