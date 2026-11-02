@tool
class_name CmdCameraFocus
extends CommandHandler
## 镜头聚焦到某个对象（或玩家），可选等待镜头移动完成。
## 需要场景里的 Camera2D 提供 focus_offset 属性（演示里的 demo_camera.gd 就有）。

func execute(ctx: EventContext) -> int:
	var camera := ctx.resolve_camera()
	if camera == null:
		ctx.log("镜头聚焦：场景里没有 Camera2D")
		return CmdResult.CONTINUE
	if not ("focus_offset" in camera):
		ctx.log("镜头聚焦：摄像机没有 focus_offset 属性")
		return CmdResult.CONTINUE

	var path := str(ctx.get_param("target", ""))
	var actor: Node2D = null
	if path.strip_edges() == "":
		actor = ctx.resolve_player()
	else:
		var resolved := ctx.resolve_scene_object(str(ctx.get_param("target_scene", "")), path)
		actor = resolved.get("node") as Node2D
	if actor == null:
		ctx.log("镜头聚焦：找不到目标 %s" % path)
		return CmdResult.CONTINUE

	var player := ctx.resolve_player()
	var anchor: Vector2 = player.global_position if player != null else camera.global_position
	var offset := Vector2(float(ctx.get_param("offset_x", 0.0)), float(ctx.get_param("offset_y", 0.0)))
	var target_offset := actor.global_position + offset - anchor
	var duration := maxf(float(ctx.get_param("duration", 0.8)), 0.01)

	var finished := [false]
	var tween := camera.create_tween()
	tween.tween_property(camera, "focus_offset", target_offset, duration)
	tween.finished.connect(func() -> void: finished[0] = true)
	ctx.on_cancel(func() -> void:
		if tween != null and tween.is_valid():
			tween.kill()
		if is_instance_valid(camera):
			camera.set("focus_offset", Vector2.ZERO)
	)

	if not bool(ctx.get_param("wait", true)):
		return CmdResult.CONTINUE
	ctx.wait_until(func() -> bool:
		if not is_instance_valid(camera):
			ctx.cancel("scene object released")
			return true
		return finished[0]
	)
	return CmdResult.WAIT
