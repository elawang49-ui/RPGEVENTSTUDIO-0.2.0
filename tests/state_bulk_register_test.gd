extends SceneTree
## 状态库批量登记自动化测试（不依赖任何第三方插件）：
##   godot --headless --path . --script res://tests/state_bulk_register_test.gd
## 退出码 0 = 全部通过。
##
## 覆盖：新旧状态识别、已登记排除、重复合并、动态引用边界、类型推断与冲突、
## @@level 作用域标记、批量登记、跳过已有、取消不落盘、写入失败回滚、
## 旧事件/关卡图兼容、对话框勾选/批量/编辑/登记全流程。

const FIXTURE_DIR := "res://tests/fixtures/bulk_scan"
const TEST_DIR := "res://.godot/bulk_register_test"
const SAMPLE_EVENTS := "res://addons/rpgeventstudio/samples/events"
const SAMPLE_GRAPHS := "res://addons/rpgeventstudio/samples/graphs"

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_test_scan_candidates()
	_test_duplicate_merge()
	_test_dynamic_boundary()
	_test_registered_exclusion()
	_test_type_inference()
	_test_register_and_reload()
	_test_register_skip_existing()
	_test_cancel_keeps_file()
	_test_write_failure_rollback()
	_test_old_samples_compatible()
	await _test_dialog_flow()
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 工具 ─────────────────────────────────────────────────

func _scan(roots: PackedStringArray, catalog: StateCatalog = null) -> Dictionary:
	if catalog == null:
		catalog = StateCatalogStore.catalog()
	return StateUsageScanner.scan(roots, catalog)

func _scan_fixtures(catalog: StateCatalog = null) -> Dictionary:
	return _scan(PackedStringArray([FIXTURE_DIR]), catalog)

func _candidate_keys(report: Dictionary) -> Dictionary:
	var out := {}
	for candidate in report["candidates"]:
		out[String(candidate["key"])] = candidate
	return out

func _fresh_catalog(path: String, seed_display: String = "旧状态") -> void:
	for suffix: String in ["", ".bak", ".tmp.tres"]:
		var target := path + suffix
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		elif DirAccess.dir_exists_absolute(target):
			DirAccess.remove_absolute(target)
	var base := StateCatalog.new()
	var existing := base.ensure("Existing.Old", "string", "旧值", "保留")
	existing.display_name = seed_display
	_check(StateCatalogStore.write(base, path) == OK, "准备测试总表 %s" % path)

func _reload(path: String) -> StateCatalog:
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return loaded if loaded is StateCatalog else null

# ── 1. 新旧状态识别 ──────────────────────────────────────

func _test_scan_candidates() -> void:
	var report := _scan_fixtures()
	var keys := _candidate_keys(report)
	_check(report["errors"].is_empty(), "夹具扫描不应有读取错误（%s）" % str(report["errors"]))
	var expected := [
		"Global.Quest.RingFound", "Global.Quest.GraphOnly", "Global.Quest.Completed",
		"School.Fame", "School.Mood", "School.PlayerTitle",
		"Global.Mixed", "@@level.DoorOpen", "Local.TempFlag",
		"Global.Script.Started", "Global.Script.Counter", "Global.Script.Nickname",
		"Global.Script.Live", "Global.Script.Level", "Global.Script.Saved",
	]
	for key in expected:
		_check(keys.has(key), "扫描应发现未登记状态 %s" % key)
	_check(not keys.has("Global.Player.HasKey"), "已登记状态 Global.Player.HasKey 应被排除")
	var ring: Dictionary = keys.get("Global.Quest.RingFound", {})
	var files := {}
	for location in ring.get("locations", [] as Array):
		files[String(location["file"])] = true
	_check(files.has(FIXTURE_DIR + "/legacy_event.tres") and files.has(FIXTURE_DIR + "/legacy_graph.tres"),
		"跨文件引用应各自记录位置（实际 %s）" % str(files.keys()))
	_check(int(ring.get("uses", 0)) == 2, "RingFound 引用次数应为 2（实际 %d）" % int(ring.get("uses", 0)))

# ── 2. 重复状态合并 ──────────────────────────────────────

func _test_duplicate_merge() -> void:
	var keys := _candidate_keys(_scan_fixtures())
	var ring: Dictionary = keys.get("Global.Quest.RingFound", {})
	var kinds: Array = ring.get("kinds", [] as Array)
	_check(kinds.has("cmd.set_switch") and kinds.has("graph.condition"),
		"同一状态的多来源使用类型应合并（实际 %s）" % str(kinds))
	# 场景外链同一事件资源时不得重复计数
	_check(int(ring.get("uses", 0)) == 2, "场景外链事件不应让引用次数翻倍（实际 %d）" % int(ring.get("uses", 0)))
	var fame: Dictionary = keys.get("School.Fame", {})
	_check(int(fame.get("uses", 0)) == 3, "Fame 引用次数应为 3（实际 %d）" % int(fame.get("uses", 0)))

# ── 3. 动态引用边界 ──────────────────────────────────────

func _test_dynamic_boundary() -> void:
	var report := _scan_fixtures()
	var dynamic_refs: Array = report["dynamic_refs"]
	_check(dynamic_refs.size() == 3, "应识别 3 条动态引用（实际 %d）" % dynamic_refs.size())
	var reasons := {}
	for ref in dynamic_refs:
		reasons[String(ref["reason"])] = true
	_check(reasons.has("dynamic_concat") and reasons.has("dynamic_expression"),
		"拼接与变量参数都应报告（实际 %s）" % str(reasons.keys()))
	var keys := _candidate_keys(report)
	_check(not keys.has("Global.Script.占位"), "动态拼接产物不应成为候选")
	_check(not keys.has("Global.1"), "格式化产物不应成为候选")
	# 动态不吞掉同文件里能静态确认的字面量
	_check(keys.has("Global.Script.Started"), "同文件的字面量引用仍应被识别")

# ── 4. 已登记排除（合成总表） ────────────────────────────

func _test_registered_exclusion() -> void:
	var catalog := StateCatalog.new()
	catalog.ensure("Global.Quest.RingFound", "bool", false, "测试")
	var keys := _candidate_keys(_scan_fixtures(catalog))
	_check(not keys.has("Global.Quest.RingFound"), "合成总表里的键应被排除")
	_check(keys.has("Global.Quest.GraphOnly"), "未登记的键应保留")

# ── 5. 类型推断与冲突 ────────────────────────────────────

func _test_type_inference() -> void:
	var keys := _candidate_keys(_scan_fixtures())
	_check(String(keys["School.Fame"]["inferred_type"]) == "int", "Fame 应推断为 int")
	_check(String(keys["School.Mood"]["inferred_type"]) == "float", "Mood 应推断为 float")
	_check(String(keys["School.PlayerTitle"]["inferred_type"]) == "string", "PlayerTitle 应推断为 string")
	_check(String(keys["Global.Script.Started"]["inferred_type"]) == "bool", "Started 应推断为 bool")
	_check(String(keys["Global.Script.Level"]["inferred_type"]) == "int", "define TYPE_INT 应推断为 int")
	_check(String(keys["Local.TempFlag"]["inferred_type"]) == "bool", "公共事件 set_switch 应推断为 bool")
	_check(String(keys["Global.Script.Saved"]["inferred_type"]) == "", "仅常量引用不应推断类型")
	_check(not bool(keys["Global.Script.Saved"]["type_conflict"]), "常量引用不应误报冲突")
	_check(bool(keys["Global.Mixed"]["type_conflict"]), "bool 与 int 混用应标记类型冲突")
	_check(not bool(keys["School.Fame"]["type_conflict"]), "int 系使用不应误报冲突")
	_check(bool(keys["@@" + "level.DoorOpen"]["scoped"]), "@@level 键应标记动态作用域")

# ── 6. 批量登记 + 保存后重新打开 ─────────────────────────

func _test_register_and_reload() -> void:
	var path := TEST_DIR + "/catalog_a.tres"
	_fresh_catalog(path)
	var entries := [
		{"key": "Global.Quest.RingFound", "type": "bool", "default_value": false, "display_name": "戒指已找到", "category": "任务"},
		{"key": "School.Fame", "type": "int", "default_value": 0, "display_name": "声望", "category": "数值"},
		{"key": "School.PlayerTitle", "type": "string", "default_value": "", "display_name": "玩家称号", "category": "数值"},
	]
	var result := StateCatalogBulk.register(entries, path)
	_check(bool(result["ok"]), "批量登记应成功（%s）" % str(result["error"]))
	_check((result["added"] as Array).size() == 3, "应新增 3 条（实际 %d）" % (result["added"] as Array).size())

	var reloaded := _reload(path)
	_check(reloaded != null, "登记后应能从磁盘重新读回")
	if reloaded == null:
		return
	_check(reloaded.definitions.size() == 4, "总表应包含原有 1 条 + 新增 3 条（实际 %d）" % reloaded.definitions.size())
	var ring := reloaded.find("Global.Quest.RingFound")
	_check(ring != null and ring.display_name == "戒指已找到" and ring.type == "bool",
		"新增开关定义应完整（实际 %s / %s）" % [ring.display_name if ring != null else "?", ring.type if ring != null else "?"])
	var fame := reloaded.find("School.Fame")
	_check(fame != null and fame.type == "int" and int(fame.default_value) == 0, "新增整数定义应完整")
	var old := reloaded.find("Existing.Old")
	_check(old != null and old.display_name == "旧状态" and old.type == "string" and str(old.default_value) == "旧值",
		"原有定义不应被批量登记改动")

# ── 7. 重复登记跳过 / 不覆盖已有定义 ─────────────────────

func _test_register_skip_existing() -> void:
	var path := TEST_DIR + "/catalog_a.tres"
	var before := FileAccess.get_md5(path)
	var repeat := StateCatalogBulk.register([
		{"key": "Global.Quest.RingFound", "type": "bool", "display_name": "不应该出现的名字"},
		{"key": "School.Fame", "type": "int"},
	], path)
	_check(bool(repeat["ok"]), "重复登记应成功返回")
	_check((repeat["added"] as Array).is_empty(), "重复登记不应新增")
	_check((repeat["skipped"] as Array).size() == 2, "重复键应全部跳过")
	_check(FileAccess.get_md5(path) == before, "全部跳过时不应写盘")
	var reloaded := _reload(path)
	var ring := reloaded.find("Global.Quest.RingFound")
	_check(ring != null and ring.display_name == "戒指已找到", "已有定义不应被覆盖")

# ── 8. 取消登记：扫描/勾选都不落盘 ───────────────────────

func _test_cancel_keeps_file() -> void:
	var path := TEST_DIR + "/catalog_a.tres"
	var before := FileAccess.get_md5(path)
	var report := _scan_fixtures()
	_check(not (report["candidates"] as Array).is_empty(), "取消场景前置：扫描有候选")
	_check(FileAccess.get_md5(path) == before, "扫描本身不修改总表")
	var empty := StateCatalogBulk.register([], path)
	_check(not bool(empty["ok"]) and str(empty["error"]) != "", "空登记应被拒绝")
	_check(FileAccess.get_md5(path) == before, "空登记不修改总表")

# ── 9. 写入失败回滚 ──────────────────────────────────────

func _test_write_failure_rollback() -> void:
	var path := TEST_DIR + "/catalog_a.tres"
	var before := FileAccess.get_md5(path)
	# 用同名目录占住 SafeFile 的临时文件路径，模拟写入失败
	var blocked := path.get_basename() + ".tmp.tres"
	DirAccess.make_dir_recursive_absolute(blocked)
	var result := StateCatalogBulk.register([
		{"key": "Rollback.Test", "type": "bool", "display_name": "回滚测试"},
	], path)
	_check(not bool(result["ok"]), "写入失败应返回失败")
	_check(str(result["error"]).begins_with("save_failed"), "错误应来自临时写入（实际 %s）" % str(result["error"]))
	_check(FileAccess.get_md5(path) == before, "失败时原总表文件不变")
	var reloaded := _reload(path)
	_check(reloaded != null and reloaded.find("Rollback.Test") == null, "失败后磁盘上没有半份状态")
	DirAccess.remove_absolute(blocked)

# ── 10. 旧事件 / 关卡图兼容 ──────────────────────────────

func _test_old_samples_compatible() -> void:
	var sample_files := [
		SAMPLE_EVENTS + "/librarian.tres",
		SAMPLE_EVENTS + "/key_pickup.tres",
		SAMPLE_EVENTS + "/locked_door.tres",
		SAMPLE_EVENTS + "/office_desk.tres",
		SAMPLE_EVENTS + "/classroom_board.tres",
		SAMPLE_EVENTS + "/basement_cutscene.tres",
		SAMPLE_GRAPHS + "/school_graph.tres",
	]
	var hashes := {}
	for sample in sample_files:
		hashes[sample] = FileAccess.get_md5(sample)
		_check(load(sample) != null, "扫描前样例可正常加载：%s" % sample.get_file())
	var report := _scan(PackedStringArray([SAMPLE_EVENTS, SAMPLE_GRAPHS]))
	var keys := _candidate_keys(report)
	for registered_key in ["Global.Player.HasKey", "School.Classroom.ClueFound", "School.Office.DiaryFound", "School.BasementUnlocked", "School.ClassroomUnlocked"]:
		_check(not keys.has(registered_key), "样例已登记状态 %s 不应出现在候选" % registered_key)
	for sample in sample_files:
		_check(FileAccess.get_md5(sample) == hashes[sample], "扫描不修改样例文件：%s" % sample.get_file())
	_check(int(report["stats"]["tres"]) >= sample_files.size(), "样例资源应全部被扫描")

# ── 11. 对话框流程（勾选 / 批量 / 编辑 / 登记 / 信号） ────

func _test_dialog_flow() -> void:
	var path := TEST_DIR + "/catalog_dialog.tres"
	_fresh_catalog(path)
	var dialog := StateBulkRegisterDialog.new()
	dialog.scan_roots = PackedStringArray([FIXTURE_DIR])
	dialog.catalog_path = path
	root.add_child(dialog)
	await process_frame

	var registered_keys: Array = []
	dialog.registered.connect(func(keys: PackedStringArray) -> void:
		for key in keys:
			registered_keys.append(String(key))
	)
	await dialog.call("_on_scan_pressed")
	await process_frame

	var entries: Dictionary = dialog.get("_entries")
	_check(not entries.is_empty(), "对话框扫描应得到候选")
	_check(not entries.has("Global.Player.HasKey"), "对话框扫描应排除已登记键")
	_check(not bool(entries.get("Global.Script.Saved", {"checked": true})["checked"]), "未定类型默认不勾选")
	_check(not bool(entries.get("Global.Mixed", {"checked": true})["checked"]), "类型冲突默认不勾选")
	_check(bool(entries.get("School.Fame", {"checked": false})["checked"]), "类型明确的候选默认勾选")

	# 勾选一个未定类型的键直接登记 → 必须被阻止且不写盘
	var before := FileAccess.get_md5(path)
	var saved: Dictionary = entries["Global.Script.Saved"]
	saved["checked"] = true
	dialog.call("_on_register_pressed")
	_check(FileAccess.get_md5(path) == before, "存在未定类型勾选项时不应写盘")
	saved["checked"] = false

	# 勾选两项，批量设类型，编辑显示名，然后确认登记
	entries["Global.Quest.RingFound"]["checked"] = true
	entries["School.Fame"]["checked"] = true
	var type_option: OptionButton = dialog.get("_type_option")
	type_option.selected = 1   # int
	dialog.call("_on_apply_type")
	var ring_entry: Dictionary = entries["Global.Quest.RingFound"]
	_check(String(ring_entry["type"]) == "int", "批量应用类型应生效")
	ring_entry["type"] = "bool"          # 单独改回（模拟逐行类型下拉）
	ring_entry["default_text"] = "false"
	ring_entry["display_name"] = "戒指到手"
	dialog.call("_do_register")
	await process_frame

	_check(registered_keys.has("Global.Quest.RingFound") and registered_keys.has("School.Fame"),
		"登记成功应发出 registered 信号（实际 %s）" % str(registered_keys))
	_check(not entries.has("Global.Quest.RingFound"), "登记后的候选应从列表移除")
	var reloaded := _reload(path)
	_check(reloaded != null and reloaded.find("Global.Quest.RingFound") != null, "对话框登记应写入总表")
	if reloaded != null and reloaded.find("Global.Quest.RingFound") != null:
		var ring := reloaded.find("Global.Quest.RingFound")
		_check(ring.display_name == "戒指到手", "界面编辑的显示名应写入")
		_check(ring.type == "bool", "逐行类型应生效")
	_check(reloaded != null and reloaded.find("School.Fame") != null and reloaded.find("School.Fame").type == "int",
		"批量类型应写入")
	_check(reloaded != null and reloaded.find("Existing.Old") != null, "原有定义保持不变")
	dialog.queue_free()
	await process_frame

# ── 报告 ─────────────────────────────────────────────────

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──────── 批量登记测试结果 ────────")
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
