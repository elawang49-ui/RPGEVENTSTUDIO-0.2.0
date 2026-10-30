extends SceneTree
## 剧情资源审计器测试（不依赖编辑器）：
##   godot --headless --path . --script res://tests/story_audit_test.gd

const FIXTURES := "res://tests/fixtures/audit"

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var empty_catalog := StateCatalog.new()
	var report := _scan(empty_catalog)
	var issues: Array = report["issues"]
	var stats: Dictionary = report["stats"]

	_check(int(stats["events"]) == 6, "应识别 6 个事件资源（实际 %d）" % int(stats["events"]))
	_check(int(stats["graphs"]) == 2, "应识别 2 个关卡图（实际 %d）" % int(stats["graphs"]))
	_check(int(stats["refs"]) >= 3, "应收集场景/图里的引用（实际 %d）" % int(stats["refs"]))

	_check(_has(issues, "event.empty"), "空事件应报告 event.empty")
	_check(_severity(issues, "event.empty") == StoryAudit.SEVERITY_ERROR, "空事件应为错误")
	_check(_count(issues, "event.duplicate_id") == 2, "两个重复 ID 事件各报一次（实际 %d）" % _count(issues, "event.duplicate_id"))
	_check(_has(issues, "common.missing"), "缺失公共事件应报告 common.missing")
	_check(_has(issues, "state.unregistered"), "未登记状态应报告 state.unregistered")
	_check(_severity(issues, "state.unregistered") == StoryAudit.SEVERITY_WARNING, "未登记状态应为警告")
	_check(_has(issues, "ref.broken"), "场景/图里的失效引用应报告 ref.broken")
	_check(_has(issues, "graph.event_path_missing"), "关卡图事件路径失效应透传 GraphValidator 结果")
	_check(_severity(issues, "graph.event_path_missing") == StoryAudit.SEVERITY_ERROR, "图事件路径失效应为错误")

	# 未引用：valid_event 被场景引用；empty_event / valid_graph 没有引用
	_check(not _path_has(issues, "event.unreferenced", FIXTURES + "/valid_event.tres"),
		"被场景引用的事件不应报告未引用")
	_check(_path_has(issues, "event.unreferenced", FIXTURES + "/empty_event.tres"),
		"没有任何引用的事件应报告未引用")
	_check(_path_has(issues, "graph.unreferenced", FIXTURES + "/valid_graph.tres"),
		"没有任何场景引用的关卡图应报告未引用")

	# 引用数量：场景 4 条 event_path + 图 1 条 event_path
	var refs: Dictionary = report["references"]
	_check(refs.has(FIXTURES + "/valid_event.tres"), "场景引用应记录 valid_event")
	_check(refs.has(FIXTURES + "/no_such_event.tres"), "失效路径也应被记录，才能报断裂引用")

	# 排序：严重级别从高到低
	var ordered := true
	for index in range(1, issues.size()):
		if int(issues[index - 1]["severity"]) < int(issues[index]["severity"]):
			ordered = false
			break
	_check(ordered, "问题应按严重级别从高到低排序")

	# 登记状态后不再误报；图 INFO 可选
	var registered := StateCatalog.new()
	registered.ensure("Audit.Fixture.Missing", "bool", true, "测试")
	var report2 := _scan(registered)
	_check(not _has(report2["issues"], "state.unregistered"), "状态登记后不应再报未登记")
	_check(not _has(report2["issues"], "graph.start_missing"), "有效图不应报缺开始节点")

	var with_info := StoryAudit.scan({
		"roots": PackedStringArray([FIXTURES]),
		"excludes": PackedStringArray(),
		"catalog": empty_catalog,
		"graph_info": true,
	})
	_check((with_info["issues"] as Array).size() >= issues.size(), "包含图 INFO 时问题数不应减少")

	# 只读：扫描前后夹具内容不变
	var before := FileAccess.get_md5(FIXTURES + "/valid_event.tres")
	_scan(empty_catalog)
	_check(FileAccess.get_md5(FIXTURES + "/valid_event.tres") == before, "审计扫描不应修改资源")

	# 真实样例冒烟
	var sample := StoryAudit.scan({
		"roots": PackedStringArray(["res://addons/rpgeventstudio/samples"]),
		"excludes": PackedStringArray(),
		"catalog": StateCatalogStore.catalog(),
	})
	_check(int(sample["stats"]["events"]) >= 6, "样例目录应扫描到事件资源")
	_check(not StoryAudit.has_errors(sample["issues"]),
		"样例资源不应有审计错误（实际 %d）" % StoryAudit.count_of(sample["issues"], StoryAudit.SEVERITY_ERROR))

	_report()
	quit(0 if _failures.is_empty() else 1)

func _scan(catalog: StateCatalog) -> Dictionary:
	return StoryAudit.scan({
		"roots": PackedStringArray([FIXTURES]),
		"excludes": PackedStringArray(),
		"catalog": catalog,
	})

func _has(issues: Array, code: String) -> bool:
	for issue in issues:
		if str(issue["code"]) == code:
			return true
	return false

func _count(issues: Array, code: String) -> int:
	var count := 0
	for issue in issues:
		if str(issue["code"]) == code:
			count += 1
	return count

func _severity(issues: Array, code: String) -> int:
	for issue in issues:
		if str(issue["code"]) == code:
			return int(issue["severity"])
	return -1

func _path_has(issues: Array, code: String, path: String) -> bool:
	for issue in issues:
		if str(issue["code"]) == code and str(issue["path"]) == path:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──────── 剧情资源审计测试结果 ────────")
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
