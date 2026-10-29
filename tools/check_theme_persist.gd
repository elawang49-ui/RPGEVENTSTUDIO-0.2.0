extends SceneTree
## 主题资源跨进程持久化检查：
##   THEME_PERSIST_MODE=create  -> 写入 res://ui/rpgeventstudio_theme.tres
##   THEME_PERSIST_MODE=verify  -> 新进程里读取 Autoload 的主题
##   THEME_PERSIST_MODE=cleanup -> 删除测试主题
const PATH := "res://ui/rpgeventstudio_theme.tres"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var mode := OS.get_environment("THEME_PERSIST_MODE")
	match mode:
		"create":
			var theme := RpgEventStudioTheme.new()
			theme.text_speed = 77.0
			theme.panel_bg_color = Color(0.10, 0.26, 0.16, 0.94)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui"))
			var error := ResourceSaver.save(theme, PATH)
			print("THEME_CREATE=", error)
			quit(0 if error == OK else 1)
		"verify":
			var runtime := root.get_node_or_null("RPGEventStudio")
			if runtime == null:
				print("THEME_VERIFY=NO_RUNTIME")
				quit(2)
				return
			var theme: RpgEventStudioTheme = runtime.get("dialogue_theme")
			var presenter = runtime.get("default_presenter")
			var ok := theme != null and is_equal_approx(theme.text_speed, 77.0) and presenter != null and is_equal_approx(presenter.get("style").text_speed, 77.0)
			print("THEME_VERIFY=", ok, " speed=", theme.text_speed if theme != null else -1)
			quit(0 if ok else 1)
		"cleanup":
			if FileAccess.file_exists(PATH):
				DirAccess.remove_absolute(PATH)
			if DirAccess.dir_exists_absolute("res://ui"):
				DirAccess.remove_absolute("res://ui")
			print("THEME_CLEANUP=ok")
			quit(0)
		_:
			print("THEME_MODE_MISSING")
			quit(2)
