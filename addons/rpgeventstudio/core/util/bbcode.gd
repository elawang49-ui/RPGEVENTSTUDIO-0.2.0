@tool
class_name Bbcode
extends RefCounted
## 轻量 BBCode 检查器：不重写 RichTextLabel 的解析，只负责给作者明确提示。
##
## 支持范围以 Godot 4.7 的 RichTextLabel 为准；这里维护的是“不需要闭合”的标签
## 与已知标签集合，用于发现未闭合 / 不匹配 / 不支持的写法。
## 真正的渲染仍然交给 RichTextLabel。

## Godot 4.7 RichTextLabel 支持的标签（按小写名匹配）。
const SUPPORTED_TAGS := {
	"b": true, "i": true, "u": true, "s": true,
	"code": true, "p": true, "center": true, "left": true, "right": true,
	"fill": true, "indent": true, "url": true, "hint": true, "img": true,
	"font": true, "font_size": true, "color": true, "bgcolor": true, "fgcolor": true,
	"outline_size": true, "outline_color": true,
	"table": true, "cell": true, "ul": true, "ol": true,
	"lb": true, "rb": true, "dropcap": true, "lang": true,
}

## 这些标签不需要闭合；出现对应闭合标签时也一并忽略，避免误报。
const NO_CLOSE_TAGS := {
	"img": true, "lb": true, "rb": true, "p": true, "fill": true,
}

## 这些标签不接受 = 参数；写了参数会被 RichTextLabel 当原文显示。
const NO_PARAM_TAGS := {
	"b": true, "i": true, "u": true, "s": true, "code": true, "p": true,
	"center": true, "left": true, "right": true, "fill": true, "indent": true,
	"lb": true, "rb": true,
}

## 这些标签必须有 = 参数，否则会被 RichTextLabel 当原文显示。
const REQUIRED_PARAM_TAGS := {
	"color": true, "bgcolor": true, "fgcolor": true, "font": true,
	"font_size": true, "outline_size": true, "outline_color": true,
	"hint": true, "lang": true, "dropcap": true,
}

const ISSUE_KEYS := ["unclosed", "mismatch", "malformed_close", "unsupported"]

static var _tag_regex: RegEx

## 返回 {unclosed: [], mismatch: [], malformed_close: [], unsupported: []}。
## names 都是小写标签名，已去重并保持出现顺序。
static func analyze(raw: String) -> Dictionary:
	var info := {
		"unclosed": [],
		"mismatch": [],
		"malformed_close": [],
		"unsupported": [],
	}
	if not raw.contains("["):
		return info
	var regex := _regex()
	var stack: Array[String] = []
	var code_depth := 0
	var pos := 0
	while true:
		var tag_match := regex.search(raw, pos)
		if tag_match == null:
			break
		pos = tag_match.get_end()
		var closing := tag_match.get_string(1) == "/"
		var name := tag_match.get_string(2).to_lower()
		var param := tag_match.get_string(3)

		# [code] 里的内容按原文显示，里面的 [b] 之类不算标签。
		if code_depth > 0:
			if closing and name == "code" and param == "":
				code_depth -= 1
				if not stack.is_empty() and stack[stack.size() - 1] == "code":
					stack.pop_back()
			continue
		if not closing and name == "code":
			stack.append("code")
			code_depth = 1
			continue

		if closing and param != "":
			_append_unique(info["malformed_close"], name)
		if not SUPPORTED_TAGS.has(name):
			_append_unique(info["unsupported"], name)
			continue
		if NO_CLOSE_TAGS.has(name):
			continue
		if not closing and NO_PARAM_TAGS.has(name) and param != "":
			_append_unique(info["unsupported"], name)
			continue
		if not closing and REQUIRED_PARAM_TAGS.has(name) and param == "":
			_append_unique(info["unsupported"], name)
			continue

		if closing:
			if stack.is_empty():
				_append_unique(info["mismatch"], name)
			elif stack[stack.size() - 1] == name:
				stack.pop_back()
			else:
				_append_unique(info["mismatch"], name)
				var found := stack.rfind(name)
				if found >= 0:
					# 把匹配标签和它里面未闭合的标签一起收掉；后者会由 unclosed 报告。
					stack.resize(found)
		else:
			stack.append(name)

	# 把栈里剩下的都报告为未闭合（去重）。
	for name in stack:
		_append_unique(info["unclosed"], name)
	return info

static func has_issues(info: Dictionary) -> bool:
	for key in ISSUE_KEYS:
		if not (info.get(key, []) as Array).is_empty():
			return true
	return false

## 编辑器/运行时共用的可读说明；editor=true 用编辑器语言，否则用游戏语言。
static func describe(info: Dictionary, editor: bool) -> String:
	var lines: PackedStringArray = []
	_add_line(lines, "unclosed", "bbcode.unclosed", info, editor)
	_add_line(lines, "mismatch", "bbcode.mismatch", info, editor)
	_add_line(lines, "malformed_close", "bbcode.malformed_close", info, editor)
	_add_line(lines, "unsupported", "bbcode.unsupported", info, editor)
	return "\n".join(lines)

# ── 内部 ─────────────────────────────────────────────────

static func _regex() -> RegEx:
	if _tag_regex == null:
		_tag_regex = RegEx.new()
		# [name] / [/name] / [name=value]
		_tag_regex.compile("\\[(/?)([A-Za-z_][A-Za-z0-9_]*)(=[^\\[\\]]*)?\\]")
	return _tag_regex

static func _append_unique(list: Array, value: String) -> void:
	if not list.has(value):
		list.append(value)

static func _format_tags(names: Array) -> String:
	var parts: PackedStringArray = []
	for name in names:
		parts.append("[%s]" % str(name))
	return ", ".join(parts)

static func _add_line(lines: PackedStringArray, key: String, message_key: String, info: Dictionary, editor: bool) -> void:
	var names: Array = info.get(key, [])
	if names.is_empty():
		return
	var params := {"tags": _format_tags(names)}
	lines.append(L10n.ui(message_key, params) if editor else L10n.game(message_key, params))
