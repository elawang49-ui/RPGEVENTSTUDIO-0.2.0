@tool
class_name StoryAudit
extends RefCounted
## 全工程剧情资源审计：把「事件 / 关卡图 / 引用 / 状态」的问题汇总成一份可定位的报告。
##
## 只读扫描，不修改任何资源；不引入新的序列化字段。
## 复用已有能力：
##   - EventReferences：场景/图里真实写下的 event_path / graph_path / ExtResource 引用
##   - GraphValidator：关卡图静态校验
##   - StateCatalog：状态注册表
##
## 每条问题都是 Dictionary：
##   code / severity / category / path / node / node_name / message_key / params / hint_key / message
## message_key 为空时，message 已经是本地化文本（来自 GraphValidator）。

const SEVERITY_INFO := 0
const SEVERITY_WARNING := 1
const SEVERITY_ERROR := 2

const DEFAULT_ROOTS: PackedStringArray = ["res://"]
const DEFAULT_EXCLUDES: PackedStringArray = ["res://.godot", "res://tests", "res://tools"]

const STATE_COMMANDS := ["set_switch", "set_variable", "variable_op", "if"]

# ── 入口 ─────────────────────────────────────────────────

## options:
##   roots: PackedStringArray          扫描目录（默认 res://）
##   excludes: PackedStringArray       跳过目录
##   catalog: StateCatalog             状态表（默认 StateCatalogStore.catalog()）
##   unreferenced: bool                是否报告未引用资源（默认 true）
##   states: bool                      是否检查未登记状态（默认 true）
##   graph_info: bool                  是否把关卡图 INFO 也列出来（默认 false）
static func scan(options: Dictionary = {}) -> Dictionary:
	var roots: PackedStringArray = options.get("roots", DEFAULT_ROOTS)
	var excludes: PackedStringArray = options.get("excludes", DEFAULT_EXCLUDES)
	var catalog: StateCatalog = options.get("catalog", StateCatalogStore.catalog())
	var check_unreferenced := bool(options.get("unreferenced", true))
	var check_states := bool(options.get("states", true))
	var include_graph_info := bool(options.get("graph_info", false))

	var issues: Array = []
	var seen := {}
	var references := {}
	var scanned_files := 0
	var events: Array = []   ## [{path, resource}]
	var graphs: Array = []

	for path in _collect_files(roots, excludes):
		if path.get_extension() != "tres":
			continue
		var head := _head(path)
		if not (head.contains("EventDefinition") or head.contains("LevelGraph")):
			continue
		scanned_files += 1
		var resource := ResourceLoader.load(path)
		if resource is EventDefinition:
			events.append({"path": path, "resource": resource})
		elif resource is LevelGraph:
			graphs.append({"path": path, "resource": resource})

	# 引用：场景 + 关卡图文本（不实例化场景）
	var scanned_refs := 0
	for root in roots:
		var one := EventReferences.scan(root, excludes)
		scanned_refs += int(one.get("scanned", 0))
		for target in (one.get("by_path", {}) as Dictionary):
			for ref in (one["by_path"][target] as Array):
				_add_reference(references, str(target), ref)

	# 重复标识先判定：需要看到全部资源
	var duplicate_events := find_duplicate_ids(events, "event_id")
	for id in duplicate_events:
		var paths: Array = duplicate_events[id]
		for path in paths:
			var others := PackedStringArray()
			for other in paths:
				if str(other) != str(path):
					others.append(str(other))
			_push(issues, seen, "event.duplicate_id", SEVERITY_ERROR, "event", str(path),
				"audit.event.duplicate_id", {"id": str(id), "others": ", ".join(others)},
				"audit.event.duplicate_id.hint")
	var duplicate_graphs := find_duplicate_ids(graphs, "graph_id")
	for id in duplicate_graphs:
		var paths: Array = duplicate_graphs[id]
		for path in paths:
			var others := PackedStringArray()
			for other in paths:
				if str(other) != str(path):
					others.append(str(other))
			_push(issues, seen, "graph.duplicate_id", SEVERITY_ERROR, "graph", str(path),
				"audit.graph.duplicate_id", {"id": str(id), "others": ", ".join(others)},
				"audit.graph.duplicate_id.hint")

	# 事件 → 公共事件引用（EventReferences 只解析场景/图，这里补上事件之间）
	var event_refs := {}

	for entry in events:
		_audit_event(entry, catalog, check_states, references, event_refs, issues, seen)

	for entry in graphs:
		_audit_graph(entry, references, include_graph_info, issues, seen)

	_audit_references(references, issues, seen)

	if check_unreferenced:
		for entry in events:
			var path := str(entry["path"])
			if path != "" and not references.has(path) and not event_refs.has(path):
				_push(issues, seen, "event.unreferenced", SEVERITY_INFO, "event", path,
					"audit.event.unreferenced", {}, "audit.event.unreferenced.hint")
		for entry in graphs:
			var path := str(entry["path"])
			if path != "" and not references.has(path):
				_push(issues, seen, "graph.unreferenced", SEVERITY_INFO, "graph", path,
					"audit.graph.unreferenced", {}, "audit.graph.unreferenced.hint")

	_sort_issues(issues)
	var by_severity := {SEVERITY_INFO: 0, SEVERITY_WARNING: 0, SEVERITY_ERROR: 0}
	for issue in issues:
		var severity := int(issue.get("severity", SEVERITY_INFO))
		by_severity[severity] = int(by_severity.get(severity, 0)) + 1
	return {
		"issues": issues,
		"references": references,
		"stats": {
			"files": scanned_files,
			"events": events.size(),
			"graphs": graphs.size(),
			"refs": references.size(),
			"scanned_refs": scanned_refs,
		},
		"by_severity": by_severity,
	}

static func count_of(issues: Array, severity: int) -> int:
	var count := 0
	for issue in issues:
		if int(issue.get("severity", SEVERITY_INFO)) == severity:
			count += 1
	return count

static func has_errors(issues: Array) -> bool:
	return count_of(issues, SEVERITY_ERROR) > 0

# ── 事件 ─────────────────────────────────────────────────

static func _audit_event(entry: Dictionary, catalog: StateCatalog, check_states: bool,
		references: Dictionary, event_refs: Dictionary, issues: Array, seen: Dictionary) -> void:
	var path := str(entry["path"])
	var event: EventDefinition = entry["resource"]
	var display := str(event.display_name).strip_edges()
	if display == "":
		_push(issues, seen, "event.no_name", SEVERITY_INFO, "event", path,
			"audit.event.no_name", {}, "audit.event.no_name.hint")

	if event.pages.is_empty():
		_push(issues, seen, "event.empty", SEVERITY_ERROR, "event", path,
			"audit.event.empty", {}, "audit.event.empty.hint")
		return

	var all_empty := true
	var state_seen := {}
	for page in event.pages:
		if page == null:
			all_empty = false
			continue
		if not page.commands.is_empty():
			all_empty = false
		_walk_commands(page.commands, path, catalog, check_states, state_seen, event_refs, issues, seen)
	if all_empty:
		_push(issues, seen, "event.no_commands", SEVERITY_WARNING, "event", path,
			"audit.event.no_commands", {}, "audit.event.no_commands.hint")

static func _walk_commands(commands: Array, path: String, catalog: StateCatalog, check_states: bool,
		state_seen: Dictionary, event_refs: Dictionary, issues: Array, seen: Dictionary) -> void:
	for command in commands:
		var cmd: EventCommand = command
		if cmd == null:
			continue
		var type := String(cmd.type)
		if STATE_COMMANDS.has(type):
			var raw_key := str(cmd.params.get("key", "")).strip_edges()
			# @@self / @@level 是运行时展开的局部键，静态无法确定具体前缀，不在这里误报。
			if check_states and raw_key != "" and not raw_key.begins_with("@@"):
				var key := StateStore.resolve_key(raw_key, "")
				if not state_seen.has(key):
					state_seen[key] = true
					if catalog == null or catalog.find(key) == null:
						_push(issues, seen, "state.unregistered", SEVERITY_WARNING, "state", path,
							"audit.state.unregistered", {"key": key}, "audit.state.unregistered.hint")
		elif type == "call_common":
			var target := str(cmd.params.get("common_path", "")).strip_edges()
			if target != "":
				event_refs[target] = true
				if not FileAccess.file_exists(target):
					_push(issues, seen, "common.missing", SEVERITY_ERROR, "event", path,
						"audit.common.missing", {"path": target}, "audit.common.missing.hint")
		elif type == "play_sfx":
			var sound := str(cmd.params.get("sound_path", "")).strip_edges()
			if sound != "" and not FileAccess.file_exists(sound):
				_push(issues, seen, "sfx.missing", SEVERITY_WARNING, "event", path,
					"audit.sfx.missing", {"path": sound}, "audit.sfx.missing.hint")
		_walk_commands(cmd.children, path, catalog, check_states, state_seen, event_refs, issues, seen)
		_walk_commands(cmd.else_children, path, catalog, check_states, state_seen, event_refs, issues, seen)

# ── 关卡图 ───────────────────────────────────────────────

static func _audit_graph(entry: Dictionary, references: Dictionary, include_info: bool,
		issues: Array, seen: Dictionary) -> void:
	var path := str(entry["path"])
	var graph: LevelGraph = entry["resource"]
	var prefix := _prefix_for(graph)
	for raw in GraphValidator.validate(graph, prefix):
		var issue: GraphIssue = raw
		if issue == null:
			continue
		if int(issue.severity) == SEVERITY_INFO and not include_info:
			continue
		_push(issues, seen, "graph." + issue.code, int(issue.severity), "graph", path,
			"", {}, "", String(issue.node_id), issue.node_name, issue.message, issue.suggestion)

static func _prefix_for(graph: LevelGraph) -> String:
	var level := str(graph.level_id).strip_edges()
	return level.capitalize() if level != "" else "School"

# ── 引用 / 重复 ──────────────────────────────────────────

static func _audit_references(references: Dictionary, issues: Array, seen: Dictionary) -> void:
	for target in references:
		var target_path := str(target)
		if not FileAccess.file_exists(target_path):
			for ref in (references[target] as Array):
				_push(issues, seen, "ref.broken", SEVERITY_ERROR, "reference", str(ref["source"]),
					"audit.ref.broken", {"target": target_path}, "audit.ref.broken.hint",
					str(ref.get("node", "")))
			continue
		var head := _head(target_path)
		if not (head.contains("EventDefinition") or head.contains("LevelGraph")):
			for ref in (references[target] as Array):
				_push(issues, seen, "ref.not_event", SEVERITY_WARNING, "reference", str(ref["source"]),
					"audit.ref.not_event", {"target": target_path}, "audit.ref.not_event.hint",
					str(ref.get("node", "")))

static func _add_reference(references: Dictionary, target: String, ref: Dictionary) -> void:
	if not references.has(target):
		references[target] = []
	for existing in references[target]:
		if str(existing["source"]) == str(ref["source"]) and str(existing["node"]) == str(ref["node"]) \
				and str(existing["kind"]) == str(ref["kind"]):
			return
	references[target].append(ref)

## 重复 ID 在收集完成后统一判定（需要看到全部资源）。
static func find_duplicate_ids(entries: Array, field: String) -> Dictionary:
	var by_id := {}
	for entry in entries:
		var resource = entry["resource"]
		var id := str(resource.get(field))
		if id == "":
			continue
		if not by_id.has(id):
			by_id[id] = []
		by_id[id].append(str(entry["path"]))
	var duplicates := {}
	for id in by_id:
		if (by_id[id] as Array).size() > 1:
			duplicates[id] = by_id[id]
	return duplicates

# ── 工具 ─────────────────────────────────────────────────

static func _collect_files(roots: PackedStringArray, excludes: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for root in roots:
		_walk(root, out, excludes)
	out.sort()
	return out

static func _walk(dir_path: String, out: PackedStringArray, excludes: PackedStringArray) -> void:
	if _excluded(dir_path, excludes):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_walk(path, out, excludes)
		elif not entry.begins_with(".") and path.ends_with(".tres") and not _excluded(path, excludes):
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

static func _excluded(path: String, excludes: PackedStringArray) -> bool:
	for exclude in excludes:
		var prefix := String(exclude)
		if path == prefix or path.begins_with(prefix + "/"):
			return true
	return false

static func _head(path: String) -> String:
	# 走 SafeFile.read_head：第 240 字节切进多字节字符时仍返回干净的合法 UTF-8 前缀
	return SafeFile.read_head(path, 240)

static func _push(issues: Array, seen: Dictionary, code: String, severity: int, category: String,
		path: String, message_key: String, params: Dictionary, hint_key: String,
		node: String = "", node_name: String = "", message: String = "", hint: String = "") -> void:
	var dedupe := "%s|%s|%s|%s" % [code, path, node, str(params.get("target", params.get("key", "")))]
	if seen.has(dedupe):
		return
	seen[dedupe] = true
	issues.append({
		"code": code,
		"severity": severity,
		"category": category,
		"path": path,
		"node": node,
		"node_name": node_name,
		"message_key": message_key,
		"params": params,
		"hint_key": hint_key,
		"message": message,
		"hint": hint,
	})

static func _sort_issues(issues: Array) -> void:
	issues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("severity", SEVERITY_INFO))
		var sb := int(b.get("severity", SEVERITY_INFO))
		if sa != sb:
			return sa > sb
		var pa := str(a.get("path", ""))
		var pb := str(b.get("path", ""))
		if pa != pb:
			return pa < pb
		var ca := str(a.get("code", ""))
		var cb := str(b.get("code", ""))
		if ca != cb:
			return ca < cb
		return str(a.get("node", "")) < str(b.get("node", "")))
