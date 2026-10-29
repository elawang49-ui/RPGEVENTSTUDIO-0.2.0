@tool
class_name CmdCallCommon
extends CommandHandler
## 调用公共事件（当前版本按资源路径加载，避免手动填 NodePath）。

func execute(ctx: EventContext) -> int:
	var path := str(ctx.get_param("common_path", ""))
	if path == "":
		ctx.log(L10n.game("diag.no_key"))
		return CmdResult.CONTINUE
	ctx.pending_call = {"kind": "common", "ref": path, "args": {}}
	return CmdResult.CALL
