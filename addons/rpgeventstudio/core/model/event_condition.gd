@tool
class_name EventCondition
extends Resource
## 一条「出现条件」：某个状态 与 某个值 比较。一个事件页里多条条件是「并且」。

@export var key: String = ""              ## 状态名，如 School.Stage / Global.Player.HasKey
@export_enum("==", "!=", ">", ">=", "<", "<=") var op: String = "=="
@export var value: Variant = true

func describe() -> String:
	return "%s %s %s" % [key if key != "" else L10n.ui("editor.unset"), op, _value_text()]

func _value_text() -> String:
	if value is bool:
		return "ON" if value else "OFF"
	return str(value)

func evaluate(store: StateStore) -> bool:
	if key.strip_edges() == "":
		return true
	# 未定义的状态按「false / 0 / 空」参与比较：
	# 这样 `X == false` 在 X 还没被写过时依然成立（新建事件的常见写法）
	return store.compare(StateStore.resolve_key(key, store.level_prefix), op, value)
