@tool
class_name StateCatalog
extends Resource
## 状态总表：每个状态一条定义。事件/图里只存 key，这里负责「名字」与「类型」。

@export var definitions: Array[StateDefinition] = []

func find(key: String) -> StateDefinition:
	for definition in definitions:
		if definition != null and definition.key == key:
			return definition
	return null

func display_name(key: String) -> String:
	var definition := find(key)
	if definition == null:
		return key
	return definition.label()

func ensure(key: String, type: String = "bool", default_value: Variant = false, category: String = "剧情") -> StateDefinition:
	var existing := find(key)
	if existing != null:
		return existing
	var definition := StateDefinition.new()
	definition.key = key
	definition.display_name = key
	definition.type = type
	definition.default_value = default_value
	definition.category = category
	definitions.append(definition)
	emit_changed()
	return definition

func remove(key: String) -> void:
	for index in range(definitions.size() - 1, -1, -1):
		if definitions[index] != null and definitions[index].key == key:
			definitions.remove_at(index)
	emit_changed()

func keys() -> Array[String]:
	var out: Array[String] = []
	for definition in definitions:
		if definition != null and definition.key != "":
			out.append(definition.key)
	return out

## 按分类分组，给选择器与调试面板用。
func grouped() -> Array:
	var groups: Array = []
	var index_by_category := {}
	for definition in definitions:
		if definition == null or definition.key == "":
			continue
		var category := definition.category if definition.category != "" else "剧情"
		if not index_by_category.has(category):
			index_by_category[category] = groups.size()
			groups.append({"category": category, "items": []})
		var group: Dictionary = groups[index_by_category[category]]
		group["items"].append(definition)
	return groups

func type_of(key: String) -> String:
	var definition := find(key)
	return definition.type if definition != null else ""
