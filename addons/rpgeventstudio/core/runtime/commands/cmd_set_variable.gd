@tool
class_name CmdSetVariable
extends CommandHandler
## 设置变量（数字 / 文本 / 布尔）。

func execute(ctx: EventContext) -> int:
	var key := str(ctx.get_param("key", ""))
	if key.strip_edges() == "":
		ctx.log(L10n.game("diag.no_key"))
		return CmdResult.CONTINUE
	var value: Variant = ctx.get_param("value", 0)
	if value is String:
		value = ValueParser.parse(value)
	ctx.set_state(key, value)
	return CmdResult.CONTINUE
