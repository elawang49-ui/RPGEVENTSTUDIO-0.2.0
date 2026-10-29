@tool
class_name CmdPlaySfx
extends CommandHandler
## 播放音效：优先交给宿主（Autoload）统一播放，宿主不在时自行播放。

func execute(ctx: EventContext) -> int:
	var path := str(ctx.get_param("sound_path", ""))
	if path == "" or not ResourceLoader.exists(path):
		ctx.log(L10n.game("diag.sfx_missing", {"path": path}))
		return CmdResult.CONTINUE
	var volume := float(ctx.get_param("volume_db", 0.0))
	if ctx.host != null and ctx.host.has_method("play_sfx"):
		ctx.host.call("play_sfx", path, volume)
	if bool(ctx.get_param("wait", false)) and ctx.host != null and ctx.host.has_method("is_sfx_playing"):
		ctx.wait_until(func() -> bool: return not bool(ctx.host.call("is_sfx_playing")))
		return CmdResult.WAIT
	return CmdResult.CONTINUE
