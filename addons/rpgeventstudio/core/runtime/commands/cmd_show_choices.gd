@tool
class_name CmdShowChoices
extends CommandHandler
## 显示选项：结果写入 @@self.choice（0 起）。键盘上下 / 手柄十字键 / 鼠标都能选。

func execute(ctx: EventContext) -> int:
	var prompt := str(ctx.get_param("prompt", ""))
	var options := _parse_options(ctx.get_param("options", []))

	if ctx.presenter == null or not is_instance_valid(ctx.presenter) or options.is_empty():
		ctx.set_state("@@self.choice", 0)
		return CmdResult.CONTINUE

	ctx.presenter.show_choices(prompt, options)
	ctx.wait_until(
		func() -> bool:
			if ctx.presenter == null or not is_instance_valid(ctx.presenter):
				# 等待期间展示层被释放：视为选择完成并取消事件，避免悬空调用卡死等待。
				ctx.cancel("presenter 已释放")
				return true
			return ctx.presenter.get_choice() >= 0,
		-1.0,
		func() -> void:
			# 取消（含展示层已释放）时不再向状态库写选择结果。
			if ctx.presenter != null and is_instance_valid(ctx.presenter):
				ctx.set_state("@@self.choice", ctx.presenter.get_choice())
	)
	return CmdResult.WAIT

func _parse_options(raw: Variant) -> Array:
	return EventCommand._choice_options(raw)
