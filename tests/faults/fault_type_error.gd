extends SceneTree
## 运行时类型错误，脚本不会执行到汇总：运行器必须判 FAIL。

func _init() -> void:
	var bad: Dictionary = JSON.parse_string("[]")
	print("unreachable ", bad)
	print("检查项：0，失败：0")
	print("RESULT: PASS")
	quit(0)
