@tool
class_name CmdShowText
extends CommandHandler
## 显示文字：带打字机效果，等待玩家按键 / 鼠标点击 / 手柄 A 继续。

func execute(ctx: EventContext) -> int:
	var speaker := str(ctx.get_param("speaker", ""))
	var text := str(ctx.get_param("text", ""))
	var auto_advance := float(ctx.get_param("auto_advance", 0.0))

	if ctx.presenter == null or not is_instance_valid(ctx.presenter):
		# 展示层缺失或已随场景释放：按「无展示层」处理，事件继续往下走。
		ctx.log(L10n.game("diag.no_presenter"))
		return CmdResult.CONTINUE

	ctx.presenter.show_text(speaker, text, auto_advance)
	ctx.wait_until(func() -> bool:
		if ctx.presenter == null or not is_instance_valid(ctx.presenter):
			# 等待期间展示层被释放（如切场景 queue_free）：视为等待完成并取消事件，
			# 否则对已释放实例逐帧报错且永不满足，事件卡死、全场交互被锁。
			ctx.cancel("presenter 已释放")
			return true
		return ctx.presenter.is_text_finished()
	)
	return CmdResult.WAIT
