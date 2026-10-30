extends SceneTree
## 断言失败但进程不崩：运行器必须依据汇总判 FAIL。

func _init() -> void:
	print("  ✗ 这是一个失败的断言")
	print("检查项：1，失败：1")
	print("RESULT: FAIL")
	quit(1)
