@tool
class_name DialoguePresenter
extends CanvasLayer
## 运行期对话界面：底部对话框 + 选项列表。
## 键盘 / 鼠标 / 手柄都通过 InputService 的动作触发，可在按键设置里改键。

var input: InputService
var blocked: bool = false
## 主题页在编辑器里实例化预览时置 true；正常运行时保持 false。
var editor_preview := false

## 当前主题；默认值在 RpgEventStudioTheme 里，未配置主题时与旧外观一致。
var style: RpgEventStudioTheme

var _root: Control
var _theme_root: Theme
var _margin: MarginContainer
var _column: VBoxContainer
var _choice_margin: MarginContainer
var _choices_scroll: ScrollContainer
var _fade_rect: ColorRect
var _fade_tween: Tween
var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _hint_label: Label
var _choices_panel: PanelContainer
var _choices_box: VBoxContainer

var _typing := false
var _waiting_confirm := false
var _text_done := true
var _reveal := 0.0
var _reveal_total := 0
var _speed := 42.0
var _auto_deadline := 0
var _auto_duration := 0.0
var _page_line := 0
## 翻页是否重复上一页最后一个完整行；默认不重复，只在边界重复部分可见行。
var page_overlap := false
var _line_tops: PackedFloat32Array = PackedFloat32Array()
var _line_tops_key := ""
var _input_cooldown := 0
var _mouse_click := false
var _choice_result := -1
var _choice_index := -1
var _choice_buttons: Array[Button] = []
var _paused_at := -1
var _panel_tween: Tween
var _choices_tween: Tween

## 调试用：最近显示过的文字与解析结果（集成测试与问题排查会读它）
var last_text := ""
var last_parsed_text := ""
var last_bbcode_issues: Dictionary = {}
var shown_texts: PackedStringArray = []

func _ready() -> void:
	if Engine.is_editor_hint() and not editor_preview:
		return
	process_mode = Node.PROCESS_MODE_PAUSABLE
	layer = 20
	if style == null:
		style = RpgEventStudioTheme.new()
	_build_ui()
	_apply_style()
	_panel.hide()
	_choices_panel.hide()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_paused_at = Time.get_ticks_msec()
	elif what == NOTIFICATION_UNPAUSED and _paused_at >= 0:
		var elapsed := Time.get_ticks_msec() - _paused_at
		if _auto_deadline > 0:
			_auto_deadline += elapsed
		_input_cooldown += elapsed
		_paused_at = -1

func _build_ui() -> void:
	_theme_root = Theme.new()
	_root = Control.new()
	_root.name = "RPGEventStudioUI"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme_root
	add_child(_root)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.modulate.a = 0.0
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade_rect)

	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.anchor_left = 0.06
	_panel.anchor_right = 0.94
	_panel.anchor_top = 0.60
	_panel.anchor_bottom = 0.93
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(_panel)

	_margin = MarginContainer.new()
	_panel.add_child(_margin)

	_column = VBoxContainer.new()
	_margin.add_child(_column)

	_name_label = Label.new()
	_column.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = false
	# 滚动在 _update_heights 里按内容高度按需开启：短文本不显示滚动条，
	# 超长文本必须能滚动，否则 1152×648 下正文会被从行中间裁掉。
	_text_label.scroll_active = false
	_text_label.scroll_following = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_column.add_child(_hint_label)

	_choices_panel = PanelContainer.new()
	_choices_panel.name = "ChoicePanel"
	# 锚点在 _apply_style 里设置：顶边固定、高度随选项数量自适应。
	_choices_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(_choices_panel)

	_choice_margin = MarginContainer.new()
	_choices_panel.add_child(_choice_margin)

	# 选项过多且窗口过矮时才出现滚动条，平时高度贴合并选项数量。
	_choices_scroll = ScrollContainer.new()
	_choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_choice_margin.add_child(_choices_scroll)

	_choices_box = VBoxContainer.new()
	_choices_scroll.add_child(_choices_box)

func _make_panel_style() -> StyleBoxFlat:
	if style == null:
		style = RpgEventStudioTheme.new()
	return style.make_panel_style()

## 注入/刷新主题。主题页与运行时共用同一个入口。
func set_dialogue_theme(theme: RpgEventStudioTheme) -> void:
	style = theme if theme != null else RpgEventStudioTheme.new()
	_line_tops.clear()
	_line_tops_key = ""
	if _root != null:
		_apply_style()
		if _choices_panel.visible:
			_update_choice_highlight()
		_schedule_height_update()

func _apply_style() -> void:
	if _root == null or style == null:
		return
	_theme_root = Theme.new()
	_theme_root.default_font = style.resolve_font()
	_theme_root.default_font_size = style.font_size
	_root.theme = _theme_root

	_panel.anchor_left = style.panel_left
	_panel.anchor_right = style.panel_right
	# 底边固定在 panel_bottom，顶边随内容（正文长度）自适应上移；
	# text_min_height 保证短文本也有稳定的面板高度，不跳动。
	_panel.anchor_top = style.panel_bottom
	_panel.anchor_bottom = style.panel_bottom
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0
	_panel.add_theme_stylebox_override("panel", style.make_panel_style())
	_margin.add_theme_constant_override("margin_left", style.content_margin_left)
	_margin.add_theme_constant_override("margin_right", style.content_margin_right)
	_margin.add_theme_constant_override("margin_top", style.content_margin_top)
	_margin.add_theme_constant_override("margin_bottom", style.content_margin_bottom)
	_column.add_theme_constant_override("separation", style.line_separation)

	_name_label.add_theme_font_size_override("font_size", style.speaker_font_size)
	_name_label.add_theme_color_override("font_color", style.speaker_color)
	_text_label.custom_minimum_size = Vector2(0, style.text_min_height)
	_text_label.add_theme_font_size_override("normal_font_size", style.text_font_size)
	_text_label.add_theme_color_override("default_color", style.text_color)
	_text_label.add_theme_constant_override("line_separation", style.line_separation)
	_hint_label.add_theme_font_size_override("font_size", style.hint_font_size)
	_hint_label.add_theme_color_override("font_color", style.hint_color)

	_choices_panel.anchor_left = style.choice_left
	_choices_panel.anchor_right = style.choice_right
	# 顶边固定在 choice_top，底边随选项数量自适应下移。
	_choices_panel.anchor_top = style.choice_top
	_choices_panel.anchor_bottom = style.choice_top
	_choices_panel.grow_vertical = Control.GROW_DIRECTION_END
	_choices_panel.offset_left = 0
	_choices_panel.offset_right = 0
	_choices_panel.offset_top = 0
	_choices_panel.offset_bottom = 0
	# 选项面板背景不透明：地图元素不允许透过面板影响选项文字。
	var choice_bg := style.make_panel_style()
	choice_bg.bg_color.a = 1.0
	_choices_panel.add_theme_stylebox_override("panel", choice_bg)
	_choice_margin.add_theme_constant_override("margin_left", style.choice_margin)
	_choice_margin.add_theme_constant_override("margin_right", style.choice_margin)
	_choice_margin.add_theme_constant_override("margin_top", style.choice_margin)
	_choice_margin.add_theme_constant_override("margin_bottom", style.choice_margin)
	_choices_box.add_theme_constant_override("separation", style.choice_separation)

	_speed = style.text_speed
	_fade_rect.color = style.fade_color
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.custom_minimum_size = Vector2(0, style.choice_min_height)
			button.add_theme_font_size_override("font_size", style.choice_font_size)

# ── 显示文字 ─────────────────────────────────────────────

func show_text(speaker: String, text: String, auto_advance: float = 0.0) -> void:
	last_text = text
	shown_texts.append(text)
	_name_label.text = speaker
	_name_label.visible = speaker.strip_edges() != ""
	_text_label.text = text
	_text_label.visible_characters = 0
	_text_label.scroll_active = false
	_page_line = 0
	_line_tops.clear()
	_line_tops_key = ""
	_hint_label.visible = false
	last_parsed_text = _text_label.get_parsed_text()
	last_bbcode_issues = Bbcode.analyze(text)
	if Bbcode.has_issues(last_bbcode_issues):
		push_warning("[RPGEventStudio] " + Bbcode.describe(last_bbcode_issues, false))

	_reveal = 0.0
	# 按解析后的可见字符数推进，不能把 [b] 这类标签字符算进打字机。
	_reveal_total = _text_label.get_total_character_count()
	_typing = _reveal_total > 0
	_waiting_confirm = false
	_text_done = false
	_auto_deadline = 0
	_auto_duration = auto_advance
	_input_cooldown = Time.get_ticks_msec() + 160
	_clear_choices()

	_show_panel_with_animation()
	_schedule_height_update()
	call_deferred("_reset_text_page")
	if not _typing:
		_finish_typing()
	elif auto_advance > 0.0:
		_auto_deadline = Time.get_ticks_msec() + int(auto_advance * 1000.0)

func is_text_finished() -> bool:
	return _text_done

## 淡入淡出：返回 tween（duration 为 0 时返回 null）。
func fade_to(alpha: float, duration: float) -> Tween:
	if _fade_rect == null:
		return null
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if duration <= 0.01:
		_fade_rect.modulate.a = alpha
		return null
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "modulate:a", alpha, duration)
	return _fade_tween

func clear_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _fade_rect != null:
		_fade_rect.modulate.a = 0.0

func hide_text() -> void:
	_hide_panel_with_animation()
	_text_done = true
	_waiting_confirm = false
	_typing = false

# ── 显示选项 ─────────────────────────────────────────────

func show_choices(prompt: String, options: Array) -> void:
	show_text("", prompt, 0.0)
	_typing = false
	_text_label.visible_characters = -1
	_waiting_confirm = false
	_text_done = false
	_choice_result = -1

	_clear_choice_buttons()
	for index in options.size():
		var button := Button.new()
		button.text = str(options[index])
		button.custom_minimum_size = Vector2(0, style.choice_min_height if style != null else 40.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# 自己管理选中项：不依赖 ui_up/ui_down，这样改键后依然有效
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.pressed.connect(_on_choice_pressed.bind(index))
		_choices_box.add_child(button)
		_choice_buttons.append(button)

	_show_choices_panel_with_animation()
	_schedule_height_update()
	_hint_label.visible = not editor_preview
	_hint_label.text = L10n.game("game.choice_hint")
	_choice_index = 0
	_update_choice_highlight()

func get_choice() -> int:
	return _choice_result

func _on_choice_pressed(index: int) -> void:
	if _choice_result >= 0 or not _choices_panel.visible or get_tree().paused:
		return
	_choice_result = index
	_hide_choices_panel_with_animation()
	_text_done = true

func _move_choice(delta: int) -> void:
	if _choice_buttons.is_empty():
		return
	_choice_index = wrapi(_choice_index + delta, 0, _choice_buttons.size())
	_update_choice_highlight()

func _update_choice_highlight() -> void:
	for index in _choice_buttons.size():
		var button := _choice_buttons[index]
		button.button_pressed = index == _choice_index
		_apply_choice_button_style(button, index == _choice_index)

func _apply_choice_button_style(button: Button, selected: bool) -> void:
	if style == null:
		return
	var box := style.make_choice_style(selected)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", box)
	button.add_theme_color_override("font_color", style.choice_selected_color if selected else style.choice_text_color)
	button.add_theme_color_override("font_hover_color", style.choice_selected_color)
	button.add_theme_color_override("font_pressed_color", style.choice_selected_color)
	button.add_theme_color_override("font_focus_color", style.choice_selected_color)

# ── 高度自适应 ───────────────────────────────────────────

var _height_retries := 0

## 正文 / 选项内容变化后延迟一帧测量，面板高度再贴合内容。
func _schedule_height_update() -> void:
	_height_retries = 0
	call_deferred("_update_heights")

func _update_heights() -> void:
	if _root == null or style == null:
		return
	var viewport_size := _root.get_viewport_rect().size
	if viewport_size.y <= 0.0:
		return
	# 布局还没给出宽度时再等一帧，最多重试 3 次。
	if _text_label.size.x <= 1.0 and _height_retries < 3:
		_height_retries += 1
		call_deferred("_update_heights")
		return
	# 对话框：正文高度夹在 [可用高度下限, 可用高度] 之间。
	# 窗口太矮时连 text_min_height 都放不下，此时优先保证面板不出屏；
	# 内容仍超过可见高度时开启滚动，不能把正文裁掉。
	var text_content := float(_text_label.get_content_height())
	var reserved := float(_margin.get_theme_constant("margin_top")) + float(_margin.get_theme_constant("margin_bottom")) \
		+ _name_label.get_combined_minimum_size().y + _hint_label.get_combined_minimum_size().y \
		+ 2.0 * float(_column.get_theme_constant("separation"))
	var panel_room := maxf(1.0, viewport_size.y * (style.panel_bottom - style.panel_top) - reserved)
	var text_min := minf(style.text_min_height, panel_room)
	var panel_max := maxf(text_min, panel_room)
	# 正文高度按整行对齐，分页边界不会留下半行。
	var line_height := maxf(1.0, float(style.text_font_size + style.line_separation))
	var snapped_max: float = floor(panel_max / line_height) * line_height
	if snapped_max < text_min:
		snapped_max = panel_max
	_text_label.custom_minimum_size = Vector2(0, clampf(text_content, text_min, snapped_max))
	# 游戏内台词不使用玩家可见的滚动条：超出部分由 _dismiss_text 翻页。
	_text_label.scroll_active = false
	if _waiting_confirm:
		_clamp_page_line()
		_update_page_hint()
	# 选项面板：高度贴合选项数量；窗口过矮且选项过多时出现滚动。
	var choice_content := _choices_box.get_combined_minimum_size().y
	var choice_reserved := 2.0 * float(style.choice_margin)
	var choice_max := maxf(0.0, viewport_size.y * (style.choice_bottom - style.choice_top) - choice_reserved)
	_choices_scroll.custom_minimum_size = Vector2(0, clampf(choice_content, 0.0, choice_max))

func _on_viewport_resized() -> void:
	# 窗口变化会改写换行/行高；重新贴合高度并按真实行偏移夹住当前页。
	_height_retries = 0
	call_deferred("_update_heights")

# ── 关闭 ─────────────────────────────────────────────────

func close_all() -> void:
	_kill_panel_tween()
	_kill_choices_tween()
	if _panel != null:
		_panel.modulate.a = 1.0
		_panel.hide()
	if _choices_panel != null:
		_choices_panel.modulate.a = 1.0
		_choices_panel.hide()
	_clear_choice_buttons()
	_typing = false
	_waiting_confirm = false
	_text_done = true
	_auto_duration = 0.0
	_choice_result = -1
	_choice_index = -1

# ── 每帧 ─────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		_mouse_click = false
		return

	var now := Time.get_ticks_msec()

	if _typing:
		_reveal += _speed * delta
		_text_label.visible_characters = int(_reveal)
		if _reveal >= float(_reveal_total):
			_finish_typing()
		_mouse_click = false
		return

	if blocked:
		_mouse_click = false
		return

	if _choices_panel.visible:
		if _pressed(InputService.ACTION_CHOICE_UP):
			_move_choice(-1)
		elif _pressed(InputService.ACTION_CHOICE_DOWN):
			_move_choice(1)
		elif now >= _input_cooldown and _pressed(InputService.ACTION_CONFIRM) and not _mouse_click:
			# 鼠标点击由按钮自己处理，这里只处理键盘与手柄
			_on_choice_pressed(_choice_index)
	elif _waiting_confirm:
		if _auto_deadline > 0 and now >= _auto_deadline:
			_dismiss_text()
		elif now >= _input_cooldown and (_pressed(InputService.ACTION_DIALOGUE_ADVANCE) or _mouse_click):
			_dismiss_text()

	_mouse_click = false

func _finish_typing() -> void:
	if _auto_duration > 0.0 and _auto_deadline == 0:
		_auto_deadline = Time.get_ticks_msec() + int(_auto_duration * 1000.0)
	_typing = false
	_text_label.visible_characters = -1
	_waiting_confirm = true
	_hint_label.visible = not editor_preview
	_update_page_hint()
	call_deferred("_update_page_hint")

## 下一页：用 RichTextLabel 的内部滚动值翻页，但不显示滚动条。
## 保留一行重叠，避免分页边界把一行切成两半。
## 用 RichTextLabel 的真实布局测量每一行的顶部偏移。
## 不能用 font_size + line_separation 估算：实际行高受字体度量、BBCode
## [font_size] 混排和自动换行影响，估算会导致页底半行或跳行。
func _measure_line_tops(force: bool = false) -> PackedFloat32Array:
	var total := _text_label.get_line_count()
	var content := float(_text_label.get_content_height())
	var key := "%d|%.1f|%.1f|%.1f|%d|%d" % [
		total, _text_label.size.x, _text_label.size.y, content,
		style.text_font_size if style != null else 0,
		style.line_separation if style != null else 0,
	]
	if not force and key == _line_tops_key and _line_tops.size() == total:
		return _line_tops
	var bar := _text_label.get_v_scroll_bar()
	var restore := bar.value
	var tops := PackedFloat32Array()
	for i in total:
		_text_label.scroll_to_line(i)
		tops.append(bar.value)
	_line_tops = tops
	_line_tops_key = key
	bar.value = restore
	return tops

## 当前页第一行的顶部。
func _page_top(tops: PackedFloat32Array) -> float:
	if tops.is_empty():
		return 0.0
	return tops[clampi(_page_line, 0, tops.size() - 1)]

## 当前页最后一行（不包含）的索引；行高来自真实布局偏移。
func _page_end_line() -> int:
	var total := _text_label.get_line_count()
	if total <= 0:
		return 0
	var tops := _measure_line_tops()
	if tops.is_empty():
		return total
	var start := clampi(_page_line, 0, total - 1)
	var limit := _page_top(tops) + _text_label.size.y + 0.5
	var content := float(_text_label.get_content_height())
	var end := start
	while end < total:
		var bottom := content if end + 1 >= total else tops[end + 1]
		if bottom > limit:
			break
		end += 1
	if end == start:
		end = mini(total, start + 1)
	return end

func _visible_lines() -> int:
	return maxi(1, _page_end_line() - _page_line)

func _next_page() -> void:
	var total := _text_label.get_line_count()
	if total <= 0:
		return
	var end := _page_end_line()
	if end >= total:
		return
	var next := end
	if page_overlap:
		next = maxi(_page_line + 1, end - 1)
	next = clampi(next, _page_line + 1, total - 1)
	_page_line = next
	_text_label.scroll_to_line(_page_line)
	if _auto_duration > 0.0:
		_auto_deadline = Time.get_ticks_msec() + int(_auto_duration * 1000.0)
	_update_page_hint()

func _has_more_pages() -> bool:
	var view_h := _text_label.size.y
	# 极端小窗口/无窗口测试下正文高度可能只有 1px；此时不翻页。
	if view_h < 24.0:
		return false
	var total := _text_label.get_line_count()
	if total <= 0:
		return false
	return _page_end_line() < total

func _clamp_page_line() -> void:
	var total := _text_label.get_line_count()
	if total <= 0:
		_page_line = 0
		return
	_page_line = clampi(_page_line, 0, total - 1)
	_text_label.scroll_to_line(_page_line)

func _update_page_hint() -> void:
	if _hint_label == null or not _waiting_confirm:
		return
	_hint_label.text = L10n.game("game.advance_more") if _has_more_pages() else L10n.game("game.advance_hint")

func _reset_text_page() -> void:
	_page_line = 0
	_line_tops.clear()
	_line_tops_key = ""
	_text_label.scroll_to_line(0)
	if _waiting_confirm:
		_update_page_hint()

func _dismiss_text() -> void:
	if _has_more_pages():
		_next_page()
		return
	_waiting_confirm = false
	_text_done = true
	_hide_panel_with_animation()

func _pressed(action: StringName) -> bool:
	if input == null:
		return false
	return input.is_action_just_pressed(action)

func _input(event: InputEvent) -> void:
	if editor_preview:
		return
	# 记录鼠标左键按下沿（即使点在 UI 上也算），供对话推进判断
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_mouse_click = true

# ── 内部 ─────────────────────────────────────────────────

func _show_panel_with_animation() -> void:
	_kill_panel_tween()
	_panel.show()
	if style != null and style.appear_duration > 0.0:
		_panel.modulate.a = 0.0
		_panel_tween = create_tween()
		_panel_tween.tween_property(_panel, "modulate:a", 1.0, style.appear_duration)
	else:
		_panel.modulate.a = 1.0

func _hide_panel_with_animation() -> void:
	_kill_panel_tween()
	if style != null and style.disappear_duration > 0.0 and _panel.visible:
		_panel_tween = create_tween()
		_panel_tween.tween_property(_panel, "modulate:a", 0.0, style.disappear_duration)
		_panel_tween.finished.connect(func() -> void:
			if _panel != null:
				_panel.hide()
				_panel.modulate.a = 1.0
		)
	else:
		_panel.hide()
		_panel.modulate.a = 1.0

func _show_choices_panel_with_animation() -> void:
	_kill_choices_tween()
	_choices_panel.show()
	if style != null and style.appear_duration > 0.0:
		_choices_panel.modulate.a = 0.0
		_choices_tween = create_tween()
		_choices_tween.tween_property(_choices_panel, "modulate:a", 1.0, style.appear_duration)
	else:
		_choices_panel.modulate.a = 1.0

func _hide_choices_panel_with_animation() -> void:
	_kill_choices_tween()
	if style != null and style.disappear_duration > 0.0 and _choices_panel.visible:
		_choices_tween = create_tween()
		_choices_tween.tween_property(_choices_panel, "modulate:a", 0.0, style.disappear_duration)
		_choices_tween.finished.connect(func() -> void:
			if _choices_panel != null:
				_choices_panel.hide()
				_choices_panel.modulate.a = 1.0
				_clear_choice_buttons()
		)
	else:
		_choices_panel.hide()
		_choices_panel.modulate.a = 1.0
		_clear_choice_buttons()

func _kill_panel_tween() -> void:
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = null

func _kill_choices_tween() -> void:
	if _choices_tween != null and _choices_tween.is_valid():
		_choices_tween.kill()
	_choices_tween = null

func _clear_choices() -> void:
	_kill_choices_tween()
	_choices_panel.modulate.a = 1.0
	_choices_panel.hide()
	if _choices_scroll != null:
		_choices_scroll.custom_minimum_size = Vector2(0, 0)
	_clear_choice_buttons()
	_choice_result = -1
	_choice_index = -1

func _clear_choice_buttons() -> void:
	if _choices_box == null:
		return
	for child in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()
	_choice_buttons.clear()
