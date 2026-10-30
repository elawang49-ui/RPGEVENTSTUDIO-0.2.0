extends SceneTree
## 故意不输出最终汇总：运行器必须判 FAIL。

func _init() -> void:
	print("这个脚本执行了，但没有最终汇总。")
	quit(0)
