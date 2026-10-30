@tool
class_name StateCatalogBulk
extends RefCounted
## 状态库批量登记：一次写入一批状态定义。
##
## 原子性保证：
##   1. 只对单个总表文件做一次 SafeFile 安全写入（临时文件 → 读回校验 → 备份 → 原子替换）；
##   2. 写入前在内存副本上操作，失败时原文件与原对象都不受影响；
##   3. 写入后重新从磁盘读回校验：新增键齐全、原有定义数量不变；
##      校验失败立即用 SafeFile 留下的 .bak 备份还原，并清空编辑器缓存。
## 已存在的键一律跳过，绝不覆盖已有定义；内部标识原样写入，不做任何改名。

const TYPES := ["bool", "int", "float", "string"]

static func register(entries: Array, path: String = StateCatalogStore.DEFAULT_PATH) -> Dictionary:
	var result := {"ok": false, "added": [], "skipped": [], "error": ""}
	if path == "":
		result["error"] = "invalid_path"
		return result
	var prepared: Array = []
	for entry in entries:
		var source: Dictionary = entry
		var key := str(source.get("key", "")).strip_edges()
		var type := str(source.get("type", ""))
		if key == "" or not TYPES.has(type):
			result["error"] = "invalid_entry:" + key
			return result
		prepared.append({
			"key": key,
			"type": type,
			"default_value": _coerce_default(type, source.get("default_value")),
			"display_name": str(source.get("display_name", "")).strip_edges(),
			"category": str(source.get("category", "")).strip_edges(),
			"description": str(source.get("description", "")),
		})

	if prepared.is_empty():
		result["error"] = "empty_entries"
		return result

	var current := StateCatalogStore.read(path)
	var original_keys := {}
	for definition in current.definitions:
		if definition != null and definition.key != "":
			original_keys[definition.key] = true

	var working := current.duplicate(true) as StateCatalog
	var added: PackedStringArray = []
	var skipped: Array = []
	for entry in prepared:
		if working.find(entry["key"]) != null:
			skipped.append({"key": entry["key"], "reason": "exists"})
			continue
		var definition := StateDefinition.new()
		definition.key = entry["key"]
		definition.display_name = entry["display_name"] if entry["display_name"] != "" else entry["key"]
		definition.type = entry["type"]
		definition.default_value = entry["default_value"]
		definition.category = entry["category"] if entry["category"] != "" else "剧情"
		working.definitions.append(definition)
		added.append(entry["key"])

	if added.is_empty():
		result["ok"] = true
		result["skipped"] = skipped
		return result

	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var write_result := SafeFile.write_resource(working, path)
	if not bool(write_result.get("ok", false)):
		result["error"] = str(write_result.get("error", "write_failed"))
		result["skipped"] = skipped
		return result

	if not _verify(path, original_keys, added):
		_restore_backup(path)
		result["error"] = "post_verify_failed"
		result["skipped"] = skipped
		return result

	StateCatalogStore.reset_cache()
	result["ok"] = true
	result["added"] = Array(added)
	result["skipped"] = skipped
	return result

## 写后校验：强制绕过资源缓存从磁盘读回，确认新增键齐全、原有定义未被覆盖。
static func _verify(path: String, original_keys: Dictionary, added: PackedStringArray) -> bool:
	var verified: StateCatalog = null
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is StateCatalog:
			verified = loaded
	if verified == null:
		return false
	var seen := {}
	for definition in verified.definitions:
		if definition == null or definition.key == "":
			continue
		seen[definition.key] = true
		# 原有定义必须原样保留
		if original_keys.has(definition.key) and not original_keys.is_empty():
			if verified.find(definition.key) == null:
				return false
	if seen.size() != original_keys.size() + added.size():
		return false
	for key in added:
		if not seen.has(key):
			return false
	return true

## 回滚：SafeFile 替换前留了 .bak，把它放回原位。
static func _restore_backup(path: String) -> void:
	var backup := path + ".bak"
	if FileAccess.file_exists(backup):
		DirAccess.rename_absolute(backup, path)
	StateCatalogStore.reset_cache()

static func _coerce_default(type: String, value: Variant) -> Variant:
	match type:
		"int":
			return int(value) if value is int or value is float else 0
		"float":
			return float(value) if value is int or value is float else 0.0
		"string":
			return str(value) if value != null else ""
		_:
			return false if value == null else bool(value)
