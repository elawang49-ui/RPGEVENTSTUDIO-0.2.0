extends SceneTree
## 空引用错误：运行器必须判 FAIL，即使后面手动打印了 PASS 汇总。

func _init() -> void:
	var missing: Node = null
	missing.name = "boom"
	print("检查项：0，失败：0")
	print("RESULT: PASS")
	quit(0)
