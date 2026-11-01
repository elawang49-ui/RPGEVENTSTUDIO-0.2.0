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
	"sacred": "白灰圣女 · 伊莉丝",
	"cute": "见习魔女 · 莓莓",
	"cool": "幽灵骇客 · 零",
	"minimal": "观测者 2B",
	"biscuit": "面包房主 · 可可",
	"crimson": "处刑人 · 维克多",
}

const TEXTS := {
	"sacred": "「当最后的星辉落入寂静圣堂，古老的誓言便会苏醒……旅人啊，请告诉我你的抉择。」",
	"cute": "哇！烤箱里的「星光草莓塔」终于出炉啦～趁热吃掉魔力恢复双倍喔！",
	"cool": "防火墙只剩最后 12 秒重构。直接切入深层矩阵！",
	"minimal": "雨停了。录音带转到了尽头，废墟里只剩下机械心脏跳动的回音。",
	"biscuit": "今天的「薄荷焦糖曲奇」烤得刚刚好！我已经把配方贴在你的手账第 3 页啦～",
	"crimson": "「午夜的钟声已经敲响了十二下。在绯红之月落下之前，交出你的底牌吧。」",
}

const CHOICES := {
	"sacred": ["解开古老封印，倾听回响", "追问关于「契约」的代价", "收起提灯，悄然离开"],
	"cute": ["尝一口刚出炉的草莓塔", "把配方抄进手账", "先去后院摘薄荷"],
	"cool": ["接入终端，追踪幽灵信号", "切断防火墙，直接突围", "伪造身份，从维护通道撤离"],
	"minimal": ["继续回放录音", "检查机械心脏", "关闭终端，回到地面"],
	"biscuit": ["翻开烘焙手账第 3 页", "帮可可搅拌焦糖", "把曲奇分给门口的猫"],
	"crimson": ["交出底牌，接受审判", "否认契约，直视逆十字", "保持沉默，等待钟声"],
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
	await _shot_no_portrait("crimson", false)
	await _shot_bbcode()
	await _shot_pagination("biscuit")

	await _shot_editor(1)
	if _w <= 1160:
		await _shot_editor_preview_mode()
	await _shot_editor(5)

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
	theme.portrait_enabled = portrait
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
	_backdrop_for("sacred")
	await create_timer(0.15).timeout
	_apply("sacred", true)
	var text := "「[b]星辉[/b]落尽时，[color=#E5D1A7]圣堂的钟声[/color]会替你回答。\n[font_size=28]—— 但代价，你准备好了吗？[/font_size]」"
	await _show_text("sacred", text)
	await _shot(_name("sacred_bbcode"))

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
	_backdrop_for("minimal")
	await create_timer(0.15).timeout
	_apply("minimal", true)
	var page := EventPage.new()
	var command := EventCommand.new()
	command.type = &"show_text"
	command.params = {"speaker": "观测者 2B", "text": "事件运行时验收：这条对白由 EventRunner → CmdShowText → DialoguePresenter 产生。"}
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
		sample.selected = 0 if preset_index == 1 else 3
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
			"cute":
				var y := 20.0
				while y < size.y:
					var x := 20.0
					while x < size.x:
						draw_circle(Vector2(x, y), 2.2, Color(1.0, 0.55, 0.63, 0.10))
						x += 30.0
					y += 30.0
			"cool", "crimson":
				var y := 0.0
				while y < size.y:
					draw_line(Vector2(0, y), Vector2(size.x, y), Color(accent, 0.06), 1.0)
					y += 24.0
				var x := 0.0
				while x < size.x:
					draw_line(Vector2(x, 0), Vector2(x, size.y), Color(accent, 0.06), 1.0)
					x += 24.0
			"minimal":
				for i in 6:
					draw_line(Vector2(0, size.y * 0.25 + i * 6), Vector2(size.x, size.y * 0.25 + i * 6), Color(1, 1, 1, 0.02), 1.0)
			"biscuit":
				var y := 0.0
				while y < size.y:
					draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.65, 0.49, 0.32, 0.10), 1.0)
					y += 24.0
				var x := 0.0
				while x < size.x:
					draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.65, 0.49, 0.32, 0.10), 1.0)
					x += 24.0
		# 暗角
		for i in 10:
			var a := 0.02 + i * 0.012
			draw_rect(Rect2(i * 8, i * 8, size.x - i * 16, size.y - i * 16), Color(0, 0, 0, a), false, 16.0)
