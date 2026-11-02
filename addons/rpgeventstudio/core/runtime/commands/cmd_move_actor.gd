@tool
class_name CmdMoveActor
extends CommandHandler
## 移动角色：相对当前位置偏移，可选等待完成；被取消时会停下并保留当前位置。

func execute(ctx: EventContext) -> int:
	var path := str(ctx.get_param("actor", ""))
	var resolved := ctx.resolve_scene_object(str(ctx.get_param("actor_scene", "")), path)
	var actor := resolved.get("node") as Node2D
	if actor == null:
		ctx.log("移动角色：找不到 %s（%s）" % [path, str(resolved.get("error", ""))])
		return CmdResult.CONTINUE

	var offset := Vector2(float(ctx.get_param("offset_x", 0.0)), float(ctx.get_param("offset_y", 0.0)))
	var duration := maxf(float(ctx.get_param("duration", 0.6)), 0.01)
	var destination := actor.global_position + offset

	var finished := [false]
	var tween := actor.create_tween()
	tween.tween_property(actor, "global_position", destination, duration)
	tween.finished.connect(func() -> void: finished[0] = true)
	ctx.on_cancel(func() -> void:
		if tween != null and tween.is_valid():
			tween.kill()
	)

	if not bool(ctx.get_param("wait", true)):
		return CmdResult.CONTINUE
	ctx.wait_until(func() -> bool:
		if not is_instance_valid(actor):
			ctx.cancel("scene object released")
			return true
		return finished[0]
	)
	return CmdResult.WAIT
