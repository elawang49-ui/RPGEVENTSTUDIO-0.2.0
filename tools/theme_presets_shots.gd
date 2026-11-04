extends SceneTree
## ATELIER v5 主题验收截图（真实分辨率离屏渲染）：
##   godot --path . --script res://tools/theme_presets_shots.gd -- 1920 1080
##   godot --path . --script res://tools/theme_presets_shots.gd -- 1280 720
## 输出：docs/images/ui-theme-presets-v5/<W>x<H>/
##
## 渲染方式：开发机屏幕放不下 1920×1080 窗口，因此用 SubViewport 离屏渲染——
## size = 目标分辨率，size_2d_override = 1280×720 + stretch，与项目 canvas_items
## 缩放等效（UI 按逻辑 1280×720 布局，按目标分辨率真实光栅化，不做任何事后缩放）。
##
## 截图走真实 StudioRuntime 默认 DialoguePresenter；另外用 EventRunner 跑一次
## show_text，验证运行时事件驱动链路。编辑器页截图实例化真实 DialogueThemeView。

const OUT_ROOT := "res://docs/images/ui-theme-presets-v5"
const BASE := Vector2i(1280, 720)
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
## 原子写入：截图先写临时目录，全部成功后才逐个覆盖到正式目录；
## 任何失败都不碰正式目录，也从不删除正式目录里的文件。
var _final_dir := OUT_ROOT
var _written: PackedStringArray = []
var _failed := 0
var _portrait_cache := {}
var _backdrop_layer: CanvasLayer
var _presenter: Node
var _runtime: Node
var _vp: SubViewport
var _portrait: Texture2D

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		_w = int(args[0])
		_h = int(args[1])
	# 离屏 SubViewport：窗口本身大小无关紧要。
	_vp = SubViewport.new()
	_vp.name = "ShotViewport"
	_vp.size = Vector2i(_w, _h)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	if Vector2i(_w, _h) != BASE:
		_vp.size_2d_override = BASE
		_vp.size_2d_override_stretch = true
	if "oversampling_override" in _vp:
		_vp.set("oversampling_override", float(_h) / float(BASE.y))
	# 离屏视口不接收 GUI 输入：真实鼠标位置不会让任何选项进入悬停态。
	_vp.gui_disable_input = true
	root.add_child(_vp)
	Input.warp_mouse(Vector2(-100, -100))
	# 静态帧冻结光标闪烁在亮相位。
	ThemeChoiceRow.freeze_blink = true
	_final_dir = "%s/%dx%d" % [OUT_ROOT, _w, _h]
	_out_dir = "res://.godot/theme_shots_tmp/%dx%d" % [_w, _h]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_final_dir))
	_portrait = load(PORTRAIT)
	await create_timer(0.5).timeout

	_runtime = root.get_node_or_null("RPGEventStudio")
	if _runtime == null:
		push_error("缺少 RPGEventStudio autoload")
		quit(1)
		return
	_presenter = _runtime.get("default_presenter")
	# 默认展示层搬进离屏视口：运行时事件链路不变，只是渲染目标换成 SubViewport。
	_presenter.reparent(_vp)
	await process_frame
	_presenter.call("_on_viewport_resized")

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

	if _failed > 0 or _written.is_empty():
		push_error("[THEME_SHOTS] %d 张截图失败，正式目录保持不变：%s" % [_failed, ProjectSettings.globalize_path(_final_dir)])
		quit(1)
		return
	var copied := 0
	for tmp_path in _written:
		var dest := "%s/%s" % [_final_dir, tmp_path.get_file()]
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(dest)) == OK:
			copied += 1
	print("[THEME_SHOTS] 已原子覆盖 %d/%d 张 → %s" % [copied, _written.size(), ProjectSettings.globalize_path(_final_dir)])
	quit(0 if copied == _written.size() else 1)

func _backdrop_for(id: String) -> void:
	if _backdrop_layer != null:
		_backdrop_layer.queue_free()
		_backdrop_layer = null
	var info := DialogueThemePresets.meta(id)
	var layer := CanvasLayer.new()
	layer.layer = 1
	_vp.add_child(layer)
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
		_runtime.call("set_dialogue_portrait", _silhouette_for(id))
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
		# 选中第二项；不模拟悬停（离屏视口已禁用 GUI 输入，鼠标不会落到任何行上）。
		_presenter.set("_choice_index", 1)
		_presenter.call("_update_choice_highlight")
		await create_timer(0.25).timeout
		# 截图态断言：只有 _choice_index 行 selected，所有行 hovered=false。
		var rows: Array = _presenter.get("_choice_rows")
		var idx := int(_presenter.get("_choice_index"))
		for i in rows.size():
			var row = rows[i]
			if bool(row.get("hovered")) or bool(row.get("selected")) != (i == idx):
				push_error("[THEME_SHOTS] %s 选项态异常：第 %d 行 selected=%s hovered=%s" % [id, i, row.get("selected"), row.get("hovered")])
				_failed += 1
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
	_vp.add_child(layer)
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
	_vp.add_child(layer)
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

## 透明底半身剪影占位立绘（QA 用，但要像样）：
## 2x 超采样后缩小得到抗锯齿边；身体自上而下明暗渐变；一侧柔和边缘光；整体 0.92 不透明。
## 形体：略小的头 + 发型外轮廓 + 颈 + 自然溜肩躯干，按距离场合成。
func _silhouette_for(id: String) -> Texture2D:
	if _portrait_cache.has(id):
		return _portrait_cache[id]
	var info := DialogueThemePresets.meta(id)
	var colors: Array = info.get("colors", ["#333333", "#cccccc"])
	var theme := DialogueThemePresets.create(id)
	var body := Color.from_string(str(info.get("stage_bottom", "#333333")), Color(0.2, 0.2, 0.2)).darkened(0.35)
	if body.get_luminance() > 0.45:
		body = body.darkened(0.5)
	var rim := Color.from_string(str(colors[1]), Color.WHITE)
	var rim_dir := 1.0 if theme.portrait_placement != "large-right" else -1.0
	var ss := 2
	var w := 300 * ss
	var h := 390 * ss
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(w) * 0.5
	var u := float(ss)
	for y in h:
		var fy := float(y)
		for x in w:
			var fx := float(x)
			var d := _silhouette_sdf(fx / u, fy / u, cx / u)
			if d > 1.5:
				continue
			# 1.5px（原尺寸）alpha 渐变边。
			var a := clampf(0.5 - d / 1.5, 0.0, 1.0) if d > -0.75 else 1.0
			var t := fy / float(h)
			var c := body.lightened(0.10 * (1.0 - t)).darkened(0.18 * t)
			# 柔和边缘光：越靠近边缘、越偏向光源一侧越亮（无硬切）。
			var side := clampf(((fx - cx) / (float(w) * 0.42)) * rim_dir, -1.0, 1.0)
			var edge := clampf(1.0 + d / 10.0, 0.0, 1.0)
			var rim_k := smoothstep(0.1, 1.0, side) * edge * edge * 0.75
			c = c.lerp(rim, rim_k)
			c.a = a * 0.92
			img.set_pixel(x, y, c)
	img.resize(w / ss, h / ss, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_portrait_cache[id] = tex
	return tex

## 半身像近似距离场（原尺寸 300×390 坐标，负=内部，单位 px）。
func _silhouette_sdf(x: float, y: float, cx: float) -> float:
	var p := Vector2(x - cx, y)
	# 头：椭圆（半径 40×48），中心 y=92。
	var head := _ellipse_sd(p - Vector2(0, 92), Vector2(40, 48))
	# 发型：略大的偏上椭圆 + 一侧垂发。
	var hair := _ellipse_sd(p - Vector2(-3, 80), Vector2(47, 50))
	var lock := _ellipse_sd(p - Vector2(-34, 128), Vector2(14, 40))
	# 颈。
	var neck := maxf(absf(p.x) - 16.0, absf(p.y - 152.0) - 22.0)
	# 躯干：溜肩——上沿为宽椭圆，向下竖直落到底。
	var shoulder := _ellipse_sd(p - Vector2(0, 236), Vector2(122, 70))
	var trunk := maxf(absf(p.x) - (104.0 + (p.y - 236.0) * 0.08), 236.0 - p.y)
	var torso := minf(shoulder, trunk)
	return _smin(_smin(minf(head, hair), lock, 6.0), _smin(neck, torso, 14.0), 10.0)

func _ellipse_sd(p: Vector2, r: Vector2) -> float:
	var k := (p / r).length()
	return (k - 1.0) * minf(r.x, r.y)

func _smin(a: float, b: float, k: float) -> float:
	var hh := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, hh) - k * hh * (1.0 - hh)

func _name(suffix: String) -> String:
	return "%s/%s_%dx%d.png" % [_out_dir, suffix, _w, _h]

func _shot(path: String) -> void:
	# 不等待 frame_post_draw：窗口被终端遮挡时 macOS 可能暂停渲染，
	# await 会一直挂起。强制绘制一帧再取纹理，保证批量截图能跑完。
	await create_timer(0.08).timeout
	RenderingServer.force_draw(true)
	var image := _vp.get_texture().get_image()
	if image == null:
		_failed += 1
		return
	# 真实分辨率渲染：尺寸不符直接判失败，绝不事后缩放。
	if image.get_width() != _w or image.get_height() != _h:
		push_error("[THEME_SHOTS] 渲染尺寸 %dx%d ≠ 目标 %dx%d" % [image.get_width(), image.get_height(), _w, _h])
		_failed += 1
		return
	var error := image.save_png(path)
	if error == OK:
		_written.append(path)
	else:
		_failed += 1
	print("[THEME_SHOTS] %s -> %d" % [path, error])

# ── 展示背景（只用于截图，不属于插件主题） ────────────────

class Backdrop extends Control:
	var top_color := Color(0.07, 0.08, 0.10)
	var bottom_color := Color(0.03, 0.03, 0.04)
	var accent := Color(1, 1, 1)
	var pattern := ""
	var _vignette: GradientTexture2D

	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
		match pattern:
			"sacred":
				for i in 9:
					var a := deg_to_rad(200.0 + i * 10.0)
					draw_line(Vector2(size.x * 0.35, 0), Vector2(size.x * 0.35, size.y) + Vector2(cos(a), sin(a)) * size.length(), Color(0.9, 0.82, 0.65, 0.05), 18.0)
			_:
				# 底图统一保持干净渐变+暗角：网格/点阵/星座这类大尺度
				# 装饰会让截图失去整体感，面板本身才是展示对象。
				pass
		# 径向暗角：单张 GradientTexture2D（中心透明 → 边缘 0.35），一次绘制，无条带。
		if _vignette == null:
			var g := Gradient.new()
			g.set_color(0, Color(0, 0, 0, 0))
			g.set_color(1, Color(0, 0, 0, 0.35))
			g.add_point(0.55, Color(0, 0, 0, 0))
			_vignette = GradientTexture2D.new()
			_vignette.gradient = g
			_vignette.fill = GradientTexture2D.FILL_RADIAL
			_vignette.fill_from = Vector2(0.5, 0.5)
			_vignette.fill_to = Vector2(1.05, 1.05)
			_vignette.width = 512
			_vignette.height = 512
		draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)
