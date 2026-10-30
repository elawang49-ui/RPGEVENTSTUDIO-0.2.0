@tool
class_name StoryDocument
extends RefCounted
## 剧情文档：把 EventPage.commands 映射成写作者视角的条目视图（台词 / 选项 / 条件 / 状态 / 指令）。
##
## 设计原则：视图只是「引用」。build_items 产出的是指向真实 EventCommand 与真实
## Array 的描述字典；所有编辑都通过本类的原子方法直接落在原有对象上，
## 不做「解析 → 重建」。这样旧事件资源无论如何都不会因为打开过剧情视图而丢内容。
##
## 选项块（show_choices）的分支语义与运行时一致：选项结果写入 @@self.choice（0 起），
## 分支是 `if @@self.choice == N`。支持两种既有写法：
##   顺序式：show_choices 后跟多个 if（每项对应一个选项）
##   嵌套式：一个 if 的 else_children 里继续放下一个 if（librarian.tres 的写法，
##           最后一段 else 当作最后一个选项的分支）
## 对选项做结构性修改（增删选项）时会改写成统一的顺序式，内容原样搬移。

signal changed

const CHOICE_STATE := "@@self.choice"

var page: EventPage

func _init(p_page: EventPage = null) -> void:
	page = p_page

# ── 视图构建 ─────────────────────────────────────────────
##
## 条目字典字段：
##   公共：kind / command / list / index / depth
##   line:      show_text
##   choice:    options / pattern / well_formed / branches(每选项的 Array 或 null) /
##              ifs / fallback / option_views(每选项的子条目)
##   condition: children_view / else_view
##   state:     set_switch / set_variable / variable_op
##   command:   其余指令（wait / play_sfx / end …），在剧情视图里保留可排序可删除

func build_items() -> Array:
	if page == null:
		return []
	return build_items_of(page.commands, 0)

static func build_items_of(list: Array, depth: int) -> Array:
	var items: Array = []
	var index := 0
	while index < list.size():
		var command: EventCommand = list[index]
		if command == null or not (command is EventCommand):
			index += 1
			continue
		match command.type:
			&"show_text":
				items.append(_line_item(command, list, index, depth))
				index += 1
			&"show_choices":
				var choice := _choice_item(command, list, index, depth)
				items.append(choice)
				index += int(choice["consumed"])
			&"if":
				items.append(_condition_item(command, list, index, depth))
				index += 1
			&"set_switch", &"set_variable", &"variable_op":
				items.append(_base_item("state", command, list, index, depth))
				index += 1
			_:
				items.append(_base_item("command", command, list, index, depth))
				index += 1
	return items

static func _base_item(kind: String, command: EventCommand, list: Array, index: int, depth: int) -> Dictionary:
	return {"kind": kind, "command": command, "list": list, "index": index, "depth": depth}

static func _line_item(command: EventCommand, list: Array, index: int, depth: int) -> Dictionary:
	return _base_item("line", command, list, index, depth)

static func _condition_item(command: EventCommand, list: Array, index: int, depth: int) -> Dictionary:
	var item := _base_item("condition", command, list, index, depth)
	item["children_view"] = build_items_of(command.children, depth + 1)
	item["else_view"] = build_items_of(command.else_children, depth + 1)
	return item

static func _choice_item(command: EventCommand, list: Array, index: int, depth: int) -> Dictionary:
	var item := _base_item("choice", command, list, index, depth)
	var options: Array = []
	var raw: Variant = command.params.get("options", [])
	if raw is Array:
		for entry in raw:
			options.append(str(entry))
	elif raw is String and str(raw).strip_edges() != "":
		options.append(str(raw))
	item["options"] = options

	var ifs: Array = []
	var branches: Array = []          # 与 ifs 一一对应的分支内容（Array 引用）
	var fallback: Array = []
	var consumed := 1
	var pattern := "plain"

	var next_index := index + 1
	# 顺序式：紧跟的 if @@self.choice == 0, 1, 2 …
	var scan := next_index
	while scan < list.size():
		var value := _choice_if_index(list[scan], ifs.size())
		if value < 0:
			break
		ifs.append(list[scan])
		branches.append(list[scan].children)
		scan += 1
	if not ifs.is_empty():
		# 只要扫到的 if 里有一个带了 else 内容，就改按嵌套式解读：
		# 旧写法（librarian.tres 等）把后续选项 / 其它情况放在 else 里，
		# 顺序式会把这段内容藏起来，结构编辑时可能丢掉。
		var has_else := false
		for node in ifs:
			if not (node as EventCommand).else_children.is_empty():
				has_else = true
				break
		if has_else:
			ifs.clear()
			branches.clear()
	if not ifs.is_empty():
		pattern = "sequential"
		consumed = scan - index
	else:
		# 嵌套式：一个 if，选项 N 的分支藏在第 N 层 else 里
		var node: EventCommand = list[next_index] if next_index < list.size() else null
		var depth_value := _choice_if_index(node, 0)
		if depth_value == 0:
			pattern = "nested"
			consumed = 2
			while node != null:
				ifs.append(node)
				branches.append(node.children)
				var else_list: Array = node.else_children
				node = null
				if else_list.size() == 1 and _choice_if_index(else_list[0], ifs.size()) >= 0:
					node = else_list[0]
				elif not else_list.is_empty():
					fallback = else_list
					break

	item["pattern"] = pattern
	item["ifs"] = ifs
	item["fallback"] = fallback
	item["consumed"] = consumed

	# 分支 → 选项映射：顺序式第 k 个 if 即选项 k；嵌套式最后的 fallback 是最后一个选项。
	var option_branches: Array = []
	for option_index in options.size():
		option_branches.append(null)
	var well_formed := false
	match pattern:
		"sequential":
			well_formed = ifs.size() <= options.size()
			for if_index in ifs.size():
				if if_index < options.size():
					option_branches[if_index] = branches[if_index]
		"nested":
			well_formed = options.size() == ifs.size() + (1 if not fallback.is_empty() else 0)
			for if_index in ifs.size():
				if if_index < options.size():
					option_branches[if_index] = branches[if_index]
			if well_formed and not fallback.is_empty() and options.size() > ifs.size():
				option_branches[ifs.size()] = fallback
		"plain":
			well_formed = ifs.is_empty() and fallback.is_empty()
	item["well_formed"] = well_formed
	item["branches"] = option_branches

	var option_views: Array = []
	for branch in option_branches:
		if branch is Array:
			option_views.append(build_items_of(branch, depth + 1))
		else:
			option_views.append([])
	item["option_views"] = option_views
	return item

## 是不是「if @@self.choice == expected」；是返回 expected，否则 -1。
static func _choice_if_index(command: Variant, expected: int) -> int:
	if command == null or not (command is EventCommand):
		return -1
	if command.type != &"if":
		return -1
	if str(command.params.get("key", "")) != CHOICE_STATE:
		return -1
	if str(command.params.get("op", "==")) != "==":
		return -1
	var parsed: Variant = ValueParser.parse(str(command.params.get("value", "")))
	if (parsed is int or parsed is float) and int(parsed) == expected:
		return expected
	return -1

# ── 撤销 ─────────────────────────────────────────────────

## 撤销管理器由编辑器层注入（依赖注入）：core 不引用 EditorInterface/EditorUndoRedoManager。
## 未注入或非编辑器环境时为 null，此时所有编辑操作直接生效。
var undo_provider: Callable = Callable()

func _undo() -> Object:
	if not undo_provider.is_valid() or not Engine.is_editor_hint():
		return null
	return undo_provider.call()

# ── 通用结构操作 ─────────────────────────────────────────

## 在 target(list, index) 插入一条指令。
func insert_command(target_list: Array, index: int, command: EventCommand, undo_name: String = "") -> void:
	var undo := _undo()
	if undo == null:
		_do_insert(target_list, index, command)
		return
	undo.create_action(undo_name if undo_name != "" else L10n.ui("story.undo.insert"), UndoRedo.MERGE_DISABLE, page)
	undo.add_do_method(self, "_do_insert", target_list, index, command)
	undo.add_undo_method(self, "_do_remove_at", target_list, index, command)
	undo.add_do_reference(command)
	undo.commit_action()

func _do_insert(target_list: Array, index: int, command: EventCommand) -> void:
	index = clampi(index, 0, target_list.size())
	target_list.insert(index, command)
	changed.emit()

func _do_remove_at(target_list: Array, index: int, _command: EventCommand = null) -> void:
	if index >= 0 and index < target_list.size():
		target_list.remove_at(index)
	changed.emit()

## 一次插入多条指令（例如「选项 + 两个分支」），撤销也是一步。
func insert_commands(target_list: Array, index: int, commands: Array, undo_name: String = "") -> void:
	var undo := _undo()
	if undo == null:
		_do_insert_many(target_list, index, commands)
		return
	undo.create_action(undo_name if undo_name != "" else L10n.ui("story.undo.insert"), UndoRedo.MERGE_DISABLE, page)
	undo.add_do_method(self, "_do_insert_many", target_list, index, commands)
	undo.add_undo_method(self, "_do_remove_many", target_list, index, commands)
	for command in commands:
		undo.add_do_reference(command)
	undo.commit_action()

func _do_insert_many(target_list: Array, index: int, commands: Array) -> void:
	var at := clampi(index, 0, target_list.size())
	for command in commands:
		target_list.insert(at, command)
		at += 1
	changed.emit()

func _do_remove_many(target_list: Array, index: int, commands: Array) -> void:
	for command in commands:
		var at := target_list.find(command)
		if at >= 0:
			target_list.remove_at(at)
	changed.emit()

## 删除条目（含选项块整体 / 条件块整体）。
func delete_item(item: Dictionary) -> void:
	var list: Array = item["list"]
	var index := int(item["index"])
	if index < 0 or index >= list.size():
		return
	var command: EventCommand = item["command"]
	var undo := _undo()
	if undo == null:
		_do_remove_at(list, index, command)
		return
	undo.create_action(L10n.ui("story.undo.delete"), UndoRedo.MERGE_DISABLE, page)
	undo.add_do_method(self, "_do_remove_at", list, index, command)
	undo.add_undo_method(self, "_do_insert", list, index, command)
	undo.add_undo_reference(command)
	undo.commit_action()

## 复制条目：深拷贝后插到原条目后面。
func duplicate_item(item: Dictionary) -> void:
	var command: EventCommand = item["command"]
	if command == null:
		return
	var copy := command.duplicate(true) as EventCommand
	var list: Array = item["list"]
	insert_command(list, int(item["index"]) + 1, copy, L10n.ui("story.undo.duplicate"))

## 在同一条列表里上移 / 下移（delta = -1 / +1）。
func move_item(item: Dictionary, delta: int) -> void:
	var list: Array = item["list"]
	var from_index := int(item["index"])
	var to_index := from_index + delta
	if to_index < 0 or to_index >= list.size():
		return
	var undo := _undo()
	if undo == null:
		_do_move(list, from_index, to_index)
		return
	undo.create_action(L10n.ui("story.undo.move"), UndoRedo.MERGE_DISABLE, page)
	undo.add_do_method(self, "_do_move", list, from_index, to_index)
	undo.add_undo_method(self, "_do_move", list, to_index, from_index)
	undo.commit_action()

func _do_move(target_list: Array, from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= target_list.size():
		return
	var command: EventCommand = target_list[from_index]
	target_list.remove_at(from_index)
	target_list.insert(clampi(to_index, 0, target_list.size()), command)
	changed.emit()

## 修改 show_text 的参数（speaker / text / auto_advance）。连续输入合并成一步。
func set_line_param(item: Dictionary, param: String, value: Variant) -> void:
	_set_param(int(item["index"]), item["command"], param, value)

func _set_param(_index: int, command: EventCommand, param: String, value: Variant) -> void:
	if command == null:
		return
	var old_value: Variant = command.params.get(param)
	if _values_equal(old_value, value):
		return
	command.params[param] = value
	command.emit_changed()
	changed.emit()
	var undo := _undo()
	if undo == null:
		return
	undo.create_action("%s:%s:%d" % [L10n.ui("story.undo.param"), param, command.get_instance_id()], UndoRedo.MERGE_ENDS, page)
	undo.add_do_method(self, "_apply_param", command, param, value)
	undo.add_undo_method(self, "_apply_param", command, param, old_value)
	undo.commit_action(false)

func _apply_param(command: EventCommand, param: String, value: Variant) -> void:
	if command == null:
		return
	command.params[param] = value
	command.emit_changed()
	changed.emit()

func _values_equal(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return a == b

## 修改条件分歧 / 状态指令的参数。
func set_condition_param(item: Dictionary, param: String, value: Variant) -> void:
	_set_param(int(item["index"]), item["command"], param, value)

func set_state_param(item: Dictionary, param: String, value: Variant) -> void:
	_set_param(int(item["index"]), item["command"], param, value)

# ── 选项块操作 ───────────────────────────────────────────

func choice_set_prompt(item: Dictionary, prompt: String) -> void:
	_set_param(int(item["index"]), item["command"], "prompt", prompt)

## 改选项文字：只动 options 数组，不改结构。
func choice_rename_option(item: Dictionary, option_index: int, text: String) -> void:
	var command: EventCommand = item["command"]
	var options: Array = command.params.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return
	var old_text := str(options[option_index])
	if old_text == text:
		return
	options[option_index] = text
	command.emit_changed()
	changed.emit()
	var undo := _undo()
	if undo == null:
		return
	undo.create_action("%s:%d" % [L10n.ui("story.undo.option"), option_index], UndoRedo.MERGE_ENDS, page)
	undo.add_do_method(self, "_apply_option", command, option_index, text)
	undo.add_undo_method(self, "_apply_option", command, option_index, old_text)
	undo.commit_action(false)

func _apply_option(command: EventCommand, option_index: int, text: String) -> void:
	var options: Array = command.params.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return
	options[option_index] = text
	command.emit_changed()
	changed.emit()

## 新增选项：改写成顺序式（原分支内容原样搬移）。
func choice_add_option(item: Dictionary, text: String) -> bool:
	if not bool(item.get("well_formed", false)):
		return false
	var command: EventCommand = item["command"]
	var options: Array = []
	for entry in item["options"]:
		options.append(str(entry))
	options.append(text)
	var branch_contents := _collect_branch_contents(item, options.size() - 1)
	_rebuild_choice(item, command, options, branch_contents, L10n.ui("story.undo.choice_add"))
	return true

## 删除选项：连分支一起删，后面的分支内容前移。
func choice_remove_option(item: Dictionary, option_index: int) -> bool:
	if not bool(item.get("well_formed", false)):
		return false
	var command: EventCommand = item["command"]
	var options: Array = []
	for entry in item["options"]:
		options.append(str(entry))
	if option_index < 0 or option_index >= options.size():
		return false
	var original_count := options.size()
	options.remove_at(option_index)
	# 先收集「删除前」全部选项的分支内容，再摘掉被删选项那一段；
	# 若先按新选项数截断再按原下标删除，会越界并丢失后面选项的分支。
	var branch_contents := _collect_branch_contents(item, original_count)
	if option_index < branch_contents.size():
		branch_contents.remove_at(option_index)
	_rebuild_choice(item, command, options, branch_contents, L10n.ui("story.undo.choice_remove"))
	return true

## 交换两个选项（文字与分支内容一起换）。
func choice_move_option(item: Dictionary, option_index: int, delta: int) -> bool:
	if not bool(item.get("well_formed", false)):
		return false
	var target := option_index + delta
	var options: Array = item["command"].params.get("options", [])
	if target < 0 or target >= options.size():
		return false
	var branches: Array = item["branches"]
	if branches[option_index] == null or branches[target] == null:
		return false
	var command: EventCommand = item["command"]
	var list_a: Array = branches[option_index]
	var list_b: Array = branches[target]
	# 交换是自反操作：do / undo 用同一组参数（两个分支数组都是活引用）。
	var undo := _undo()
	if undo == null:
		_do_swap_option(command, option_index, target, list_a, list_b)
		return true
	undo.create_action(L10n.ui("story.undo.choice_move"), UndoRedo.MERGE_DISABLE, page)
	undo.add_do_method(self, "_do_swap_option", command, option_index, target, list_a, list_b)
	undo.add_undo_method(self, "_do_swap_option", command, option_index, target, list_a, list_b)
	undo.commit_action()
	return true

func _do_swap_option(command: EventCommand, a: int, b: int, list_a: Array, list_b: Array) -> void:
	var options: Array = command.params.get("options", [])
	if a < 0 or a >= options.size() or b < 0 or b >= options.size():
		return
	var text: Variant = options[a]
	options[a] = options[b]
	options[b] = text
	var contents_a := list_a.duplicate()
	list_a.clear()
	for entry in list_b:
		list_a.append(entry)
	list_b.clear()
	for entry in contents_a:
		list_b.append(entry)
	command.emit_changed()
	changed.emit()

## 给还没有分支的选项块生成分支（改写成顺序式，全部分支为空）。
func choice_ensure_branches(item: Dictionary) -> bool:
	if not bool(item.get("well_formed", false)):
		return false
	var command: EventCommand = item["command"]
	var options: Array = []
	for entry in item["options"]:
		options.append(str(entry))
	if options.is_empty():
		return false
	_rebuild_choice(item, command, options, [], L10n.ui("story.undo.choice_branches"))
	return true

## 收集前 option_count 个选项当前的分支内容（引用原命令对象，不深拷贝）。
func _collect_branch_contents(item: Dictionary, option_count: int) -> Array:
	var branches: Array = item["branches"]
	var out: Array = []
	for option_index in option_count:
		var contents: Array = []
		if option_index < branches.size() and branches[option_index] is Array:
			for entry in branches[option_index]:
				contents.append(entry)
		out.append(contents)
	return out

## 把选项块改写成顺序式：show_choices + 每个选项一个 if @@self.choice == k。
func _rebuild_choice(item: Dictionary, command: EventCommand, options: Array, branch_contents: Array, undo_name: String) -> void:
	var list: Array = item["list"]
	var index := int(item["index"])
	var consumed := int(item.get("consumed", 1))

	# 原切片备份（undo 用），并从原 if 节点把分支内容摘出来复用
	var originals: Array = []
	for offset in consumed:
		if index + offset < list.size():
			originals.append(list[index + offset])

	var rebuilt: Array = []
	var new_show := command.duplicate() as EventCommand
	new_show.params["options"] = options
	rebuilt.append(new_show)
	for option_index in options.size():
		var branch := CommandRegistry.create_command(&"if")
		branch.params["key"] = CHOICE_STATE
		branch.params["op"] = "=="
		branch.params["value"] = str(option_index)
		if option_index < branch_contents.size():
			for entry in branch_contents[option_index]:
				branch.children.append(entry)
		rebuilt.append(branch)

	var undo := _undo()
	if undo == null:
		_do_replace_slice(list, index, originals, rebuilt)
		return
	undo.create_action(undo_name, UndoRedo.MERGE_DISABLE, page)
	undo.add_do_method(self, "_do_replace_slice", list, index, originals, rebuilt)
	undo.add_undo_method(self, "_do_replace_slice", list, index, rebuilt, originals)
	for entry in rebuilt:
		undo.add_do_reference(entry)
	for entry in originals:
		undo.add_undo_reference(entry)
	undo.commit_action()

func _do_replace_slice(target_list: Array, index: int, remove_list: Array, insert_list: Array) -> void:
	# remove_list / insert_list 是命令对象数组：先按对象逐个移除，再按对象逐个插入。
	for entry in remove_list:
		var at := target_list.find(entry)
		if at >= 0:
			target_list.remove_at(at)
	var at_index := clampi(index, 0, target_list.size())
	for entry in insert_list:
		target_list.insert(at_index, entry)
		at_index += 1
	changed.emit()

# ── 汇总信息（预览 / 诊断用） ─────────────────────────────

static func collect_texts(items: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for item in items:
		match str(item.get("kind", "")):
			"line":
				out.append(str(item["command"].params.get("text", "")))
			"choice":
				out.append(str(item["command"].params.get("prompt", "")))
				for option in item["options"]:
					out.append(str(option))
				for view in item["option_views"]:
					out.append_array(collect_texts(view))
			"condition":
				out.append_array(collect_texts(item["children_view"]))
				out.append_array(collect_texts(item["else_view"]))
	return out
