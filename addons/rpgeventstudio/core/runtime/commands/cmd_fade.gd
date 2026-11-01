@tool
class_name CmdFade
extends CommandHandler
## 画面淡入淡出。取消时立刻清掉遮罩，避免游戏黑屏卡死。

func execute(ctx: EventContext) -> int:
	if ctx.presenter == null or not is_instance_valid(ctx.presenter):
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
		if ctx.presenter != null and is_instance_valid(ctx.presenter) and ctx.presenter.has_method("clear_fade"):
			ctx.presenter.clear_fade()
	)

	if tween == null or not bool(ctx.get_param("wait", true)):
		return CmdResult.CONTINUE

	var finished := [false]
	tween.finished.connect(func() -> void: finished[0] = true)
	ctx.wait_until(func() -> bool:
		if ctx.presenter == null or not is_instance_valid(ctx.presenter):
			# 展示层被释放时 tween 会随之失效、finished 不再发出：视为等待完成并取消事件。
			ctx.cancel("presenter 已释放")
			return true
		return finished[0]
	)
	return CmdResult.WAIT
