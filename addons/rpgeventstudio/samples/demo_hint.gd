extends Label
## 演示场景顶部的操作提示，跟随语言设置切换。

func _process(_delta: float) -> void:
	var text_value := L10n.game("sample.hint")
	if text != text_value:
		text = text_value
