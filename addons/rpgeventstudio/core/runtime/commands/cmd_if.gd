@tool
class_name CmdIf
extends CommandHandler
## 条件分歧：满足走 children，不满足走 else_children。

func execute(ctx: EventContext) -> int:
	var key := str(ctx.get_param("key", ""))
	var command := ctx.command
	if command == null:
		return CmdResult.CONTINUE

	if key.strip_edges() == "":
		ctx.pending_block = command.children
		return CmdResult.ENTER_BLOCK

	var op := str(ctx.get_param("op", "=="))
	var expected := ValueParser.parse(str(ctx.get_param("value", "true")))
	# 实际值只用于追踪展示；compare 本身不读第二遍，执行语义不变。
	var actual: Variant = ctx.get_state(key, null)
	var matched := ctx.compare_state(key, op, expected)
	ctx.trace_condition(key, op, expected, actual, matched, "then" if matched else "else")
	ctx.pending_block = command.children if matched else command.else_children
	return CmdResult.ENTER_BLOCK
