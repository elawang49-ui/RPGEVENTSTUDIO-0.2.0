class_name RuntimeDisplayNames
extends RefCounted
## 运行时 UI 的显示名辅助：把内部 ID（状态键 / 事件 ID / 图节点 / 阶段 / 指令控制流）
## 转成策划能读懂的文字。
##
## 原则：
##   - 优先读用户数据里的显示名（状态库显示名、图节点标题、事件显示名）。
##   - 没有显示名时退回类型中文 + 原始 ID，绝不伪装成已本地化。
##   - 只读现有资源与 API（StateCatalogStore / LevelGraph.node_by_id / L10n），不改 Core。

## graph 资源路径 -> LevelGraph。展示层缓存，运行期图资源不会换内容。
static var _graph_cache: Dictionary = {}

# ── 状态 ─────────────────────────────────────────────────

## 状态键显示名；未登记的键明确标注「未登记」，不冒充显示名。
static func state_label(key: String) -> String:
	if key == "":
		return ""
	if StateCatalogStore.is_known(key):
		return StateCatalogStore.display(key)
	return key + L10n.game("display.state.unregistered")

## 状态值文本。stage 键的字符串值按阶段词条翻译（stage.<值>），其余原样显示。
static func value_text(value: Variant, key: String = "") -> String:
	if value == null:
		return L10n.game("debug.value_none")
	if value is bool:
		return L10n.game("debug.value_true") if value else L10n.game("debug.value_false")
	if value is String and key.ends_with(".Stage"):
		var stage := stage_label(value)
		return stage
	return str(value)

# ── 阶段 ─────────────────────────────────────────────────

## 阶段 ID -> 中文（词条 stage.<id>）；没有词条就原样返回 ID。
static func stage_label(stage_id: String) -> String:
	if stage_id == "":
		return L10n.game("debug.value_none")
	var text := L10n.game("stage." + stage_id)
	return stage_id if text.begins_with("stage.") else text

# ── 事件 ─────────────────────────────────────────────────

## 事件显示名；资源没写显示名时退回事件 ID（原样，不伪装）。
static func event_label(event_name: String, event_id: String = "") -> String:
	if event_name.strip_edges() != "":
		return event_name
	if event_id != "":
		return event_id
	return L10n.game("display.event.unnamed")

# ── 关卡图节点 ───────────────────────────────────────────

## 节点显示文字：节点标题 > 类型中文 + 语义摘要（describe）> 类型中文 + ID > 纯 ID。
static func node_label(graph_path: String, graph_id: String, node_id: String,
		node_type: String = "") -> String:
	var node := _lookup_node(graph_path, graph_id, node_id)
	if node != null:
		if node.title.strip_edges() != "":
			return node.title
		var described := node.describe()
		# 阶段节点的语义摘要是 stage_id，按阶段词条翻译；无词条时保持原 ID。
		if node.type == "stage":
			described = stage_label(described)
		var type_cn := type_label(node.type)
		if described != "":
			return "%s·%s" % [type_cn, described] if type_cn != "" else described
		if type_cn != "":
			return "%s %s" % [type_cn, node_id]
	if node_type != "":
		var type_cn := type_label(node_type)
		if type_cn != "":
			return "%s %s" % [type_cn, node_id]
	return node_id

## 从 trace 的 graph_path 找节点；找不到返回 null。
static func _lookup_node(graph_path: String, graph_id: String, node_id: String) -> LevelNode:
	if graph_path == "" or node_id == "":
		return null
	var graph := _graph_at(graph_path)
	if graph == null:
		return null
	return graph.node_by_id(StringName(node_id))

static func _graph_at(path: String) -> LevelGraph:
	if _graph_cache.has(path):
		return _graph_cache.get(path)
	var graph: LevelGraph = null
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_REUSE)
		if loaded is LevelGraph:
			graph = loaded
	_graph_cache[path] = graph
	return graph

## 节点类型中文（graph.node.* 词条）。
static func type_label(node_type: String) -> String:
	if node_type == "":
		return ""
	var text := L10n.game("graph.node." + node_type)
	return "" if text.begins_with("graph.node.") else text

## 图连接端口中文；未知端口原样显示。
static func port_label(port: String) -> String:
	match port:
		"out":
			return L10n.game("display.port.out")
		"true":
			return L10n.game("display.port.true")
		"false":
			return L10n.game("display.port.false")
	return port

## 指令控制流结果中文（RuntimeTrace._control_name 的原始枚举）。
static func control_label(result: String) -> String:
	if result == "":
		return ""
	var text := L10n.game("trace.control." + result)
	return result if text.begins_with("trace.control.") else text
