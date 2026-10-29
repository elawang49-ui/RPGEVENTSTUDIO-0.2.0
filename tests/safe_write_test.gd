extends SceneTree
## 故障注入：验证异常情况下原始文件不被破坏。
##   godot --headless --path . --script res://tests/safe_write_test.gd

var _checks := 0
var _failures: PackedStringArray = []
var _dir := "res://.godot/safe_test/"

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

func _cleanup() -> void:
	for name in ["normal.csv", "empty.csv", "header.csv", "drop.csv", "dup.csv", "blocked.csv", "catalog.tres"]:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = _dir + str(name) + str(suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)

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
