extends Node
## 剧情资源审计面板的编辑器内自测（真实 EditorInterface / Tree / 主屏标签）。
##   RPGEVENTSTUDIO_AUDIT_SELFTEST=1 godot --editor --path .
## 结果打印 [AUDIT]，全部通过退出码 0。

const FIXTURES := "res://tests/fixtures/audit"

var _checks := 0
var _failures: PackedStringArray = []
var _panel: Control
var _plugin: EditorPlugin
var _activated: Array = []

func start(plugin: EditorPlugin, view: Control) -> void:
	_plugin = plugin
	_panel = view
	await get_tree().create_timer(1.0).timeout
	if _panel == null:
		_fail("拿不到审计面板实例")
		_finish()
		return
	_panel.set("scan_roots", PackedStringArray([FIXTURES]))
	_panel.set("scan_excludes", PackedStringArray())
	_panel.issue_activated.connect(func(issue: Dictionary) -> void:
		_activated.append(issue)
	)

	var before := FileAccess.get_md5(FIXTURES + "/valid_event.tres")
	_panel.call("_on_scan_pressed")
	await _wait_scan()
	_check(not bool(_panel.get("_scanning")), "扫描应结束")
	_check(FileAccess.get_md5(FIXTURES + "/valid_event.tres") == before, "扫描不应修改资源文件")

	var report: Dictionary = _panel.call("last_report")
	var stats: Dictionary = report.get("stats", {})
	var issues: Array = _panel.call("issues")
	_check(int(stats.get("events", 0)) == 6, "面板应扫描到 6 个事件")
	_check(int(stats.get("graphs", 0)) == 2, "面板应扫描到 2 个关卡图")
	_check(not issues.is_empty(), "面板应得到问题列表")
	var shown_all := int(_panel.call("visible_issue_count"))
	_check(shown_all == issues.size(), "默认筛选应显示全部问题（显示 %d / 共 %d）" % [shown_all, issues.size()])

	var errors := StoryAudit.count_of(issues, StoryAudit.SEVERITY_ERROR)
	_check(errors > 0, "夹具中应有错误级问题")
	_panel.call("set_filter_severity", StoryAudit.SEVERITY_ERROR)
	_check(_panel.call("visible_issue_count") == errors, "只看错误时应只显示错误")
	_panel.call("show_all")
	var shown_restored := int(_panel.call("visible_issue_count"))
	_check(shown_restored == issues.size(), "恢复全部筛选（显示 %d / 共 %d）" % [shown_restored, issues.size()])

	var summary: Label = _panel.get("_summary")
	_check(summary != null and summary.text.contains("错误"), "摘要应显示错误计数")

	_panel.call("activate_first")
	_check(not _activated.is_empty(), "双击/激活应发出 issue_activated")
	var first: Dictionary = _activated.back()
	_check(str(first.get("path", "")) != "", "激活的问题应带资源路径")

	# 定位：事件 → 事件面板；关卡图 → 主屏
	_plugin.call("_on_audit_issue", {"path": FIXTURES + "/valid_event.tres"})
	await get_tree().process_frame
	var event_panel: Control = _plugin.get("_panel")
	var definition: EventDefinition = null
	if event_panel != null:
		definition = event_panel.get("_definition")
	_check(definition != null and String(definition.event_id) == "valid_event", "审计定位应打开事件定义")

	_plugin.call("_on_audit_issue", {"path": FIXTURES + "/valid_graph.tres"})
	await get_tree().process_frame
	var main_screen: Control = _plugin.get("_main_screen")
	_check(main_screen != null and main_screen.call("current_graph") != null, "审计定位应打开关卡图")

	_finish()

func _wait_scan() -> void:
	for i in 60:
		await get_tree().process_frame
		if not bool(_panel.get("_scanning")):
			return

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[AUDIT] ✓ ", message)
	else:
		_failures.append(message)
		print("[AUDIT] ✗ ", message)

func _fail(message: String) -> void:
	_checks += 1
	_failures.append(message)
	print("[AUDIT] ✗ ", message)

func _finish() -> void:
	print("")
	print("[AUDIT] ===== 检查 %d 项，失败 %d 项 =====" % [_checks, _failures.size()])
	for failure in _failures:
		print("[AUDIT] ✗ ", failure)
	print("[AUDIT] RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)
