@tool
extends Node
## 批量登记扫描夹具：故意使用一批未登记的状态键。
## 这个脚本只用于验证扫描规则（含动态引用），永远不会被实例化运行。

const SAVE_KEY := "Global.Script.Saved"

var _state := StateStore.new()

func _ready() -> void:
	var runtime := get_node_or_null("RPGEventStudio")
	if runtime != null:
		runtime.set_state("Global.Script.Started", true)
		runtime.set_state("Global.Script.Nickname", "无名氏")
		runtime.set_state("Global.Script.Counter", 3)
		print(runtime.get_bool("Global.Script.Live"))
	_state.set_value("Global.Script.Counter", 0)
	_state.add("Global.Script.Counter", 1)
	_state.define("Global.Script.Level", TYPE_INT, 0)
	_state.compare("Global.Script.Counter", ">=", 2)

func _dynamic_slot(slot: String) -> void:
	_state.set_value("Global.Script." + slot, true)

func _dynamic_format(id: int) -> void:
	_state.set_value("Global.%d" % id, false)

func _dynamic_variable(key: String) -> void:
	_state.set_value(key, 1)
