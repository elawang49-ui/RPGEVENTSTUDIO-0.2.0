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
var selected := false
var hovered := false

var button: Button
var _font: Font
var _tween: Tween

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
	selected = value
	if button != null:
		button.button_pressed = value
	_apply_style()
	queue_redraw()

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
	_font = style.resolve_body_font()
	custom_minimum_size = Vector2(0, style.choice_min_height)
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", style.choice_font_size)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER if style.text_align == "center" else HORIZONTAL_ALIGNMENT_LEFT
	var marker_pad := 12
	if style.choice_marker != "none":
		marker_pad = maxi(12, style.choice_marker_width + 10)
	var box := StyleBoxFlat.new()
	if style.uses_bare_choices():
		box.bg_color = Color(0, 0, 0, 0)
		box.border_color = Color(0, 0, 0, 0)
		box.set_border_width_all(0)
		box.set_corner_radius_all(0)
	else:
		box = style.make_choice_style(selected)
	box.content_margin_left = float(marker_pad) if style.text_align != "center" else 12.0
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

func _draw() -> void:
	if style == null or not style.uses_bare_choices() or size.x <= 1.0 or size.y <= 1.0:
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
		"pill":
			_draw_pill(r, fill, text_color, border_color, border_w)
		"spindle":
			_draw_spindle(r, fill, text_color, border_color, border_w)
		"swallowtail":
			_draw_swallowtail(r, fill, text_color, border_color, border_w)
		"crystal":
			_draw_crystal(r, fill, text_color, border_color, border_w)
		"filament":
			_draw_filament(r, text_color)
		_:
			_draw_flat(r, fill, text_color, border_color, border_w)
	if hovered and not selected and style.choice_style != "filament":
		draw_line(Vector2(r.position.x + 2.0, r.position.y + 5.0), Vector2(r.position.x + 2.0, r.end.y - 5.0),
			Color(style.choice_accent_color, 0.9), 2.0, true)
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

func _draw_filament(r: Rect2, text_color: Color) -> void:
	var font := _font if _font != null else style.resolve_body_font()
	var fs := style.choice_font_size
	var center := r.size.y * 0.5
	var active := selected or hovered
	if not active:
		return
	var alpha := 1.0 if selected else 0.45
	var gold := Color(style.choice_accent_color, alpha)
	var text_size := font.get_string_size(button.text if button != null else "", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var side_room := (r.size.x - text_size.x) * 0.5
	if side_room > 58.0:
		var left_text := "── ✦"
		var right_text := "✦ ──"
		var lw := font.get_string_size(left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var rw := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(r.size.x * 0.5 - text_size.x * 0.5 - lw - 12.0, center + 5.0), left_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gold)
		draw_string(font, Vector2(r.size.x * 0.5 + text_size.x * 0.5 + 12.0, center + 5.0), right_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gold)
	_draw_taper_underline(r, gold, alpha)

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

func _draw_marker(r: Rect2, text_color: Color) -> void:
	if style.choice_marker == "none":
		return
	var marker := ""
	match style.choice_marker:
		"number":
			if selected and style.choice_marker_glyph.strip_edges() != "":
				marker = style.choice_marker_glyph
			else:
				marker = "%02d" % (index + 1)
		"glyph":
			marker = style.choice_marker_glyph
		"crosshair":
			marker = "✖" if selected else "+"
		"seal":
			marker = "印"
		"heart":
			_draw_heart_marker(r, text_color)
			return
		_:
			marker = style.choice_marker_glyph
	if marker.strip_edges() == "":
		return
	var mcolor := Color(style.choice_accent_color, 0.75)
	if selected:
		mcolor = text_color
	elif hovered:
		mcolor = style.choice_hover_text_color
	var size_px := style.choice_marker_size
	var y := (r.size.y + float(size_px)) * 0.5 - 1.0
	var x := r.position.x + 12.0
	if style.choice_marker == "seal":
		draw_rect(Rect2(x, (r.size.y - size_px) * 0.5, float(size_px), float(size_px)), Color(style.choice_accent_color, 0.9 if selected else 0.55), true)
		mcolor = Color(1, 1, 1, 1)
		x += 2.0
	if _font == null:
		_font = style.resolve_body_font()
	draw_string(_font, Vector2(x, y), marker, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, mcolor)


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
