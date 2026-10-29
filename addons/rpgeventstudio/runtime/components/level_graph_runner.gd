class_name LevelGraphRunner2D
extends Node
## 挂在关卡场景里：进入关卡时启动总控图。
## 图上的一切推进都通过统一状态服务与事件运行时完成，不需要为关卡写脚本。

@export_file("*.tres") var graph_path: String = ""
@export var auto_start: bool = true

var runner: GraphRunner

func _ready() -> void:
	if not auto_start:
		return
	start_graph()

func start_graph() -> void:
	var runtime := get_node_or_null("/root/" + StudioRuntime.AUTOLOAD_NAME)
	if runtime == null:
		push_error("[RPGEventStudio] 没有运行时单例，关卡图无法启动")
		return
	if not ResourceLoader.exists(graph_path):
		push_error("[RPGEventStudio] 关卡图找不到：%s" % graph_path)
		return
	var graph := load(graph_path) as LevelGraph
	if graph == null:
		push_error("[RPGEventStudio] 不是关卡图资源：%s" % graph_path)
		return

	runner = GraphRunner.new()
	runner.host = self
	runner.graph = graph
	runner.state = runtime.get("state")
	runner.bus = runtime.get("bus")
	runner.level_prefix = str(runtime.get("level_prefix"))
	runner.event_starter = func(definition: EventDefinition, args: Dictionary, filter: Array) -> void:
		runtime.call("start_event", definition, args, filter)
	runtime.call("register_graph", runner)
	runner.start()

func stop_graph() -> void:
	if runner != null:
		runner.stop()
