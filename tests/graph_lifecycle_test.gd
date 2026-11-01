extends SceneTree
## 关卡图生命周期回归（P0-1）：进出关卡场景时 GraphRunner 的注册/注销必须对称，
## 旧图释放后不得继续响应状态变化（否则重进关卡会出现双 Runner、状态串台、重复触发）。
##   godot --headless --path . --script res://tests/graph_lifecycle_test.gd

const GRAPH_PATH := "res://.godot/graph_lifecycle_probe.tres"
const PROBE_KEY := "School.LifecycleProbe"         # 图上监视条件观察的状态键
const ESCALATED_KEY := "School.LifecycleEscalated" # 监视条件触发后图会写入的状态键（传播副作用）
const STAGE_KEY := "School.Stage"                  # 开始节点推进到的阶段键

var _checks := 0
var _failures: PackedStringArray = []
var _runtime: Node
var _state: StateStore

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_runtime = root.get_node_or_null("RPGEventStudio")
	_check(_runtime != null, "测试环境里应有 RPGEventStudio 运行时")
	if _runtime == null:
		_report()
		quit(1)
		return
	_state = _runtime.get("state")

	_check(_build_graph() == OK, "测试关卡图应能保存")

	await _test_register_on_enter()
	await _test_unregister_and_silence_on_free()
	await _test_reenter_keeps_single_runner()
	await _test_stop_graph_idempotent_and_restart()
	await _test_enter_exit_cycles()

	if FileAccess.file_exists(GRAPH_PATH):
		DirAccess.remove_absolute(GRAPH_PATH)
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 用例 ─────────────────────────────────────────────────

func _test_register_on_enter() -> void:
	_reset_state()
	var host := _enter()
	await _frames(3)
	_check(_graphs().size() == 1, "进入场景后运行时应注册恰好 1 个关卡图")
	var runner: GraphRunner = _graphs()[0] if not _graphs().is_empty() else null
	_check(runner != null and runner.running, "注册的 runner 应处于运行状态")
	_check(str(_state.get_value(STAGE_KEY)) == "exploration", "关卡图应自动启动并推进到探索阶段")
	_free_host(host)
	await _frames(2)

func _test_unregister_and_silence_on_free() -> void:
	_reset_state()
	var host := _enter()
	await _frames(3)
	var runner: GraphRunner = _graphs()[0] if not _graphs().is_empty() else null
	host.queue_free()
	await _frames(3)
	_check(_graphs().is_empty(), "宿主场景释放后 graphs 应注销旧图")
	_check(runner != null and not runner.running, "旧 runner 应完全停止")
	_check(runner == null or not _state.changed.is_connected(Callable(runner, "_on_state_changed")),
		"旧 runner 应断开 StateStore.changed 连接")
	_check(runner == null or runner.node_state_changed.get_connections().is_empty(),
		"旧 runner 的节点状态转发应一并断开")
	_check(runner == null or runner.stage_changed.get_connections().is_empty(),
		"旧 runner 的阶段转发应一并断开")
	_check(runner == null or not runner.has_signal("stopped") or runner.stopped.get_connections().is_empty(),
		"旧 runner 的停止广播连接应一并断开")
	_state.set_value(PROBE_KEY, true)
	await _frames(3)
	_check(not _state.get_bool(ESCALATED_KEY), "释放后翻转监视键不应再触发旧图传播")
	_state.set_value(PROBE_KEY, false)
	await _frames(1)

func _test_reenter_keeps_single_runner() -> void:
	_reset_state()
	var host := _enter()
	await _frames(3)
	_check(_graphs().size() == 1, "重新进入场景后 graphs 应恰好 1 个 runner（无重复注册/残留）")
	_state.set_value(PROBE_KEY, true)
	await _frames(3)
	_check(_state.get_bool(ESCALATED_KEY), "新 runner 应正常响应监视键变化")
	_state.set_value(PROBE_KEY, false)
	_state.set_value(ESCALATED_KEY, false)
	_free_host(host)
	await _frames(2)

func _test_stop_graph_idempotent_and_restart() -> void:
	_reset_state()
	var host := _enter()
	await _frames(3)
	var component: Node = host.get_node("LevelGraph")
	var runner: GraphRunner = _graphs()[0] if not _graphs().is_empty() else null
	var stopped_count := {"n": 0}
	if runner != null and runner.has_signal("stopped"):
		runner.stopped.connect(func(_graph_runner) -> void: stopped_count["n"] += 1)
	component.call("stop_graph")
	component.call("stop_graph")
	runner.stop() # runner 层重复停止：不应报错、不应重复广播
	await _frames(2)
	_check(_graphs().is_empty(), "stop_graph 后应从 graphs 注销")
	_check(stopped_count["n"] == 1, "重复停止只应广播一次 stopped")
	_check(runner == null or not _state.changed.is_connected(Callable(runner, "_on_state_changed")),
		"手动停止后也应断开状态监视连接")
	_state.set_value(PROBE_KEY, true)
	await _frames(2)
	_check(not _state.get_bool(ESCALATED_KEY), "手动停止后翻转监视键不应触发旧图")
	_state.set_value(PROBE_KEY, false)
	_state.set_value(ESCALATED_KEY, false)

	component.call("start_graph") # start → stop → start：同一节点重进关卡
	await _frames(3)
	_check(_graphs().size() == 1, "重新 start_graph 后 graphs 应恰好 1 个（旧 runner 不残留）")
	_check(str(_state.get_value(STAGE_KEY)) == "exploration", "重新 start_graph 后应再次推进到探索阶段")
	_state.set_value(PROBE_KEY, true)
	await _frames(3)
	_check(_state.get_bool(ESCALATED_KEY), "重启后的 runner 应正常响应监视键变化")
	_state.set_value(PROBE_KEY, false)
	_state.set_value(ESCALATED_KEY, false)
	_free_host(host)
	await _frames(2)
	_check(_graphs().is_empty(), "重启后的图随宿主释放也应注销")

func _test_enter_exit_cycles() -> void:
	for i in 3:
		_reset_state()
		var host := _enter()
		await _frames(3)
		_check(_graphs().size() == 1, "循环 %d：进入后 graphs 应恰好 1 个" % (i + 1))
		_free_host(host)
		await _frames(3)
		_check(_graphs().is_empty(), "循环 %d：退出后 graphs 应清空" % (i + 1))
		_state.set_value(PROBE_KEY, true)
		await _frames(3)
		_check(not _state.get_bool(ESCALATED_KEY), "循环 %d：旧图不应再响应状态变化" % (i + 1))
		_state.set_value(PROBE_KEY, false)
		_state.set_value(ESCALATED_KEY, false)
		await _frames(1)
	_check(_graphs().is_empty(), "3 次进出循环后不应残留任何 runner")

# ── 环境 ─────────────────────────────────────────────────

## 构造最小关卡图：start → stage；监视 @@level.LifecycleProbe == true → 写 @@level.LifecycleEscalated
func _build_graph() -> int:
	var graph := LevelGraph.new()
	graph.graph_id = &"lifecycle_probe"
	graph.level_id = &"school"
	var entry := LevelNode.new()
	entry.node_id = &"start_1"
	entry.type = "start"
	var stage := LevelNode.new()
	stage.node_id = &"stage_1"
	stage.type = "stage"
	stage.params = {"stage_id": "exploration"}
	var probe := LevelNode.new()
	probe.node_id = &"probe_1"
	probe.type = "condition"
	probe.params = {"key": "@@level.LifecycleProbe", "op": "==", "value": "true", "monitor": true}
	var escalate := LevelNode.new()
	escalate.node_id = &"escalate_1"
	escalate.type = "action"
	escalate.params = {"key": "@@level.LifecycleEscalated", "op": "set", "value": "true"}
	graph.add_node(entry)
	graph.add_node(stage)
	graph.add_node(probe)
	graph.add_node(escalate)
	graph.connect_nodes(entry.node_id, "out", stage.node_id, "in")
	graph.connect_nodes(probe.node_id, "true", escalate.node_id, "in")
	var err := ResourceSaver.save(graph, GRAPH_PATH)
	if err != OK:
		push_error("无法保存测试关卡图：%s" % error_string(err))
	return err

## 造一个挂在宿主节点下的 LevelGraphRunner2D，加入场景树即触发 _ready → start_graph
func _enter() -> Node:
	var host := Node2D.new()
	host.name = "LifecycleHost"
	var component := LevelGraphRunner2D.new()
	component.name = "LevelGraph"
	component.graph_path = GRAPH_PATH
	host.add_child(component)
	root.add_child(host)
	return host

func _free_host(host: Node) -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()

## 每轮进入前把监视键/副作用键归零，避免上一轮的状态影响判定
func _reset_state() -> void:
	_state.set_value(PROBE_KEY, false)
	_state.set_value(ESCALATED_KEY, false)
	_state.set_value(STAGE_KEY, "")

func _graphs() -> Array:
	return _runtime.get("graphs")

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 关卡图生命周期测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
