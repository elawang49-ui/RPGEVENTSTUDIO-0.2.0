extends SceneTree
## 主题「重新加载」缓存回归测试（P1 主题重载）：
##   godot --headless --path . --script res://tests/theme_reload_test.gd
## 编辑器保存走 ResourceSaver.save(内存实例)，资源缓存里留的是同一个（可能已改动的）对象；
## 「重新加载」必须以 CACHE_MODE_REPLACE 强制读盘，否则永远拿不到磁盘上的外部修改。

const TEST_THEME_PATH := "res://.godot/test_theme_reload.tres"
const DEFAULT_THEME_PATH := "res://ui/rpgeventstudio_theme.tres"

var _checks := 0
var _failures: PackedStringArray = []
var _ui_dir_created_by_test := false
var _default_theme_created_by_test := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var ui_dir := ProjectSettings.globalize_path("res://ui")
	_ui_dir_created_by_test = not DirAccess.dir_exists_absolute(ui_dir)
	_default_theme_created_by_test = not ResourceLoader.exists(DEFAULT_THEME_PATH)

	# 先把主题写到磁盘，再实例化主题页，让 _ready 走真实加载路径
	_write_theme_to_disk(33, TEST_THEME_PATH)
	var host := Node.new()
	host.name = "ThemeReloadHost"
	root.add_child(host)
	var view: Control = load("res://addons/rpgeventstudio/editor/theme/dialogue_theme_view.gd").new()
	view.theme_path = TEST_THEME_PATH
	host.add_child(view)
	await process_frame
	_check(view.get("_theme") != null, "主题页应能在 headless 下完成构建并载入主题")
	var initial: Resource = view.get("_theme")
	_check(initial != null and int(initial.get("text_font_size")) == 33,
		"初始加载应读到磁盘值 33（实际 %s）" % str(initial.get("text_font_size") if initial != null else "null"))

	await _test_reload_reads_disk_after_external_change(view)
	await _test_save_then_reload_consistent(view)
	await _test_reload_forwards_to_runtime(view)

	_cleanup(view)
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 用例 ─────────────────────────────────────────────────

## 1) 加载 → 内存改值并保存 → 外部改写磁盘 → 重新加载应拿到磁盘新值。
##    （修复前：load() 走 CACHE_MODE_REUSE 返回缓存里的脏对象 44，红灯）
func _test_reload_reads_disk_after_external_change(view: Control) -> void:
	var theme: Resource = view.get("_theme")
	theme.set("text_font_size", 44)
	view.call("_save_theme")
	_check(_disk_font_size(TEST_THEME_PATH) == 44, "保存后磁盘应是 44（实际 %d）" % _disk_font_size(TEST_THEME_PATH))

	# 外部（编辑器之外）直接改写磁盘文件为另一个值
	_write_theme_to_disk(55, TEST_THEME_PATH)
	_check(_disk_font_size(TEST_THEME_PATH) == 55, "外部改写后磁盘应是 55（实际 %d）" % _disk_font_size(TEST_THEME_PATH))

	view.call("_reload_theme")
	var reloaded: Resource = view.get("_theme")
	_check(reloaded != null and int(reloaded.get("text_font_size")) == 55,
		"重新加载应读到磁盘新值 55（实际 %s）" % str(reloaded.get("text_font_size") if reloaded != null else "null"))

## 2) 不回归：保存 → 重新加载应得到相同内容。
func _test_save_then_reload_consistent(view: Control) -> void:
	var theme: Resource = view.get("_theme")
	theme.set("text_font_size", 66)
	view.call("_save_theme")
	_check(_disk_font_size(TEST_THEME_PATH) == 66, "保存后磁盘应是 66（实际 %d）" % _disk_font_size(TEST_THEME_PATH))
	view.call("_reload_theme")
	var reloaded: Resource = view.get("_theme")
	_check(reloaded != null and int(reloaded.get("text_font_size")) == 66,
		"保存后重新加载应得到相同内容 66（实际 %s）" % str(reloaded.get("text_font_size") if reloaded != null else "null"))

## 3) 全链路不回归：默认路径下「重新加载」应把读盘得到的新对象转发给运行时。
func _test_reload_forwards_to_runtime(view: Control) -> void:
	var runtime: Node = root.get_node_or_null("RPGEventStudio")
	_check(runtime != null, "运行时 Autoload 应可用于验证转发")
	if runtime == null:
		return
	_write_theme_to_disk(77, DEFAULT_THEME_PATH)
	view.theme_path = DialogueThemeView.THEME_PATH
	view.call("_reload_theme")
	var forwarded: Resource = runtime.get("dialogue_theme")
	var view_theme: Resource = view.get("_theme")
	_check(forwarded != null and forwarded == view_theme,
		"重新加载应把新主题对象转发给运行时（apply_dialogue_theme）")
	_check(forwarded != null and int(forwarded.get("text_font_size")) == 77,
		"转发给运行时的应是磁盘新值 77（实际 %s）" % str(forwarded.get("text_font_size") if forwarded != null else "null"))
	# 恢复运行时状态，避免残留影响同进程的后续检查
	runtime.call("reload_dialogue_theme")

# ── 工具 ─────────────────────────────────────────────────

func _write_theme_to_disk(font_size: int, path: String) -> void:
	var theme := RpgEventStudioTheme.new()
	theme.set("text_font_size", font_size)
	var error := ResourceSaver.save(theme, path)
	if error != OK:
		_check(false, "无法写入测试主题文件 %s（错误码 %d）" % [path, error])

func _disk_font_size(path: String) -> int:
	var fresh: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if fresh == null:
		return -1
	return int(fresh.get("text_font_size"))

func _cleanup(view: Control) -> void:
	view.queue_free()
	_remove_file(TEST_THEME_PATH)
	if _default_theme_created_by_test:
		_remove_file(DEFAULT_THEME_PATH)
	# _save_theme 会无条件确保 res://ui 存在；若本测试创建了空目录则移除，保持工作区干净
	var ui_dir := ProjectSettings.globalize_path("res://ui")
	if _ui_dir_created_by_test and DirAccess.dir_exists_absolute(ui_dir):
		if DirAccess.get_files_at(ui_dir).is_empty():
			DirAccess.remove_absolute(ui_dir)

func _remove_file(path: String) -> void:
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 主题重载测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
