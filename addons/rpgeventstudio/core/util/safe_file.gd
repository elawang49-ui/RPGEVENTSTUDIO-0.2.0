@tool
class_name SafeFile
extends RefCounted
## 安全写入：临时文件 → 读回校验 → 备份 → 原子替换 → 再校验；任何一步失败都不碰原文件。

static func write_text(path: String, content: String, validator: Callable = Callable(), options: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "error": "", "backup": ""}
	if content.is_empty() and not bool(options.get("allow_empty", false)):
		result["error"] = "empty_content"
		return result
	var min_size := int(options.get("min_size", -1))
	if min_size >= 0 and content.length() < min_size:
		result["error"] = "too_small"
		return result

	var original := ""
	if FileAccess.file_exists(path):
		original = FileAccess.get_file_as_string(path)
		if original.is_empty() and not bool(options.get("allow_empty_original", false)):
			result["error"] = "original_empty_refused"
			return result

	var temp_path := path + ".tmp"
	if not _write_raw(temp_path, content):
		result["error"] = "temp_write_failed"
		return result
	if FileAccess.get_file_as_string(temp_path) != content:
		_remove(temp_path)
		result["error"] = "temp_readback_mismatch"
		return result
	if validator.is_valid():
		var check: Variant = validator.call(temp_path)
		var ok := false
		if check is Dictionary:
			ok = bool(check.get("ok", false))
			if not ok:
				result["error"] = str(check.get("error", "validation_failed"))
		elif check is bool:
			ok = check
		if not ok:
			if str(result["error"]) == "":
				result["error"] = "validation_failed"
			_remove(temp_path)
			return result

	var backup := ""
	if original != "":
		backup = path + ".bak"
		if not _write_raw(backup, original):
			_remove(temp_path)
			result["error"] = "backup_failed"
			return result

	if not _rename(temp_path, path):
		_remove(temp_path)
		result["error"] = "rename_failed"
		return result

	# 替换后再读一次；不匹配就从备份恢复
	if FileAccess.get_file_as_string(path) != content:
		if backup != "" and _rename(backup, path):
			result["error"] = "post_verify_failed_restored"
		else:
			result["error"] = "post_verify_failed"
		return result

	result["ok"] = true
	result["backup"] = backup
	return result

static func write_resource(resource: Resource, path: String, expected_script: Script = null) -> Dictionary:
	var result := {"ok": false, "error": ""}
	if resource == null:
		result["error"] = "null_resource"
		return result
	var extension := path.get_extension()
	var temp_path := path.get_basename() + ".tmp." + extension
	# 临时路径被同名目录占住时直接判失败：既避免覆盖写坏目录，也避免 ResourceSaver 抛出难读的引擎错误。
	if DirAccess.dir_exists_absolute(temp_path):
		result["error"] = "save_failed:temp_path_blocked"
		return result
	var error := ResourceSaver.save(resource, temp_path)
	if error != OK:
		result["error"] = "save_failed:%d" % error
		return result
	var script := expected_script if expected_script != null else resource.get_script()
	var loaded := ResourceLoader.load(temp_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or (script != null and loaded.get_script() != script):
		_remove(temp_path)
		result["error"] = "verify_failed"
		return result

	var original := ""
	if FileAccess.file_exists(path):
		original = FileAccess.get_file_as_string(path)
		if original.is_empty():
			_remove(temp_path)
			result["error"] = "original_empty_refused"
			return result
		if not _write_raw(path + ".bak", original):
			_remove(temp_path)
			result["error"] = "backup_failed"
			return result
	if not _rename(temp_path, path):
		_remove(temp_path)
		result["error"] = "rename_failed"
		return result
	resource.take_over_path(path)
	result["ok"] = true
	return result

static func _write_raw(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.close()
	return true

static func _rename(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(from_path, to_path) == OK

static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
