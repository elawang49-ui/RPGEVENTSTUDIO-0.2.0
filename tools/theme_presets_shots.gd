extends SceneTree
## 第二批主题真实窗口验收截图（1280×820 / 1152×648）：
##   godot --path . --script res://tools/theme_presets_shots.gd -- 1280 820
## 输出：docs/images/ui-theme-presets-v2/<W>x<H>/
##
## 截图走真实 StudioRuntime 默认 DialoguePresenter；另外用 EventRunner 跑一次
## show_text，验证运行时事件驱动链路。编辑器页截图实例化真实 DialogueThemeView。

const OUT_ROOT := "res://docs/images/ui-theme-presets-v2"
const PORTRAIT := "res://addons/rpgeventstudio/samples/ui/sample_portrait.png"

const SPEAKERS := {
	"verse": "艾琳",
	"codex": "艾琳",
	"terminal": "艾琳",
	"candy": "见习魔女 · 莓莓",
	"tide": "领航员 · 深潮",
	"ember": "守烛人 · 薇拉",
	"frost": "霜语者 · 伊塔",
	"ink": "墨痕客 · 无名",
	"pixel": "旅人 · LOU",
	"nocturne": "夜行者 · K",
	"grove": "林间向导 · 苔苔",
	"tactical": "哨站联络员 · 铁壁",
}

const TEXTS := {
	"verse": "「风从钟楼那边吹过来的时候，我就知道你会来。」",
	"codex": "「风从钟楼那边吹过来的时候，我就知道你会来。」",
	"terminal": "「风从钟楼那边吹过来的时候，我就知道你会来。」",
	"candy": "哇！烤箱里的「星光草莓塔」终于出炉啦～趁热吃掉魔力恢复双倍喔！",
	"tide": "「深潮流向在子夜反转。跟紧我，别在第三道防波堤回头。」",
	"ember": "「烛火还剩最后一寸。在余烬熄灭之前，说出你藏在灰烬里的名字。」",
	"frost": "「霜降之前，湖面的冰会先记住每一片雪花落下的形状。」",
	"ink": "「剑已归鞘，墨还未干。这一笔写完，我们便两不相欠。」",
	"pixel": "「检测到新的支线任务：在黎明前点亮三座烽火台。」",
	"nocturne": "「刚看到你的消息。天台的风很大，要上来吗？」",
	"grove": "「嘘——苔藓睡着了。沿着萤火的方向走，就能找到森林的心。」",
	"tactical": "「哨站通讯恢复正常。确认坐标后，沿 B 通道撤离，完毕。」",
}

const CHOICES := {
	"verse": ["接受这份邀请", "再问问她的来意", "转身离开"],
	"codex": ["接受这份邀请", "再问问她的来意", "转身离开"],
	"terminal": ["接入终端，追踪信号", "切断防火墙，直接突围", "记录日志，稍后处理"],
	"candy": ["尝一口刚出炉的草莓塔", "把配方抄进手账", "先去后院摘薄荷"],
	"tide": ["跟紧领航员", "检查防波堤的潮汐表", "返回甲板等待信号"],
	"ember": ["说出灰烬里的名字", "追问烛火的来历", "保持沉默，凝视余烬"],
	"frost": ["跟随霜语者前行", "询问雪原的边界", "在原地等待天亮"],
	"ink": ["交出那幅未干的字", "请教他的剑名", "拱手告辞，各走各路"],
	"pixel": ["接受任务", "查看地图", "整理装备"],
	"nocturne": ["这就上来", "太晚了，明天吧", "在楼下等你"],
	"grove": ["跟着萤火走", "问问苔苔森林的事", "先记下这条路"],
	"tactical": ["确认坐标，开始撤离", "请求火力支援", "保持静默，观察敌情"],
}

var _w := 1280
var _h := 820
var _out_dir := OUT_ROOT
var _backdrop_layer: CanvasLayer
var _presenter: Node
var _runtime: Node
var _portrait: Texture2D

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		_w = int(args[0])
		_h = int(args[1])
	root.size = Vector2i(_w, _h)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	_out_dir = "%s/%dx%d" % [OUT_ROOT, _w, _h]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_portrait = load(PORTRAIT)
	await create_timer(0.5).timeout

	_runtime = root.get_node_or_null("RPGEventStudio")
	if _runtime == null:
		push_error("缺少 RPGEventStudio autoload")
		quit(1)
		return
	_presenter = _runtime.get("default_presenter")

	# 真实运行时事件：show_text 走 EventRunner → presenter。
	await _shot_runtime_event()

	for id in DialogueThemePresets.ids():
		await _shot_preset(id, false)
		await _shot_preset(id, true)

	# 特色补充：无立绘退化 / BBCode 混排 / 长文分页。
	await _shot_no_portrait("ember", false)
	await _shot_bbcode()
	await _shot_pagination("codex")

	await _shot_editor(1)
	await _shot_editor(3)
	await _shot_editor(9)
	if _w <= 1160:
		await _shot_editor_preview_mode()
	await _shot_editor(6)

	print("[THEME_SHOTS] 输出目录：%s" % ProjectSettings.globalize_path(_out_dir))
	quit(0)

func _backdrop_for(id: String) -> void:
	if _backdrop_layer != null:
		_backdrop_layer.queue_free()
		_backdrop_layer = null
	var info := DialogueThemePresets.meta(id)
	var layer := CanvasLayer.new()
	layer.layer = 1
	root.add_child(layer)
	_backdrop_layer = layer
	var bg := Backdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.top_color = Color.from_string(str(info.get("stage_top", "#121418")), Color(0.07, 0.08, 0.10))
	bg.bottom_color = Color.from_string(str(info.get("stage_bottom", "#08090c")), Color(0.03, 0.03, 0.04))
	var colors: Array = info.get("colors", ["#ffffff"])
	bg.accent = Color.from_string(str(colors[0]), Color.WHITE)
	bg.pattern = id
	layer.add_child(bg)

func _apply(id: String, portrait: bool = true) -> RpgEventStudioTheme:
	var theme: RpgEventStudioTheme = _runtime.call("apply_dialogue_theme_preset", id)
	# 正常截图遵循预设本身是否带立绘；只有“无立绘”补拍才强制关闭。
	if not portrait:
		theme.portrait_enabled = false
	_presenter.call("set_dialogue_theme", theme)
	if portrait:
		_runtime.call("set_dialogue_portrait", _portrait)
	else:
		_runtime.call("clear_dialogue_portrait")
	return theme

func _show_text(id: String, text: String = "") -> void:
	_presenter.call("show_text", str(SPEAKERS.get(id, "旁白")), text if text != "" else str(TEXTS.get(id, "")))
	_presenter.call("_finish_typing")
	await create_timer(0.35).timeout

func _shot_preset(id: String, choices: bool) -> void:
	_presenter.call("close_all")
	_backdrop_for(id)
	await create_timer(0.2).timeout
	_apply(id, true)
	if choices:
		_presenter.call("show_choices", "接下来要怎么做？", CHOICES.get(id, []))
		await create_timer(0.25).timeout
		# 选中第二项，并让第三项保持悬停：截图能同时看出 selected / hover。
		_presenter.set("_choice_index", 1)
		_presenter.call("_update_choice_highlight")
		var rows: Array = _presenter.get("_choice_rows")
		if rows.size() >= 3 and rows[2] != null:
			rows[2].call("set_hovered", true)
		await create_timer(0.25).timeout
		await _shot(_name("%s_choices" % id))
	else:
		await _show_text(id)
		await _shot(_name(id))

func _shot_no_portrait(id: String, choices: bool) -> void:
	_presenter.call("close_all")
	_backdrop_for(id)
	await create_timer(0.15).timeout
	_apply(id, false)
	if choices:
		_presenter.call("show_choices", "接下来要怎么做？", CHOICES.get(id, []))
	else:
		await _show_text(id)
	await create_timer(0.3).timeout
	await _shot(_name("%s_no_portrait" % id))

func _shot_bbcode() -> void:
	_presenter.call("close_all")
	_backdrop_for("verse")
	await create_timer(0.15).timeout
	_apply("verse", true)
	var text := "「[b]星辉[/b]落尽时，[color=#C9A878]圣堂的钟声[/color]会替你回答。\n[font_size=28]—— 但代价，你准备好了吗？[/font_size]」"
	await _show_text("verse", text)
	await _shot(_name("verse_bbcode"))

func _shot_pagination(id: String) -> void:
	_presenter.call("close_all")
	_backdrop_for(id)
	await create_timer(0.15).timeout
	_apply(id, true)
	var long_text := "这是用于验收长篇中文对白分页的第一段。对话框底边固定，顶部随内容向上生长；当正文超过可用高度时，翻页而不是让玩家看到滚动条。"
	for i in 10:
		long_text += "\n第 %d 段：晨光穿过彩窗，尘埃在光柱里缓慢漂浮。旅人把提灯放在石阶上，听见远处传来钟声与风铃的回响。" % (i + 2)
	long_text += "\n最后一段：如果你能看到这一行，说明分页保留了完整行，没有把中文标点切成两半。"
	await _show_text(id, long_text)
	await _shot(_name("%s_page1" % id))
	_presenter.call("_dismiss_text")
	await create_timer(0.35).timeout
	await _shot(_name("%s_page2" % id))

func _shot_runtime_event() -> void:
	_presenter.call("close_all")
	_backdrop_for("codex")
	await create_timer(0.15).timeout
	_apply("codex", true)
	var page := EventPage.new()
	var command := EventCommand.new()
	command.type = &"show_text"
	command.params = {"speaker": "艾琳", "text": "事件运行时验收：这条对白由 EventRunner → CmdShowText → DialoguePresenter 产生。"}
	page.commands = [command]
	var definition := EventDefinition.new()
	definition.event_id = &"theme_acceptance"
	definition.display_name = "主题验收"
	definition.pages = [page]
	_runtime.call("start_event", definition, {}, [])
	await create_timer(0.5).timeout
	var typed := str(_presenter.get("last_text"))
	_presenter.call("_finish_typing")
	await create_timer(0.3).timeout
	await _shot(_name("runtime_event"))
	print("[THEME_SHOTS] EventRunner last_text=%s" % typed)
	# 推进并结束事件
	_presenter.set("_mouse_click", true)
	await create_timer(0.4).timeout

func _shot_editor(preset_index: int) -> void:
	if _backdrop_layer != null:
		_backdrop_layer.visible = false
	_presenter.visible = false
	await create_timer(0.2).timeout
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var view: Control = load("res://addons/rpgeventstudio/editor/theme/dialogue_theme_view.gd").new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(view)
	await create_timer(0.8).timeout
	view.call("_on_preset_selected", preset_index)
	var sample: OptionButton = view.get("_sample")
	if sample != null:
		sample.selected = 0 if preset_index in [1, 2, 3, 7, 9, 10] else 3
		sample.item_selected.emit(sample.selected)
	await create_timer(0.8).timeout
	await _shot(_name("theme_editor_%d" % preset_index))
	layer.queue_free()
	await create_timer(0.2).timeout
	_presenter.visible = true

func _shot_editor_preview_mode() -> void:
	if _backdrop_layer != null:
		_backdrop_layer.visible = false
	_presenter.visible = false
	await create_timer(0.2).timeout
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var view: Control = load("res://addons/rpgeventstudio/editor/theme/dialogue_theme_view.gd").new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(view)
	await create_timer(0.8).timeout
	view.call("_on_preset_selected", 1)
	var toggle: Button = view.get("_preview_toggle")
	if toggle != null:
		toggle.button_pressed = true
		toggle.toggled.emit(true)
	var sample: OptionButton = view.get("_sample")
	if sample != null:
		sample.selected = 3
		sample.item_selected.emit(3)
	await create_timer(0.8).timeout
	await _shot(_name("theme_editor_preview_mode"))
	layer.queue_free()
	await create_timer(0.2).timeout
	_presenter.visible = true

func _name(suffix: String) -> String:
	return "%s/%s_%dx%d.png" % [_out_dir, suffix, _w, _h]

func _shot(path: String) -> void:
	# 不等待 frame_post_draw：窗口被终端遮挡时 macOS 可能暂停渲染，
	# await 会一直挂起。强制绘制一帧再取纹理，保证批量截图能跑完。
	await create_timer(0.08).timeout
	RenderingServer.force_draw(true)
	var image := root.get_texture().get_image()
	if image == null:
		return
	if image.get_width() != _w or image.get_height() != _h:
		image.resize(_w, _h, Image.INTERPOLATE_LANCZOS)
	var error := image.save_png(path)
	print("[THEME_SHOTS] %s -> %d" % [path, error])

# ── 展示背景（只用于截图，不属于插件主题） ────────────────

class Backdrop extends Control:
	var top_color := Color(0.07, 0.08, 0.10)
	var bottom_color := Color(0.03, 0.03, 0.04)
	var accent := Color(1, 1, 1)
	var pattern := ""

	func _draw() -> void:
		var steps := 80
		for i in steps:
			var t := float(i) / float(steps - 1)
			var c := top_color.lerp(bottom_color, t)
			draw_rect(Rect2(0, size.y * t, size.x, size.y / float(steps) + 1.0), c, true)
		match pattern:
			"sacred":
				for i in 9:
					var a := deg_to_rad(200.0 + i * 10.0)
					draw_line(Vector2(size.x * 0.35, 0), Vector2(size.x * 0.35, size.y) + Vector2(cos(a), sin(a)) * size.length(), Color(0.9, 0.82, 0.65, 0.05), 18.0)
			_:
				# 底图统一保持干净渐变+暗角：网格/点阵/星座这类大尺度
				# 装饰会让截图失去整体感，面板本身才是展示对象。
				pass
		# 柔和暗角：四边各自向内渐隐的渐层，不出现矩形轮廓线。
		var vsteps := 18
		var depth := 64.0
		for i in vsteps:
			var a := 0.05 * (1.0 - float(i) / float(vsteps))
			var off := depth * float(i) / float(vsteps)
			var band := depth / float(vsteps) + 1.0
			draw_rect(Rect2(0, off, size.x, band), Color(0, 0, 0, a), true)
			draw_rect(Rect2(0, size.y - off - band, size.x, band), Color(0, 0, 0, a), true)
			draw_rect(Rect2(off, 0, band, size.y), Color(0, 0, 0, a * 0.7), true)
			draw_rect(Rect2(size.x - off - band, 0, band, size.y), Color(0, 0, 0, a * 0.7), true)
