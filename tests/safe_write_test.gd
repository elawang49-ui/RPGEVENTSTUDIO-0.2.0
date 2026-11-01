extends SceneTree
## 故障注入：验证异常情况下原始文件不被破坏；另覆盖文件头 UTF-8 截断的调用点行为。
##   godot --headless --path . --script res://tests/safe_write_test.gd

var _checks := 0
var _failures: PackedStringArray = []
var _dir := "res://.godot/safe_test/"

## UTF-8 截断夹具目录：放在 .godot 下，事件列表面板与审计默认扫描都会跳过，
## 事件夹具与关卡图夹具分开放（图夹具只是文本，不能被 StoryAudit 当资源加载）。
const UTF8_EVENT_DIR := "res://.godot/utf8_head_event_test/"
const UTF8_GRAPH_DIR := "res://.godot/utf8_head_graph_test/"

var _utf8_cut_event := ""
var _utf8_cut_graph := ""
var _utf8_expected_head := ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	_test_normal()
	_test_empty_rejected()
	_test_bad_header()
	_test_row_drop()
	_test_duplicate_key()
	_test_temp_failure()
	_test_resource()
	_test_head_call_sites()
	_test_read_head()
	_report()
	_cleanup()
	quit(0 if _failures.is_empty() else 1)

func _make_csv(rows: int) -> String:
	var text := "keys,zh_CN,en\n"
	for index in rows:
		text += "k.%d,中文%d,Text %d\n" % [index, index, index]
	return text

func _test_normal() -> void:
	var path := _dir + "normal.csv"
	var original := _make_csv(6)
	_write(path, original)
	var result := SafeCsv.write(path, _make_csv(6).replace("Text 1", "Changed"), 5)
	_check(bool(result.get("ok", false)), "校验通过时正常替换")
	_check(FileAccess.get_file_as_string(path).contains("Changed"), "内容已更新")
	_check(FileAccess.file_exists(path + ".bak"), "保留了原文件备份")
	_check(FileAccess.get_file_as_string(path + ".bak") == original, "备份内容与原文件一致")

func _test_empty_rejected() -> void:
	var path := _dir + "empty.csv"
	var original := _make_csv(5)
	_write(path, original)
	var result := SafeCsv.write(path, "", 3)
	_check(not bool(result.get("ok", true)), "空输出应被拒绝")
	_check(FileAccess.get_file_as_string(path) == original, "空输出时原文件不变")

func _test_bad_header() -> void:
	var path := _dir + "header.csv"
	var original := _make_csv(5)
	_write(path, original)
	var result := SafeCsv.write(path, "a,b,c\n1,2,3\n", 3)
	_check(not bool(result.get("ok", true)), "缺少必需列应被拒绝")
	_check(FileAccess.get_file_as_string(path) == original, "结构错误时原文件不变")

func _test_row_drop() -> void:
	var path := _dir + "drop.csv"
	var original := _make_csv(20)
	_write(path, original)
	var result := SafeCsv.write(path, _make_csv(5), 3)
	_check(not bool(result.get("ok", true)), "条目骤降应被拒绝")
	_check(FileAccess.get_file_as_string(path) == original, "条目骤降时原文件不变")
	if FileAccess.file_exists(path + ".tmp"):
		_check(false, "失败后不应残留临时文件")

func _test_duplicate_key() -> void:
	var path := _dir + "dup.csv"
	var original := _make_csv(4)
	_write(path, original)
	var bad := "keys,zh_CN,en\nk.1,甲,A\nk.1,乙,B\nk.2,丙,C\n"
	var result := SafeCsv.write(path, bad, 2)
	_check(not bool(result.get("ok", true)), "重复键应被拒绝")
	_check(FileAccess.get_file_as_string(path) == original, "重复键时原文件不变")

func _test_temp_failure() -> void:
	var path := _dir + "blocked.csv"
	var original := _make_csv(4)
	_write(path, original)
	# 用一个同名目录占住 .tmp 路径，模拟写入失败
	DirAccess.make_dir_absolute(path + ".tmp")
	var result := SafeCsv.write(path, _make_csv(4), 3)
	_check(not bool(result.get("ok", true)), "临时文件写入失败应中止")
	_check(FileAccess.get_file_as_string(path) == original, "写入失败时原文件不变")
	DirAccess.remove_absolute(path + ".tmp")

func _test_resource() -> void:
	var catalog := StateCatalog.new()
	catalog.definitions.append(StateDefinition.new())
	var path := _dir + "catalog.tres"
	var result := SafeFile.write_resource(catalog, path)
	_check(bool(result.get("ok", false)), "资源安全写入成功")
	var loaded := load(path)
	_check(loaded is StateCatalog, "写入后的资源能正确解析")
	var broken := SafeFile.write_resource(null, path)
	_check(not bool(broken.get("ok", true)), "空资源应被拒绝")

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

# ── 8. 文件头 UTF-8 截断（三个调用点共用行为） ────────────
## 构造第 240 字节恰好切进多字节中文字符的文件：截断点放在 event_id / 注记字符串值内，
## 使 3 字节“中”/“图”从第 238 字节开始（缓冲区只含首字节 + 1 个续字节）。
## 修复前调用点用 get_buffer(240).get_string_from_utf8()，尾部残缺序列会被引擎
## 替换成 U+FFFD（并打印 Unicode parsing error 诊断）；修复后应返回干净的合法前缀。

## 事件夹具：手写 .tres（探针已验证可正常 load 成 EventDefinition）。
func _build_utf8_event_fixture() -> bool:
	var part_a := "[gd_resource type=\"Resource\" script_class=\"EventDefinition\" load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://addons/rpgeventstudio/core/model/event_definition.gd\" id=\"1\"]\n\n[resource]\nscript = ExtResource(\"1\")\nevent_id = &\""
	var pad := 238 - part_a.to_utf8_buffer().size()
	if pad < 0:
		return false
	_utf8_expected_head = part_a + "x".repeat(pad)
	var content := part_a + "x".repeat(pad) + "中" + "\"\ndisplay_name = \"截断探针\"\npages = []\n"
	_utf8_cut_event = UTF8_EVENT_DIR + "cut_event.tres"
	DirAccess.make_dir_recursive_absolute(UTF8_EVENT_DIR)
	_write(_utf8_cut_event, content)
	return true

## 关卡图夹具：纯文本即可（EventReferences 只做文本解析，不加载资源）。
func _build_utf8_graph_fixture() -> bool:
	var g_head := "[gd_resource type=\"Resource\" script_class=\"LevelGraph\" format=3]\n\ng_header_note = \""
	var gpad := 238 - g_head.to_utf8_buffer().size()
	if gpad < 0:
		return false
	var gcontent := g_head + "y".repeat(gpad) + "图" + "\"\nevent_path = \"" + _utf8_cut_event + "\"\n"
	_utf8_cut_graph = UTF8_GRAPH_DIR + "cut_graph.tres"
	DirAccess.make_dir_recursive_absolute(UTF8_GRAPH_DIR)
	_write(_utf8_cut_graph, gcontent)
	return true

func _test_head_call_sites() -> void:
	_check(_build_utf8_event_fixture() and _build_utf8_graph_fixture(), "UTF-8 截断夹具模板字节布局有效")
	if _utf8_cut_event == "" or _utf8_cut_graph == "":
		return
	# 前置字节事实：两个夹具的第 240 字节都切进 3 字节中文字符（首字节 + 1 续字节已入缓冲）
	var ef := FileAccess.open(_utf8_cut_event, FileAccess.READ)
	var eb := ef.get_buffer(240)
	ef.close()
	_check(eb.size() == 240 and (int(eb[238]) & 0xF0) == 0xE0 and (int(eb[239]) & 0xC0) == 0x80,
		"前置：事件夹具第 240 字节切进 3 字节中文")
	var gf := FileAccess.open(_utf8_cut_graph, FileAccess.READ)
	var gb := gf.get_buffer(240)
	gf.close()
	_check(gb.size() == 240 and (int(gb[238]) & 0xF0) == 0xE0 and (int(gb[239]) & 0xC0) == 0x80,
		"前置：关卡图夹具第 240 字节切进 3 字节中文")

	# story_audit 的头部读取（修复前返回带 U+FFFD 的 240 字符污染串）
	var head := StoryAudit._head(_utf8_cut_event)
	_check(head == _utf8_expected_head, "头部读取应返回干净的合法 UTF-8 前缀（不含残缺尾巴）")
	_check(not head.contains("\uFFFD"), "头部不应含 U+FFFD 替换符乱码")
	_check(head.contains("EventDefinition"), "头部仍应能识别 EventDefinition")

	# 调用点公开行为：检测本身在修复前后都必须成立（回归保护）
	var refs := EventReferences.scan(UTF8_GRAPH_DIR, PackedStringArray())
	_check((refs["by_path"] as Dictionary).has(_utf8_cut_event),
		"EventReferences 应从头部被切断的关卡图文本检出 event_path 引用")
	var audit := StoryAudit.scan({"roots": PackedStringArray([UTF8_EVENT_DIR]), "excludes": PackedStringArray(), "unreferenced": false})
	_check(int((audit["stats"] as Dictionary)["events"]) == 1,
		"StoryAudit 应把头部被切断的事件资源统计为已扫描")
	var panel: Control = load("res://addons/rpgeventstudio/editor/event_list/event_list_panel.gd").new()
	panel.call("_collect", _utf8_cut_event)
	_check((panel.get("_events") as Array).size() == 1, "事件列表 _collect 应收录头部被切断的事件资源")
	panel.free()

# ── 9. SafeFile.read_head 单元行为 ────────────────────────

func _test_read_head() -> void:
	_check(SafeFile.read_head(_dir + "no_such_file.bin", 240) == "", "read_head 对读不到的文件返回空串")

	var ascii_path := _dir + "head_ascii.txt"
	_write(ascii_path, "a".repeat(300))
	_check(SafeFile.read_head(ascii_path, 240) == "a".repeat(240), "纯 ASCII 头部精确读取 240 字节")

	var short_path := _dir + "head_short.txt"
	_write(short_path, "abc")
	_check(SafeFile.read_head(short_path, 240) == "abc", "文件短于 max_bytes 时返回全文")

	var boundary_path := _dir + "head_boundary.txt"
	_write(boundary_path, "b".repeat(240) + "tail")
	_check(SafeFile.read_head(boundary_path, 240) == "b".repeat(240), "边界恰好落在 ASCII 上时不丢字节")

	# 3 字节中文从第 238 字节开始：缓冲含首字节 + 1 续字节，残缺尾巴整体丢弃
	var cut_head := SafeFile.read_head(_utf8_cut_event, 240)
	_check(cut_head == _utf8_expected_head, "切进中文时返回合法前缀（丢弃残缺序列）")
	_check(not cut_head.contains("\uFFFD"), "read_head 不产生 U+FFFD 乱码")

	var full_path := _dir + "head_full_cjk.txt"
	_write(full_path, "c".repeat(237) + "中" + "d".repeat(10))
	_check(SafeFile.read_head(full_path, 240) == "c".repeat(237) + "中", "完整落在界内的多字节字符应保留")

	var lead_path := _dir + "head_lead_only.txt"
	_write(lead_path, "e".repeat(239) + "中" + "f")
	_check(SafeFile.read_head(lead_path, 240) == "e".repeat(239), "只剩首字节时连同首字节一起丢弃")

	var emoji_path := _dir + "head_emoji.txt"
	_write(emoji_path, "g".repeat(238) + "🙂" + "h")
	_check(SafeFile.read_head(emoji_path, 240) == "g".repeat(238), "4 字节字符被切时丢弃残缺序列")

	var tail_path := _dir + "head_tail_cjk.txt"
	_write(tail_path, "ab中字")
	_check(SafeFile.read_head(tail_path, 240) == "ab中字", "文件结尾的完整中文字符不受影响")

func _cleanup() -> void:
	for name in ["normal.csv", "empty.csv", "header.csv", "drop.csv", "dup.csv", "blocked.csv", "catalog.tres"]:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = _dir + str(name) + str(suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	for utf8_path in [_utf8_cut_event, _utf8_cut_graph, _dir + "head_ascii.txt", _dir + "head_short.txt",
			_dir + "head_boundary.txt", _dir + "head_full_cjk.txt", _dir + "head_lead_only.txt",
			_dir + "head_emoji.txt", _dir + "head_tail_cjk.txt"]:
		if utf8_path != "" and FileAccess.file_exists(utf8_path):
			DirAccess.remove_absolute(utf8_path)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 安全写入故障注入：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
