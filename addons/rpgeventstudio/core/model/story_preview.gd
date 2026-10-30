@tool
class_name StoryPreview
extends RefCounted
## 全文预览：把剧情条目渲染成一段连续的 BBCode，交给 RichTextLabel 显示。
## 只做展示，不修改任何原始文案；BBCode 原样交给渲染器，
## 同时用 Bbcode.analyze 汇总「不支持的标签」等提示。

const MARKER_COLOR := "8a8f9c"
const DEFAULT_SPEAKER_COLOR := "e8c56b"

## 渲染整段剧情。depth 由条目自带。
static func build(items: Array, roster: StoryCharacters = null) -> String:
	var parts := PackedStringArray()
	_append_items(parts, items, roster, 0)
	return "\n".join(parts)

static func _append_items(parts: PackedStringArray, items: Array, roster: StoryCharacters, depth: int) -> void:
	var pad := "".lpad(depth * 2, "　")
	for item in items:
		match str(item.get("kind", "")):
			"line":
				_append_line(parts, item, roster, pad)
			"choice":
				_append_choice(parts, item, roster, pad)
			"condition":
				var condition: EventCommand = item["command"]
				parts.append("%s%s" % [pad, _marker(L10n.ui("story.preview.condition", {
					"expr": _condition_text(condition),
				}))])
				_append_items(parts, item["children_view"], roster, depth + 1)
				if not (item["else_view"] as Array).is_empty():
					parts.append("%s%s" % [pad, _marker(L10n.ui("story.preview.else"))])
					_append_items(parts, item["else_view"], roster, depth + 1)
			"state":
				parts.append("%s%s" % [pad, _marker(L10n.ui("story.preview.state", {
					"summary": CommandRegistry.summary(item["command"]),
				}))])
			"command":
				parts.append("%s%s" % [pad, _marker(L10n.ui("story.preview.command", {
					"summary": CommandRegistry.summary(item["command"]),
				}))])

static func _append_line(parts: PackedStringArray, item: Dictionary, roster: StoryCharacters, pad: String) -> void:
	var speaker := str(item["command"].params.get("speaker", ""))
	var text := str(item["command"].params.get("text", ""))
	if speaker.strip_edges() != "":
		parts.append("%s%s" % [pad, _speaker_text(speaker, roster)])
	parts.append("%s%s" % [pad, text])

static func _append_choice(parts: PackedStringArray, item: Dictionary, roster: StoryCharacters, pad: String) -> void:
	var prompt := str(item["command"].params.get("prompt", ""))
	if prompt.strip_edges() != "":
		parts.append("%s%s" % [pad, _speaker_style_wrap(prompt, DEFAULT_SPEAKER_COLOR)])
	var options: Array = item["options"]
	var views: Array = item["option_views"]
	for option_index in options.size():
		parts.append("%s%s" % [pad, L10n.ui("story.preview.option", {
			"number": option_index + 1,
			"text": str(options[option_index]),
		})])
		if option_index < views.size() and not (views[option_index] as Array).is_empty():
			_append_items(parts, views[option_index], roster, _option_depth(item))
	if bool(item.get("well_formed", false)) == false:
		parts.append("%s%s" % [pad, _marker(L10n.ui("story.preview.choice_raw"))])

## 选项分支的缩进深度：条目 depth + 1（视图里已经带 depth，取第一个即可，
## 空分支时按 depth+1 处理）。
static func _option_depth(item: Dictionary) -> int:
	var views: Array = item["option_views"]
	for view in views:
		if not (view as Array).is_empty():
			return int(view[0].get("depth", int(item["depth"]) + 1))
	return int(item["depth"]) + 1

static func _condition_text(command: EventCommand) -> String:
	var key := str(command.params.get("key", ""))
	if key.strip_edges() == "":
		return L10n.ui("editor.unset")
	var label := StateCatalogStore.display(key)
	return "%s %s %s" % [label, command.params.get("op", "=="), _value_label(command.params.get("value", ""))]

static func _value_label(value: Variant) -> String:
	var parsed: Variant = ValueParser.parse(str(value))
	if parsed is bool:
		return "ON" if parsed else "OFF"
	return str(parsed)

static func _speaker_text(speaker: String, roster: StoryCharacters) -> String:
	var color := DEFAULT_SPEAKER_COLOR
	if roster != null:
		var character := roster.find_by_display_name(speaker)
		if character != null:
			color = character.color.to_html(false)
	return _speaker_style_wrap(speaker, color)

static func _speaker_style_wrap(text: String, color_hex: String) -> String:
	return "[color=#%s]%s[/color]" % [color_hex, text]

static func _marker(text: String) -> String:
	return "[color=#%s]── %s ──[/color]" % [MARKER_COLOR, text]

# ── BBCode 问题汇总 ──────────────────────────────────────

## 汇总剧情里所有文案（正文 / 提示语 / 选项）的 BBCode 问题。
static func collect_issues(items: Array) -> Dictionary:
	var info := {"unclosed": [], "mismatch": [], "malformed_close": [], "unsupported": []}
	_scan_issues(info, items)
	return info

static func _scan_issues(info: Dictionary, items: Array) -> void:
	for item in items:
		match str(item.get("kind", "")):
			"line":
				_merge(info, Bbcode.analyze(str(item["command"].params.get("text", ""))))
			"choice":
				_merge(info, Bbcode.analyze(str(item["command"].params.get("prompt", ""))))
				for option in item["options"]:
					_merge(info, Bbcode.analyze(str(option)))
				for view in item["option_views"]:
					_scan_issues(info, view)
			"condition":
				_scan_issues(info, item["children_view"])
				_scan_issues(info, item["else_view"])

static func _merge(target: Dictionary, source: Dictionary) -> void:
	for key in target.keys():
		for name_text in source.get(key, []):
			if not (target[key] as Array).has(name_text):
				(target[key] as Array).append(name_text)
