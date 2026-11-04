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

var _time := 0.0

func _process(delta: float) -> void:
	if style == null:
		return
	if style.ornament_rotation_speed > 0.0 and style.corner_ornament in ["astrolabe", "butterfly"]:
		_time += delta * style.ornament_rotation_speed
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
		"octagon":
			var n := minf(float(style.panel_notch_size), minf(w, h) * 0.25)
			return PackedVector2Array([
				Vector2(n, 0), Vector2(w - n, 0), Vector2(w, n), Vector2(w, h - n),
				Vector2(w - n, h), Vector2(n, h), Vector2(0, h - n), Vector2(0, n),
			])
		"shard":
			return PackedVector2Array([
				Vector2(0, h * 0.06), Vector2(w * 0.98, 0),
				Vector2(w, h * 0.88), Vector2(w * 0.02, h),
			])
		"double-inner-line":
			# Ember：四角 14px 切角，边框由 _draw_frame 画双发丝。
			var n := minf(float(maxi(4, style.panel_notch_size)), minf(w, h) * 0.25)
			return PackedVector2Array([
				Vector2(n, 0), Vector2(w - n, 0), Vector2(w, n), Vector2(w, h - n),
				Vector2(w - n, h), Vector2(n, h), Vector2(0, h - n), Vector2(0, n),
			])
		"cut-corner-thick":
			# Tactical：厚切角（比 double-inner-line 更大缺口，粗描边）。
			var n := minf(float(maxi(8, style.panel_notch_size * 2)), minf(w, h) * 0.3)
			return PackedVector2Array([
				Vector2(n, 0), Vector2(w, 0), Vector2(w, h - n),
				Vector2(w - n, h), Vector2(0, h), Vector2(0, n),
			])
		"leaf":
			var big := float(style.panel_corner_radius)
			var small := float(style.panel_leaf_small_radius)
			return _rounded_points_radii(rect, [small, big, small, big])
		"pixel-stepped":
			# Pixel：4px 阶梯角多边形；边框 polyline 自然呈阶梯。
			var st := 4.0
			return PackedVector2Array([
				Vector2(2 * st, 0), Vector2(w - 2 * st, 0), Vector2(w - 2 * st, st),
				Vector2(w - st, st), Vector2(w - st, 2 * st), Vector2(w, 2 * st),
				Vector2(w, h - 2 * st), Vector2(w - st, h - 2 * st), Vector2(w - st, h - st),
				Vector2(w - 2 * st, h - st), Vector2(w - 2 * st, h), Vector2(2 * st, h),
				Vector2(2 * st, h - st), Vector2(st, h - st), Vector2(st, h - 2 * st),
				Vector2(0, h - 2 * st), Vector2(0, 2 * st), Vector2(st, 2 * st),
				Vector2(st, st), Vector2(2 * st, st),
			])
		_:
			return PackedVector2Array([
				Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h),
			])

func _is_polygon() -> bool:
	return style.panel_shape in ["notched", "slant", "octagon", "shard", "double-inner-line", "cut-corner-thick", "pixel-stepped", "leaf"]

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
				ThemeDraw.fill(self, grown, c)
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
			ThemeDraw.fill(self, _shape_points(hard_rect), hard_color)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = hard_color
			sb.set_corner_radius_all(style.panel_corner_radius)
			draw_style_box(sb, hard_rect)

func _draw_base(rect: Rect2, points: PackedVector2Array) -> void:
	# 面板底统一走一次顶点色多边形：圆角面板先展开成圆角轮廓点，
	# 渐变用顶点色插值，不再逐行 draw_rect（逐行会在缩放后出现扫描线纹）。
	var radius := 0.0 if _is_polygon() else float(style.panel_corner_radius)
	var shape := points if radius <= 0.0 else _rounded_points(rect, radius)
	ThemeDraw.fill(self, shape, style.panel_bg_color)
	if style.panel_gradient:
		_draw_polygon_gradient(shape, rect, style.panel_gradient_top, style.panel_gradient_bottom)

## 逐角圆角轮廓点，radii 顺序：右上、右下、左下、左上。
func _rounded_points_radii(rect: Rect2, radii: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var lim := minf(rect.size.x, rect.size.y) * 0.5
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in 4:
		var r := minf(float(radii[c]), lim)
		var center: Vector2
		match c:
			0: center = Vector2(rect.end.x - r, rect.position.y + r)
			1: center = Vector2(rect.end.x - r, rect.end.y - r)
			2: center = Vector2(rect.position.x + r, rect.end.y - r)
			_: center = Vector2(rect.position.x + r, rect.position.y + r)
		for i in 9:
			var a: float = starts[c] + PI * 0.5 * float(i) / 8.0
			out.append(center + Vector2(cos(a), sin(a)) * r)
	return out

## 圆角矩形轮廓点（每角 8 段），供顶点色渐变使用。
func _rounded_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var out := PackedVector2Array()
	var centers := [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
	]
	var start_angles := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in 4:
		for i in 9:
			var a: float = start_angles[c] + PI * 0.5 * float(i) / 8.0
			out.append(centers[c] + Vector2(cos(a), sin(a)) * r)
	return out

## 竖直渐变：一次 draw_polygon，顶点色按 y 线性插值。
func _draw_vertical_gradient(rect: Rect2, top: Color, bottom: Color, _steps: int = 0) -> void:
	if rect.size.y <= 0.0:
		return
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

func _draw_polygon_gradient(points: PackedVector2Array, rect: Rect2, top: Color, bottom: Color) -> void:
	if rect.size.y <= 0.0 or points.size() < 3:
		return
	var colors := PackedColorArray()
	for p in points:
		colors.append(top.lerp(bottom, clampf((p.y - rect.position.y) / rect.size.y, 0.0, 1.0)))
	ThemeDraw.fill_colors(self, points, colors)

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
		"constellation":
			var pts := PackedVector2Array([
				Vector2(0.08, 0.18), Vector2(0.19, 0.10), Vector2(0.31, 0.22),
				Vector2(0.44, 0.12), Vector2(0.57, 0.26), Vector2(0.70, 0.16),
				Vector2(0.84, 0.30), Vector2(0.26, 0.40), Vector2(0.52, 0.46),
				Vector2(0.76, 0.42),
			])
			for i in pts.size():
				var p := area.position + Vector2(pts[i].x * area.size.x, pts[i].y * area.size.y)
				draw_circle(p, 1.6, Color(color, color.a * 1.4))
				if i > 0:
					var q := area.position + Vector2(pts[i - 1].x * area.size.x, pts[i - 1].y * area.size.y)
					draw_dashed_line(q, p, Color(color, color.a * 0.8), 1.0, 3.0)

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

	# v5 形状自带的附加描边。
	match style.panel_shape:
		"double-inner-line":
			# Ember 双发丝：两条不同间距的细内框，外框由上方 polyline 完成。
			var c := style.frame_inner_color if style.frame_inner_color.a > 0.0 else Color(style.panel_border_color, 0.6)
			for gap in [float(maxi(5, style.frame_inner_gap)), float(maxi(9, style.frame_inner_gap + 4))]:
				var p := _inset_shape_points(points, gap)
				if p.size() > 1:
					var closed := p.duplicate()
					closed.append(p[0])
					draw_polyline(closed, Color(c, c.a * (0.9 if gap < 8.0 else 0.5)), 1.0, true)
		"glass":
			# Frost 玻璃：顶部短高光线 + 内圈淡描边。
			var seg := minf(72.0, rect.size.x * 0.14)
			draw_rect(Rect2(rect.position.x + 18.0, 0.0, seg, 2.0), style.accent_color, true)
			var inner := _inset_rect(rect, 3.0)
			if inner.size.x > 4.0 and inner.size.y > 4.0:
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(0, 0, 0, 0)
				sb.border_color = Color(1, 1, 1, 0.10)
				sb.set_border_width_all(1)
				sb.set_corner_radius_all(maxi(0, style.panel_corner_radius - 3))
				draw_style_box(sb, inner)
		"cut-corner-thick":
			# Tactical：切角内再压一条强调折线 + 顶部标签条底色。
			var p := _inset_shape_points(points, float(maxi(6, style.panel_border_width + 3)))
			if p.size() > 1:
				var closed := p.duplicate()
				closed.append(p[0])
				draw_polyline(closed, Color(style.accent_color, 0.55), 1.0, true)
		"pixel-stepped":
			# Pixel：内圈 1px 阶梯暗线，强化像素描边厚度。
			var p := _inset_shape_points(points, 4.0)
			if p.size() > 1:
				var closed := p.duplicate()
				closed.append(p[0])
				draw_polyline(closed, Color(style.accent_color, 0.4), 1.0, true)
		_:
			pass

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
		"lace":
			_draw_lace(rect)
		"tapered":
			_draw_tapered_frame(rect)
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
		"bracket":
			_draw_brackets(rect)
		"astrolabe":
			_draw_astrolabe(rect)
		"butterfly":
			_draw_butterfly(rect)
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


# ── 第四轮装饰 ───────────────────────────────────────────

func _draw_lace(rect: Rect2) -> void:
	var color := style.accent_color
	var top := 9.0
	var step := 13.0
	var x := 14.0
	while x < rect.size.x - 14.0:
		draw_arc(Vector2(x, top), 6.0, 0.0, PI, 12, Color(color, 0.45), 1.2, true)
		draw_circle(Vector2(x, top + 1.0), 1.1, Color(color, 0.6))
		x += step
	var inner := _inset_rect(rect, float(maxi(5, style.frame_inner_gap)))
	if inner.size.x > 4 and inner.size.y > 4:
		_draw_dashed_rect(inner, Color(style.frame_inner_color, 0.75), 1.0)

func _draw_tapered_frame(rect: Rect2) -> void:
	var c := style.frame_inner_color
	_draw_taper_line(Vector2(10.0, 1.0), Vector2(rect.size.x - 10.0, 1.0), c)
	_draw_taper_line(Vector2(10.0, rect.size.y - 1.0), Vector2(rect.size.x - 10.0, rect.size.y - 1.0), Color(c, c.a * 0.55))
	# 两端小菱星
	ThemeDraw.fill(self, PackedVector2Array([
		Vector2(8, 1), Vector2(11, 4), Vector2(8, 7), Vector2(5, 4)
	]), Color(c, 0.55))

func _draw_taper_line(a: Vector2, b: Vector2, color: Color) -> void:
	# 两端渐隐：三层连续线，避免分段虚线感；半像素对齐保证 1px 线不破碎。
	var aa := Vector2(a.x, floorf(a.y) + 0.5)
	var bb := Vector2(b.x, floorf(b.y) + 0.5)
	draw_line(aa, bb, Color(color, color.a * 0.18), 1.0, true)
	draw_line(aa.lerp(bb, 0.10), aa.lerp(bb, 0.90), Color(color, color.a * 0.42), 1.0, true)
	draw_line(aa.lerp(bb, 0.26), aa.lerp(bb, 0.74), Color(color, color.a * 0.78), 1.0, true)

func _draw_astrolabe(rect: Rect2) -> void:
	var radius := minf(rect.size.y * 0.36, 46.0)
	var center := Vector2(radius * 0.72, rect.size.y * 0.5)
	var c := style.corner_ornament_color
	draw_set_transform(center, deg_to_rad(_time), Vector2.ONE)
	# 外圈虚线
	var segs := 32
	for i in segs:
		if i % 2 != 0:
			continue
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		draw_arc(Vector2.ZERO, radius, a0, a1, 4, Color(c, 0.75), 1.2, true)
	draw_arc(Vector2.ZERO, radius * 0.78, 0, TAU, 48, Color(0.957, 0.906, 0.773, 0.62), 1.0, true)
	# 八角星盘指针
	var star := PackedVector2Array()
	for i in 16:
		var ang := TAU * float(i) / 16.0
		var rr := radius * (0.92 if i % 2 == 0 else 0.30)
		star.append(Vector2(cos(ang), sin(ang)) * rr)
	ThemeDraw.fill(self, star, Color(c, 0.10))
	var star_closed := star.duplicate()
	star_closed.append(star[0])
	draw_polyline(star_closed, Color(c, 0.85), 1.0, true)
	draw_circle(Vector2.ZERO, radius * 0.10, Color(0.957, 0.906, 0.773, 0.95))
	draw_circle(Vector2.ZERO, radius * 0.035, Color(c, 1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_butterfly(rect: Rect2) -> void:
	var flap := 0.82 + 0.18 * absf(sin(_time * 1.8))
	var center := Vector2(rect.size.x - 34.0, 26.0)
	var c := style.corner_ornament_color
	draw_set_transform(center, 0.0, Vector2(flap, 1.0))
	var upper := Color(c, 0.75)
	var lower := Color(c, 0.55)
	ThemeDraw.fill(self, PackedVector2Array([
		Vector2(0, 0), Vector2(-18, -13), Vector2(-25, -2), Vector2(-13, 4), Vector2(0, 1)
	]), upper)
	ThemeDraw.fill(self, PackedVector2Array([
		Vector2(0, 0), Vector2(18, -13), Vector2(25, -2), Vector2(13, 4), Vector2(0, 1)
	]), Color(c, 0.9))
	ThemeDraw.fill(self, PackedVector2Array([
		Vector2(0, 2), Vector2(-13, 8), Vector2(-9, 17), Vector2(0, 8)
	]), lower)
	ThemeDraw.fill(self, PackedVector2Array([
		Vector2(0, 2), Vector2(13, 8), Vector2(9, 17), Vector2(0, 8)
	]), Color(c, 0.65))
	draw_line(Vector2(0, -2), Vector2(0, 12), Color(1, 1, 1, 0.85), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 四角 L 形括线：臂长 corner_ornament_size、线宽 2、内缩 corner_bracket_inset。
func _draw_brackets(rect: Rect2) -> void:
	var c := style.corner_ornament_color
	var arm := float(maxi(4, style.corner_ornament_size))
	var i := float(style.corner_bracket_inset)
	var w := 2.0
	var l := rect.position.x + i
	var t := rect.position.y + i
	var r := rect.end.x - i
	var b := rect.end.y - i
	for corner in [[Vector2(l, t), 1.0, 1.0], [Vector2(r, t), -1.0, 1.0], [Vector2(l, b), 1.0, -1.0], [Vector2(r, b), -1.0, -1.0]]:
		var p: Vector2 = corner[0]
		var sx: float = corner[1]
		var sy: float = corner[2]
		draw_polyline(PackedVector2Array([p + Vector2(0, sy * arm), p, p + Vector2(sx * arm, 0)]), c, w, true)
