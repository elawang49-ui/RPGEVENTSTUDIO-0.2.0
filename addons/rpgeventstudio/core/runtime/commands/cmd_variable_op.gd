@tool
class_name CmdVariableOp
extends CommandHandler
## 变量加减乘除。

func execute(ctx: EventContext) -> int:
	var key := str(ctx.get_param("key", ""))
	if key.strip_edges() == "":
		return CmdResult.CONTINUE
	var current := ValueParser.to_number(ctx.get_state(key, 0))
	var operand := ValueParser.to_number(ctx.get_param("value", 1.0))
	var result := current
	match str(ctx.get_param("op", "+")):
		"+": result = current + operand
		"-": result = current - operand
		"*": result = current * operand
		"/":
			if is_zero_approx(operand):
				ctx.log(L10n.game("diag.divide_zero"))
				return CmdResult.CONTINUE
			result = current / operand
		_:
			return CmdResult.CONTINUE

	var declared := ctx.state.type_of(ctx.key(key))
	if declared == TYPE_INT:
		ctx.set_state(key, int(round(result)))
	elif declared == TYPE_FLOAT:
		ctx.set_state(key, result)
	else:
		ctx.set_state(key, int(round(result)) if is_equal_approx(result, round(result)) else result)
	return CmdResult.CONTINUE
