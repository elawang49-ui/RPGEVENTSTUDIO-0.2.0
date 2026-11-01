extends SceneTree
## 分页专项验收截图：
##   godot --path . --script res://tools/dialogue_pagination_shots.gd -- 1152 648
## 输出 docs/images/dialogue-pagination-acceptance/

const DEFAULT_OUT_DIR := "res://docs/images/dialogue-pagination-acceptance"
const FONT_FIXTURE := "res://tests/fixtures/fonts/custom_serif.tres"

var _w := 1152
var _h := 648
var _out_dir := DEFAULT_OUT_DIR
var _presenter: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		_w = int(args[0])
		_h = int(args[1])
	var env_dir := OS.get_environment("PAGINATION_SHOT_DIR").strip_edges()
	if env_dir != "":
		_out_dir = env_dir
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	var scene: Node = load("res://addons/rpgeventstudio/samples/scenes/school_demo.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.8).timeout
	var runtime := root.get_node_or_null("RPGEventStudio")
	_presenter = runtime.get("presenter") if runtime != null else null
	if _presenter == null:
		quit(1)
		return
	_presenter.set("blocked", true)

	# 1. 不重叠：第二页从第一个未完整行开始。
	await _show_story(false)
	await _shot("overlap_off_page1_%dx%d.png" % [_w, _h])
	_presenter.call("_next_page")
	await create_timer(0.25).timeout
	await _shot("overlap_off_page2_%dx%d.png" % [_w, _h])

	# 2. 保留一行重叠：第二页重复上一页最后一个完整行。
	await _show_story(true)
	_presenter.call("_next_page")
	await create_timer(0.25).timeout
	await _shot("overlap_on_page2_%dx%d.png" % [_w, _h])

	# 3. BBCode 混排（粗体/斜体/40 号/12 号）。
	await _show_bbcode()
	await _shot("bbcode_mixed_%dx%d.png" % [_w, _h])
	_presenter.call("_next_page")
	await create_timer(0.25).timeout
	await _shot("bbcode_mixed_page2_%dx%d.png" % [_w, _h])

	# 4. 自定义字体。
	await _show_custom_font()
	await _shot("custom_font_%dx%d.png" % [_w, _h])
	_presenter.call("_next_page")
	await create_timer(0.25).timeout
	await _shot("custom_font_page2_%dx%d.png" % [_w, _h])
	quit()

func _base_theme() -> RpgEventStudioTheme:
	var theme := RpgEventStudioTheme.new()
	theme.text_speed = 4000.0
	return theme

func _show_story(overlap: bool) -> void:
	var theme := _base_theme()
	_presenter.call("set_dialogue_theme", theme)
	_presenter.set("page_overlap", overlap)
	var text := ""
	for i in 12:
		text += "第%02d段：这是用于对照的短剧情对白。\n" % (i + 1)
	_presenter.call("show_text", "旁白", text)
	_presenter.call("_finish_typing")
	await create_timer(0.35).timeout

func _show_bbcode() -> void:
	var theme := _base_theme()
	_presenter.call("set_dialogue_theme", theme)
	_presenter.set("page_overlap", false)
	var text := "[b]图书馆的钥匙[/b]\n[i]旁白：[/i]你翻开旧书，发现一张折角地图。\n[font_size=40]教室门已经打开。[/font_size]\n继续向前，地下室就在走廊尽头。\n[font_size=12]小字备注：别忘了检查黑板。[/font_size]"
	_presenter.call("show_text", "图书管理员", text)
	_presenter.call("_finish_typing")
	await create_timer(0.35).timeout

func _show_custom_font() -> void:
	var theme := _base_theme()
	theme.font_path = FONT_FIXTURE
	theme.text_font_size = 22
	theme.line_separation = 8
	_presenter.call("set_dialogue_theme", theme)
	_presenter.set("page_overlap", false)
	var text := "这是一段用于验收自定义字体分页的中文对白。换行、行距与字号都必须按实际字体度量计算，不能再用固定像素估算。"
	text += "\n" + "这是第二段：如果分页准确，页底不会出现半行。"
	text += "\n" + "这是第三段：翻页后应从下一行继续。"
	text += "\n" + "这是第四段：最后一页再次确认才结束。"
	text += "\n" + "这是第五段：用于补足页面高度。"
	text += "\n" + "这是第六段：用于补足页面高度。"
	_presenter.call("show_text", "旁白", text)
	_presenter.call("_finish_typing")
	await create_timer(0.35).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		return
	var path := "%s/%s" % [_out_dir, name]
	image.save_png(path)
	print("[PAGINATION] ", path, " ", image.get_size())
