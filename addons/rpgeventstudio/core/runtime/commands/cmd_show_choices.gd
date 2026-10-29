@tool
class_name CmdShowChoices
extends CommandHandler
## 显示选项：结果写入 @@self.choice（0 起）。键盘上下 / 手柄十字键 / 鼠标都能选。

func execute(ctx: EventContext) -> int:
	var prompt := str(ctx.get_param("prompt", ""))
	var options := _parse_options(ctx.get_param("options", []))

	if ctx.presenter == null or options.is_empty():
		ctx.set_state("@@self.choice", 0)
		return CmdResult.CONTINUE

	ctx.presenter.show_choices(prompt, options)
	ctx.wait_until(
		func() -> bool: return ctx.presenter.get_choice() >= 0,
		-1.0,
		func() -> void: ctx.set_state("@@self.choice", ctx.presenter.get_choice())
	)
	return CmdResult.WAIT

func _parse_options(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for item in raw:
			var text := str(item).strip_edges()
			if text != "":
				out.append(text)
	elif raw is String:
		for line in String(raw).split("\n", false):
			var text := line.strip_edges()
			if text != "":
				out.append(text)
	return out
