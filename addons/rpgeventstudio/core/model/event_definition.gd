@tool
class_name EventDefinition
extends Resource
## 一个事件的完整定义：可以有多页，页序号越大优先级越高。

@export var event_id: StringName = &"event"
@export var display_name: String = "新事件"
@export var pages: Array[EventPage] = []
@export var notes: String = ""
@export var schema_version: int = 1

## 取当前生效的页：从后往前找第一个条件全部满足的页。没有则返回 -1。
## trigger_filter 非空时，只考虑触发方式在其中的页（交互组件/自动事件靠它区分）。
func get_active_page(store: StateStore, trigger_filter: Array = []) -> int:
	for index in range(pages.size() - 1, -1, -1):
		var page: EventPage = pages[index]
		if page == null:
			continue
		if not trigger_filter.is_empty() and not matches_trigger(page, trigger_filter):
			continue
		if page.is_active(store):
			return index
	return -1

func matches_trigger(page: EventPage, trigger_filter: Array) -> bool:
	for wanted in trigger_filter:
		if String(wanted) == page.trigger:
			return true
	return false

func add_page() -> EventPage:
	var page := EventPage.new()
	pages.append(page)
	emit_changed()
	return page

func remove_page(index: int) -> void:
	if index < 0 or index >= pages.size():
		return
	pages.remove_at(index)
	emit_changed()

func summary() -> String:
	return "%s（%d 页）" % [display_name, pages.size()]

# Internal undo endpoint: redo restores the exact same page Resources.
func _replace_pages(replacement: Array) -> void:
	pages.assign(replacement)
	emit_changed()
