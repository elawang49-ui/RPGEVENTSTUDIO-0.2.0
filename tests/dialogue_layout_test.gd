extends SceneTree
## 对话框小窗口布局测试（无编辑器）：
##   godot --headless --path . --script res://tests/dialogue_layout_test.gd
## 覆盖 1152×648 下：超长正文不能出现玩家可见滚动条，必须可翻页；
## 短正文不显示滚动条；对话框/选项面板底边不越出窗口；选项过多时使用内部滚动。

const VIEW_W := 1152
const VIEW_H := 648

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(VIEW_W, VIEW_H)
	var presenter := DialoguePresenter.new()
	root.add_child(presenter)
	await process_frame
	await process_frame

	var label: RichTextLabel = presenter.get("_text_label")
	var panel: PanelContainer = presenter.get("_panel")
	_check(label != null and panel != null, "对话框界面已构建")
	if label == null or panel == null:
		_report()
		quit(1)
		return

	var long_text := ""
	for i in 24:
		long_text += "这是一段用于验收的较长正文，用来验证超长文本可以滚动而不是被裁掉。"
	presenter.show_text("旁白", long_text)
	presenter.call("_finish_typing")
	for i in 10:
		await process_frame

	var text_bar := label.get_v_scroll_bar()
	_check(not label.scroll_active, "超长正文不启用玩家滚动条")
	_check(not text_bar.visible, "超长正文本体滚动条不可见")
	_check(label.get_content_height() > label.size.y, "超长正文内容高于可见区域")
	_check(bool(presenter.call("_has_more_pages")), "超长正文可翻页")
	presenter.call("_dismiss_text")
	await process_frame
	_check(text_bar.value > 0.0, "推进后翻到下一页（scroll=%.1f）" % text_bar.value)
	_check(bool(presenter.get("_waiting_confirm")), "翻页后仍等待继续")
	_check(panel.visible, "翻页后面板保持显示")
	_assert_inside(panel, "超长正文对话框")

	presenter.show_text("旁白", "短句。")
	presenter.call("_finish_typing")
	for i in 10:
		await process_frame
	_check(not label.scroll_active and not text_bar.visible, "短正文不显示滚动条")
	_check(label.get_content_height() <= label.size.y + 1.0, "短正文完整可见")
	_assert_inside(panel, "短正文对话框")

	var options: Array[String] = []
	for i in 12:
		options.append("选项 %d：这是一条用于检查过多选项时内部滚动的文本。" % (i + 1))
	presenter.show_choices("请选择处理方式", options)
	for i in 10:
		await process_frame
	var choices_panel: PanelContainer = presenter.get("_choices_panel")
	var choices_scroll: ScrollContainer = presenter.get("_choices_scroll")
	_check(choices_panel != null and choices_panel.visible, "选项面板可见")
	_check(choices_scroll != null and choices_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"选项面板允许按需纵向滚动")
	_check(choices_scroll != null and choices_scroll.custom_minimum_size.y <= VIEW_H,
		"选项滚动区高度不超过窗口")
	_check((presenter.get("_choice_buttons") as Array).size() == options.size(), "选项按钮数量与选项一致")
	_assert_inside(choices_panel, "选项面板")

	# 回归：短选项时按钮曾按文字最小宽度排版，缩在选项区左侧、面板右侧留大片空白。
	presenter.show_choices("要问点什么吗？", ["询问钥匙", "离开"])
	for i in 10:
		await process_frame
	var short_buttons: Array = presenter.get("_choice_buttons")
	_check(short_buttons.size() == 2, "短选项：按钮数量与选项一致")
	var short_width := 0.0
	for button in short_buttons:
		short_width = maxf(short_width, (button as Button).size.x)
	_check(short_width >= choices_scroll.size.x - 8.0,
		"短选项：按钮撑满选项区宽度（按钮 %.0f / 选项区 %.0f）" % [short_width, choices_scroll.size.x])

	presenter.queue_free()
	_report()
	quit(0 if _failures.is_empty() else 1)

func _assert_inside(control: Control, title: String) -> void:
	if control == null:
		_check(false, "%s存在" % title)
		return
	_check(control.position.y >= -1.0 and control.position.y + control.size.y <= float(VIEW_H) + 1.0,
		"%s底边不越出窗口（bottom=%.1f）" % [title, control.position.y + control.size.y])

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──────── 对话框布局测试结果 ────────")
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
