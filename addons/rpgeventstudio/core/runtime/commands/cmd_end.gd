@tool
class_name CmdEnd
extends CommandHandler
## 结束事件。

func execute(_ctx: EventContext) -> int:
	return CmdResult.HALT
