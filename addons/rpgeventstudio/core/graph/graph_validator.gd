@tool
class_name GraphValidator
extends RefCounted
## 关卡图静态校验器：只读检查 LevelGraph 资源，不接触 GraphEdit、不改运行时语义。
##
## 分级原则（结合 GraphRunner 的真实执行机制，而不是“见循环就报错”）：
##   - 错误：不改就一定出错——缺开始节点、断线、必填参数缺失、AND 汇合永远达不到、
##           不含任何汇合闸门的令牌死循环（运行时会在 4000 次激活后中止整张图）。
##   - 警告：大概率有问题但运行时能兜底——不可达节点、未登记状态、监视条件互相触发等。
##   - 提示：合法但值得知道——经过 AND 汇合的循环（fired 标记保证只跑一圈）、
##           条件某个出口没接、完成标记未填等。
##
## 循环判定依据（对应 GraphRunner）：
##   - 监视型条件不转发令牌（激活时直接 return，只在状态翻转时发令牌）→ 不构成令牌环。
##   - merge_and 有 fired 标记，全局只放行一次 → 经过它的环最多绕一圈。
##   - end 不向外传播，但也不会叫停别的分支 → 不能作为环的闸门。
##   - 其余节点每次激活都向外传播 → 令牌环无闸门即无限，直到 MAX_ACTIVATIONS 中止。

const VALID_OUT_PORTS := {
	"start": ["out"],
	"stage": ["out"],
	"action": ["out"],
	"condition": ["true", "false"],
	"event": ["done"],
	"merge_and": ["out"],
	"merge_or": ["out"],
	"end": [],
}

## 校验一张图。level_prefix 与运行时 StateStore.resolve_key 的前缀一致，默认 "School"。
static func validate(graph: LevelGraph, level_prefix: String = "School") -> Array[GraphIssue]:
	var issues: Array[GraphIssue] = []
	if graph == null:
		return issues

	var nodes := _live_nodes(graph)
	_check_starts(graph, nodes, issues)
	_check_connections(graph, nodes, issues)
	_check_params_and_reachability(graph, nodes, level_prefix, issues)
	_check_cycles(graph, nodes, level_prefix, issues)
	return issues

static func count_of(issues: Array[GraphIssue], severity: int) -> int:
	var total := 0
	for issue in issues:
		if issue.severity == severity:
			total += 1
	return total

## 有错误的图不允许静默当作“已验证”保存。
static func has_errors(issues: Array[GraphIssue]) -> bool:
	return count_of(issues, GraphIssue.Severity.ERROR) > 0

# ── 开始节点 ─────────────────────────────────────────────

static func _check_starts(graph: LevelGraph, nodes: Dictionary, issues: Array[GraphIssue]) -> void:
	var enabled_starts: Array[LevelNode] = []
	var disabled_starts := 0
	for node in nodes.values():
		if node.type != "start":
			continue
		if node.enabled:
			enabled_starts.append(node)
		else:
			disabled_starts += 1

	if enabled_starts.is_empty():
		_push(issues, GraphIssue.Severity.ERROR, "start_missing", &"", "",
			L10n.ui("graph.check.start_missing"), L10n.ui("graph.check.start_missing_hint"))
	elif enabled_starts.size() > 1:
		var ids: Array[String] = []
		for node in enabled_starts:
			ids.append(String(node.node_id))
		_push(issues, GraphIssue.Severity.ERROR, "start_duplicate", enabled_starts[1].node_id, _name_of(enabled_starts[1]),
			L10n.ui("graph.check.start_duplicate", {"count": enabled_starts.size(), "ids": "、".join(ids)}),
			L10n.ui("graph.check.start_duplicate_hint"))
	if disabled_starts > 0:
		_push(issues, GraphIssue.Severity.INFO, "start_disabled", &"", "",
			L10n.ui("graph.check.start_disabled", {"count": disabled_starts}),
			L10n.ui("graph.check.start_disabled_hint"))

	if graph.entry_node != &"":
		var entry: LevelNode = nodes.get(graph.entry_node, null)
		if entry == null or entry.type != "start":
			_push(issues, GraphIssue.Severity.WARNING, "entry_invalid", graph.entry_node, String(graph.entry_node),
				L10n.ui("graph.check.entry_invalid", {"node": String(graph.entry_node)}),
				L10n.ui("graph.check.entry_invalid_hint"))

# ── 连线 ─────────────────────────────────────────────────

static func _check_connections(graph: LevelGraph, nodes: Dictionary, issues: Array[GraphIssue]) -> void:
	var seen := {}
	for connection in graph.connections:
		if connection == null:
			continue
		var from: LevelNode = nodes.get(connection.from_node, null)
		var to: LevelNode = nodes.get(connection.to_node, null)
		if from == null or to == null:
			var broken := String(connection.from_node) if from == null else String(connection.to_node)
			_push(issues, GraphIssue.Severity.ERROR, "conn_broken", connection.from_node, broken,
				L10n.ui("graph.check.conn_broken", {"node": broken}),
				L10n.ui("graph.check.conn_broken_hint"))
			continue
		var valid_outs: Array = VALID_OUT_PORTS.get(from.type, [])
		if not valid_outs.has(connection.from_port):
			_push(issues, GraphIssue.Severity.ERROR, "conn_port", from.node_id, _name_of(from),
				L10n.ui("graph.check.conn_port", {"node": _name_of(from), "port": connection.from_port}),
				L10n.ui("graph.check.conn_port_hint"))
			continue
		if connection.to_port != "in":
			_push(issues, GraphIssue.Severity.ERROR, "conn_port", to.node_id, _name_of(to),
				L10n.ui("graph.check.conn_to_port", {"node": _name_of(to), "port": connection.to_port}),
				L10n.ui("graph.check.conn_to_port_hint"))
			continue
		if to.type == "start":
			_push(issues, GraphIssue.Severity.ERROR, "conn_to_start", to.node_id, _name_of(to),
				L10n.ui("graph.check.conn_to_start", {"node": _name_of(to)}),
				L10n.ui("graph.check.conn_to_start_hint"))
			continue
		var key := "%s|%s|%s|%s" % [connection.from_node, connection.from_port, connection.to_node, connection.to_port]
		if seen.has(key):
			_push(issues, GraphIssue.Severity.WARNING, "conn_duplicate", from.node_id, _name_of(from),
				L10n.ui("graph.check.conn_duplicate", {"from": _name_of(from), "to": _name_of(to)}),
				L10n.ui("graph.check.conn_duplicate_hint"))
		seen[key] = true

# ── 参数 / 状态登记 / 可达性 / 条件出口 ──────────────────

static func _check_params_and_reachability(graph: LevelGraph, nodes: Dictionary, level_prefix: String, issues: Array[GraphIssue]) -> void:
	# 可达性：起点 = 启用的开始节点 + 监视型条件（它们不靠入边触发，状态一变就自己发令牌）。
	var roots: Array[StringName] = []
	for node in nodes.values():
		if node.type == "start" and node.enabled:
			roots.append(node.node_id)
		elif node.type == "condition" and node.enabled and _is_monitor(node) and _resolved_key(node, level_prefix) != "":
			roots.append(node.node_id)

	var adjacency := _activation_adjacency(graph, nodes)
	var reached := _flood(roots, adjacency)
	var unreachable: Array[String] = []
	for node in nodes.values():
		if not node.enabled or node.type == "start":
			continue
		if not reached.has(node.node_id):
			unreachable.append("%s（%s）" % [_name_of(node), String(node.node_id)])
			if unreachable.size() >= 6:
				break
	if not unreachable.is_empty():
		_push(issues, GraphIssue.Severity.WARNING, "reach_unreachable", &"", "",
			L10n.ui("graph.check.unreachable", {"nodes": "、".join(unreachable)}),
			L10n.ui("graph.check.unreachable_hint"))

	var out_true := {}
	var out_false := {}
	for connection in graph.connections:
		if connection == null or not nodes.has(connection.from_node):
			continue
		if connection.from_port == "true":
			out_true[connection.from_node] = true
		elif connection.from_port == "false":
			out_false[connection.from_node] = true

	for node in nodes.values():
		if not node.enabled:
			continue
		match node.type:
			"condition":
				var key := str(node.get_param("key", ""))
				if key.strip_edges() == "":
					_push(issues, GraphIssue.Severity.ERROR, "param_missing", node.node_id, _name_of(node),
						L10n.ui("graph.check.param_missing", {"node": _name_of(node), "field": L10n.ui("param.state")}),
						L10n.ui("graph.check.param_missing_hint"))
				else:
					_check_state_registered(issues, node, "key", level_prefix)
				var has_true: bool = out_true.get(node.node_id, false)
				var has_false: bool = out_false.get(node.node_id, false)
				if not has_true and not has_false:
					_push(issues, GraphIssue.Severity.WARNING, "cond_no_branch", node.node_id, _name_of(node),
						L10n.ui("graph.check.cond_no_branch", {"node": _name_of(node)}),
						L10n.ui("graph.check.cond_no_branch_hint"))
				elif not has_true or not has_false:
					_push(issues, GraphIssue.Severity.INFO, "cond_branch_missing", node.node_id, _name_of(node),
						L10n.ui("graph.check.cond_branch_missing", {"node": _name_of(node), "port": "true" if not has_true else "false"}),
						L10n.ui("graph.check.cond_branch_missing_hint"))
			"action":
				var key := str(node.get_param("key", ""))
				if key.strip_edges() == "":
					_push(issues, GraphIssue.Severity.ERROR, "param_missing", node.node_id, _name_of(node),
						L10n.ui("graph.check.param_missing", {"node": _name_of(node), "field": L10n.ui("param.state")}),
						L10n.ui("graph.check.param_missing_hint"))
				else:
					_check_state_registered(issues, node, "key", level_prefix)
			"stage":
				if str(node.get_param("stage_id", "")).strip_edges() == "":
					_push(issues, GraphIssue.Severity.ERROR, "param_missing", node.node_id, _name_of(node),
						L10n.ui("graph.check.param_missing", {"node": _name_of(node), "field": L10n.ui("param.stage_id")}),
						L10n.ui("graph.check.param_missing_hint"))
			"event":
				_check_event(issues, node)
			"end":
				var completed := str(node.get_param("completed_key", ""))
				if completed.strip_edges() == "":
					_push(issues, GraphIssue.Severity.INFO, "end_no_key", node.node_id, _name_of(node),
						L10n.ui("graph.check.end_no_key", {"node": _name_of(node)}),
						L10n.ui("graph.check.end_no_key_hint"))
				else:
					_check_state_registered(issues, node, "completed_key", level_prefix)
			"merge_and":
				var incoming := graph.incoming_count(node.node_id)
				var required := int(node.get_param("required", 0))
				if required > incoming:
					_push(issues, GraphIssue.Severity.ERROR, "merge_over_required", node.node_id, _name_of(node),
						L10n.ui("graph.check.merge_over_required", {"node": _name_of(node), "required": required, "incoming": incoming}),
						L10n.ui("graph.check.merge_over_required_hint"))
				elif incoming == 0:
					_push(issues, GraphIssue.Severity.WARNING, "merge_no_input", node.node_id, _name_of(node),
						L10n.ui("graph.check.merge_no_input", {"node": _name_of(node)}),
						L10n.ui("graph.check.merge_no_input_hint"))

static func _check_state_registered(issues: Array[GraphIssue], node: LevelNode, param: String, level_prefix: String) -> void:
	var raw := str(node.get_param(param, ""))
	if raw.strip_edges() == "":
		return
	var resolved := StateStore.resolve_key(raw, level_prefix)
	if StateCatalogStore.is_known(resolved):
		return
	_push(issues, GraphIssue.Severity.WARNING, "state_unregistered", node.node_id, _name_of(node),
		L10n.ui("graph.check.state_unregistered", {"node": _name_of(node), "key": resolved}),
		L10n.ui("graph.check.state_unregistered_hint"))

static func _check_event(issues: Array[GraphIssue], node: LevelNode) -> void:
	var path := str(node.get_param("event_path", ""))
	if path.strip_edges() == "":
		_push(issues, GraphIssue.Severity.ERROR, "event_path_empty", node.node_id, _name_of(node),
			L10n.ui("graph.check.event_path_empty", {"node": _name_of(node)}),
			L10n.ui("graph.check.event_path_empty_hint"))
		return
	if not ResourceLoader.exists(path):
		_push(issues, GraphIssue.Severity.ERROR, "event_path_missing", node.node_id, _name_of(node),
			L10n.ui("graph.check.event_path_missing", {"node": _name_of(node), "path": path}),
			L10n.ui("graph.check.event_path_missing_hint"))
		return
	var definition := load(path) as EventDefinition
	if definition == null:
		_push(issues, GraphIssue.Severity.ERROR, "event_not_definition", node.node_id, _name_of(node),
			L10n.ui("graph.check.event_not_definition", {"node": _name_of(node), "path": path}),
			L10n.ui("graph.check.event_not_definition_hint"))
		return
	var trigger := str(node.get_param("trigger", "interact"))
	for page in definition.pages:
		if page != null and page.trigger == trigger:
			return
	_push(issues, GraphIssue.Severity.WARNING, "event_trigger_no_page", node.node_id, _name_of(node),
		L10n.ui("graph.check.event_trigger_no_page", {"node": _name_of(node), "trigger": trigger}),
		L10n.ui("graph.check.event_trigger_no_page_hint"))

# ── 循环 ─────────────────────────────────────────────────

static func _check_cycles(graph: LevelGraph, nodes: Dictionary, level_prefix: String, issues: Array[GraphIssue]) -> void:
	# 令牌传播图：监视型条件不转发令牌、end 不向外传播、禁用节点不可激活。
	var token_graph := _token_adjacency(graph, nodes)
	var roots: Array[StringName] = []
	for node in nodes.values():
		if node.type == "start" and node.enabled:
			roots.append(node.node_id)
		elif node.type == "condition" and node.enabled and _is_monitor(node) and _resolved_key(node, level_prefix) != "":
			# 监视条件状态翻转时从自己的出口发令牌，等效于这些目标各有一个隐形起点。
			for connection in graph.outgoing(node.node_id):
				if connection != null and token_graph.has(connection.to_node):
					roots.append(connection.to_node)
	var reached := _flood(roots, token_graph)

	# 去掉 AND 汇合（fired 只放行一次）之后还剩的环 → 运行时必然传播到上限中止。
	var unguarded := _cycles_excluding(token_graph, reached, nodes, ["merge_and"])
	for component in unguarded:
		_push(issues, GraphIssue.Severity.ERROR, "cycle_unguarded", component[0], "",
			L10n.ui("graph.check.cycle_unguarded", {"nodes": _names_of(component, nodes)}),
			L10n.ui("graph.check.cycle_unguarded_hint"))
	if unguarded.is_empty():
		# 有环但都带 AND 闸门 → 现有机制保证终止，只做提示。
		var gated := _cycles_excluding(token_graph, reached, nodes, [])
		for component in gated:
			if _component_has_type(component, nodes, "merge_and"):
				_push(issues, GraphIssue.Severity.INFO, "cycle_gated", component[0], "",
					L10n.ui("graph.check.cycle_gated", {"nodes": _names_of(component, nodes)}),
					L10n.ui("graph.check.cycle_gated_hint"))
				break

	# 监视条件之间的正反馈振荡：A 的分支写入能让 B 成立的值，B 又写回能让 A 成立的值。
	_check_monitor_oscillation(graph, nodes, level_prefix, issues)

## 监视条件 A 的分支写入了能让监视条件 B 成立的值时，连一条 A→B 的元边；元图成环即振荡风险。
static func _check_monitor_oscillation(graph: LevelGraph, nodes: Dictionary, level_prefix: String, issues: Array[GraphIssue]) -> void:
	var monitors: Array[LevelNode] = []
	for node in nodes.values():
		if node.type == "condition" and node.enabled and _is_monitor(node) and _resolved_key(node, level_prefix) != "":
			monitors.append(node)
	if monitors.size() < 2:
		return

	var writes_by_monitor := {}
	for monitor in monitors:
		writes_by_monitor[monitor.node_id] = _writes_reachable(graph, nodes, monitor, level_prefix)

	for source in monitors:
		var path := _meta_cycle_from(source, monitors, writes_by_monitor, level_prefix)
		if path.is_empty():
			continue
		_push(issues, GraphIssue.Severity.WARNING, "monitor_oscillation", source.node_id, _name_of(source),
			L10n.ui("graph.check.monitor_oscillation", {"nodes": _names_of(path, nodes)}),
			L10n.ui("graph.check.monitor_oscillation_hint"))
		return

## 从 source 沿元边找一条回到 source 的路，返回路径上的监视条件（含 source），找不到返回空数组。
static func _meta_cycle_from(source: LevelNode, monitors: Array[LevelNode], writes_by_monitor: Dictionary, level_prefix: String) -> Array:
	var parent := {}
	var queue: Array[StringName] = []
	for candidate in monitors:
		if candidate.node_id == source.node_id:
			continue
		if not _writes_satisfy(writes_by_monitor.get(source.node_id, {}), candidate, level_prefix):
			continue
		if not queue.has(candidate.node_id):
			parent[candidate.node_id] = source.node_id
			queue.append(candidate.node_id)

	while not queue.is_empty():
		var current_id: StringName = queue.pop_front()
		for candidate in monitors:
			if candidate.node_id == current_id:
				continue
			if not _writes_satisfy(writes_by_monitor.get(current_id, {}), candidate, level_prefix):
				continue
			if candidate.node_id == source.node_id:
				# 回到 source：还原路径 source → … → current → source（首尾都带 source，读作一个环）。
				var path: Array = []
				var walk: StringName = current_id
				while true:
					path.append(walk)
					if walk == source.node_id:
						break
					walk = parent.get(walk, source.node_id)
				path.reverse()
				path.append(source.node_id)
				return path
			if not parent.has(candidate.node_id):
				parent[candidate.node_id] = current_id
				queue.append(candidate.node_id)
	return []

## 从监视条件的出口做令牌遍历（不穿过其它监视条件、不穿过 AND 汇合），收集动作写入的 key→值与 end 完成标记。
static func _writes_reachable(graph: LevelGraph, nodes: Dictionary, monitor: LevelNode, level_prefix: String) -> Dictionary:
	var writes := {}
	var visited := {monitor.node_id: true}
	var queue: Array[StringName] = []
	for connection in graph.outgoing(monitor.node_id):
		if connection != null:
			queue.append(connection.to_node)
	while not queue.is_empty():
		var node_id: StringName = queue.pop_front()
		if visited.has(node_id):
			continue
		visited[node_id] = true
		var node: LevelNode = nodes.get(node_id, null)
		if node == null or not node.enabled:
			continue
		match node.type:
			"condition":
				continue   # 到达其它监视条件即止：令牌在这里被丢弃
			"end":
				var completed := str(node.get_param("completed_key", ""))
				if completed.strip_edges() != "":
					writes[StateStore.resolve_key(completed, level_prefix)] = true
				continue   # end 之后令牌不再传播
			"action":
				var raw := str(node.get_param("key", ""))
				if raw.strip_edges() != "":
					var value: Variant = node.get_param("value", true)
					if value is String:
						value = ValueParser.parse(value)
					writes[StateStore.resolve_key(raw, level_prefix)] = value
			"merge_and":
				continue   # AND 只放行一次，撑不起持续的振荡
			_:
				pass
		for connection in graph.outgoing(node_id):
			if connection != null:
				queue.append(connection.to_node)
	return writes

## 写入集合里是否存在某个 (key, value) 能让监视条件成立（布尔/数值/文本的常量判断）。
static func _writes_satisfy(writes: Dictionary, monitor: LevelNode, level_prefix: String) -> bool:
	var key := _resolved_key(monitor, level_prefix)
	if not writes.has(key):
		return false
	var expected: Variant = monitor.get_param("value", true)
	if expected is String:
		expected = ValueParser.parse(expected)
	var op := str(monitor.get_param("op", "=="))
	return _compare_for_satisfy(writes[key], op, expected)

static func _compare_for_satisfy(written: Variant, op: String, expected: Variant) -> bool:
	match op:
		"==":
			return _loose_eq(written, expected)
		"!=":
			return not _loose_eq(written, expected)
		">", ">=", "<", "<=":
			var a := float(written) if (written is int or written is float) else NAN
			var b := float(expected) if (expected is int or expected is float) else NAN
			if is_nan(a) or is_nan(b):
				return false
			match op:
				">": return a > b
				">=": return a >= b
				"<": return a < b
				_: return a <= b
		_:
			return false

static func _loose_eq(a: Variant, b: Variant) -> bool:
	if a is bool or b is bool:
		return bool(a) == bool(b)
	if a is int or a is float:
		return (b is int or b is float) and absf(float(a) - float(b)) < 0.0001
	return str(a) == str(b)

# ── 图算法工具 ───────────────────────────────────────────

## 有效节点表：node_id -> LevelNode（跳过空项）。
static func _live_nodes(graph: LevelGraph) -> Dictionary:
	var nodes := {}
	for node in graph.nodes:
		if node != null and node.node_id != &"":
			nodes[node.node_id] = node
	return nodes

static func _is_monitor(node: LevelNode) -> bool:
	return bool(node.get_param("monitor", true))

## 激活传播邻接表（可达性用）：任何节点激活后都可能把令牌发给这些目标。
static func _activation_adjacency(graph: LevelGraph, nodes: Dictionary) -> Dictionary:
	var adjacency := {}
	for node in nodes.values():
		if not node.enabled:
			continue
		var targets: Array[StringName] = []
		for connection in graph.outgoing(node.node_id):
			if connection != null and nodes.has(connection.to_node):
				targets.append(connection.to_node)
		adjacency[node.node_id] = targets
	return adjacency

## 令牌传播邻接表（循环检测用）：监视型条件不转发令牌，end 不向外传播。
static func _token_adjacency(graph: LevelGraph, nodes: Dictionary) -> Dictionary:
	var adjacency := {}
	for node in nodes.values():
		if not node.enabled:
			continue
		if node.type == "condition" and _is_monitor(node):
			continue
		var targets: Array[StringName] = []
		if node.type != "end":
			for connection in graph.outgoing(node.node_id):
				if connection != null and nodes.has(connection.to_node):
					targets.append(connection.to_node)
		adjacency[node.node_id] = targets
	return adjacency

static func _flood(roots: Array[StringName], adjacency: Dictionary) -> Dictionary:
	var visited := {}
	var queue: Array[StringName] = []
	for root in roots:
		if adjacency.has(root) and not visited.has(root):
			visited[root] = true
			queue.append(root)
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for target in adjacency.get(current, []):
			if not visited.has(target) and adjacency.has(target):
				visited[target] = true
				queue.append(target)
	return visited

## 在 reached 子图里找环：先排除 exclude_types 节点，剩下的强连通分量（大小>1 或自环）即环。
static func _cycles_excluding(token_graph: Dictionary, reached: Dictionary, nodes: Dictionary, exclude_types: Array) -> Array:
	var filtered := {}
	for node_id in reached:
		var node: LevelNode = nodes.get(node_id, null)
		if node == null or exclude_types.has(node.type):
			continue
		var kept: Array[StringName] = []
		for target in token_graph.get(node_id, []):
			if not reached.has(target):
				continue
			var target_node: LevelNode = nodes.get(target, null)
			if target_node == null or exclude_types.has(target_node.type):
				continue
			kept.append(target)
		filtered[node_id] = kept
	return _strongly_connected_cycles(filtered)

## Tarjan 强连通分量；返回所有“成环”的分量（大小>1 或带自环），每个分量是节点 id 数组。
static func _strongly_connected_cycles(adjacency: Dictionary) -> Array:
	var index := {}
	var low := {}
	var on_stack := {}
	var stack: Array[StringName] = []
	var counter := [0]
	var result: Array = []

	for start in adjacency.keys():
		if not index.has(start):
			_tarjan(start, adjacency, index, low, on_stack, stack, counter, result)
	return result

static func _tarjan(node_id: StringName, adjacency: Dictionary, index: Dictionary, low: Dictionary,
		on_stack: Dictionary, stack: Array[StringName], counter: Array, result: Array) -> void:
	# 递归实现即可：编辑器里的关卡图规模很小。
	index[node_id] = counter[0]
	low[node_id] = counter[0]
	counter[0] += 1
	stack.append(node_id)
	on_stack[node_id] = true

	for target in adjacency.get(node_id, []):
		if not index.has(target):
			_tarjan(target, adjacency, index, low, on_stack, stack, counter, result)
			low[node_id] = mini(low[node_id], low[target])
		elif on_stack.get(target, false):
			low[node_id] = mini(low[node_id], index[target])

	if low[node_id] == index[node_id]:
		var component: Array = []
		while true:
			var popped: StringName = stack.pop_back()
			on_stack[popped] = false
			component.append(popped)
			if popped == node_id:
				break
		var has_self_loop: bool = (adjacency.get(node_id, []) as Array).has(node_id)
		if component.size() > 1 or has_self_loop:
			result.append(component)

# ── 小工具 ───────────────────────────────────────────────

static func _resolved_key(node: LevelNode, level_prefix: String) -> String:
	var raw := str(node.get_param("key", ""))
	if raw.strip_edges() == "":
		return ""
	return StateStore.resolve_key(raw, level_prefix)

static func _name_of(node: LevelNode) -> String:
	if node == null:
		return ""
	if node.title.strip_edges() != "":
		return node.title
	return L10n.ui("graph.node." + node.type)

static func _names_of(ids: Array, nodes: Dictionary) -> String:
	var names: Array[String] = []
	for id in ids:
		var node: LevelNode = nodes.get(id, null)
		names.append(_name_of(node) if node != null else String(id))
	return "、".join(names)

static func _component_has_type(component: Array, nodes: Dictionary, type: String) -> bool:
	for id in component:
		var node: LevelNode = nodes.get(id, null)
		if node != null and node.type == type:
			return true
	return false

static func _push(issues: Array[GraphIssue], severity: int, code: String, node_id: StringName,
		node_name: String, message: String, suggestion: String) -> void:
	var issue := GraphIssue.new()
	issue.severity = severity
	issue.code = code
	issue.node_id = node_id
	issue.node_name = node_name
	issue.message = message
	issue.suggestion = suggestion
	issues.append(issue)
