@tool
class_name StateUsageScanner
extends RefCounted
## 全工程状态引用扫描器：为「状态库批量登记」找出还没登记的状态。
##
## 扫描来源：
##   1. 事件/公共事件/关卡图资源（.tres）：按数据模型逐字段读取，字段本身就是状态语义，
##      属于「确定的引用」。
##   2. 场景（.tscn）：通过 PackedScene.get_state() 读取节点属性（不实例化场景、不运行
##      任何 @tool 脚本），提取其中内嵌或外链的事件/图资源；外链资源全局去重后仍以
##      资源文件本身为引用位置。
##   3. GDScript：只认「状态语义的方法调用 + 字面量参数」——set_state/get_state/
##      set_value/get_value/get_bool/get_int/get_float/compare/add/define，并且键要满足
##      Scope.Sub.Name（两段以上）或 @@level.X 的形态；其余字符串一律不当作状态。
##
## 动态引用（"Global." + name、"Global.%s" % id、以变量为参数的调用）无法静态确认，
## 单独放进 dynamic_refs 报告，绝不混进候选列表假装已识别。

const KIND_EVENT_CONDITION := "event.condition"
const KIND_CMD_PREFIX := "cmd."
const KIND_CMD_CUSTOM := "cmd.custom"
const KIND_GRAPH_CONDITION := "graph.condition"
const KIND_GRAPH_ACTION := "graph.action"
const KIND_GRAPH_END := "graph.end"
const KIND_SCRIPT := "script"
const KIND_SCRIPT_CONST := "script.const"

## 事件/图模型里可能持有状态键的指令参数之外的兜底参数名（未注册指令类型用）。
const FALLBACK_STATE_PARAM := "key"

## 默认跳过：编辑器缓存、插件框架自身（框架代码里状态参数都是变量，只会产生噪音）。
const DEFAULT_EXCLUDES: PackedStringArray = [
	"res://.godot",
	"res://addons/rpgeventstudio/core",
	"res://addons/rpgeventstudio/runtime",
]

const SCRIPT_METHODS: PackedStringArray = [
	"set_state", "get_state", "set_value", "get_value",
	"get_bool", "get_int", "get_float", "compare", "add", "define",
]

static var _regex_cache: Dictionary = {}

# ── 入口 ─────────────────────────────────────────────────

## roots：要扫描的目录（res:// 路径）。catalog：当前状态总表，里面的键会被排除。
## 返回：
##   candidates   Array[Dictionary] 未登记候选，见 _record / _finalize
##   dynamic_refs Array[Dictionary] 动态/无法静态确认的引用
##   errors       Array[Dictionary] 加载失败的文件
##   stats        Dictionary 扫描统计
static func scan(roots: PackedStringArray, catalog: StateCatalog, options: Dictionary = {}) -> Dictionary:
	var excludes: PackedStringArray = options.get("excludes", DEFAULT_EXCLUDES)
	var registered := {}
	if catalog != null:
		for key in catalog.keys():
			registered[key] = true
	var result := {
		"candidates": {},
		"dynamic_refs": [],
		"errors": [],
		"stats": {"gd": 0, "tres": 0, "tscn": 0, "skipped_catalog": 0},
		"dynamic_keys": {},
		"seen_resources": {},
		"pending_resources": {},
	}
	var scanned: PackedStringArray = []
	for path in _collect_files(roots, excludes):
		scanned.append(path)
		match path.get_extension():
			"gd":
				result["stats"]["gd"] += 1
				_scan_script(path, result)
			"tres":
				result["stats"]["tres"] += 1
				_scan_resource_file(path, result)
			"tscn":
				result["stats"]["tscn"] += 1
				_scan_scene_file(path, result)
	# 场景/资源里外链的模型资源：路径在扫描范围之外时补扫一次，保证引用不漏
	for ext_path in result["pending_resources"].keys():
		if not result["seen_resources"].has(ext_path):
			_scan_resource_file(String(ext_path), result)
	result.erase("seen_resources")
	result.erase("pending_resources")
	var candidates: Array = []
	for key in result["candidates"].keys():
		var candidate: Dictionary = result["candidates"][key]
		if registered.has(key):
			continue
		_finalize_candidate(candidate)
		candidates.append(candidate)
	candidates.sort_custom(func(a, b) -> bool: return String(a["key"]) < String(b["key"]))
	result["candidates"] = candidates
	return result

# ── 键形态判断 ───────────────────────────────────────────

## 严格键形态（脚本字面量用）：Scope.Sub.Name 至少两段，或 @@level.X。
## 单段（如 "hp"）在脚本里和普通字符串无法区分，不算确认引用。
static func is_strict_key(text: String) -> bool:
	var key := text.strip_edges()
	if key == "":
		return false
	if key.begins_with("@@level."):
		return _is_identifier(key.substr(8))
	var parts := key.split(".")
	if parts.size() < 2:
		return false
	for part in parts:
		if not _is_identifier(part):
			return false
	return true

static func _is_identifier(text: String) -> bool:
	if text.is_empty():
		return false
	for i in text.length():
		var code := text.unicode_at(i)
		var ok := (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
				or (code >= 48 and code <= 57) or code == 95
		if not ok:
			return false
		if i == 0 and code >= 48 and code <= 57:
			return false
	return true

# ── 类型推断 ─────────────────────────────────────────────

## 从一个「值」推断状态类型；推断不出返回空串。
static func suggest_from_value(value: Variant) -> String:
	if value is bool:
		return "bool"
	if value is int:
		return "int"
	if value is float:
		return "float"
	if value is String:
		return _classify_literal_text(value)
	return ""

static func _classify_literal_text(text: String) -> String:
	var parsed: Variant = ValueParser.parse(text)
	if parsed is bool:
		return "bool"
	if parsed is int:
		return "int"
	if parsed is float:
		return "float"
	if parsed is String and str(parsed).strip_edges() != "":
		return "string"
	return ""

## 多处使用合并出一个类型：一致 → 该类型；纯 int/float 混用 → float；
## 跨类型家族（bool/int/string 混用）→ 冲突，保留出现最多的一种仅作展示。
static func _finalize_candidate(candidate: Dictionary) -> void:
	var suggestions: Array = candidate["suggestions"]
	var nonstandard := not is_strict_key(String(candidate["key"]))
	candidate["nonstandard"] = nonstandard
	# 对外暴露稳定的「使用类型」列表（去重后排序）；kind_set 仅内部计数。
	var kinds: Array = (candidate["kind_set"] as Dictionary).keys()
	kinds.sort()
	candidate["kinds"] = kinds
	if suggestions.is_empty():
		candidate["inferred_type"] = ""
		return
	var votes := {}
	for suggestion in suggestions:
		votes[suggestion] = int(votes.get(suggestion, 0)) + 1
	if votes.size() == 1:
		candidate["inferred_type"] = String(suggestions[0])
		candidate["type_votes"] = votes
		return
	if votes.size() == 2 and votes.has("int") and votes.has("float"):
		candidate["inferred_type"] = "float"
		candidate["type_votes"] = votes
		return
	candidate["type_conflict"] = true
	var best := ""
	var best_count := -1
	for type in votes.keys():
		if int(votes[type]) > best_count:
			best = String(type)
			best_count = int(votes[type])
	candidate["inferred_type"] = best
	candidate["type_votes"] = votes

# ── 记录 ─────────────────────────────────────────────────

static func _record(result: Dictionary, key: String, file: String, line: int, kind: String, detail: String, suggestion: String) -> void:
	var clean := key.strip_edges()
	if clean == "" or clean.contains("\n") or clean.contains("\t"):
		return
	var candidates: Dictionary = result["candidates"]
	var candidate: Dictionary = candidates.get(clean, {})
	if candidate.is_empty():
		candidate = {
			"key": clean,
			"uses": 0,
			"locations": [],
			"kind_set": {},
			"suggestions": [],
			"inferred_type": "",
			"type_conflict": false,
			"nonstandard": false,
			"scoped": clean.begins_with("@@"),
		}
		candidates[clean] = candidate
	candidate["uses"] = int(candidate["uses"]) + 1
	(candidate["locations"] as Array).append({"file": file, "line": line, "kind": kind, "detail": detail})
	(candidate["kind_set"] as Dictionary)[kind] = true
	if suggestion != "":
		(candidate["suggestions"] as Array).append(suggestion)

static func _report_dynamic(result: Dictionary, file: String, line: int, snippet: String, reason: String) -> void:
	var dedup: Dictionary = result["dynamic_keys"]
	var marker := "%s:%d" % [file, line]
	if dedup.has(marker):
		return
	dedup[marker] = true
	var text := snippet.strip_edges()
	if text.length() > 120:
		text = text.substr(0, 120) + "…"
	(result["dynamic_refs"] as Array).append({"file": file, "line": line, "snippet": text, "reason": reason})

# ── 文件收集 ─────────────────────────────────────────────

static func _collect_files(roots: PackedStringArray, excludes: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for root in roots:
		var dir_path := String(root).strip_edges()
		if dir_path == "":
			continue
		_walk_dir(dir_path, out, excludes)
	out.sort()
	return out

static func _walk_dir(dir_path: String, out: PackedStringArray, excludes: PackedStringArray) -> void:
	if _is_excluded(dir_path, excludes):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_walk_dir(path, out, excludes)
		elif not name.begins_with(".") and _is_scannable(name) and not _is_excluded(path, excludes):
			out.append(path)
		name = dir.get_next()
	dir.list_dir_end()

static func _is_scannable(name: String) -> bool:
	if name.ends_with(".bak") or ".tmp." in name:
		return false
	var ext := name.get_extension()
	return ext == "gd" or ext == "tres" or ext == "tscn"

static func _is_excluded(path: String, excludes: PackedStringArray) -> bool:
	for exclude in excludes:
		var prefix := String(exclude)
		if path == prefix or path.begins_with(prefix + "/"):
			return true
	return false

# ── 资源扫描 ─────────────────────────────────────────────

static func _scan_resource_file(path: String, result: Dictionary) -> void:
	var seen: Dictionary = result["seen_resources"]
	if seen.has(path):
		return
	seen[path] = true
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		(result["errors"] as Array).append({"file": path, "error": "load_failed"})
		return
	if resource is StateCatalog:
		result["stats"]["skipped_catalog"] += 1
		return
	_walk_model_resource(resource, path, result, 0)

## 任何资源里只要属性值是事件/公共事件/关卡图，就按模型继续走（限制深度防失控）。
## 内嵌子资源（resource_path 为空）以当前文件为引用位置；外链资源交给它自己的文件
## 扫描并去重，避免同一批状态被引用者和被引用文件各计一次。
static func _walk_model_resource(resource: Resource, path: String, result: Dictionary, depth: int) -> void:
	if resource is EventDefinition:
		_walk_event_definition(resource, path, result, "")
		return
	if resource is CommonEvent:
		for command in resource.commands:
			_walk_command(command, path, "公共事件", result)
		return
	if resource is LevelGraph:
		_walk_level_graph(resource, path, result)
		return
	if depth >= 3:
		return
	for property in resource.get_property_list():
		var usage: int = int(property.get("usage", 0))
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var value: Variant = resource.get(String(property.get("name", "")))
		_handled_model_value(value, path, result, depth)

## 场景/资源里遇到模型资源时的统一分流。
static func _handled_model_value(value: Variant, path: String, result: Dictionary, depth: int) -> void:
	if not (value is EventDefinition or value is CommonEvent or value is LevelGraph):
		if value is Resource and depth < 3:
			_walk_model_resource(value, path, result, depth + 1)
		return
	var model: Resource = value
	if model.resource_path == "":
		_walk_model_resource(model, path, result, depth + 1)
	else:
		result["pending_resources"][model.resource_path] = true

static func _scan_scene_file(path: String, result: Dictionary) -> void:
	var seen: Dictionary = result["seen_resources"]
	if seen.has(path):
		return
	seen[path] = true
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		(result["errors"] as Array).append({"file": path, "error": "load_failed"})
		return
	# 节点属性里直接挂着的资源（内嵌子资源 / 外链资源）。get_state() 只读序列化数据，
	# 不实例化场景、不运行任何 @tool 脚本。
	var scene_state := packed.get_state()
	for node_index in scene_state.get_node_count():
		var node_name := scene_state.get_node_name(node_index)
		for prop_index in scene_state.get_node_property_count(node_index):
			var value: Variant = scene_state.get_node_property_value(node_index, prop_index)
			if value is EventDefinition and (value as Resource).resource_path == "":
				_walk_event_definition(value, path, result, node_name + "·")
			elif value is CommonEvent and (value as Resource).resource_path == "":
				for command in value.commands:
					_walk_command(command, path, node_name, result)
			elif value is LevelGraph and (value as Resource).resource_path == "":
				_walk_level_graph(value, path, result)
			else:
				_handled_model_value(value, path, result, 0)
	# 外链资源表兜底：get_state() 未解析出来的 ext_resource 也登记去重
	for ext_path in _scene_ext_resources(path):
		if ext_path.get_extension() == "tres":
			result["pending_resources"][ext_path] = true

## 场景外链资源路径表（只看 .tres，供去重；真正取状态仍以资源文件为准）。
static func _scene_ext_resources(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var text := FileAccess.get_file_as_string(path)
	var regex := _regex("\\[ext_resource[^\\]]*path=\"([^\"]+)\"")
	var found := regex.search(text)
	while found != null:
		var target := found.get_string(1)
		if target.get_extension() == "tres" and not out.has(target):
			out.append(target)
		found = regex.search(text, found.get_end())
	return out

static func _walk_event_definition(definition: EventDefinition, path: String, result: Dictionary, prefix: String) -> void:
	for index in definition.pages.size():
		var page: EventPage = definition.pages[index]
		if page == null:
			continue
		var where := prefix + "P%d" % (index + 1)
		for condition in page.conditions:
			if condition == null or condition.key.strip_edges() == "":
				continue
			_record(result, condition.key, path, -1, KIND_EVENT_CONDITION, where, suggest_from_value(condition.value))
		for command in page.commands:
			_walk_command(command, path, where, result)

static func _walk_command(command: EventCommand, path: String, where: String, result: Dictionary) -> void:
	if command == null:
		return
	var params: Dictionary = command.params
	var spec := CommandRegistry.spec(command.type)
	if not spec.is_empty():
		for param in spec.get("params", []):
			if str(param.get("type", "")) != "state":
				continue
			var value: Variant = params.get(str(param.get("name", "")), "")
			if value is String and str(value).strip_edges() == "":
				continue
			_record(result, str(value), path, -1, KIND_CMD_PREFIX + String(command.type), where, _command_suggestion(command))
	else:
		# 未注册的指令类型：只认名为 key 的字符串参数，不猜语义
		var fallback: Variant = params.get(FALLBACK_STATE_PARAM, null)
		if fallback is String and str(fallback).strip_edges() != "":
			_record(result, str(fallback), path, -1, KIND_CMD_CUSTOM, where, "")
	for child in command.children:
		_walk_command(child, path, where, result)
	for child in command.else_children:
		_walk_command(child, path, where, result)

static func _command_suggestion(command: EventCommand) -> String:
	match String(command.type):
		"set_switch":
			return "bool"
		"if", "set_variable", "variable_op":
			return suggest_from_value(command.params.get("value", null))
	return ""

static func _walk_level_graph(graph: LevelGraph, path: String, result: Dictionary) -> void:
	for node in graph.nodes:
		if node == null:
			continue
		var where := String(node.node_id)
		match node.type:
			"condition":
				var key := str(node.get_param("key", "")).strip_edges()
				if key != "":
					_record(result, key, path, -1, KIND_GRAPH_CONDITION, where, suggest_from_value(node.get_param("value", null)))
			"action":
				var key := str(node.get_param("key", "")).strip_edges()
				if key != "":
					var suggestion := ""
					if str(node.get_param("op", "set")) == "toggle":
						suggestion = "bool"
					else:
						suggestion = suggest_from_value(node.get_param("value", null))
					_record(result, key, path, -1, KIND_GRAPH_ACTION, where, suggestion)
			"end":
				var key := str(node.get_param("completed_key", "")).strip_edges()
				if key != "":
					_record(result, key, path, -1, KIND_GRAPH_END, where, "bool")

# ── GDScript 扫描 ────────────────────────────────────────

static func _scan_script(path: String, result: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	for index in lines.size():
		_scan_script_line(String(lines[index]), path, index + 1, result)

static func _scan_script_line(line: String, path: String, lineno: int, result: Dictionary) -> void:
	var code := _strip_comment(line)
	if code.strip_edges() == "":
		return
	_scan_const_literal(code, path, lineno, result)
	for method in SCRIPT_METHODS:
		var regex := _regex("\\b" + method + "\\s*\\(")
		var found := regex.search(code)
		while found != null:
			_scan_call_site(method, code, found.get_end(), path, lineno, result)
			found = regex.search(code, found.get_end())

## 只处理「括号后第一个参数」：字面量且满足严格键形态才算确认引用。
static func _scan_call_site(method: String, code: String, args_start: int, path: String, lineno: int, result: Dictionary) -> void:
	var after := code.substr(args_start)
	var trimmed := after.lstrip(" \t")
	if trimmed.is_empty():
		return
	if trimmed.begins_with("'") or trimmed.begins_with("\""):
		var quote := trimmed.substr(0, 1)
		var close := trimmed.find(quote, 1)
		if close < 0:
			return
		var literal := trimmed.substr(1, close - 1)
		var tail := trimmed.substr(close + 1)
		if is_strict_key(literal):
			_record(result, literal, path, lineno, KIND_SCRIPT, method, _tail_suggestion(method, tail))
		elif literal.contains("%") or literal.ends_with("."):
			_report_dynamic(result, path, lineno, code, "dynamic_concat")
		# 其余字面量是普通字符串，不是状态
		return
	# 非字面量参数：变量、函数返回值、拼接结果，都无法静态确认
	_report_dynamic(result, path, lineno, code, "dynamic_expression")

static func _tail_suggestion(method: String, tail: String) -> String:
	match method:
		"get_bool":
			return "bool"
		"get_int":
			return "int"
		"get_float":
			return "float"
		"add":
			return _first_value_literal(tail)
		"define":
			var type_match := _regex("TYPE_(BOOL|INT|FLOAT|STRING)").search(tail)
			if type_match == null:
				return ""
			match type_match.get_string(1):
				"BOOL":
					return "bool"
				"INT":
					return "int"
				"FLOAT":
					return "float"
				"STRING":
					return "string"
			return ""
		"compare":
			var compare_match := _regex(",\\s*['\"](?:==|!=|>=|<=|>|<)['\"]\\s*,\\s*(true|false|[-+]?\\d+(?:\\.\\d+)?|['\"][^'\"]*['\"])").search(tail)
			if compare_match == null:
				return ""
			return _classify_literal_text(compare_match.get_string(1))
		"set_state", "set_value":
			return _first_value_literal(tail)
	return ""

static func _first_value_literal(tail: String) -> String:
	var found := _regex("^\\s*,\\s*(true|false|[-+]?\\d+(?:\\.\\d+)?|\"[^\"]*\"|'[^']*')").search(tail)
	if found == null:
		return ""
	return _classify_literal_text(found.get_string(1))

## const 常量里符合严格键形态的字符串：低置信的脚本引用，单独标记。
static func _scan_const_literal(code: String, path: String, lineno: int, result: Dictionary) -> void:
	var found := _regex("^\\s*const\\s+[A-Za-z_]\\w*\\s*:?\\s*=?\\s*(['\"])([^'\"]+)\\1").search(code)
	if found == null:
		return
	var literal := found.get_string(2)
	if is_strict_key(literal):
		_record(result, literal, path, lineno, KIND_SCRIPT_CONST, "const", "")

static func _strip_comment(line: String) -> String:
	var in_string := false
	var quote := " "
	for i in line.length():
		var ch := line[i]
		if in_string:
			if ch == quote:
				in_string = false
		elif ch == "\"" or ch == "'":
			in_string = true
			quote = ch
		elif ch == "#":
			return line.substr(0, i)
	return line

static func _regex(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		var compiled := RegEx.new()
		compiled.compile(pattern)
		_regex_cache[pattern] = compiled
	return _regex_cache[pattern]
