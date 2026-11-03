extends SceneTree
## UI 外观拓展包 · 真实运行态验收（非 headless 窗口 + 真实输入事件）
##   godot --path . --script res://tools/acceptance/ui_runtime_acceptance.gd
##
## 覆盖：与图书管理员交互 → 正文显示 → 长文本分页翻页 → 短文本布局 →
##       选项显示 → 选项切换反馈 → 动画最终帧 → 按键设置弹层（布局/交互/关闭）。
## 截图与结果写入 docs/ 下，供人工复核；脚本本身不修改示例数据。

const SHOT_DIR := "res://docs/images/ui-appearance-runtime"
const RESULT_DIR := "res://docs/qa/2026-11-03/ui-appearance-runtime"
const VIEW := Vector2i(1152, 648)

var _checks: Array[Dictionary] = []
var _scene: Node
var _runtime: Node
var _presenter: DialoguePresenter
var _player: Node2D
var _shot_index := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = VIEW
	DisplayServer.window_set_size(VIEW)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESULT_DIR))
	await create_timer(0.35).timeout

	_scene = load("res://addons/rpgeventstudio/samples/scenes/school_demo.tscn").instantiate()
	root.add_child(_scene)
	await create_timer(0.9).timeout
	_runtime = root.get_node_or_null("RPGEventStudio")
	_player = root.get_node_or_null("SchoolDemo/Player")
	if _runtime == null or _player == null:
		_fail("bootstrap", "运行时或玩家节点缺失")
		_report()
		quit(1)
		return
	_presenter = _runtime.get("presenter") as DialoguePresenter
	await _shot("01-world")

	await _scene_interact()
	await _choices()
	await _after_choice()
	await _long_text_pages()
	await _wide_layout()
	await _input_settings()

	_report()
	quit(0 if _failure_count() == 0 else 1)

# ── 1. 走到图书管理员身边并按交互键 ─────────────────────────

func _scene_interact() -> void:
	var interactor := _scene.get_node_or_null("Librarian/EventInteractor") as EventInteractor2D
	if interactor == null:
		_fail("interact", "找不到图书管理员交互组件")
		return
	# 真实按键驱动角色移动（走 InputService 动作，不直接改坐标）
	await _hold_until([&"move_right"], func() -> bool: return _player.global_position.x >= 598.0, 3.0)
	await _hold_until([&"move_up"], func() -> bool: return _player.global_position.y <= 362.0, 3.0)
	await create_timer(0.25).timeout
	_check("interact.reach", _player.global_position.distance_to(interactor.global_position) <= 78.0,
		"玩家进入交互半径（距离 %.1f）" % _player.global_position.distance_to(interactor.global_position))

	# 示例场景里也有一枚静态 Prompt 占位；运行时用的是组件自己创建的 _prompt。
	var prompt := interactor.get("_prompt") as Label
	await _wait_until(func() -> bool: return prompt != null and prompt.visible, 1.0)
	_check("interact.prompt", prompt != null and prompt.visible,
		"交互提示出现（%s）" % (prompt.text if prompt != null else "无 Prompt"))
	await _shot("02-interact-prompt")

	await _press_key(KEY_SPACE)
	await process_frame
	var started := _presenter != null and _presenter.get("_panel") != null and (_presenter.get("_panel") as Control).visible
	_check("interact.trigger", started, "按下交互键后对话框打开")
	if not started:
		return
	await _wait_text_finished(2.0)
	var shown: String = _presenter.last_text
	_check("dialogue.first_text", shown.contains("你看起来在找什么"), "正文显示第一句：%s" % shown)
	await create_timer(0.45).timeout
	await _shot("03-dialogue-short")

	var panel := _presenter.get("_panel") as PanelContainer
	var vp := root.get_visible_rect().size
	_check("dialogue.short_bounds", panel.global_position.y >= 0.0 and panel.global_position.y + panel.size.y <= vp.y + 0.5,
		"短文本对话框在窗口内（bottom=%.1f / %.1f）" % [panel.global_position.y + panel.size.y, vp.y])
	_check("dialogue.short_no_scroll", not (_presenter.get("_text_label") as RichTextLabel).get_v_scroll_bar().visible,
		"短文本不出现正文滚动条")
	_check("dialogue.speaker_style", _presenter.get("_name_label") != null and (_presenter.get("_name_label") as Label).get_theme_stylebox("normal") != null,
		"说话人标签应用了外观包样式")
	_check("dialogue.final_alpha", is_equal_approx((_presenter.get("_panel") as Control).modulate.a, 1.0),
		"出现动画结束后不透明度为 1")

# ── 2. 选项显示与选中反馈 ─────────────────────────────────

func _choices() -> void:
	if _presenter == null:
		_fail("choices", "没有对话框")
		return
	await _advance()
	await _wait_until(func() -> bool: return (_presenter.get("_choices_panel") as Control).visible and (_presenter.get("_choice_buttons") as Array).size() == 2, 2.0)
	# 等选项面板的出现动画（0.18s）结束再取「最终画面」，否则截到半透明中间帧。
	await create_timer(0.4).timeout
	var buttons: Array = _presenter.get("_choice_buttons")
	var panel := _presenter.get("_choices_panel") as Control
	print("[DEBUG] choices visible=", panel.visible if panel != null else "null", " buttons=", buttons.size(), " result=", _presenter.get_choice(), " index=", _presenter.get("_choice_index"))
	_check("choices.visible", panel != null and panel.visible and buttons.size() == 2,
		"选项面板显示且为 2 项（实际 %d）" % buttons.size())
	if buttons.size() != 2:
		return
	_check("choices.numbered", str(buttons[0].text).begins_with("01") and str(buttons[1].text).begins_with("02"),
		"选项带编号：%s / %s" % [buttons[0].text, buttons[1].text])
	_check("choices.default_selected", int(_presenter.get("_choice_index")) == 0, "默认选中第 1 项")
	var normal_box := buttons[1].get_theme_stylebox("normal") as StyleBoxFlat
	var selected_box := buttons[0].get_theme_stylebox("normal") as StyleBoxFlat
	_check("choices.selected_style", normal_box != null and selected_box != null and selected_box.bg_color != normal_box.bg_color,
		"选中项与未选中项背景不同（%s / %s）" % [selected_box.bg_color if selected_box != null else "?", normal_box.bg_color if normal_box != null else "?"])
	await _shot("04-choices")

	# 键盘切换
	await _press_key(KEY_DOWN)
	await create_timer(0.25).timeout
	_check("choices.keyboard_switch", int(_presenter.get("_choice_index")) == 1, "方向键把选中项切到第 2 项")
	var sel1 := (buttons[1].get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	_check("choices.keyboard_feedback", sel1 != (buttons[0].get_theme_stylebox("normal") as StyleBoxFlat).bg_color,
		"切换后高亮跟随到第 2 项")
	await _shot("05-choice-keyboard")

	# 鼠标悬停切换
	var pos: Vector2 = buttons[0].get_global_rect().get_center()
	_move_mouse(pos)
	await create_timer(0.3).timeout
	_check("choices.mouse_switch", int(_presenter.get("_choice_index")) == 0, "鼠标移到第 1 项后选中反馈切回第 1 项")
	await _shot("06-choice-mouse")

	# 真实点击选中（走 GUI 命中，不直接发 pressed）
	_move_mouse(pos)
	await process_frame
	_mouse_press(pos)
	await process_frame
	_mouse_release(pos)
	await create_timer(0.3).timeout
	_check("choices.click_select", not (_presenter.get("_choices_panel") as Control).visible,
		"鼠标点击后选项面板关闭并进入所选分支")

# ── 3. 选项之后：短句 / 获得提示 / 事件第二页 ─────────────

func _after_choice() -> void:
	if _presenter == null:
		return
	await _wait_new_text("这把钥匙给你", 3.0)
	await create_timer(0.45).timeout
	var got_key: String = _presenter.last_text
	_check("flow.key_text", got_key.contains("这把钥匙给你"), "选项分支正文：%s" % got_key)
	await _shot("07-branch-text")

	await _advance()
	await _wait_new_text("获得【教室钥匙】", 3.0)
	await create_timer(0.45).timeout
	_check("flow.item_text", _presenter.last_text.contains("获得【教室钥匙】"), "获得道具提示：%s" % _presenter.last_text)
	await _shot("08-item-text")

	# `end` 指令结束的是整个事件；再交互一次才会命中「已持有钥匙」的条件页。
	await _advance()
	await create_timer(0.7).timeout
	_check("flow.event_end", not (_presenter.get("_panel") as Control).visible, "获得钥匙后本次事件结束")
	await _press_key(KEY_SPACE)
	await _wait_new_text("钥匙要收好", 3.0)
	await create_timer(0.55).timeout
	_check("flow.conditional_page", _presenter.last_text.contains("钥匙要收好"),
		"再次交互命中条件页：%s" % _presenter.last_text)
	var panel := _presenter.get("_panel") as Control
	_check("anim.final_frame", panel.visible and is_equal_approx(panel.modulate.a, 1.0) and is_equal_approx(panel.offset_top, 0.0) and is_equal_approx(panel.offset_bottom, 0.0),
		"动画结束后的最终画面：可见、alpha=1、offset=0")
	await _shot("09-anim-final")
	await _advance()
	await create_timer(0.45).timeout

# ── 4. 长文本分页（真实运行时 + 默认展示层） ──────────────

func _long_text_pages() -> void:
	var definition := EventDefinition.new()
	definition.event_id = &"ui_acceptance_long"
	definition.display_name = "长文本验收"
	var page := EventPage.new()
	var text := ""
	for i in 14:
		text += "第%02d段：这段长正文用于验收运行态分页，确认每页行首行尾都不被裁切。\n" % (i + 1)
	page.commands = [_text_command("图书管理员", text), _end_command()]
	definition.pages = [page]

	var lines_before: int = (_presenter.get("_text_label") as RichTextLabel).get_line_count()
	_runtime.call("start_event", definition, {}, [], {"kind": "acceptance", "node": "RuntimeAcceptance"})
	await create_timer(0.35).timeout
	_presenter.call("_finish_typing")
	await create_timer(0.45).timeout
	_check("long.started", (_presenter.get("_panel") as Control).visible, "长文本事件在真实运行时启动")
	_check("long.needs_pages", bool(_presenter.call("_has_more_pages")), "长文本需要翻页")
	var label := _presenter.get("_text_label") as RichTextLabel
	_check("long.no_scrollbar", not label.get_v_scroll_bar().visible, "长文本不使用滚动条")
	var first := int(_presenter.get("_page_line"))
	await _shot("10-long-page1")

	await _advance()
	await create_timer(0.35).timeout
	var second := int(_presenter.get("_page_line"))
	_check("long.page2_advance", second > first, "翻页推进（%d → %d）" % [first, second])
	_check("long.page2_visible", label.get_visible_line_count() > 0, "第 2 页有可见行")
	await _shot("11-long-page2")

	await _advance()
	await create_timer(0.35).timeout
	var third := int(_presenter.get("_page_line"))
	_check("long.page3_advance", third > second, "再次翻页推进（%d → %d）" % [second, third])
	await _shot("12-long-page3")

	var pages := 0
	while bool(_presenter.call("_has_more_pages")) and pages < 40 and (_presenter.get("_panel") as Control).visible:
		await _advance()
		pages += 1
		await create_timer(0.26).timeout
	_check("long.terminates", pages < 40, "长文本翻页可终止（额外 %d 页）" % pages)

	# 清场，回到干净状态
	_runtime.call("cancel_all", "acceptance")
	await create_timer(0.35).timeout
	_check("long.cleanup", not (_presenter.get("_panel") as Control).visible, "验收事件结束后界面复位（正文行数 %d → %d）" %
		[lines_before, label.get_line_count()])

# ── 4b. 1280×820 大窗边界 ────────────────────────────────

func _wide_layout() -> void:
	root.size = Vector2i(1280, 820)
	DisplayServer.window_set_size(Vector2i(1280, 820))
	await create_timer(0.45).timeout
	var definition := EventDefinition.new()
	definition.event_id = &"ui_acceptance_wide"
	definition.display_name = "大窗长文本验收"
	var page := EventPage.new()
	var text := ""
	for i in 10:
		text += "大窗第%02d段：检查 1280×820 下正文分页、面板边界与选项区宽度。\n" % (i + 1)
	page.commands = [_text_command("图书管理员", text), _end_command()]
	definition.pages = [page]
	_runtime.call("start_event", definition, {}, [], {"kind": "acceptance", "node": "RuntimeAcceptance"})
	await create_timer(0.35).timeout
	_presenter.call("_finish_typing")
	await create_timer(0.5).timeout
	var panel := _presenter.get("_panel") as Control
	var label := _presenter.get("_text_label") as RichTextLabel
	var font := label.get_theme_font("normal_font")
	var line_height := font.get_height(21) + 7.0
	var ratio := label.size.y / line_height
	var vp := root.get_visible_rect().size
	_check("wide.panel_inside", panel.global_position.y >= 0.0 and panel.global_position.y + panel.size.y <= vp.y + 0.5,
		"1280×820 面板在窗口内（bottom=%.0f / %.0f）" % [panel.global_position.y + panel.size.y, vp.y])
	_check("wide.whole_lines", absf(ratio - roundf(ratio)) < 0.02,
		"1280×820 正文按真实行高取整（%.1f / %.1f = %.2f 行）" % [label.size.y, line_height, ratio])
	_check("wide.page_turn", bool(_presenter.call("_has_more_pages")), "1280×820 长文本可翻页")
	await _shot("12b-long-1280x820")
	await _advance()
	await create_timer(0.3).timeout
	await _shot("12c-long-1280x820-page2")
	_runtime.call("cancel_all", "acceptance")
	await create_timer(0.35).timeout
	root.size = VIEW
	DisplayServer.window_set_size(VIEW)
	await create_timer(0.45).timeout

# ── 5. 按键设置弹层 ──────────────────────────────────────

func _input_settings() -> void:
	var panel: InputSettingsPanel = _runtime.get("settings_panel")
	if panel == null:
		_fail("settings", "找不到按键设置面板")
		return
	await _press_key(KEY_F1)
	await create_timer(0.45).timeout
	_check("settings.open_by_key", panel.is_open() and panel.visible, "按 F1 打开按键设置弹层")
	var root_control := panel.get("_panel") as PanelContainer
	var rect := root_control.get_global_rect()
	var vp := root.get_visible_rect().size
	_check("settings.bounds", rect.position.x >= 0.0 and rect.position.y >= 0.0
		and rect.end.x <= vp.x + 0.5 and rect.end.y <= vp.y + 0.5,
		"弹层在窗口内（%.0fx%.0f @ %.0f,%.0f / %.0fx%.0f）" % [rect.size.x, rect.size.y, rect.position.x, rect.position.y, vp.x, vp.y])
	var rows := panel.get("_rows") as VBoxContainer
	_check("settings.rows", rows != null and rows.get_child_count() >= 8, "操作行已生成（%d 组）" % (rows.get_child_count() if rows != null else 0))
	_check("settings.blocks_game", bool(_runtime.call("is_ui_blocking")), "弹层打开时游戏输入被阻断")
	await _shot("13-input-settings")

	# 交互：切换语言后再切回，行与文案都要刷新
	var lang := panel.get("_lang_option") as OptionButton
	lang.select(1)
	lang.item_selected.emit(1)
	await create_timer(0.3).timeout
	_check("settings.language", str((panel.get("_title") as Label).text) == "Input Settings", "语言切换后标题刷新为英文（实际 %s）" % (panel.get("_title") as Label).text)
	await _shot("14-input-settings-en")
	lang.select(0)
	lang.item_selected.emit(0)
	await create_timer(0.3).timeout
	_check("settings.language_back", str((panel.get("_title") as Label).text) == "按键设置", "语言切回中文（实际 %s）" % (panel.get("_title") as Label).text)

	# 交互：点「修改」进入改键监听，Esc 取消监听且弹层不关闭
	var change_button := _find_button(rows, "修改")
	_check("settings.rebind_button", change_button != null, "找到改键按钮")
	if change_button != null:
		await _click_mouse(change_button.get_global_rect().get_center())
		await create_timer(0.45).timeout
		_check("settings.listening", panel.is_listening(), "点击修改后进入按键监听")
		await _shot("15-input-listening")
		_press_escape()
		await create_timer(0.4).timeout
		_check("settings.cancel_listen", not panel.is_listening() and panel.is_open(), "Esc 只取消监听，不关闭弹层")

	# 关闭：先点关闭按钮，再用 Esc 覆盖键盘关闭
	var close_button := panel.get("_close_button") as Button
	await _click_mouse(close_button.get_global_rect().get_center())
	await create_timer(0.35).timeout
	_check("settings.close_button", not panel.is_open(), "点击关闭按钮后弹层关闭")
	await _shot("16-settings-closed")

	await _press_key(KEY_F1)
	await create_timer(0.35).timeout
	_check("settings.reopen", panel.is_open(), "再次按 F1 重新打开")
	_press_escape()
	await create_timer(0.35).timeout
	_check("settings.close_esc", not panel.is_open(), "Esc 关闭弹层")
	_check("settings.unblock", not bool(_runtime.call("is_ui_blocking")), "关闭后游戏输入恢复")
	await _shot("17-settings-restored")

# ── 工具 ─────────────────────────────────────────────────

func _text_command(speaker: String, text: String) -> EventCommand:
	var command := EventCommand.new()
	command.type = &"show_text"
	command.params = {"speaker": speaker, "text": text, "auto_advance": 0.0}
	return command

func _end_command() -> EventCommand:
	var command := EventCommand.new()
	command.type = &"end"
	command.params = {}
	return command

## 真实按键：和玩家一样走 InputEventKey，同时覆盖事件型与轮询型输入路径。
func _press_key(code: int) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _move_mouse(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)

func _mouse_press(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)

func _mouse_release(position: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)

func _press_escape() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_ESCAPE
	press.physical_keycode = KEY_ESCAPE
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.keycode = KEY_ESCAPE
	release.physical_keycode = KEY_ESCAPE
	release.pressed = false
	Input.parse_input_event(release)

func _find_button(root_node: Node, text: String) -> Button:
	for child in root_node.get_children():
		if child is Button and str((child as Button).text) == text:
			return child as Button
		var nested := _find_button(child, text)
		if nested != null:
			return nested
	return null

func _wait_until(predicate: Callable, timeout: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return
		await process_frame

func _click_mouse(position: Vector2) -> void:
	_move_mouse(position)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)

func _advance() -> void:
	await _press_key(KEY_SPACE)

func _hold_until(actions: Array, done: Callable, seconds: float) -> void:
	for action in actions:
		Input.action_press(action)
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if done.call():
			break
		await process_frame
	for action in actions:
		Input.action_release(action)
	await create_timer(0.05).timeout

func _wait_text_finished(timeout: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if _presenter != null and bool(_presenter.is_text_finished()):
			return
		await process_frame

func _wait_new_text(needle: String, timeout: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if _presenter != null and str(_presenter.last_text).contains(needle):
			await _wait_text_finished(1.0)
			return
		await process_frame

func _check(id: String, ok: bool, detail: String) -> void:
	_checks.append({"id": id, "ok": ok, "detail": detail})
	print("%s %s | %s" % ["PASS" if ok else "FAIL", id, detail])

func _fail(id: String, detail: String) -> void:
	_check(id, false, detail)

func _failure_count() -> int:
	var count := 0
	for item in _checks:
		if not bool(item["ok"]):
			count += 1
	return count

func _report() -> void:
	var failures := _failure_count()
	print("──── 运行态验收：%d 项，失败 %d 项 ────" % [_checks.size(), failures])
	var data := {
		"view": [VIEW.x, VIEW.y],
		"passed": _checks.size() - failures,
		"failed": failures,
		"checks": _checks,
		"shots": SHOT_DIR,
		"at": Time.get_datetime_string_from_system(),
		"godot": Engine.get_version_info()["string"],
	}
	var file := FileAccess.open(RESULT_DIR + "/result.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
		print("[ACCEPTANCE] 结果写入 ", RESULT_DIR, "/result.json")

func _shot(name: String) -> void:
	# 强制重绘再抓帧：窗口被终端遮挡时不会自动出帧，get_texture 会拿到旧帧；
	# 只等 process_frame 就会截到上一状态（Kimi 之前的截图超时也与此有关）。
	RenderingServer.force_draw(true)
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		_fail("shot." + name, "抓帧失败")
		return
	var path := "%s/%s.png" % [SHOT_DIR, name]
	image.save_png(path)
	_shot_index += 1
	print("[SHOT] ", path, " ", image.get_size())
