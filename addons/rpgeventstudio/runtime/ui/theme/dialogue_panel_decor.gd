@tool
class_name DialoguePanelDecor
extends Control
## 对话框底/边框/底纹/角标的组合绘制组件。
##
## 这是一个纯视觉 Control：不处理输入，不参与内容布局。DialoguePresenter 把它
## 放在内容 MarginContainer 之前、填满面板，因此所有装饰都在文字下方绘制。
## 参数全部来自 RpgEventStudioTheme，不在这里硬编码任何一套主题。

var style: RpgEventStudioTheme:
	set(value):
		style = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if style == null or size.x <= 1.0 or size.y <= 1.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var points := _shape_points(rect)
	var font := style.resolve_font()
	_draw_shadow(rect, points)
	_draw_base(rect, points)
	_draw_pattern(rect)
	_draw_frame(rect, points, font)
	_draw_ornaments(rect, font)

func _shape_points(rect: Rect2) -> PackedVector2Array:
	var w := rect.size.x
	var h := rect.size.y
	match style.panel_shape:
		"notched":
			var n := float(style.panel_notch_size)
			n = minf(n, minf(w, h) * 0.25)
			return PackedVector2Array([
				Vector2(n, 0), Vector2(w, 0), Vector2(w, h - n),
				Vector2(w - n, h), Vector2(0, h), Vector2(0, n),
			])
		"slant":
			var s := minf(float(style.panel_slant_size), w * 0.25)
			return PackedVector2Array([
				Vector2(s, 0), Vector2(w, 0), Vector2(w - s, h), Vector2(0, h),
			])
		_:
			return PackedVector2Array([
				Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h),
			])

func _is_polygon() -> bool:
	return style.panel_shape == "notched" or style.panel_shape == "slant"

func _draw_shadow(rect: Rect2, points: PackedVector2Array) -> void:
	# 软阴影：用几层偏移形状模拟，不依赖 StyleBox 的矩形假设。
	if style.panel_shadow_color.a > 0.0 and style.panel_shadow_size > 0:
		var size := float(style.panel_shadow_size)
		var offset := style.panel_shadow_offset
		for i in range(6, 0, -1):
			var grow := size * float(i) / 6.0
			var alpha := style.panel_shadow_color.a * (0.10 + 0.16 * (1.0 - float(i) / 6.0))
			var shadow_rect := Rect2(
				Vector2(-grow, -grow) + offset,
				rect.size + Vector2(grow * 2.0, grow * 2.0)
			)
			var c := Color(style.panel_shadow_color, alpha)
			if _is_polygon():
				var grown := _shape_points(shadow_rect)
				draw_colored_polygon(grown, c)
			else:
				var sb := StyleBoxFlat.new()
				sb.bg_color = c
				sb.set_corner_radius_all(style.panel_corner_radius)
				draw_style_box(sb, shadow_rect)
	# 贴纸硬阴影：纯色、无模糊、只偏移一次。
	if style.hard_shadow_color.a > 0.0:
		var hard_rect := Rect2(style.hard_shadow_offset, rect.size)
		var hard_color := style.hard_shadow_color
		if _is_polygon():
			draw_colored_polygon(_shape_points(hard_rect), hard_color)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = hard_color
			sb.set_corner_radius_all(style.panel_corner_radius)
			draw_style_box(sb, hard_rect)

func _draw_base(rect: Rect2, points: PackedVector2Array) -> void:
	var radius := 0.0 if _is_polygon() else float(style.panel_corner_radius)
	if radius > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = style.panel_bg_color
		sb.set_corner_radius_all(int(radius))
		draw_style_box(sb, rect)
		if style.panel_gradient:
			# 圆角面板上不做像素级渐变裁切；用一条低透明度渐变叠在内部，
			# 视觉上保留上下明暗，又不会在圆角外露出硬边。
			var inner := rect.grow(-maxf(1.0, radius * 0.25))
			_draw_vertical_gradient(inner, style.panel_gradient_top, style.panel_gradient_bottom, 48)
		return
	if _is_polygon():
		draw_colored_polygon(points, style.panel_bg_color)
		if style.panel_gradient:
			_draw_polygon_gradient(points, rect, style.panel_gradient_top, style.panel_gradient_bottom)
	else:
		if style.panel_gradient:
			_draw_vertical_gradient(rect, style.panel_gradient_top, style.panel_gradient_bottom, 64)
		else:
			draw_rect(rect, style.panel_bg_color, true)

## 用 1px 横条绘制竖直渐变；比生成纹理更直接，也方便按形状逐行裁剪。
func _draw_vertical_gradient(rect: Rect2, top: Color, bottom: Color, steps: int) -> void:
	if rect.size.y <= 0.0:
		return
	var count := maxi(2, steps)
	for i in count:
		var t := float(i) / float(count - 1)
		var color := top.lerp(bottom, t)
		var y := rect.position.y + rect.size.y * float(i) / float(count)
		var h := rect.size.y / float(count) + 1.0
		draw_rect(Rect2(rect.position.x, y, rect.size.x, h), color, true)

func _draw_polygon_gradient(points: PackedVector2Array, rect: Rect2, top: Color, bottom: Color) -> void:
	var h := int(ceil(rect.size.y))
	if h <= 0:
		return
	for y in h:
		var t := float(y) / float(maxi(1, h - 1))
		var color := top.lerp(bottom, t)
		var span := _span_at_y(points, float(y) + 0.5)
		if span.y > span.x:
			draw_rect(Rect2(span.x, float(y), span.y - span.x, 1.0), color, true)

## 计算多边形在指定 y 上的左右边界（只用于当前四种轮廓）。
func _span_at_y(points: PackedVector2Array, y: float) -> Vector2:
	var xs := PackedFloat32Array()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if (a.y <= y and b.y >= y) or (b.y <= y and a.y >= y):
			if is_equal_approx(a.y, b.y):
				xs.append(a.x)
				xs.append(b.x)
			else:
				var t := (y - a.y) / (b.y - a.y)
				xs.append(lerpf(a.x, b.x, t))
	if xs.is_empty():
		return Vector2.ZERO
	var lo := xs[0]
	var hi := xs[0]
	for x in xs:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return Vector2(lo, hi)

func _inset_rect(rect: Rect2, amount: float) -> Rect2:
	return Rect2(rect.position + Vector2(amount, amount), rect.size - Vector2(amount * 2.0, amount * 2.0))

func _draw_pattern(rect: Rect2) -> void:
	if style.pattern_style == "none" or style.pattern_color.a <= 0.0:
		return
	var inset := 2.0
	if style.panel_shape == "notched":
		inset = float(style.panel_notch_size) + 2.0
	elif style.panel_shape == "slant":
		inset = float(style.panel_slant_size) + 2.0
	var area := _inset_rect(rect, inset)
	if area.size.x <= 4.0 or area.size.y <= 4.0:
		return
	var step := maxi(4, style.pattern_spacing)
	var color := style.pattern_color
	match style.pattern_style:
		"notebook":
			var y := area.position.y
			while y < area.end.y:
				draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), color, 1.0)
				y += step
			var x := area.position.x
			while x < area.end.x:
				draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), color, 1.0)
				x += step
		"grid":
			var y := area.position.y
			while y < area.end.y:
				draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), color, 1.0)
				y += step
			var x := area.position.x
			while x < area.end.x:
				draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), color, 1.0)
				x += step
		"dots":
			var y := area.position.y + step * 0.5
			while y < area.end.y:
				var x := area.position.x + step * 0.5
				while x < area.end.x:
					draw_circle(Vector2(x, y), 1.4, color)
					x += step
				y += step
		"slash":
			var offset := -area.size.y
			while offset < area.size.x:
				var from := Vector2(area.position.x + offset, area.end.y)
				var to := from + Vector2(area.size.y, -area.size.y)
				draw_line(from, to, color, 2.0)
				offset += step
		"rays":
			var origin := Vector2(area.position.x + area.size.x * 0.18, area.position.y + area.size.y * 0.12)
			for i in 7:
				var angle := PI * 0.15 + float(i) * PI * 0.11
				draw_line(origin, origin + Vector2(cos(angle), sin(angle)) * area.size.length(), color, 1.0)

func _draw_frame(rect: Rect2, points: PackedVector2Array, _font: Font) -> void:
	var color := style.panel_border_color
	var width := float(style.panel_border_width)
	if _is_polygon():
		if width > 0.0 and color.a > 0.0:
			var closed := points.duplicate()
			closed.append(points[0])
			draw_polyline(closed, color, width, true)
	else:
		if width > 0.0 and color.a > 0.0:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = color
			sb.set_border_width_all(int(width))
			sb.set_corner_radius_all(style.panel_corner_radius)
			draw_style_box(sb, rect)

	match style.frame_style:
		"double", "ornament":
			_draw_inner_line(rect, points, false)
		"stitch":
			_draw_stitch(rect)
		"blade":
			var by := float(style.top_blade_width)
			if by > 0.0:
				draw_rect(Rect2(0, 0, rect.size.x, by), style.top_blade_color, true)
				draw_line(Vector2(0, by + 1.0), Vector2(rect.size.x, by + 1.0), Color(style.top_blade_color, 0.28), 1.0)
		"hairline":
			var x := 22.0
			draw_line(Vector2(x, 1.0), Vector2(rect.size.x - 22.0, 1.0), style.frame_inner_color, 1.0)
			var tick := 22.0
			while tick < rect.size.x - 22.0:
				draw_line(Vector2(tick, 0.0), Vector2(tick, 4.0), style.frame_inner_color, 1.0)
				tick += 42.0
		"armor":
			var bar := float(style.armor_bar_width)
			if bar > 0.0:
				draw_rect(Rect2(0, 0, bar, rect.size.y), style.accent_color, true)
				draw_rect(Rect2(bar + 2.0, 0, 2.0, rect.size.y), style.accent_secondary, true)
				draw_line(Vector2(0, 0), Vector2(rect.size.x, 0), Color(style.accent_secondary, 0.65), 1.0)
		_:
			pass

	# 顶部刀锋独立于 frame_style：猩红主题即使以后换边框也保留刀痕。
	if style.top_blade_width > 0 and style.frame_style != "blade":
		draw_rect(Rect2(0, 0, rect.size.x, style.top_blade_width), style.top_blade_color, true)

func _draw_inner_line(rect: Rect2, points: PackedVector2Array, dashed: bool) -> void:
	var gap := float(style.frame_inner_gap)
	var width := float(style.frame_inner_width)
	var color := style.frame_inner_color
	if width <= 0.0 or color.a <= 0.0:
		return
	var inner := _inset_rect(rect, gap)
	if inner.size.x <= 0 or inner.size.y <= 0:
		return
	if _is_polygon():
		var p := _inset_shape_points(points, gap)
		if p.size() > 1:
			var closed := p.duplicate()
			closed.append(p[0])
			draw_polyline(closed, color, width, true)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = color
		sb.set_border_width_all(int(maxf(1.0, width)))
		sb.set_corner_radius_all(maxi(0, style.panel_corner_radius - int(gap)))
		if dashed or style.frame_inner_dash:
			_draw_dashed_rect(inner, color, width)
		else:
			draw_style_box(sb, inner)

## 斜切形状的内缩近似：沿质心缩放，保持内外框平行感。
func _inset_shape_points(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= float(points.size())
	var out := PackedVector2Array()
	for p in points:
		var dir := (center - p).normalized()
		out.append(p + dir * amount)
	return out

func _draw_dashed_rect(rect: Rect2, color: Color, width: float) -> void:
	var dash := 5.0
	draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, width, dash)
	draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color, width, dash)
	draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color, width, dash)
	draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color, width, dash)

func _draw_stitch(rect: Rect2) -> void:
	var inner := _inset_rect(rect, float(maxi(4, style.frame_inner_gap)))
	if inner.size.x <= 0 or inner.size.y <= 0:
		return
	_draw_dashed_rect(inner, style.frame_inner_color, float(maxi(1, style.frame_inner_width)))

func _draw_corner_glyphs(rect: Rect2, font: Font, count: int) -> void:
	if style.corner_glyph.strip_edges() == "" or style.corner_ornament_color.a <= 0.0:
		return
	var glyph := style.corner_glyph
	var glyph_size := style.corner_ornament_size
	var inset := 14.0
	var positions := [
		Vector2(inset, inset + glyph_size * 0.72),
		Vector2(rect.size.x - inset - glyph_size * 0.72, inset + glyph_size * 0.72),
		Vector2(inset, rect.size.y - inset),
		Vector2(rect.size.x - inset - glyph_size * 0.72, rect.size.y - inset),
	]
	for i in mini(count, positions.size()):
		draw_string(font, positions[i], glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, style.corner_ornament_color)

func _draw_ornaments(rect: Rect2, font: Font) -> void:
	if style.corner_ornament == "none":
		return
	match style.corner_ornament:
		"star":
			_draw_corner_glyphs(rect, font, 4)
		"cross":
			_draw_cross_ornaments(rect)
		"tape":
			_draw_tape(rect)
		"seal":
			_draw_seal(rect, font)
		"blade":
			var c := style.corner_ornament_color
			draw_line(Vector2(0, 12), Vector2(26, 12), c, 2.0)
			draw_line(Vector2(rect.size.x - 26, rect.size.y - 12), Vector2(rect.size.x, rect.size.y - 12), c, 2.0)
		_:
			pass

func _draw_cross_ornaments(rect: Rect2) -> void:
	var c := style.corner_ornament_color
	var s := 9.0
	var p := Vector2(16, 16)
	draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), c, 2.0)
	draw_line(p + Vector2(0, -s), p + Vector2(0, s), c, 2.0)
	var q := Vector2(rect.size.x - 16, rect.size.y - 16)
	draw_line(q + Vector2(-s, 0), q + Vector2(s, 0), c, 2.0)
	draw_line(q + Vector2(0, -s), q + Vector2(0, s), c, 2.0)

func _draw_tape(rect: Rect2) -> void:
	var tape_w := minf(76.0, rect.size.x * 0.28)
	var tape_h := 17.0
	var center := Vector2(rect.size.x - tape_w * 0.5 - 26.0, 2.0)
	draw_set_transform(center, deg_to_rad(6.0), Vector2.ONE)
	draw_rect(Rect2(-tape_w * 0.5, -tape_h * 0.5, tape_w, tape_h), style.corner_ornament_color, true)
	var stripe := Color(1, 1, 1, 0.14)
	var x := -tape_w * 0.5
	while x < tape_w * 0.5:
		draw_line(Vector2(x, -tape_h * 0.5), Vector2(x, tape_h * 0.5), stripe, 3.0)
		x += 10.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_seal(rect: Rect2, font: Font) -> void:
	var seal_size := 24.0
	var p := Vector2(rect.size.x - seal_size - 14.0, rect.size.y - seal_size - 14.0)
	draw_rect(Rect2(p, Vector2(seal_size, seal_size)), style.corner_ornament_color, true)
	draw_rect(Rect2(p, Vector2(seal_size, seal_size)), Color(1, 1, 1, 0.35), false, 1.0)
	var glyph := style.corner_glyph if style.corner_glyph != "" else "印"
	draw_string(font, p + Vector2(4, seal_size * 0.72), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, int(seal_size * 0.72), Color(1, 1, 1, 0.95))
