@tool
class_name CmdWait
extends CommandHandler
## 等待固定秒数。

func execute(ctx: EventContext) -> int:
	var seconds := float(ctx.get_param("seconds", 1.0))
	if seconds <= 0.0:
		return CmdResult.CONTINUE
	ctx.wait_seconds(seconds)
	return CmdResult.WAIT
