@tool
class_name CmdShowText
extends CommandHandler
## 显示文字：带打字机效果，等待玩家按键 / 鼠标点击 / 手柄 A 继续。

func execute(ctx: EventContext) -> int:
	var speaker := str(ctx.get_param("speaker", ""))
	var text := str(ctx.get_param("text", ""))
	var auto_advance := float(ctx.get_param("auto_advance", 0.0))

	if ctx.presenter == null:
		ctx.log(L10n.game("diag.no_presenter"))
		return CmdResult.CONTINUE

	ctx.presenter.show_text(speaker, text, auto_advance)
	ctx.wait_until(func() -> bool: return ctx.presenter.is_text_finished())
	return CmdResult.WAIT
