@tool
extends RefCounted
## Undo targets outlive editor panels. Only a WeakRef points back to the view.
## Data mutations belong to resources; closing/reopening a panel cannot retarget undo.

func _refresh(definition: EventDefinition, view: WeakRef, selected: int = -1, notify: bool = true) -> void:
	if notify:
		definition.emit_changed()
	var panel = view.get_ref() if view != null else null
	if is_instance_valid(panel) and panel.get("_definition") == definition:
		if selected >= 0:
			panel.set("_page_index", selected)
		panel.call("_refresh_all")

func replace_pages(definition: EventDefinition, pages: Array, selected: int, view: WeakRef) -> void:
	definition._replace_pages(pages)
	_refresh(definition, view, clampi(selected, 0, maxi(0, pages.size() - 1)), false)

func insert_command(page: EventPage, list: Array, index: int, command: EventCommand, definition: EventDefinition, view: WeakRef) -> void:
	if is_same(list, page.commands):
		page.insert_command(index, command)
	else:
		var commands := list.duplicate()
		commands.insert(clampi(index, 0, commands.size()), command)
		page._replace_list(list, commands)
	_refresh(definition, view)

func remove_command(page: EventPage, list: Array, index: int, definition: EventDefinition, view: WeakRef) -> void:
	if is_same(list, page.commands):
		page.remove_command(index)
	elif index >= 0 and index < list.size():
		var commands := list.duplicate()
		commands.remove_at(index)
		page._replace_list(list, commands)
	_refresh(definition, view)

func move_command(page: EventPage, list: Array, from: int, to: int, definition: EventDefinition, view: WeakRef) -> void:
	if is_same(list, page.commands):
		page.move_command(from, to)
	elif from >= 0 and from < list.size():
		var commands := list.duplicate()
		var command: EventCommand = commands.pop_at(from)
		commands.insert(clampi(to, 0, commands.size()), command)
		page._replace_list(list, commands)
	_refresh(definition, view)

func set_page_property(definition: EventDefinition, target: Resource, property: String, value: Variant, view: WeakRef) -> void:
	target.set(property, value)
	target.emit_changed()
	_refresh(definition, view)

func set_command_param(definition: EventDefinition, command: EventCommand, parameter: String, value: Variant, view: WeakRef) -> void:
	command.set_param(parameter, value)
	_refresh(definition, view)

func cross_move(page: EventPage, from_list: Array, from: int, to_list: Array, to: int, definition: EventDefinition, view: WeakRef) -> void:
	if from >= 0 and from < from_list.size():
		var command: EventCommand = from_list[from]
		from_list.remove_at(from)
		to_list.insert(clampi(to, 0, to_list.size()), command)
		page.emit_changed()
	_refresh(definition, view)
