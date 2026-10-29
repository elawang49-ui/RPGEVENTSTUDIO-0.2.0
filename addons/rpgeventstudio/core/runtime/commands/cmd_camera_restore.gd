@tool
class_name CmdCameraRestore
extends CommandHandler
## 镜头恢复跟随玩家（把 focus_offset 拉回 0）。

func execute(ctx: EventContext) -> int:
	var camera := ctx.resolve_camera()
	if camera == null or not ("focus_offset" in camera):
		ctx.log("恢复镜头：场景里没有可用的 Camera2D")
		return CmdResult.CONTINUE

	var duration := maxf(float(ctx.get_param("duration", 0.8)), 0.01)
	var finished := [false]
	var tween := camera.create_tween()
	tween.tween_property(camera, "focus_offset", Vector2.ZERO, duration)
	tween.finished.connect(func() -> void: finished[0] = true)
	ctx.on_cancel(func() -> void:
		if tween != null and tween.is_valid():
			tween.kill()
		if is_instance_valid(camera):
			camera.set("focus_offset", Vector2.ZERO)
	)

	if not bool(ctx.get_param("wait", true)):
		return CmdResult.CONTINUE
	ctx.wait_until(func() -> bool: return finished[0])
	return CmdResult.WAIT
