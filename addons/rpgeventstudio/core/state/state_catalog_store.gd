@tool
class_name StateCatalogStore
extends RefCounted
## 状态总表的读写入口。编辑器与游戏共用同一份「默认总表」，测试可以显式指定路径。

const DEFAULT_PATH := "res://state/state_catalog.tres"

static var _catalog: StateCatalog = null

static func get_path() -> String:
	return DEFAULT_PATH

static func catalog() -> StateCatalog:
	if _catalog == null:
		_catalog = read(DEFAULT_PATH)
	return _catalog

## 读取指定路径的总表；不存在则返回空表（不落盘）。
static func read(path: String) -> StateCatalog:
	if path != "" and ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is StateCatalog:
			return loaded
	return StateCatalog.new()

## 写回指定路径。
static func write(target: StateCatalog, path: String) -> int:
	if target == null or path == "":
		return ERR_INVALID_PARAMETER
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var result := SafeFile.write_resource(target, path)
	return OK if bool(result.get("ok", false)) else FAILED

## 编辑器里用：确保默认总表文件存在。
static func ensure_file() -> StateCatalog:
	var current := catalog()
	if ResourceLoader.exists(DEFAULT_PATH):
		return current
	var error := write(current, DEFAULT_PATH)
	if error != OK:
		push_warning("[RPGEventStudio] 状态总表保存失败：%d" % error)
	return current

static func save() -> int:
	return write(catalog(), DEFAULT_PATH)

static func display(key: String) -> String:
	if key == "":
		return ""
	return catalog().display_name(key)

static func is_known(key: String) -> bool:
	return catalog().find(key) != null

static func type_of(key: String) -> String:
	return catalog().type_of(key)

static func reset_cache() -> void:
	_catalog = null
