@tool
class_name CmdSetSwitch
extends CommandHandler
## 设置开关（布尔状态）。

func execute(ctx: EventContext) -> int:
	var key := str(ctx.get_param("key", ""))
	if key.strip_edges() == "":
		ctx.log(L10n.game("diag.no_key"))
		return CmdResult.CONTINUE
	return CmdResult.CONTINUE if ctx.set_state(key, bool(ctx.get_param("value", true))) == OK else CmdResult.ABORT
