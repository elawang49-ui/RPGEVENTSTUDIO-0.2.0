@tool
class_name StoryTemplates
extends RefCounted
## 剧情模板：一键生成真实可编辑的 EventDefinition（不是演示页）。
## 生成的资源结构与手做事件完全一致，走同一个运行时与同一个编辑器。

const KEYS := ["npc_dialogue", "investigate", "multi_choice", "condition_branch", "item_get", "door_lock", "autorun"]

# ── 模板清单 ─────────────────────────────────────────────

static func all() -> Array:
	var out: Array = []
	for id in KEYS:
		out.append({
			"id": id,
			"name": L10n.ui("story.template." + id),
			"hint": L10n.ui("story.template." + id + "_hint"),
		})
	return out

static func build(id: String) -> EventDefinition:
	match id:
		"npc_dialogue": return _npc_dialogue()
		"investigate": return _investigate()
		"multi_choice": return _multi_choice()
		"condition_branch": return _condition_branch()
		"item_get": return _item_get()
		"door_lock": return _door_lock()
		"autorun": return _autorun()
	return null

# ── 各模板 ───────────────────────────────────────────────

## NPC 普通对话：一页交互，几条来回台词。
static func _npc_dialogue() -> EventDefinition:
	var definition := _definition(&"npc_dialogue", L10n.ui("story.template.npc"))
	var page := EventPage.new()
	page.commands = [
		_text(L10n.ui("story.template.speaker_a"), L10n.ui("story.template.npc_line1")),
		_text("", L10n.ui("story.template.npc_narration")),
		_text(L10n.ui("story.template.speaker_a"), L10n.ui("story.template.npc_line2")),
		_end(),
	]
	definition.pages = [page]
	return definition

## 首次调查 / 重复调查：第一次有发现（写开关），之后只会说同一句话。
static func _investigate() -> EventDefinition:
	var definition := _definition(&"investigate", L10n.ui("story.template.investigate"))
	var key := "Global.Investigate.DeskChecked"

	var repeat_page := EventPage.new()
	repeat_page.commands = [
		_text("", L10n.ui("story.template.investigate_repeat")),
		_end(),
	]
	definition.pages.append(repeat_page)

	var first_page := EventPage.new()
	first_page.conditions = [_condition(key, false)]
	first_page.commands = [
		_text("", L10n.ui("story.template.investigate_first")),
		_switch(key, true),
		_text("", L10n.ui("story.template.investigate_found")),
		_end(),
	]
	definition.pages.append(first_page)
	return definition

## 多选项对话：三个选项，各自分支。
static func _multi_choice() -> EventDefinition:
	var definition := _definition(&"multi_choice", L10n.ui("story.template.multi_choice"))
	var option_a := L10n.ui("story.template.choice_a")
	var option_b := L10n.ui("story.template.choice_b")
	var option_c := L10n.ui("story.template.choice_c")

	var page := EventPage.new()
	page.commands = [
		_text(L10n.ui("story.template.speaker_b"), L10n.ui("story.template.multi_line")),
		_choices(L10n.ui("story.template.multi_prompt"), [option_a, option_b, option_c]),
		_choice_branch(0, L10n.ui("story.template.multi_reply_a")),
		_choice_branch(1, L10n.ui("story.template.multi_reply_b")),
		_choice_branch(2, L10n.ui("story.template.multi_reply_c")),
		_end(),
	]
	definition.pages = [page]
	return definition

## 条件分支：按开关走不同台词。
static func _condition_branch() -> EventDefinition:
	var definition := _definition(&"condition_branch", L10n.ui("story.template.condition_branch"))
	var key := "Global.Mission.QuestAccepted"

	var page := EventPage.new()
	var branch := CommandRegistry.create_command(&"if")
	branch.params["key"] = key
	branch.params["op"] = "=="
	branch.params["value"] = "true"
	branch.children = [_text(L10n.ui("story.template.speaker_b"), L10n.ui("story.template.branch_then"))]
	branch.else_children = [_text(L10n.ui("story.template.speaker_b"), L10n.ui("story.template.branch_else"))]
	page.commands = [
		_text(L10n.ui("story.template.speaker_b"), L10n.ui("story.template.branch_intro")),
		branch,
		_end(),
	]
	definition.pages = [page]
	return definition

## 物品获取：第一次拿到（写开关），之后提示已经拿过。
static func _item_get() -> EventDefinition:
	var definition := _definition(&"item_get", L10n.ui("story.template.item_get"))
	var key := "Global.Player.HasSample"

	var got_page := EventPage.new()
	got_page.conditions = [_condition(key, true)]
	got_page.commands = [
		_text("", L10n.ui("story.template.item_empty")),
		_end(),
	]
	definition.pages.append(got_page)

	var take_page := EventPage.new()
	take_page.conditions = [_condition(key, false)]
	take_page.commands = [
		_text("", L10n.ui("story.template.item_found")),
		_switch(key, true),
		_text("", L10n.ui("story.template.item_obtained")),
		_end(),
	]
	definition.pages.append(take_page)
	return definition

## 门锁与机关：有钥匙开门并写开关，没钥匙被挡住。
static func _door_lock() -> EventDefinition:
	var definition := _definition(&"door_lock", L10n.ui("story.template.door_lock"))
	var key := "Global.Player.HasKey"
	var opened := "Global.Door.OfficeOpen"

	var open_page := EventPage.new()
	open_page.conditions = [_condition(key, true)]
	open_page.commands = [
		_text("", L10n.ui("story.template.door_open")),
		_switch(opened, true),
		_end(),
	]
	definition.pages.append(open_page)

	var locked_page := EventPage.new()
	locked_page.conditions = [_condition(key, false)]
	locked_page.commands = [
		_text("", L10n.ui("story.template.door_locked")),
		_end(),
	]
	definition.pages.append(locked_page)
	return definition

## 自动触发事件：进入场景 / 走到触发区时自动演出。
static func _autorun() -> EventDefinition:
	var definition := _definition(&"autorun_event", L10n.ui("story.template.autorun"))
	var key := "Global.Mission.IntroPlayed"

	var page := EventPage.new()
	page.trigger = "autorun"
	page.repeat_policy = "once"
	page.commands = [
		_text("", L10n.ui("story.template.autorun_line1")),
		_text(L10n.ui("story.template.speaker_a"), L10n.ui("story.template.autorun_line2")),
		_switch(key, true),
		_end(),
	]
	definition.pages = [page]
	return definition

# ── 构造工具 ─────────────────────────────────────────────

static func _definition(id: StringName, display: String) -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = id
	definition.display_name = display
	definition.notes = L10n.ui("story.template.notes")
	return definition

static func _text(speaker: String, body: String) -> EventCommand:
	var command := CommandRegistry.create_command(&"show_text")
	command.params["speaker"] = speaker
	command.params["text"] = body
	return command

static func _choices(prompt: String, options: Array) -> EventCommand:
	var command := CommandRegistry.create_command(&"show_choices")
	command.params["prompt"] = prompt
	command.params["options"] = options
	return command

## 顺序式选项分支：if @@self.choice == index { 台词 }。
static func _choice_branch(index: int, body: String) -> EventCommand:
	var command := CommandRegistry.create_command(&"if")
	command.params["key"] = StoryDocument.CHOICE_STATE
	command.params["op"] = "=="
	command.params["value"] = str(index)
	command.children = [_text("", body)]
	return command

static func _switch(key: String, value: bool) -> EventCommand:
	var command := CommandRegistry.create_command(&"set_switch")
	command.params["key"] = key
	command.params["value"] = value
	return command

static func _end() -> EventCommand:
	return CommandRegistry.create_command(&"end")

static func _condition(key: String, value: Variant) -> EventCondition:
	var condition := EventCondition.new()
	condition.key = key
	condition.op = "=="
	condition.value = value
	return condition
