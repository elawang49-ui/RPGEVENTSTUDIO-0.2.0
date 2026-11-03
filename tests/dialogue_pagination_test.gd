extends SceneTree
## 对话框分页专项验收：
##   godot --headless --path . --script res://tests/dialogue_pagination_test.gd
## 覆盖真实布局行高、BBCode/主题/自定义字体、窗口变化、打字机、键鼠手柄/Auto、最后一页、选项切换。

const VIEW_W := 1152
const VIEW_H := 648
const DEFAULT_FONT_FIXTURE := "res://tests/fixtures/fonts/pagination_sans.otf"
const FONT_FIXTURE := "res://tests/fixtures/fonts/custom_serif.tres"

var _checks := 0
var _failures: PackedStringArray = []
var _p: DialoguePresenter
var _service: InputService
var _label: RichTextLabel

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(VIEW_W, VIEW_H)
	_service = InputService.new()
	_p = DialoguePresenter.new()
	var initial_theme := RpgEventStudioTheme.new()
	initial_theme.font_path = DEFAULT_FONT_FIXTURE
	_p.style = initial_theme
	_p.input = _service
	root.add_child(_p)
	await process_frame
	await process_frame
	_label = _p.get("_text_label")
	_check(_label != null, "对话框正文已构建")
	if _label == null:
		_report(); quit(1); return

	await _test_plain_long()
	await _test_newlines()
	await _test_bbcode_mixed()
	await _test_theme_sizes()
	await _test_custom_font()
	await _test_resize()
	await _test_typing_state()
	await _test_keyboard()
	await _test_mouse()
	await _test_gamepad()
	await _test_auto_play()
	await _test_auto_after_typing()
	await _test_last_page_and_choices()
	await _test_overlap_mode()
	await _test_font_metrics_alignment()

	_p.queue_free()
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 1. 普通中文长文本 ──────────────────────────────────────

func _test_plain_long() -> void:
	_set_theme(20, 8)
	var text := "这是一段用于验收的较长正文，用来验证分页行高与阅读连续性。" .repeat(18)
	await _show_ready(text)
	_check(not _label.scroll_active, "普通长文：不启用滚动条")
	_check(not _label.get_v_scroll_bar().visible, "普通长文：滚动条不可见")
	_check(bool(_p.call("_has_more_pages")), "普通长文：需要翻页")
	var total := _label.get_line_count()
	var pages := await _walk_pages("普通长文", false)
	_check(pages > 1, "普通长文：实际翻页（%d 页）" % pages)
	_check(int(_p.call("_page_end_line")) == total, "普通长文：最后一页覆盖到最后一行")
	_check(bool(_p.get("_panel").visible), "普通长文：最后一页仍显示面板")

# ── 2. 多段换行 ────────────────────────────────────────────

func _test_newlines() -> void:
	_set_theme(20, 8)
	var text := ""
	for i in 8:
		text += "第%d段：这是用于验收的较长正文，段落之间保留换行。" % (i + 1) + "\n"
	await _show_ready(text)
	_check(_label.get_line_count() >= 8, "换行文本：RichTextLabel 生成多行")
	_check(bool(_p.call("_has_more_pages")), "换行文本：需要翻页")
	var pages := await _walk_pages("换行文本", false)
	_check(pages > 1 and int(_p.call("_page_end_line")) == _label.get_line_count(),
		"换行文本：连续翻页且最后一页完整（%d 页）" % pages)

# ── 3. BBCode 混排 ─────────────────────────────────────────

func _test_bbcode_mixed() -> void:
	_set_theme(20, 8)
	var block := "[b]粗体标题[/b] 普通文本，用于检查混合字号。 [font_size=40]这是 40 号大字[/font_size] 然后回到普通文本。 [i]斜体说明[/i] 再补一句普通文本。 [font_size=12]这是 12 号小字[/font_size] 继续普通文本。"
	await _show_ready(block.repeat(4))
	_check(not _label.scroll_active and not _label.get_v_scroll_bar().visible,
		"BBCode 混排：无玩家可见滚动条")
	_check(bool(_p.call("_has_more_pages")), "BBCode 混排：需要翻页")
	var pages := await _walk_pages("BBCode 混排", false)
	_check(pages >= 2, "BBCode 混排：大字号行不会被跳过（%d 页）" % pages)
	_check(int(_p.call("_page_end_line")) == _label.get_line_count(),
		"BBCode 混排：最后一页覆盖完整内容")

# ── 4. 不同主题字号 + 自定义字体 ───────────────────────────

func _test_theme_sizes() -> void:
	for case in [
		{"name": "主题 14/4", "size": 14, "sep": 4},
		{"name": "主题 32/8", "size": 32, "sep": 8},
	]:
		_set_theme(int(case["size"]), int(case["sep"]))
		await _show_ready("这是一段用于验收的较长正文，用来验证不同主题字号下的分页。" .repeat(16))
		_check(not _label.get_v_scroll_bar().visible, "%s：无滚动条" % case["name"])
		var pages := await _walk_pages(str(case["name"]), false)
		_check(pages > 1, "%s：按实际行高翻页（%d 页）" % [case["name"], pages])
		_check(int(_p.call("_page_end_line")) == _label.get_line_count(),
			"%s：最后一页完整" % case["name"])

func _test_custom_font() -> void:
	_check(ResourceLoader.exists(FONT_FIXTURE), "自定义字体 fixture 存在")
	var theme := RpgEventStudioTheme.new()
	theme.text_font_size = 22
	theme.line_separation = 8
	theme.text_speed = 4000.0
	theme.font_path = FONT_FIXTURE
	_p.set_dialogue_theme(theme)
	await process_frame
	var font := theme.resolve_font()
	_check(font != null, "自定义字体可解析")
	await _show_ready("这是一段用于验收的较长正文，用来验证自定义字体下的分页与行高。" .repeat(16))
	_check(not _label.get_v_scroll_bar().visible, "自定义字体：无滚动条")
	var pages := await _walk_pages("自定义字体", false)
	_check(pages > 1, "自定义字体：实际翻页（%d 页）" % pages)
	_check(int(_p.call("_page_end_line")) == _label.get_line_count(),
		"自定义字体：最后一页完整")

# ── 5. 窗口尺寸变化 ───────────────────────────────────────

func _test_resize() -> void:
	_set_theme(20, 8)
	await _show_ready("这是一段用于验收的较长正文，用来验证窗口尺寸变化时的分页。" .repeat(20))
	_p.call("_next_page")
	await create_timer(0.15).timeout
	var before := int(_p.get("_page_line"))
	root.size = Vector2i(960, 600)
	await create_timer(0.25).timeout
	_p.call("_update_heights")
	await process_frame
	var total := _label.get_line_count()
	_check(int(_p.get("_page_line")) >= 0 and int(_p.get("_page_line")) < total,
		"缩小窗口：页起始行有效（%d/%d）" % [int(_p.get("_page_line")), total])
	_check(int(_p.call("_page_end_line")) <= total, "缩小窗口：页结束行不越界")
	# before 只可能 >= 0（_page_line 全程被 clamp），旧断言 before >= 0 恒真无鉴别力；
	# 改为 _next_page 的真实后序条件：要么页起始行已前进（>= 1），要么正文本就一页容纳（末页无需翻页）。
	_check(before >= 1 or int(_p.call("_page_end_line")) >= total,
		"缩小窗口：翻页状态未崩溃（翻页后应已前进，或正文本就一页容纳）")
	root.size = Vector2i(1280, 820)
	await create_timer(0.25).timeout
	_p.call("_update_heights")
	await process_frame
	_check(int(_p.get("_page_line")) < _label.get_line_count(),
		"放大窗口：页起始行仍有效")
	root.size = Vector2i(VIEW_W, VIEW_H)
	await create_timer(0.2).timeout
	_p.call("_update_heights")

# ── 6. 打字机状态 ─────────────────────────────────────────

func _test_typing_state() -> void:
	_set_theme(20, 8, 300.0)
	_p.show_text("旁白", "这是一段用于验收打字机状态的长文本，需要多个页面才能读完。" .repeat(18))
	var waited := 0
	while not bool(_p.get("_typing")) and waited < 120:
		await process_frame
		waited += 1
	_check(bool(_p.get("_typing")), "打字机：已进入逐字显示")
	await _press_key(KEY_SPACE)
	_check(bool(_p.get("_typing")), "打字机：输入不会在逐字阶段抢翻页")
	_check(int(_p.get("_page_line")) == 0, "打字机：逐字阶段页起始行不变")
	waited = 0
	while bool(_p.get("_typing")) and waited < 600:
		await process_frame
		waited += 1
	_check(not bool(_p.get("_typing")), "打字机：自然结束后停止")
	_check(bool(_p.get("_waiting_confirm")), "打字机：结束后等待确认")
	await create_timer(0.22).timeout
	await _press_key(KEY_SPACE)
	_check(int(_p.get("_page_line")) > 0, "打字机：结束后按键才翻页")

# ── 7. 真实输入链路 ───────────────────────────────────────

func _test_keyboard() -> void:
	await _new_long()
	var before := int(_p.get("_page_line"))
	var n: int = _p.get("shown_texts").size()
	await _press_key(KEY_SPACE)
	_check(int(_p.get("_page_line")) > before, "键盘确认键：翻页")
	_check(_p.get("shown_texts").size() == n, "键盘确认键：未误推进下一段")
	_check(bool(_p.get("_panel").visible), "键盘确认键：未误关闭面板")

func _test_mouse() -> void:
	await _new_long()
	var before := int(_p.get("_page_line"))
	await _click_mouse()
	_check(int(_p.get("_page_line")) > before, "鼠标左键：翻页")
	_check(bool(_p.get("_panel").visible), "鼠标左键：未误关闭面板")

func _test_gamepad() -> void:
	await _new_long()
	var before := int(_p.get("_page_line"))
	await _press_pad()
	_check(int(_p.get("_page_line")) > before, "手柄 A：翻页")
	_check(bool(_p.get("_panel").visible), "手柄 A：未误关闭面板")

func _test_auto_play() -> void:
	_set_theme(20, 8)
	_p.show_text("旁白", "这是一段用于验收自动播放翻页的长文本，需要多个页面才能读完。" .repeat(18), 0.3)
	var waited := 0
	while not bool(_p.get("_waiting_confirm")) and waited < 300:
		await process_frame
		waited += 1
	var deadline_before := int(_p.get("_auto_deadline"))
	await create_timer(0.55).timeout
	_check(int(_p.get("_page_line")) > 0, "自动播放：到时自动翻页")
	_check(int(_p.get("_auto_deadline")) > deadline_before, "自动播放：翻页后重置计时")
	_check(bool(_p.get("_panel").visible), "自动播放：翻页时保持面板")

## 阅读倒计时属于展示完成后的页面，不能在打字阶段提前耗尽。
func _test_auto_after_typing() -> void:
	_set_theme(20, 8, 1.0)
	_p.show_text("旁白", "逐字显示后才开始自动推进计时。", 0.2)
	_check(int(_p.get("_auto_deadline")) == 0, "自动播放：打字开始时尚未启动阅读计时")
	await create_timer(0.25).timeout
	_check(bool(_p.get("_typing")), "自动播放：阅读时长经过后仍在打字")
	_check(bool(_p.get("_panel").visible), "自动播放：打字期间保持面板")
	_p.call("_finish_typing")
	_check(int(_p.get("_auto_deadline")) > Time.get_ticks_msec(), "自动播放：打字完成后获得完整阅读时间")
	await process_frame
	_check(bool(_p.get("_waiting_confirm")), "自动播放：打字完成后的首帧仍等待阅读")
	_check(not _p.is_text_finished(), "自动播放：不能在打字完成时立即结束事件等待")
	await create_timer(0.28).timeout
	_check(_p.is_text_finished(), "自动播放：阅读时间结束后正常完成")

# ── 8. 最后一页与选项状态 ─────────────────────────────────

func _test_last_page_and_choices() -> void:
	_set_theme(20, 8)
	await _show_ready("这是一段用于验收最后一页的长文本，需要多个页面才能读完。" .repeat(18))
	var guard := 0
	while bool(_p.call("_has_more_pages")) and guard < 50:
		_p.call("_next_page")
		guard += 1
	_check(int(_p.call("_page_end_line")) == _label.get_line_count(),
		"最后一页：覆盖到最后一行")
	_check(not bool(_p.call("_has_more_pages")), "最后一页：没有下一页")
	await create_timer(0.22).timeout
	await _press_key(KEY_SPACE)
	await process_frame
	_check(not bool(_p.get("_panel").visible), "最后一页：再次确认才关闭")
	_check(bool(_p.get("_text_done")), "最后一页：文本状态已结束")

	await _show_ready("这是一段用于验收选项面板的较长文本，先翻一页再显示选项。" .repeat(18))
	_p.call("_next_page")
	await process_frame
	_p.call("show_choices", "请选择处理方式", ["选项一", "选项二", "选项三"])
	await process_frame
	_check(int(_p.get("_page_line")) == 0, "选项：不继承上一段对白页位置")
	_check(not _label.scroll_active and not _label.get_v_scroll_bar().visible,
		"选项：不继承正文滚动条状态")
	_check(bool(_p.get("_choices_panel").visible), "选项：选项面板显示")

## 对照：保留一行重叠时，下一页从上一页最后一个完整行开始；
## 默认不重叠，只重复页底部分可见行。
func _test_overlap_mode() -> void:
	_set_theme(20, 8)
	await _show_ready("这是一段用于验收分页重叠对照的长文本，检查阅读连续性。" .repeat(18))
	var start := int(_p.get("_page_line"))
	var end := int(_p.call("_page_end_line"))
	_p.set("page_overlap", true)
	_p.call("_next_page")
	await process_frame
	var overlap_next := int(_p.get("_page_line"))
	_check(overlap_next == maxi(start + 1, end - 1),
		"重叠模式：下一页从上一页最后完整行开始（%d→%d）" % [start, overlap_next])
	_check(overlap_next < end, "重叠模式：确实重复一行")
	_p.call("_next_page")
	await process_frame
	_check(bool(_p.get("_waiting_confirm")), "重叠模式：翻页后仍等待确认")

	_set_theme(20, 8)
	await _show_ready("这是一段用于验收分页重叠对照的长文本，检查阅读连续性。" .repeat(18))
	_p.set("page_overlap", false)
	var no_start := int(_p.get("_page_line"))
	var no_end := int(_p.call("_page_end_line"))
	_p.call("_next_page")
	await process_frame
	_check(int(_p.get("_page_line")) == no_end,
		"不重叠：下一页从第一个未完整行开始（%d→%d）" % [no_start, no_end])
	_check(int(_p.get("_page_line")) > no_start, "不重叠：页面向前推进")

# ── 默认字体：行高取整（页底不能露半行） ───────────────────

## 回归：正文高度曾用 font_size + line_separation 估算（21+7=28），
## 而中文字体真实行高约 38；按 28 取整会在页底露出下一行的上半截。
func _test_font_metrics_alignment() -> void:
	var theme := RpgEventStudioTheme.new()
	theme.text_font_size = 21
	theme.line_separation = 7
	theme.text_speed = 4000.0
	_p.set_dialogue_theme(theme)
	await _show_ready("默认字体行高验收：这一段文本用于确认正文高度按真实字体度量取整。" .repeat(18))
	var font := _label.get_theme_font("normal_font")
	var line_height := font.get_height(21) + 7.0
	var ratio := _label.size.y / line_height
	_check(absf(ratio - roundf(ratio)) < 0.02,
		"默认字体：正文高度按真实行高取整（%.1f / %.1f = %.2f 行）" % [_label.size.y, line_height, ratio])
	var start := int(_p.get("_page_line"))
	var end := int(_p.call("_page_end_line"))
	var tops: PackedFloat32Array = _p.call("_measure_line_tops", true)
	if end < tops.size() and start < tops.size():
		_check(tops[end] - tops[start] >= _label.size.y - 0.5,
			"默认字体：页底不露半行（下一行起点 %.1f ≥ 视口 %.1f）" % [tops[end] - tops[start], _label.size.y])
	else:
		_check(true, "默认字体：单页文本无需检查页底")

# ── 分页完整性 ─────────────────────────────────────────────

func _walk_pages(title: String, overlap: bool) -> int:
	_p.set("page_overlap", overlap)
	var guard := 0
	var pages := 1
	while bool(_p.call("_has_more_pages")) and guard < 40:
		var start := int(_p.get("_page_line"))
		var end := int(_p.call("_page_end_line"))
		_check_page_bounds(title, start, end)
		_p.call("_next_page")
		await process_frame
		var next := int(_p.get("_page_line"))
		var expected := end if not overlap else maxi(start + 1, end - 1)
		_check(next == expected, "%s：第 %d 页起点连续（%d→%d）" % [title, pages + 1, start, next])
		_check(bool(_p.get("_waiting_confirm")), "%s：翻页后仍等待确认" % title)
		pages += 1
		guard += 1
	_check(pages < 40, "%s：翻页次数未失控" % title)
	return pages

func _check_page_bounds(title: String, start: int, end: int) -> void:
	var total := _label.get_line_count()
	var tops: PackedFloat32Array = _p.call("_measure_line_tops")
	var content := float(_label.get_content_height())
	_check(start >= 0 and end > start and end <= total, "%s：页范围有效（%d..%d/%d）" % [title, start, end, total])
	if tops.is_empty() or start >= tops.size():
		return
	var limit := tops[start] + _label.size.y + 0.5
	var inside := true
	for i in range(start, end):
		var bottom := content if i + 1 >= tops.size() else tops[i + 1]
		if bottom > limit + 0.5:
			inside = false
	_check(inside, "%s：页内行均未越出正文高度" % title)
	if end < total:
		var end_bottom := content if end + 1 >= tops.size() else tops[end + 1]
		_check(end_bottom > limit, "%s：下一页从第一个未完整行开始" % title)

# ── 辅助 ─────────────────────────────────────────────────

func _set_theme(font_size: int, sep: int, speed: float = 4000.0) -> void:
	var theme := RpgEventStudioTheme.new()
	theme.font_path = DEFAULT_FONT_FIXTURE
	theme.text_font_size = font_size
	theme.line_separation = sep
	theme.text_speed = speed
	_p.set_dialogue_theme(theme)

func _new_long() -> void:
	_set_theme(20, 8)
	await _show_ready("这是一段用于验收输入链路的长文本，需要多个页面才能读完。" .repeat(18))

func _show_ready(text: String) -> void:
	_p.call("show_text", "旁白", text)
	var waited := 0
	while not bool(_p.get("_waiting_confirm")) and waited < 500:
		await process_frame
		waited += 1
	await create_timer(0.22).timeout

func _press_key(code: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = code
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await create_timer(0.18).timeout

func _click_mouse() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(600, 500)
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(600, 500)
	Input.parse_input_event(up)
	await create_timer(0.18).timeout

func _press_pad() -> void:
	var down := InputEventJoypadButton.new()
	down.device = 0
	down.button_index = JOY_BUTTON_A
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventJoypadButton.new()
	up.device = 0
	up.button_index = JOY_BUTTON_A
	up.pressed = false
	Input.parse_input_event(up)
	await create_timer(0.18).timeout

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──────── 对话框分页专项测试 ────────")
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
