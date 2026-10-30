@tool
class_name EventReferences
extends RefCounted
## 扫描场景/关卡图里对事件资源的真实引用。
## 只认 Godot 文件里确实写下的 event_path / event = ExtResource(...) / graph_path，
## 不做「全文搜索事件名」这种不可靠的猜测。
##
## 已知限制：
## - 只解析当前工程里的 .tscn / .tres 文本，不解析实例化场景内部（那里的事件写在子场景文件里，
##   本扫描会把子场景单独算一份，所以不会漏，但不会展开成实例路径）；
## - 脚本里动态 load() 的事件无法静态得知，会显示为「未引用」。

## root 允许限定扫描范围（审计器按目录扫描/测试夹具），默认整个工程。
## excludes 与 StoryAudit 的排除目录一致，避免把 tests/tools 里的夹具算进引用。
static func scan(root: String = "res://", excludes: PackedStringArray = []) -> Dictionary:
	var result := {"by_path": {}, "scanned": 0}
	_scan_dir(root if root.strip_edges() != "" else "res://", result, excludes)
	return result

static func _scan_dir(dir_path: String, result: Dictionary, excludes: PackedStringArray = []) -> void:
	if _excluded(dir_path, excludes):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(path, result, excludes)
		elif entry.ends_with(".tscn"):
			_parse_scene(path, result)
		elif entry.ends_with(".tres"):
			_parse_graph(path, result)
		entry = dir.get_next()
	dir.list_dir_end()

static func _excluded(path: String, excludes: PackedStringArray) -> bool:
	for exclude in excludes:
		var prefix := String(exclude)
		if path == prefix or path.begins_with(prefix + "/"):
			return true
	return false

static func _parse_scene(path: String, result: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	result["scanned"] = int(result["scanned"]) + 1

	var ext_paths := {}
	var current_node := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("[ext_resource"):
			var res_path := _attr(line, "path")
			var id := _attr(line, "id")
			if res_path != "" and id != "":
				ext_paths[id] = res_path
		elif line.begins_with("[node"):
			current_node = _node_path(_attr(line, "parent"), _attr(line, "name"))
		elif line.begins_with("event_path ="):
			_add(result, _quoted(line), "scene", path, current_node)
		elif line.begins_with("graph_path ="):
			_add(result, _quoted(line), "scene", path, current_node)
		elif line.begins_with("event =") and line.contains("ExtResource"):
			_add(result, _ext_id_path(line, ext_paths), "scene", path, current_node)
		elif line.begins_with("graph =") and line.contains("ExtResource"):
			_add(result, _ext_id_path(line, ext_paths), "scene", path, current_node)
	file.close()

static func _parse_graph(path: String, result: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var head := file.get_buffer(240).get_string_from_utf8()
	file.seek(0)
	if not head.contains("LevelGraph"):
		file.close()
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("event_path ="):
			_add(result, _quoted(line), "graph", path, "")
		elif line.contains("\"event_path\":") and line.contains("res://"):
			_add(result, _dict_quoted(line, "event_path"), "graph", path, "")
	file.close()

static func _add(result: Dictionary, target: String, kind: String, source: String, node_path: String) -> void:
	if target == "":
		return
	var by_path: Dictionary = result["by_path"]
	if not by_path.has(target):
		by_path[target] = []
	# 同一节点上 event 与 event_path 都写了同一个资源时只记一次
	for existing in by_path[target]:
		if existing["kind"] == kind and existing["source"] == source and existing["node"] == node_path:
			return
	by_path[target].append({"kind": kind, "source": source, "node": node_path})

static func _attr(line: String, key: String) -> String:
	var token := key + "=\""
	var index := line.find(token)
	if index < 0:
		return ""
	var start := index + token.length()
	var end := line.find("\"", start)
	if end < 0:
		return ""
	return line.substr(start, end - start)

static func _quoted(line: String) -> String:
	var start := line.find("\"")
	if start < 0:
		return ""
	var end := line.find("\"", start + 1)
	if end < 0:
		return ""
	return line.substr(start + 1, end - start - 1)

static func _dict_quoted(line: String, key: String) -> String:
	var token := "\"" + key + "\":"
	var index := line.find(token)
	if index < 0:
		return ""
	var start := line.find("\"", index + token.length())
	if start < 0:
		return ""
	var end := line.find("\"", start + 1)
	if end < 0:
		return ""
	return line.substr(start + 1, end - start - 1)

static func _ext_id_path(line: String, ext_paths: Dictionary) -> String:
	var start := line.find("ExtResource(\"")
	if start < 0:
		return ""
	start += "ExtResource(\"".length()
	var end := line.find("\"", start)
	if end < 0:
		return ""
	var id := line.substr(start, end - start)
	return str(ext_paths.get(id, ""))

static func _node_path(parent: String, name: String) -> String:
	if name == "":
		return parent
	if parent == "" or parent == ".":
		return name
	return parent + "/" + name
