@tool
class_name ThemeChoiceRow
extends Control
## 单个选项的组合组件：Control 负责形状/阴影/标记绘制，内部 Button 负责
## 鼠标点击、悬停与文字。DialoguePresenter 仍把 Button 暴露在 _choice_buttons，
## 因此旧的键盘/点击/测试接口不变。

var style: RpgEventStudioTheme:
	set(value):
		style = value
		_apply_style()
var index := 0
## 横排（聊天胶囊）时由 Presenter 给出的最小宽度；竖排为 0（撑满）。
var min_width := 0.0
var selected := false
var hovered := false

var button: Button
var _font: Font
var _tween: Tween
## 选中反馈动画进度（0→1，≤240ms）；用于 grow-line/bar-up 等需要展开的效果。
var _select_progress := 0.0:
	set(value):
		_select_progress = value
		queue_redraw()
var _select_tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(0, 44)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if button == null:
		button = Button.new()
		button.name = "ChoiceButton"
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.mouse_entered.connect(func() -> void: set_hovered(true))
		button.mouse_exited.connect(func() -> void: set_hovered(false))
		add_child(button)
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.offset_left = 0
		button.offset_top = 0
		button.offset_right = 0
		button.offset_bottom = 0
	_layout_button()
	_apply_style()

func configure(theme: RpgEventStudioTheme, choice_index: int, text: String) -> void:
	style = theme
	index = choice_index
	if button == null:
		_ready()
	button.text = text
	button.tooltip_text = text
	_apply_style()

func set_selected(value: bool) -> void:
	var was := selected
	selected = value
	if button != null:
		button.button_pressed = value
	if selected and not was and style != null and not style.motion_reduced:
		_play_select_anim()
	elif not selected:
		_select_progress = 0.0
	_apply_style()
	queue_redraw()

## 选中反馈 ≤240ms：只驱动一个 0→1 进度，绘制层按 select_anim 解读。
func _play_select_anim() -> void:
	if _select_tween != null and _select_tween.is_valid():
		_select_tween.kill()
	if style.select_anim == "none" or style.select_anim == "step-cursor":
		_select_progress = 1.0
		return
	_select_progress = 0.0
	_select_tween = create_tween()
	_select_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_select_tween.tween_property(self, "_select_progress", 1.0, 0.22)

func set_hovered(value: bool) -> void:
	if hovered == value:
		return
	hovered = value
	# 悬停只改变视觉反馈，不抢键盘选中项；鼠标点击时才提交选择。
	_apply_font_colors()
	queue_redraw()

func _apply_style() -> void:
	if style == null or button == null:
		return
	_font = style.resolve_choice_font()
	custom_minimum_size = Vector2(min_width, style.choice_min_height)
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", style.choice_font_size)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER if (style.text_align == "center" or style.choice_style == "chat-chip") else HORIZONTAL_ALIGNMENT_LEFT
	# 像素光标步进闪烁需要逐帧重绘；其余样式静态。
	set_process(selected and style.choice_style == "pixel-box" and not style.motion_reduced)
	var marker_pad := 12
	if style.choice_marker != "none":
		marker_pad = maxi(12, style.choice_marker_width + 10)
		if style.choice_marker == "keycap":
			marker_pad = maxi(marker_pad, int(float(style.choice_marker_size) * 1.3) + 18)
	match style.choice_style:
		"glass-row":
			marker_pad = maxi(marker_pad, 22)
		"pixel-box":
			marker_pad = maxi(marker_pad, 30)
	var box := StyleBoxFlat.new()
	if _custom_draw():
		box.bg_color = Color(0, 0, 0, 0)
		box.border_color = Color(0, 0, 0, 0)
		box.set_border_width_all(0)
		box.set_corner_radius_all(0)
	else:
		box = style.make_choice_style(selected)
	box.content_margin_left = float(marker_pad) if (style.text_align != "center" and style.choice_style != "chat-chip") else 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	_apply_font_colors()
	_update_button_offset()

func _apply_font_colors() -> void:
	if style == null or button == null:
		return
	if style.uses_bare_choices():
		var base := style.choice_hover_text_color if hovered else style.choice_text_color
		var hover := style.choice_hover_text_color
		var active := style.choice_selected_color
		button.add_theme_color_override("font_color", base)
		button.add_theme_color_override("font_hover_color", active if selected else hover)
		button.add_theme_color_override("font_pressed_color", active)
		button.add_theme_color_override("font_focus_color", active)
		button.add_theme_color_override("font_disabled_color", base)
	else:
		button.add_theme_color_override("font_color", style.choice_selected_color if selected else style.choice_text_color)
		button.add_theme_color_override("font_hover_color", style.choice_selected_color if selected else style.choice_hover_text_color)
		button.add_theme_color_override("font_pressed_color", style.choice_selected_color)
		button.add_theme_color_override("font_focus_color", style.choice_selected_color)
		button.add_theme_color_override("font_disabled_color", style.choice_text_color)

func _update_button_offset() -> void:
	_layout_button()

## 手动贴合行宽：Button 直接做 anchor 全铺时会被自身最小宽度顶出，
## 造成选项文字在右侧被裁掉。这里固定左上角，再按行宽减掉选中位移。
func _layout_button() -> void:
	if button == null or style == null:
		return
	var shift := 0.0
	if selected and style.uses_bare_choices():
		shift = -float(style.choice_selected_shift)
	button.position = Vector2(shift, 0.0)
	button.size = Vector2(maxf(1.0, size.x - absf(shift)), maxf(1.0, size.y))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_button()
		queue_redraw()

const V5_STYLES := ["paper-sign", "keycap-index", "pill-solid", "skew-strip", "underline-list", "glass-row", "ink-stroke", "pixel-box", "chat-chip", "leaf-row"]

## v5 样式始终自绘（即使选项面板是 panel 模式），保证 pixel-box 等不被 StyleBox 圆角覆盖。
func _custom_draw() -> bool:
	return style != null and (style.uses_bare_choices() or style.choice_style in V5_STYLES)

func _draw() -> void:
	if style == null or not _custom_draw() or size.x <= 1.0 or size.y <= 1.0:
		return
	var shift := -float(style.choice_selected_shift) if selected else 0.0
	var r := Rect2(Vector2(shift, 0), Vector2(size.x - absf(shift), size.y))
	var fill := style.choice_normal_bg
	var text_color := style.choice_text_color
	if selected:
		fill = style.choice_selected_bg
		text_color = style.choice_selected_color
	elif hovered:
		fill = style.choice_hover_bg
		text_color = style.choice_hover_text_color
	var border_color := style.choice_selected_border_color if selected else style.choice_border_color
	var border_w := float(style.choice_border_width)
	match style.choice_style:
		"wing":
			_draw_wing(r, fill, text_color, border_color, border_w)
		"bar":
			_draw_bar(r, fill, text_color, border_color, border_w)
		"skew":
			_draw_skew(r, fill, text_color, border_color, border_w)
		"notch":
			_draw_notch(r, fill, text_color, border_color, border_w)
		"note":
			_draw_note(r, fill, text_color, border_color, border_w)
		"pill", "pill-solid":
			_draw_pill(r, fill, text_color, border_color, border_w)
		"spindle":
			_draw_spindle(r, fill, text_color, border_color, border_w)
		"swallowtail":
			_draw_swallowtail(r, fill, text_color, border_color, border_w)
		"crystal":
			_draw_crystal(r, fill, text_color, border_color, border_w)
		"filament":
			_draw_filament(r, text_color)
		"paper-sign":
			_draw_paper_sign(r, fill, text_color, border_color, border_w)
		"keycap-index":
			_draw_keycap_index(r, fill, text_color, border_color, border_w)
		"skew-strip":
			_draw_skew_strip(r, fill, text_color, border_color, border_w)
		"underline-list":
			_draw_underline_list(r, fill, text_color, border_color, border_w)
		"glass-row":
			_draw_glass_row(r, fill, text_color, border_color, border_w)
		"ink-stroke":
			_draw_ink_stroke(r, fill, text_color, border_color, border_w)
		"pixel-box":
			_draw_pixel_box(r, fill, text_color, border_color, border_w)
		"chat-chip":
			_draw_chat_chip(r, fill, text_color, border_color, border_w)
		"leaf-row":
			_draw_leaf_row(r, fill, text_color, border_color, border_w)
		_:
			_draw_flat(r, fill, text_color, border_color, border_w)
	if hovered and not selected and style.choice_style not in ["filament", "underline-list", "ink-stroke", "glass-row", "pixel-box", "paper-sign", "chat-chip"]:
		draw_line(Vector2(r.position.x + 2.0, r.position.y + 5.0), Vector2(r.position.x + 2.0, r.end.y - 5.0),
			Color(style.choice_accent_color, 0.9), 2.0, true)
	_draw_select_fx(r, text_color)
	_draw_marker(r, text_color)

func _draw_flat(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	draw_rect(r, fill, true)
	if border_w > 0.0:
		draw_rect(r, border, false, border_w)

func _draw_pill(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	if style.choice_shadow_color.a > 0.0:
		var sr := Rect2(r.position + style.choice_shadow_offset, r.size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = style.choice_shadow_color
		sb.set_corner_radius_all(int(r.size.y * 0.5))
		draw_style_box(sb, sr)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(int(border_w))
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	draw_style_box(sb, r)

func _draw_skew(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	var slant := minf(tan(deg_to_rad(float(style.choice_skew_degrees))) * r.size.y, r.size.x * 0.22)
	var p := PackedVector2Array([
		Vector2(r.position.x + slant, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - slant, r.end.y),
		Vector2(r.position.x, r.end.y),
	])
	draw_colored_polygon(p, fill)
	if border_w > 0.0:
		draw_line(p[0], p[3], border, border_w, true)
		draw_line(p[3], p[2], Color(border, border.a * 0.55), maxf(1.0, border_w - 1.0), true)
		draw_line(p[0], p[1], Color(border, border.a * 0.35), 1.0, true)

func _draw_notch(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	var n := minf(8.0, minf(r.size.x, r.size.y) * 0.2)
	if n < 0.5:
		draw_rect(r, fill, true)
		return
	var p := PackedVector2Array([
		Vector2(r.position.x + n, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.end.y - n),
		Vector2(r.end.x - n, r.end.y),
		Vector2(r.position.x, r.end.y),
		Vector2(r.position.x, r.position.y + n),
	])
	draw_colored_polygon(p, fill)
	if border_w > 0.0:
		draw_line(p[3], p[4], border, border_w, true)
		draw_line(p[4], p[5], border, border_w * 0.6, true)
		draw_line(p[0], p[1], Color(border, border.a * 0.4), 1.0, true)

func _draw_note(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	if style.choice_shadow_color.a > 0.0:
		var sr := Rect2(r.position + style.choice_shadow_offset, r.size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = style.choice_shadow_color
		sb.set_corner_radius_all(style.choice_corner_radius)
		draw_style_box(sb, sr)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(int(border_w))
	sb.set_corner_radius_all(style.choice_corner_radius)
	draw_style_box(sb, r)
	# 便签纸右上角折角，增加手账感。
	var fold := minf(12.0, r.size.x * 0.1)
	var p := PackedVector2Array([
		Vector2(r.end.x - fold, r.position.y + border_w),
		Vector2(r.end.x - border_w, r.position.y + border_w),
		Vector2(r.end.x - border_w, r.position.y + border_w + fold),
	])
	draw_colored_polygon(p, Color(style.accent_color, 0.35))

func _draw_wing(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	var steps := 24
	for i in steps:
		var t := float(i) / float(steps - 1)
		var c := fill
		c.a *= pow(1.0 - t, 0.85)
		var x := r.position.x + r.size.x * float(i) / float(steps)
		draw_rect(Rect2(x, r.position.y, r.size.x / float(steps) + 1.0, r.size.y), c, true)
	if selected:
		draw_line(Vector2(r.position.x + 1.0, r.position.y), Vector2(r.end.x, r.position.y), Color(border, 0.35), 1.0)
		draw_line(Vector2(r.position.x + 1.0, r.end.y), Vector2(r.end.x, r.end.y), Color(border, 0.35), 1.0)
	if border_w > 0.0:
		var line_color := border
		if selected:
			line_color = style.choice_selected_border_color
		elif hovered:
			line_color = style.choice_accent_color
		draw_line(Vector2(r.position.x + border_w * 0.5, r.position.y), Vector2(r.position.x + border_w * 0.5, r.end.y), line_color, maxf(2.0, border_w), true)

func _draw_bar(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	if fill.a > 0.0:
		_wing_fill(r, fill, 16)
	if border_w > 0.0:
		var bar_color := border
		if selected:
			bar_color = style.choice_selected_border_color
		elif hovered:
			bar_color = Color(style.choice_accent_color, 0.85)
		draw_line(Vector2(r.position.x + 1.5, r.position.y), Vector2(r.position.x + 1.5, r.end.y), bar_color, maxf(2.0, border_w), true)

func _wing_fill(r: Rect2, fill: Color, steps: int) -> void:
	for i in steps:
		var t := float(i) / float(steps - 1)
		var c := fill
		c.a *= pow(1.0 - t, 0.7)
		var x := r.position.x + r.size.x * float(i) / float(steps)
		draw_rect(Rect2(x, r.position.y, r.size.x / float(steps) + 1.0, r.size.y), c, true)

func _draw_spindle(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	if r.size.x < 8.0:
		return
	var n := minf(12.0, r.size.x * 0.08)
	var p := PackedVector2Array([
		Vector2(r.position.x + n, r.position.y),
		Vector2(r.end.x - n, r.position.y),
		Vector2(r.end.x, r.position.y + r.size.y * 0.5),
		Vector2(r.end.x - n, r.end.y),
		Vector2(r.position.x + n, r.end.y),
		Vector2(r.position.x, r.position.y + r.size.y * 0.5),
	])
	if style.choice_shadow_color.a > 0.0:
		var shifted := PackedVector2Array()
		for point in p:
			shifted.append(point + style.choice_shadow_offset)
		draw_colored_polygon(shifted, style.choice_shadow_color)
	draw_colored_polygon(p, fill)
	if border_w > 0.0:
		var closed := p.duplicate()
		closed.append(p[0])
		draw_polyline(closed, border, border_w, true)
		if selected:
			var inner := PackedVector2Array()
			for point in p:
				inner.append(r.get_center() + (point - r.get_center()) * 0.90)
			var ic := inner.duplicate()
			ic.append(inner[0])
			draw_polyline(ic, Color(1, 1, 1, 0.55), 1.0, true)

func _draw_swallowtail(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	if r.size.x < 8.0:
		return
	var notch := minf(minf(9.0, r.size.y * 0.22), r.size.x * 0.15)
	var p := PackedVector2Array([
		Vector2(r.position.x, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - notch, r.position.y + r.size.y * 0.5),
		Vector2(r.end.x, r.end.y),
		Vector2(r.position.x, r.end.y),
	])
	if style.choice_shadow_color.a > 0.0:
		var sr := Rect2(r.position + style.choice_shadow_offset, r.size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = style.choice_shadow_color
		sb.set_corner_radius_all(style.choice_corner_radius)
		draw_style_box(sb, sr)
	draw_colored_polygon(p, fill)
	if border_w > 0.0:
		draw_line(p[0], p[4], border, border_w, true)
		draw_line(p[1], p[2], Color(border, 0.45), 1.0, true)
		draw_line(p[2], p[3], Color(border, 0.45), 1.0, true)

func _draw_crystal(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	if r.size.x < 8.0:
		return
	var p: PackedVector2Array
	if index % 2 == 0:
		p = PackedVector2Array([
			Vector2(r.position.x, r.position.y + 3.0),
			Vector2(r.end.x, r.position.y),
			Vector2(r.end.x - r.size.x * 0.03, r.end.y),
			Vector2(r.position.x + r.size.x * 0.04, r.end.y - 3.0),
		])
	else:
		p = PackedVector2Array([
			Vector2(r.position.x + r.size.x * 0.03, r.position.y),
			Vector2(r.end.x - r.size.x * 0.02, r.position.y + 3.0),
			Vector2(r.end.x, r.end.y - 3.0),
			Vector2(r.position.x, r.end.y),
		])
	if style.choice_shadow_color.a > 0.0:
		var shifted := PackedVector2Array()
		for point in p:
			shifted.append(point + style.choice_shadow_offset)
		draw_colored_polygon(shifted, style.choice_shadow_color)
	draw_colored_polygon(p, fill)
	if border_w > 0.0:
		draw_line(p[0], p[3], border, border_w, true)
		draw_line(p[0], p[1], Color(border, 0.55), 1.0, true)
		draw_line(p[1], p[2], Color(border, 0.25), 1.0, true)
		if selected:
			draw_line(p[1], p[2], Color(0.0, 0.831, 1.0, 0.75), 2.0, true)

func _draw_filament(r: Rect2, _text_color: Color) -> void:
	# 普通行纯文字；只有选中行两端出现渐隐金线 + 菱形（grow-line 时随进度生长）。
	if not selected:
		return
	var font := _font if _font != null else style.resolve_choice_font()
	var fs := style.choice_font_size
	var center := r.size.y * 0.5
	var gold := style.choice_accent_color
	var text_size := font.get_string_size(button.text if button != null else "", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var side_room := (r.size.x - text_size.x) * 0.5
	if side_room <= 40.0:
		return
	var grow := _select_progress if style.select_anim == "grow-line" and not style.motion_reduced else 1.0
	var line_len := minf(56.0, side_room - 30.0) * grow
	var ly := floorf(center) + 0.5
	var lx2 := r.size.x * 0.5 - text_size.x * 0.5 - 16.0
	var rx1 := r.size.x * 0.5 + text_size.x * 0.5 + 16.0
	var clear := Color(gold, 0.0)
	# 渐隐线：外端透明 → 内端实色（顶点色线段，单次绘制）。
	draw_polyline_colors(PackedVector2Array([Vector2(lx2 - line_len, ly), Vector2(lx2, ly)]), PackedColorArray([clear, gold]), 1.0, true)
	draw_polyline_colors(PackedVector2Array([Vector2(rx1, ly), Vector2(rx1 + line_len, ly)]), PackedColorArray([gold, clear]), 1.0, true)
	if grow >= 0.99:
		_marker_diamond(Vector2(lx2 - line_len - 6.0, center), 3.5, Color(gold, 0.85))
		_marker_diamond(Vector2(rx1 + line_len + 6.0, center), 3.5, Color(gold, 0.85))

func _draw_taper_underline(r: Rect2, color: Color, alpha: float) -> void:
	var steps := 20
	var start := r.size.x * 0.18
	var end := r.size.x * 0.82
	var y := r.end.y - 4.0
	for i in steps:
		var t := float(i) / float(steps - 1)
		var a := sin(t * PI) * alpha * 0.8
		var p1 := Vector2(start + (end - start) * t, y)
		var p2 := Vector2(start + (end - start) * float(i + 1) / float(steps), y)
		draw_line(p1, p2, Color(color, a), 1.0)

## 标记全部几何绘制：禁用字符装饰；编号 01/02 是内容而非装饰，允许文字。
func _draw_marker(r: Rect2, text_color: Color) -> void:
	if style.choice_marker == "none":
		return
	var mcolor := Color(style.choice_accent_color, 0.75)
	if selected:
		mcolor = text_color
	elif hovered:
		mcolor = style.choice_hover_text_color
	var cx := r.position.x + 12.0 + minf(8.0, float(style.choice_marker_width) * 0.3)
	var cy := r.size.y * 0.5
	var s := float(maxi(6, style.choice_marker_size)) * 0.5
	match style.choice_marker:
		"number", "index":
			_draw_marker_text("%02d" % (index + 1), r, text_color)
		"glyph":
			# 旧字段兼容：不再画字符，统一落成菱形。
			_marker_diamond(Vector2(cx, cy), s * 0.55, mcolor)
		"crosshair":
			draw_arc(Vector2(cx, cy), s * 0.72, 0, TAU, 16, mcolor, 1.4, true)
			draw_line(Vector2(cx - s, cy), Vector2(cx + s, cy), mcolor, 1.4, true)
			draw_line(Vector2(cx, cy - s), Vector2(cx, cy + s), mcolor, 1.4, true)
		"seal":
			var half := s * 0.9
			draw_rect(Rect2(cx - half, cy - half, half * 2.0, half * 2.0), Color(style.choice_accent_color, 0.9 if selected else 0.55), true)
			draw_rect(Rect2(cx - half + 2.0, cy - half + 2.0, half * 2.0 - 4.0, half * 2.0 - 4.0), Color(1, 1, 1, 0.45), false, 1.0)
		"heart":
			_draw_heart_marker(r, text_color)
		"bar":
			if selected:
				_rounded_bar(Rect2(r.position.x + 10.0, r.position.y + 6.0, 3.0, r.size.y - 12.0), mcolor)
		"tri":
			# 三角光标只出现在选中行：普通行无符号（Codex/Tide 设计）。
			if selected:
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx - s * 0.5, cy - s * 0.8), Vector2(cx - s * 0.5, cy + s * 0.8), Vector2(cx + s * 0.7, cy),
				]), mcolor)
		"diamond":
			_marker_diamond(Vector2(cx, cy), s * 0.55, mcolor)
		"square":
			var half := s * 0.6
			draw_rect(Rect2(cx - half, cy - half, half * 2.0, half * 2.0), mcolor, false, 1.6)
		"keycap":
			var kw := s * 2.6
			var kr := Rect2(r.position.x + 8.0, cy - s, kw, s * 2.0)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(style.choice_accent_color, 0.16 if not selected else 0.85)
			sb.border_color = Color(style.choice_accent_color, 0.75)
			sb.set_border_width_all(1)
			sb.border_width_bottom = 2
			sb.set_corner_radius_all(3)
			draw_style_box(sb, kr)
			_draw_marker_text("%d" % (index + 1), r, text_color, kr)
		"leaf":
			_marker_leaf(Vector2(cx, cy), s * 0.75, mcolor)
		_:
			pass

func _marker_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0),
	]), color)

func _marker_leaf(center: Vector2, radius: float, color: Color) -> void:
	# 叶片：两瓣圆弧组成尖椭圆 + 一条叶脉。
	var p := PackedVector2Array()
	for i in 13:
		var a := PI * 2.0 * float(i) / 12.0
		var w := sin(a) * radius * 0.62
		var h := -cos(a) * radius * 1.15
		p.append(center + Vector2(w * (0.6 + 0.4 * cos(a)), h))
	draw_colored_polygon(p, color)
	draw_line(center + Vector2(0, -radius * 0.9), center + Vector2(0, radius * 0.95), Color(1, 1, 1, 0.35), 1.0)

## 数字编号是内容：仅 number/index/keycap 允许走文字。
func _draw_marker_text(text: String, r: Rect2, text_color: Color, box: Rect2 = Rect2()) -> void:
	if _font == null:
		_font = style.resolve_choice_font()
	var fs := mini(style.choice_marker_size, style.choice_font_size)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var origin := Vector2(r.position.x + 12.0, (r.size.y + float(fs)) * 0.5 - 2.0)
	if box.size.x > 1.0:
		origin = Vector2(box.position.x + (box.size.x - tw) * 0.5,
			box.position.y + (box.size.y - _font.get_height(fs)) * 0.5 + _font.get_ascent(fs))
	draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color if selected else Color(style.choice_accent_color, 0.9))

func _draw_heart_marker(r: Rect2, text_color: Color) -> void:
	var c := Color(style.choice_accent_color, 0.9)
	if selected:
		c = text_color
	elif hovered:
		c = style.choice_hover_text_color
	var cx := r.position.x + 14.0
	var cy := r.size.y * 0.5 - 1.0
	var s := 5.0
	draw_circle(Vector2(cx - s * 0.55, cy - s * 0.25), s * 0.62, c)
	draw_circle(Vector2(cx + s * 0.55, cy - s * 0.25), s * 0.62, c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - s * 1.12, cy - s * 0.18),
		Vector2(cx + s * 1.12, cy - s * 0.18),
		Vector2(cx, cy + s * 1.15),
	]), c)

# ── v5 新选项样式（全部几何绘制，禁用字符装饰） ──────────

## Codex 纸签：纸底 + 细边 + 左缘小缺口（签条感）。
func _draw_paper_sign(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	if style.choice_shadow_color.a > 0.0:
		draw_rect(Rect2(r.position + style.choice_shadow_offset, r.size), style.choice_shadow_color, true)
	draw_rect(r, fill, true)
	if border_w > 0.0:
		draw_rect(r, border, false, border_w)
	# 上缘一条淡色高光，模拟纸面厚度。
	draw_line(r.position + Vector2(border_w, border_w), Vector2(r.end.x - border_w, r.position.y + border_w), Color(1, 1, 1, 0.35), 1.0)

## Terminal 键帽索引行：左侧键帽盒装编号 + 行底极简。
func _draw_keycap_index(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	if fill.a > 0.0:
		draw_rect(r, fill, true)
	if border_w > 0.0 and border.a > 0.0:
		draw_rect(r, border, false, border_w)
	if selected:
		# 选中：左侧加一条实心指示段。
		draw_rect(Rect2(r.position.x, r.position.y, 4.0, r.size.y), style.choice_accent_color, true)

## Tide 斜切条：平行四边 + 选中时白色错位投影（由 shadow_offset/choice_accent 驱动）。
func _draw_skew_strip(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	var slant := minf(tan(deg_to_rad(14.0)) * r.size.y, r.size.x * 0.2)
	var p := PackedVector2Array([
		Vector2(r.position.x + slant, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - slant, r.end.y),
		Vector2(r.position.x, r.end.y),
	])
	if selected and style.choice_shadow_color.a > 0.0:
		var shifted := PackedVector2Array()
		for point in p:
			shifted.append(point + Vector2(4.0, 3.0))
		draw_colored_polygon(shifted, style.choice_shadow_color)
	draw_colored_polygon(p, fill)
	if border_w > 0.0:
		draw_line(p[0], p[3], border, border_w, true)
		draw_line(p[3], p[2], Color(border, border.a * 0.5), maxf(1.0, border_w - 1.0), true)
		draw_line(p[0], p[1], Color(border, border.a * 0.4), 1.0, true)

## Ember/Ink 无框列表：不画盒子，仅底部线；选中时横线加深。
func _draw_underline_list(r: Rect2, _fill: Color, _text_color: Color, border: Color, _border_w: float) -> void:
	var y := r.end.y - 1.0
	var line_color := Color(border, 0.35)
	var w := 1.0
	if selected:
		line_color = style.choice_selected_border_color
		w = 2.0
		# 选中时加一条横向暗红渐变底。
		var c0 := Color(style.choice_selected_bg, style.choice_selected_bg.a * 0.8)
		var c1 := Color(style.choice_selected_bg, 0.0)
		var top := r.position.y
		var bot := r.end.y - 3.0
		var mid := r.position.x + r.size.x * 0.5
		draw_polygon(PackedVector2Array([Vector2(r.position.x, top), Vector2(mid, top), Vector2(mid, bot), Vector2(r.position.x, bot)]),
			PackedColorArray([c1, c0, c0, c1]))
		draw_polygon(PackedVector2Array([Vector2(mid, top), Vector2(r.end.x, top), Vector2(r.end.x, bot), Vector2(mid, bot)]),
			PackedColorArray([c0, c1, c1, c0]))
	elif hovered:
		line_color = Color(style.choice_accent_color, 0.7)
	draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), line_color, w, true)

## Frost 玻璃行：半透底 + 顶部高光线 + 选中左侧指示条。
func _draw_glass_row(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(style.choice_corner_radius)
	draw_style_box(sb, r)
	# 玻璃高光：顶部 1px 亮线。
	draw_line(r.position + Vector2(8.0, 1.0), Vector2(r.end.x - 8.0, r.position.y + 1.0), Color(1, 1, 1, 0.22), 1.0, true)
	if border_w > 0.0 and border.a > 0.0:
		var bb := StyleBoxFlat.new()
		bb.bg_color = Color(0, 0, 0, 0)
		bb.border_color = border
		bb.set_border_width_all(int(border_w))
		bb.set_corner_radius_all(style.choice_corner_radius)
		draw_style_box(bb, r)
	if selected:
		# 柔光：两圈递减透明描边。
		for i in 2:
			var glow := StyleBoxFlat.new()
			glow.bg_color = Color(0, 0, 0, 0)
			glow.border_color = Color(style.choice_accent_color, 0.18 - 0.08 * i)
			glow.set_border_width_all(2)
			glow.set_corner_radius_all(style.choice_corner_radius + 2 + i * 2)
			draw_style_box(glow, r.grow(2.0 + 2.0 * i))
		# 选中竖条：bar-up 动画时交给 _draw_select_fx，避免重复。
		if style.select_anim != "bar-up" or style.motion_reduced:
			_rounded_bar(Rect2(r.position.x + 6.0, r.position.y + 8.0, 3.0, r.size.y - 16.0), style.choice_accent_color)

func _rounded_bar(rect: Rect2, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(2)
	draw_style_box(sb, rect)

## Ink 墨迹下划线：无框；底部一条两端渐细的墨线，选中时刷出效果由 _select_progress 承担。
func _draw_ink_stroke(r: Rect2, _fill: Color, _text_color: Color, border: Color, _border_w: float) -> void:
	if hovered and not selected:
		draw_line(Vector2(r.position.x, r.end.y - 2.0), Vector2(r.end.x, r.end.y - 2.0), Color(style.choice_accent_color, 0.35), 1.0, true)
		return
	var progress := _select_progress if selected else 0.0
	if not selected:
		return
	# 墨迹：多段宽度渐变的横条模拟毛笔（从中心向两端渐细，随 progress 自左向右刷出）。
	var y := r.end.y - 4.0
	var total := r.size.x * 0.92
	var drawn := total * progress
	var x0 := r.position.x + r.size.x * 0.04
	var steps := 28
	var i := 0
	while i < steps:
		var t := float(i) / float(steps - 1)
		var seg_x := x0 + total * t
		if seg_x - x0 > drawn:
			break
		var w := (1.2 + 1.6 * sin(t * PI)) * _ink_alpha_weight(t)
		var seg_w := minf(total / float(steps) + 1.0, x0 + drawn - seg_x)
		draw_rect(Rect2(seg_x, y - w * 0.5, seg_w, w), Color(border if border.a > 0 else style.choice_accent_color, 0.9), true)
		i += 1

func _ink_alpha_weight(t: float) -> float:
	return 1.0 - 0.55 * absf(t - 0.5) * 2.0

## Pixel 行：行内不画框；选中行左侧像素箭头光标（方块拼成，0.8s 步进闪烁），无实底高亮。
func _draw_pixel_box(r: Rect2, _fill: Color, _text_color: Color, _border: Color, _border_w: float) -> void:
	if not selected:
		return
	if not style.motion_reduced and (Time.get_ticks_msec() / 400) % 2 == 1:
		return
	var px := 3.0
	var cx := r.position.x + 10.0
	var cy := floorf(r.size.y * 0.5)
	var c := style.choice_selected_color
	# 三列阶梯：高 5/3/1 格，拼成向右的像素三角。
	for col in 3:
		var rows := 5 - col * 2
		draw_rect(Rect2(cx + float(col) * px, cy - float(rows) * px * 0.5, px, float(rows) * px), c, true)

func _process(_delta: float) -> void:
	if selected and style != null and style.choice_style == "pixel-box":
		queue_redraw()

## Nocturne 回复胶囊：右端圆角胶囊，选中加描边与淡底。
func _draw_chat_chip(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	var chip := Rect2(r.position.x + 8.0, r.position.y + 3.0, r.size.x - 16.0, r.size.y - 6.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(maxi(1, int(border_w)))
	sb.set_corner_radius_all(int(chip.size.y * 0.5))
	draw_style_box(sb, chip)
	if selected:
		draw_style_box(_chip_outline(border), chip.grow(2.0))

func _chip_outline(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(99)
	return sb

## Grove 叶行：圆角底 + 左端叶形标记（几何叶片，非字符）。
func _draw_leaf_row(r: Rect2, fill: Color, _text_color: Color, border: Color, border_w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(int(border_w))
	sb.corner_radius_top_left = style.choice_corner_radius
	sb.corner_radius_top_right = maxi(4, style.choice_corner_radius / 4)
	sb.corner_radius_bottom_right = style.choice_corner_radius
	sb.corner_radius_bottom_left = maxi(4, style.choice_corner_radius / 4)
	draw_style_box(sb, r)

# ── 选中反馈动画（由 _select_progress 驱动，≤240ms） ─────

func _draw_select_fx(r: Rect2, text_color: Color) -> void:
	if not selected or _select_progress <= 0.0:
		return
	var p := _select_progress
	var accent := style.choice_selected_border_color if style.choice_selected_border_color.a > 0.0 else style.choice_accent_color
	match style.select_anim:
		"grow-line":
			# 两端金线从文字向外生长（filament 已在自身绘制里处理，避免双线）。
			if style.choice_style == "filament":
				return
			var font := _font if _font != null else style.resolve_choice_font()
			var tw := font.get_string_size(button.text if button != null else "", HORIZONTAL_ALIGNMENT_LEFT, -1, style.choice_font_size).x
			var len := minf(56.0, maxf(0.0, (r.size.x - tw) * 0.5 - 18.0)) * p
			var cy := floorf(r.size.y * 0.5) + 0.5
			var cx := r.size.x * 0.5
			draw_line(Vector2(cx - tw * 0.5 - 12.0, cy), Vector2(cx - tw * 0.5 - 12.0 - len, cy), accent, 1.0, true)
			draw_line(Vector2(cx + tw * 0.5 + 12.0, cy), Vector2(cx + tw * 0.5 + 12.0 + len, cy), accent, 1.0, true)
		"bar-up":
			# 左侧 3px 圆角指示条由下往上长出。
			var h := (r.size.y - 16.0) * p
			if h > 1.0:
				_rounded_bar(Rect2(r.position.x + 6.0, r.end.y - 8.0 - h, 3.0, h), style.choice_accent_color)
		"shift":
			# 整条右移已由 selected_shift 承担；有 marker 时不再叠加第二个箭头。
			if style.choice_marker == "none":
				draw_colored_polygon(PackedVector2Array([
					Vector2(r.position.x + 6.0, r.size.y * 0.5 - 5.0),
					Vector2(r.position.x + 6.0, r.size.y * 0.5 + 5.0),
					Vector2(r.position.x + 6.0 + 8.0 * p, r.size.y * 0.5),
				]), Color(accent, 0.5 + 0.5 * p))
		"glow":
			draw_rect(r.grow(1.0), Color(accent, 0.35 * sin(p * PI)), false, 3.0)
		"stamp-line":
			# 印章线：底部横线从左刷出。
			var y := r.end.y - 3.0
			draw_line(Vector2(r.position.x, y), Vector2(r.position.x + r.size.x * p, y), accent, 2.0, true)
		"pop":
			# 胶囊回弹已由位移表现；补一个短暂放大描边。
			draw_rect(r.grow(2.0 * (1.0 - p)), Color(accent, 0.6 * (1.0 - p)), false, 1.5)
		_:
			pass
