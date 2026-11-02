@tool
class_name CommandRegistry
extends RefCounted
## 指令注册表：显示名、分类、参数 schema、处理器。
## 所有界面文字都是翻译键（cmd.* / cat.* / param.*），新增指令 = 加一行注册 + 一个 handler 文件。

const CAT_DIALOGUE := "cat.dialogue"
const CAT_FLOW := "cat.flow"
const CAT_STATE := "cat.state"
const CAT_AUDIO := "cat.audio"
const CAT_CHARACTER := "cat.character"
const CAT_OTHER := "cat.other"

static var _specs: Dictionary = {}
static var _order: Array[StringName] = []
static var _handlers: Dictionary = {}
static var _built := false
## 宿主通过 register_host_command 注册的指令 id：用于保护内置指令不被覆盖。
static var _host_types: Dictionary = {}

# ── 查询 ─────────────────────────────────────────────────

static func ensure_built() -> void:
	if _built:
		return
	_built = true
	_register(&"show_text", "cmd.show_text", CAT_DIALOGUE, [
		{"name": "speaker", "label_key": "param.speaker", "type": "text", "default": ""},
		{"name": "text", "label_key": "param.text", "type": "multiline", "default": ""},
		{"name": "auto_advance", "label_key": "param.auto_advance", "type": "float", "default": 0.0},
	], CmdShowText.new())

	_register(&"show_choices", "cmd.show_choices", CAT_DIALOGUE, [
		{"name": "prompt", "label_key": "param.prompt", "type": "text", "default": ""},
		{"name": "options", "label_key": "param.options", "type": "options", "default": "是\n否"},
	], CmdShowChoices.new())

	_register(&"if", "cmd.if", CAT_FLOW, [
		{"name": "key", "label_key": "param.state", "type": "state", "default": ""},
		{"name": "op", "label_key": "param.op", "type": "op", "default": "=="},
		{"name": "value", "label_key": "param.value", "type": "text", "default": "true"},
	], CmdIf.new())

	_register(&"wait", "cmd.wait", CAT_FLOW, [
		{"name": "seconds", "label_key": "param.seconds", "type": "float", "default": 1.0},
	], CmdWait.new())

	_register(&"call_common", "cmd.call_common", CAT_FLOW, [
		{"name": "common_path", "label_key": "param.common_event", "type": "event_path", "default": ""},
	], CmdCallCommon.new())

	_register(&"end", "cmd.end", CAT_FLOW, [], CmdEnd.new())

	_register(&"set_switch", "cmd.set_switch", CAT_STATE, [
		{"name": "key", "label_key": "param.switch", "type": "state", "default": ""},
		{"name": "value", "label_key": "param.switch_on", "type": "bool", "default": true},
	], CmdSetSwitch.new())

	_register(&"set_variable", "cmd.set_variable", CAT_STATE, [
		{"name": "key", "label_key": "param.variable", "type": "state", "default": ""},
		{"name": "value", "label_key": "param.value", "type": "text", "default": "0"},
	], CmdSetVariable.new())

	_register(&"variable_op", "cmd.variable_op", CAT_STATE, [
		{"name": "key", "label_key": "param.variable", "type": "state", "default": ""},
		{"name": "op", "label_key": "param.arith", "type": "arith", "default": "+"},
		{"name": "value", "label_key": "param.number", "type": "float", "default": 1.0},
	], CmdVariableOp.new())

	_register(&"play_sfx", "cmd.play_sfx", CAT_AUDIO, [
		{"name": "sound_path", "label_key": "param.sound", "type": "sound_path", "default": ""},
		{"name": "volume_db", "label_key": "param.volume", "type": "float", "default": 0.0},
		{"name": "wait", "label_key": "param.wait_done", "type": "bool", "default": false},
	], CmdPlaySfx.new())

	_register(&"move_actor", "cmd.move_actor", CAT_CHARACTER, [
		{"name": "actor", "label_key": "param.actor", "type": "node_ref", "default": "", "hint": "param.node_ref_hint"},
		{"name": "offset_x", "label_key": "param.offset_x", "type": "float", "default": 0.0},
		{"name": "offset_y", "label_key": "param.offset_y", "type": "float", "default": 0.0},
		{"name": "duration", "label_key": "param.duration", "type": "float", "default": 0.6},
		{"name": "wait", "label_key": "param.wait_done", "type": "bool", "default": true},
	], CmdMoveActor.new())

	_register(&"camera_focus", "cmd.camera_focus", CAT_CHARACTER, [
		{"name": "target", "label_key": "param.camera_target", "type": "node_ref", "default": "", "hint": "param.node_ref_hint"},
		{"name": "offset_x", "label_key": "param.offset_x", "type": "float", "default": 0.0},
		{"name": "offset_y", "label_key": "param.offset_y", "type": "float", "default": 0.0},
		{"name": "duration", "label_key": "param.duration", "type": "float", "default": 0.8},
		{"name": "wait", "label_key": "param.wait_done", "type": "bool", "default": true},
	], CmdCameraFocus.new())

	_register(&"camera_restore", "cmd.camera_restore", CAT_CHARACTER, [
		{"name": "duration", "label_key": "param.duration", "type": "float", "default": 0.8},
		{"name": "wait", "label_key": "param.wait_done", "type": "bool", "default": true},
	], CmdCameraRestore.new())

	_register(&"fade", "cmd.fade", CAT_CHARACTER, [
		{"name": "mode", "label_key": "param.fade_mode", "type": "choice",
			"options": ["fade.out", "fade.in"], "values": ["out", "in"], "default": "out"},
		{"name": "duration", "label_key": "param.duration", "type": "float", "default": 0.4},
		{"name": "wait", "label_key": "param.wait_done", "type": "bool", "default": true},
	], CmdFade.new())

# ── 宿主扩展（通用能力） ─────────────────────────────────

## 宿主工程注册自定义指令：插件核心不预置任何宿主内容，宿主内容留在宿主工程。
##
## spec 字段（全部可选，params 建议提供）：
##   name_key:     界面显示名的翻译键；缺失时回退 fallback_name，再缺失显示 type
##   fallback_name: 显示名兜底文本（宿主没注入词条也能看懂）
##   category:     自定义分类字符串（编辑器「添加指令」菜单按它分组）
##   params:       与内置指令相同的参数 schema（name/label_key/type/default/hint）
##   block:        是否是带 children/else_children 的块指令（如 if）
##   summary:      列表摘要模板，可用 {参数名} 占位符
##
## 规则：
##   - 内置指令不可覆盖（返回 ERR_ALREADY_EXISTS，handler/spec 保持原样）；
##   - 同名宿主指令先到先得，重复注册同样拒绝；
##   - 建议在宿主启动时（autoload _ready 或首次用到前）注册一次。
static func register_host_command(type: StringName, spec: Dictionary, p_handler: CommandHandler) -> int:
	ensure_built()
	if type == &"" or p_handler == null:
		return ERR_INVALID_PARAMETER
	if _handlers.has(type):
		# 内置指令或已注册的宿主指令都不可覆盖：先到先得，保护已有事件不受影响。
		return ERR_ALREADY_EXISTS
	var normalized := {
		"name_key": str(spec.get("name_key", "")),
		"fallback_name": str(spec.get("fallback_name", "")),
		"category": str(spec.get("category", CAT_OTHER)),
		"params": spec.get("params", []),
		"block": bool(spec.get("block", false)),
		"summary": str(spec.get("summary", "")),
	}
	_specs[type] = normalized
	_order.append(type)
	_handlers[type] = p_handler
	_host_types[type] = true
	return OK

static func is_host_command(type: StringName) -> bool:
	return _host_types.has(type)

# ── 供编辑器使用 ─────────────────────────────────────────

static func all_types() -> Array[StringName]:
	ensure_built()
	return _order.duplicate()

static func spec(type: StringName) -> Dictionary:
	ensure_built()
	return _specs.get(type, {})

static func display_name(type: StringName) -> String:
	var s := spec(type)
	var name_key := str(s.get("name_key", ""))
	var fallback := str(s.get("fallback_name", ""))
	if name_key == "":
		return str(type) if fallback == "" else fallback
	var text := L10n.ui(name_key)
	# L10n 缺键时返回键名本身：宿主没注入词条时退到 fallback_name，再退到 type。
	if text == name_key:
		return fallback if fallback != "" else name_key
	return text

static func category_label(category: String) -> String:
	return L10n.ui(category)

static func categories() -> Array[String]:
	ensure_built()
	var out: Array[String] = []
	for type in _order:
		var category: String = str(_specs[type].get("category", CAT_OTHER))
		if not out.has(category):
			out.append(category)
	return out

static func types_in_category(category: String) -> Array[StringName]:
	ensure_built()
	var out: Array[StringName] = []
	for type in _order:
		if str(_specs[type].get("category", CAT_OTHER)) == category:
			out.append(type)
	return out

static func param_label(param: Dictionary) -> String:
	var key := str(param.get("label_key", ""))
	if key == "":
		return str(param.get("name", ""))
	return L10n.ui(key)

static func params_of(type: StringName) -> Array:
	return spec(type).get("params", [])

static func is_block(type: StringName) -> bool:
	return bool(spec(type).get("block", false))

static func create_command(type: StringName) -> EventCommand:
	var command := EventCommand.new()
	command.type = type
	var defaults := {}
	for param in params_of(type):
		defaults[str(param.get("name", ""))] = param.get("default", null)
	command.params = defaults
	return command

static func summary(command: EventCommand) -> String:
	if command == null:
		return ""
	var title := display_name(command.type)
	match command.type:
		&"show_text":
			return "%s：%s" % [title, _one_line(command.params.get("text", ""))]
		&"show_choices":
			return "%s：%s" % [title, _one_line(command.params.get("prompt", ""))]
		&"if":
			var key := str(command.params.get("key", ""))
			if key.strip_edges() == "":
				return title
			return "%s：%s %s %s" % [title, StateCatalogStore.display(key), command.params.get("op", "=="), _value_label(command.params.get("value", ""))]
		&"set_switch":
			return "%s：%s = %s" % [title, StateCatalogStore.display(str(command.params.get("key", ""))), "ON" if bool(command.params.get("value", true)) else "OFF"]
		&"set_variable":
			return "%s：%s = %s" % [title, StateCatalogStore.display(str(command.params.get("key", ""))), command.params.get("value", "")]
		&"variable_op":
			return "%s：%s %s %s" % [title, StateCatalogStore.display(str(command.params.get("key", ""))), command.params.get("op", "+"), command.params.get("value", "")]
		&"wait":
			return "%s %s" % [title, command.params.get("seconds", 1.0)]
		&"call_common":
			return "%s：%s" % [title, _basename(command.params.get("common_path", ""))]
		&"play_sfx":
			return "%s：%s" % [title, _basename(command.params.get("sound_path", ""))]
	# 宿主指令：spec.summary 提供 {参数名} 模板；没有模板时退回显示名。
	var template := str(spec(command.type).get("summary", ""))
	if template != "":
		var rendered := template
		for key in command.params.keys():
			rendered = rendered.replace("{%s}" % str(key), _one_line(command.params.get(key, "")))
		return "%s：%s" % [title, rendered]
	return title

static func handler(type: StringName) -> CommandHandler:
	ensure_built()
	return _handlers.get(type, null)

# ── 内部 ─────────────────────────────────────────────────

static func _register(type: StringName, name_key: String, category: String, params: Array, handler: CommandHandler) -> void:
	_specs[type] = {"name_key": name_key, "category": category, "params": params, "block": type == &"if"}
	_order.append(type)
	_handlers[type] = handler

static func _one_line(value: Variant) -> String:
	var text := str(value).replace("\n", " ")
	if text.length() > 28:
		return text.substr(0, 28) + "…"
	return text

static func _value_label(value: Variant) -> String:
	var parsed: Variant = ValueParser.parse(str(value))
	if parsed is bool:
		return "ON" if parsed else "OFF"
	return str(parsed)

static func _basename(value: Variant) -> String:
	var text := str(value)
	if text == "":
		return "—"
	return text.get_file()
