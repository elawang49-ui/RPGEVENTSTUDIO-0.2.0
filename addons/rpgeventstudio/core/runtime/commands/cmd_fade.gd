@tool
class_name CmdFade
extends CommandHandler
## 画面淡入淡出。取消时立刻清掉遮罩，避免游戏黑屏卡死。

func execute(ctx: EventContext) -> int:
	if ctx.presenter == null:
		return CmdResult.CONTINUE
	if not ctx.presenter.has_method("fade_to"):
		# 自定义展示层可以明确不支持淡入淡出：跳过并在调试日志里说明，不假装已执行。
		ctx.log("当前展示层不支持 fade_to，跳过淡入淡出")
		return CmdResult.CONTINUE

	var mode := str(ctx.get_param("mode", "out"))
	var alpha := 1.0 if mode == "out" else 0.0
	var duration := maxf(float(ctx.get_param("duration", 0.4)), 0.0)
	var tween: Tween = ctx.presenter.fade_to(alpha, duration)

	ctx.on_cancel(func() -> void:
		if tween != null and tween.is_valid():
			tween.kill()
		ctx.presenter.clear_fade()
	)

	if tween == null or not bool(ctx.get_param("wait", true)):
		return CmdResult.CONTINUE

	var finished := [false]
	tween.finished.connect(func() -> void: finished[0] = true)
	ctx.wait_until(func() -> bool: return finished[0])
	return CmdResult.WAIT
