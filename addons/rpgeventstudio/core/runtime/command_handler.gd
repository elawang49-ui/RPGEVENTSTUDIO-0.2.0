@tool
class_name CommandHandler
extends RefCounted
## 指令处理器基类。execute() 必须同步返回 CmdResult，绝不允许 await —— 
## 异步（等对话、等计时、等动画）统一由 EventRunner 轮询 ctx 的等待条件完成。

func execute(_ctx: EventContext) -> int:
	return CmdResult.CONTINUE
