extends SceneTree
## 第三轮验收：运行时对话框长文本翻页截图（无玩家可见滚动条）。
##   godot --path . --script res://tools/round3_scroll_shots.gd -- 1152 648
## 输出：docs/images/round3/scroll-fix/after/

const DEFAULT_OUT_DIR := "res://docs/images/round3/scroll-fix/after"

var _w := 1152
var _h := 648
var _out_dir := DEFAULT_OUT_DIR

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		_w = int(args[0])
		_h = int(args[1])
	var env_dir := OS.get_environment("ROUND3_SHOT_DIR").strip_edges()
	if env_dir != "":
		_out_dir = env_dir
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	var scene: Node = load("res://addons/rpgeventstudio/samples/scenes/school_demo.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.8).timeout
	var runtime := root.get_node_or_null("RPGEventStudio")
	var presenter: Node = runtime.get("presenter") if runtime != null else null
	if presenter == null:
		quit(1)
		return

	var long_text := ""
	for i in 20:
		long_text += "这是一段用于验收的较长正文，用来验证超长文本是否出现滚动条。"
	presenter.call("show_text", "验收旁白", long_text)
	presenter.call("_finish_typing")
	await create_timer(0.8).timeout
	var label: RichTextLabel = presenter.get("_text_label")
	print("[R3] page1 active=", label.scroll_active, " vbar=", label.get_v_scroll_bar().visible,
		" size=", label.size, " content=", label.get_content_height())
	await _shot("dialogue_long_page1_%dx%d.png" % [_w, _h])

	presenter.call("_dismiss_text")
	await create_timer(0.5).timeout
	print("[R3] page2 scroll=", label.get_v_scroll_bar().value, " hint=", presenter.get("_hint_label").text)
	await _shot("dialogue_long_page2_%dx%d.png" % [_w, _h])

	presenter.call("show_text", "验收旁白", "短句。")
	presenter.call("_finish_typing")
	await create_timer(0.5).timeout
	await _shot("dialogue_short_%dx%d.png" % [_w, _h])
	quit()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		return
	var path := "%s/%s" % [_out_dir, name]
	image.save_png(path)
	print("[R3] ", path, " ", image.get_size())
