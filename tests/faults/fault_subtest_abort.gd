extends SceneTree
## 子测试运行时中断，但主流程仍打印 PASS 汇总：运行器必须依据 SCRIPT ERROR 判 FAIL。

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_broken_subtest()
	print("检查项：1，失败：0")
	print("RESULT: PASS")
	quit(0)

func _broken_subtest() -> void:
	var bad: Dictionary = JSON.parse_string("[]")
	print("unreachable ", bad)
