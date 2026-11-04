@tool
class_name DialogueNameplate
extends Control
## 跨框铭牌：形状/阴影/角标由本组件绘制，文字使用真实 Label（便于主题字号、
## 字体与颜色统一）。浮空铭牌不占正文空间；inside 型铭牌（header/blade/poetic）
## 由 Presenter 在正文列里预留高度，所以永远不会压住台词。

var style: RpgEventStudioTheme:
	set(value):
		style = value
		_apply_style()
		queue_redraw()

var label: Label
var title_label: Label

var _speaker := ""
var _tag := ""
var _title := ""
var _glyph_width := 0.0
var _tag_width := 0.0
var _text_width := 0.0
var _title_width := 0.0
var _font: Font
var _tag_font_size := 12
var _title_font_size := 11
## 朱印铭牌固定边长（px）。
const SEAL_SIDE := 54.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.name = "SpeakerLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(title_label)
	_apply_style()

func set_style(value: RpgEventStudioTheme) -> void:
	style = value

func set_speaker(speaker: String, tag: String = "") -> void:
	_speaker = speaker
	_tag = tag if tag != "" else (style.nameplate_tag if style != null else "")
	_title = style.speaker_title if style != null else ""
	if label == null:
		return
	label.text = speaker
	label.visible = speaker.strip_edges() != ""
	if title_label != null:
		title_label.text = _title
	fit_to_content()
	queue_redraw()

func is_inside_panel() -> bool:
	return style != null and style.nameplate_style in ["header", "blade", "poetic"]

func fit_to_content() -> void:
	if label == null or style == null:
		return
	_font = style.resolve_font()
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", style.speaker_font_size)
	label.add_theme_color_override("font_color", style.nameplate_text_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag_font_size = maxi(10, style.hint_font_size)
	_title_font_size = maxi(9, style.hint_font_size - 1)
	if title_label != null:
		title_label.add_theme_font_override("font", _font)
		title_label.add_theme_font_size_override("font_size", _title_font_size)
		var title_color := style.nameplate_text_color
		title_color.a *= 0.72
		title_label.add_theme_color_override("font_color", title_color)
		title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font_size := style.speaker_font_size
	_glyph_width = 0.0
	if style.nameplate_style == "ribbon":
		_glyph_width = 24.0
	elif style.nameplate_glyph.strip_edges() != "":
		_glyph_width = _font.get_string_size(style.nameplate_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 6.0
	_tag_width = 0.0
	if _tag.strip_edges() != "" and style.nameplate_style != "column":
		_tag_width = _font.get_string_size(_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, _tag_font_size).x + 12.0
	_title_width = 0.0
	if _title.strip_edges() != "":
		_title_width = _font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_font_size).x + 8.0
	# 不依赖 Label 的布局缓存：直接用字体测量，避免首帧字体尚未 shape 时
	# get_combined_minimum_size() 返回 0，导致铭牌被裁成一个小方块。
	_text_width = _tracked_width(_speaker, font_size)
	var text_height := maxf(_font.get_height(font_size), float(font_size + 4))
	# 字距开启时文字由 _draw 逐字绘制：Label 保留文本（供测试/检查读取），
	# 但字体色置为透明，避免与手动画的文字重影。
	label.text = _speaker
	if _tracking_px() > 0.0:
		label.add_theme_color_override("font_color", Color(style.nameplate_text_color, 0.0))
	var pad_x := float(style.nameplate_padding_x)
	var pad_y := float(style.nameplate_padding_y)
	match style.nameplate_style:
		"column":
			var w := float(style.nameplate_column_width)
			var h := text_height + float(_tag_font_size) + 10.0
			_set_size(Vector2(w, h))
			label.position = Vector2(_glyph_width + 2.0, 2.0)
			label.size = Vector2(maxf(4.0, w - _glyph_width - 10.0), text_height)
		"header":
			var w := _text_width + _glyph_width + pad_x * 2.0 + 12.0
			var h := text_height + pad_y * 2.0
			_set_size(Vector2(w, h))
			label.position = Vector2(pad_x + _glyph_width, pad_y)
			label.size = Vector2(_text_width + 2.0, text_height)
		"blade":
			var w := _text_width + _glyph_width + pad_x * 2.0 + 10.0
			var h := text_height + pad_y * 2.0 + 2.0
			_set_size(Vector2(w, h))
			label.position = Vector2(pad_x + _glyph_width, pad_y + 1.0)
			label.size = Vector2(_text_width + 2.0, text_height)
		"poetic":
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var w := maxf(_text_width + _glyph_width * 2.0 + 96.0, 360.0)
			var h := text_height + pad_y * 2.0
			_set_size(Vector2(w, h))
			label.position = Vector2(0, pad_y)
			label.size = Vector2(w, text_height)
		"ribbon":
			var w := _text_width + _glyph_width + pad_x * 2.0 + 8.0
			var h := text_height + pad_y * 2.0
			_set_size(Vector2(w, h))
			label.position = Vector2(pad_x + _glyph_width, pad_y)
			label.size = Vector2(_text_width + 2.0, text_height)
		"plaque":
			var w := _text_width + _title_width + pad_x * 2.0 + 14.0
			var h := text_height + pad_y * 2.0 + 8.0
			_set_size(Vector2(w, h))
			label.position = Vector2(pad_x + 5.0, pad_y + 4.0)
			label.size = Vector2(_text_width + 2.0, text_height)
			if title_label != null:
				title_label.position = Vector2(pad_x + _text_width + 12.0, pad_y + 4.0 + text_height - _title_font_size - 2.0)
				title_label.size = Vector2(_title_width, float(_title_font_size + 4))
		"seal":
			# 方形朱印：固定 54px 见方，竖排文字由 _draw 逐字绘制，称号在印面下方。
			var side := SEAL_SIDE
			var h := side + (float(_title_font_size) + 6.0 if _title.strip_edges() != "" else 0.0)
			_set_size(Vector2(side, h))
			label.visible = false
			if title_label != null:
				title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				title_label.position = Vector2(-24.0, side + 1.0)
				title_label.size = Vector2(side + 48.0, float(_title_font_size + 3))
		"floating":
			var w := maxf(_text_width, _title_width) + 8.0
			var h := text_height + (float(_title_font_size) + 5.0 if _title.strip_edges() != "" else 0.0) + 4.0
			_set_size(Vector2(w, h))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.position = Vector2(0, 2.0)
			label.size = Vector2(w, text_height)
			if title_label != null:
				title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				title_label.position = Vector2(0, text_height + 4.0)
				title_label.size = Vector2(w, float(_title_font_size + 3))
		"callsign":
			var w := _text_width + _tag_width + pad_x * 2.0 + 16.0
			var h := text_height + pad_y * 2.0 + 4.0
			_set_size(Vector2(w, h))
			label.position = Vector2(pad_x + 6.0, pad_y + 2.0)
			label.size = Vector2(_text_width + 2.0, text_height)
		"phone":
			var w := _text_width + _title_width + pad_x * 2.0 + 18.0
			var h := text_height + pad_y * 2.0 + 2.0
			_set_size(Vector2(w, h))
			label.position = Vector2(pad_x + 7.0, pad_y + 1.0)
			label.size = Vector2(_text_width + 2.0, text_height)
			if title_label != null:
				title_label.position = Vector2(pad_x + _text_width + 13.0, pad_y + 1.0 + text_height - _title_font_size - 2.0)
				title_label.size = Vector2(_title_width, float(_title_font_size + 4))
		_:
			var w := _text_width + _glyph_width + _tag_width + pad_x * 2.0 + 8.0
			var h := text_height + pad_y * 2.0
			_set_size(Vector2(w, h))
			label.position = Vector2(pad_x + _glyph_width, pad_y)
			label.size = Vector2(_text_width + 2.0, text_height)
	if title_label != null:
		title_label.visible = _title.strip_edges() != ""
	queue_redraw()

## 字距（em→px）：speaker_tracking 按字号换算；逐字宽度求和供测量与绘制共用。
func _tracking_px() -> float:
	return style.speaker_tracking * float(style.speaker_font_size)

func _tracked_width(text: String, font_size: int) -> float:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if _tracking_px() > 0.0 and text.length() > 1:
		w += _tracking_px() * float(text.length() - 1)
	return w

func _set_size(value: Vector2) -> void:
	custom_minimum_size = value
	size = value

## header / poetic 由 Presenter 根据面板宽度拉长，画线才不会只有名字那么短。
func apply_layout_width(width: float) -> void:
	if style == null or label == null:
		return
	if style.nameplate_style == "header":
		var target := maxf(custom_minimum_size.x, width)
		_set_size(Vector2(target, size.y))
	elif style.nameplate_style == "poetic":
		var target := maxf(_text_width + _glyph_width * 2.0 + 96.0, width)
		_set_size(Vector2(target, size.y))
		label.position = Vector2(0, float(style.nameplate_padding_y))
		label.size = Vector2(target, label.size.y)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_redraw()

func _apply_style() -> void:
	if style == null:
		return
	rotation_degrees = float(style.nameplate_rotation)
	fit_to_content()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if style == null or size.x <= 1.0 or size.y <= 1.0:
		return
	match style.nameplate_style:
		"column":
			_draw_column()
			return
		"header":
			_draw_header()
			return
		"poetic":
			_draw_poetic()
			return
		"blade":
			_draw_blade()
			return
		"ribbon":
			_draw_ribbon()
			return
		"plaque":
			_draw_plaque()
			return
		"seal":
			_draw_seal_plate()
			return
		"floating":
			_draw_floating()
			return
		"callsign":
			_draw_callsign()
			return
		"phone":
			_draw_phone()
			return
	_draw_shadow()
	var radius := float(style.nameplate_radius)
	match style.nameplate_style:
		"capsule":
			radius = size.y * 0.5
		"parallelogram":
			_draw_parallelogram()
		"wood":
			_draw_rounded_rect(radius)
			_draw_wood_lines()
		"blood":
			_draw_rounded_rect(0.0)
			_draw_blood_detail()
		_:
			_draw_rounded_rect(radius)
	_draw_text_details()
	_draw_speaker_tracked()

func _panel_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)

func _draw_shadow() -> void:
	if style.nameplate_shadow_color.a > 0.0:
		var r := Rect2(style.nameplate_shadow_offset, size)
		_draw_shape(r, style.nameplate_shadow_color)

func _draw_shape(r: Rect2, color: Color) -> void:
	if style.nameplate_style == "parallelogram":
		var s := minf(8.0, r.size.x * 0.2)
		var p := PackedVector2Array([
			Vector2(r.position.x + s, r.position.y),
			Vector2(r.end.x, r.position.y),
			Vector2(r.end.x - s, r.end.y),
			Vector2(r.position.x, r.end.y),
		])
		draw_colored_polygon(p, color)
		return
	if style.nameplate_style == "blade":
		draw_colored_polygon(_blade_points(r), color)
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(maxf(0.0, style.nameplate_radius if style.nameplate_style != "capsule" else r.size.y * 0.5)))
	if style.nameplate_style == "wood" or style.nameplate_style == "ribbon":
		sb.set_corner_radius_all(int(r.size.y * 0.5) if style.nameplate_style == "ribbon" else style.nameplate_radius)
	draw_style_box(sb, r)

func _draw_rounded_rect(radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = style.nameplate_bg
	sb.border_color = style.nameplate_border
	sb.set_border_width_all(style.nameplate_border_width)
	sb.set_corner_radius_all(int(maxf(0.0, radius)))
	draw_style_box(sb, _panel_rect())

func _draw_parallelogram() -> void:
	var r := _panel_rect()
	var s := minf(8.0, r.size.x * 0.2)
	var p := PackedVector2Array([
		Vector2(r.position.x + s, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - s, r.end.y),
		Vector2(r.position.x, r.end.y),
	])
	draw_colored_polygon(p, style.nameplate_bg)
	if style.nameplate_border_width > 0 and style.nameplate_border.a > 0:
		var closed := p.duplicate()
		closed.append(p[0])
		draw_polyline(closed, style.nameplate_border, float(style.nameplate_border_width), true)

func _draw_wood_lines() -> void:
	var r := _panel_rect()
	var c := Color(1, 1, 1, 0.10)
	var y := r.position.y + 5.0
	while y < r.end.y - 3.0:
		draw_line(Vector2(r.position.x + 4.0, y), Vector2(r.end.x - 4.0, y), c, 1.0)
		y += 6.0

func _draw_blood_detail() -> void:
	var r := _panel_rect()
	draw_line(Vector2(0, 0), Vector2(0, r.size.y), Color(1, 1, 1, 0.55), 2.0)
	if _tag.strip_edges() != "":
		var tag_w := _tag_width
		draw_rect(Rect2(r.end.x - tag_w - 4.0, 3.0, tag_w, r.size.y - 6.0), Color(0, 0, 0, 0.80), true)

func _draw_column() -> void:
	var r := _panel_rect()
	if style.nameplate_bg.a > 0.0:
		draw_rect(Rect2(0, 0, r.size.x - 8.0, r.size.y), style.nameplate_bg, true)
	if style.nameplate_glyph.strip_edges() != "":
		draw_string(_font, Vector2(0, style.speaker_font_size), style.nameplate_glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, style.speaker_font_size, style.nameplate_text_color)
	if _tag.strip_edges() != "":
		var tag_y := style.speaker_font_size + float(_tag_font_size) + 4.0
		draw_string(_font, Vector2(_glyph_width + 2.0, tag_y), _tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _tag_font_size, Color(style.nameplate_accent, 0.82))
	if style.nameplate_divider:
		draw_line(Vector2(r.size.x - 1.0, 4.0), Vector2(r.size.x - 1.0, r.size.y - 4.0), style.nameplate_divider_color, 1.0)

func _draw_text_details() -> void:
	var font_size := style.speaker_font_size
	if style.nameplate_glyph.strip_edges() != "":
		var gy := (size.y + float(font_size)) * 0.5 - 2.0
		draw_string(_font, Vector2(float(style.nameplate_padding_x), gy), style.nameplate_glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, style.nameplate_accent)
	if _tag.strip_edges() != "":
		var tag_color := style.nameplate_text_color
		tag_color.a *= 0.72
		if style.nameplate_style == "blood":
			tag_color = Color(1.0, 0.62, 0.68, 1.0)
		var tx := size.x - _tag_width - float(style.nameplate_padding_x) + 2.0
		var ty := (size.y + float(_tag_font_size)) * 0.5 - 1.0
		draw_string(_font, Vector2(tx, ty), _tag, HORIZONTAL_ALIGNMENT_LEFT, -1, _tag_font_size, tag_color)

# ── 第四轮 inside 型铭牌 ─────────────────────────────────

func _draw_header() -> void:
	var fs := style.speaker_font_size
	var cy := size.y * 0.5
	var glyph_x := float(style.nameplate_padding_x)
	_draw_crescent(Vector2(glyph_x + _glyph_width * 0.42, cy), fs * 0.34, style.nameplate_accent, false)
	var line_start := label.position.x + _text_width + 8.0
	var line_end := size.x - float(style.nameplate_padding_x)
	if line_end > line_start:
		_draw_tapered_line(line_start, line_end, cy, style.nameplate_accent, false)
		draw_string(_font, Vector2(line_end - 8.0, cy + 4.0), "✦", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(style.nameplate_accent, 0.7))

func _draw_poetic() -> void:
	var fs := style.speaker_font_size
	var cy := size.y * 0.5
	var glyph_w := _font.get_string_size(style.nameplate_glyph if style.nameplate_glyph != "" else "☽", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var left_x := float(style.nameplate_padding_x)
	var right_x := size.x - float(style.nameplate_padding_x) - glyph_w
	_draw_crescent(Vector2(left_x + glyph_w * 0.42, cy), fs * 0.34, style.nameplate_accent, false)
	_draw_crescent(Vector2(right_x + glyph_w * 0.42, cy), fs * 0.34, style.nameplate_accent, true)
	var center := size.x * 0.5
	var text_left := center - _text_width * 0.5 - 8.0
	var text_right := center + _text_width * 0.5 + 8.0
	var left_line_start := float(style.nameplate_padding_x) + glyph_w + 6.0
	if text_left > left_line_start + 4.0:
		_draw_tapered_line(left_line_start, text_left, cy, style.nameplate_accent, true)
	var right_line_end := right_x - 6.0
	if right_line_end > text_right + 4.0:
		_draw_tapered_line(text_right, right_line_end, cy, style.nameplate_accent, false)

func _draw_blade() -> void:
	var r := _panel_rect()
	if style.nameplate_shadow_color.a > 0.0:
		draw_colored_polygon(_blade_points(Rect2(style.nameplate_shadow_offset, size)), style.nameplate_shadow_color)
	var p := _blade_points(r)
	draw_colored_polygon(p, style.nameplate_bg)
	draw_line(p[0], p[1], Color(style.nameplate_accent, 0.9), 2.0, true)
	draw_line(p[3], p[2], Color(style.nameplate_accent, 0.45), 1.0, true)
	var fs := style.speaker_font_size
	_draw_diamond(Vector2(float(style.nameplate_padding_x) + fs * 0.28, size.y * 0.5), fs * 0.24, style.nameplate_accent)

func _draw_ribbon() -> void:
	var r := _panel_rect()
	if style.nameplate_shadow_color.a > 0.0:
		var sr := Rect2(style.nameplate_shadow_offset, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = style.nameplate_shadow_color
		sb.set_corner_radius_all(int(size.y * 0.5))
		draw_style_box(sb, sr)
	var sb := StyleBoxFlat.new()
	sb.bg_color = style.nameplate_bg
	sb.border_color = style.nameplate_border
	sb.set_border_width_all(style.nameplate_border_width)
	sb.set_corner_radius_all(int(size.y * 0.5))
	draw_style_box(sb, r)
	# 手绘蝴蝶结：两个环 + 中心结 + 两条短飘带。
	var bow_center := Vector2(float(style.nameplate_padding_x) + 9.0, size.y * 0.5)
	var loop_r := minf(6.5, size.y * 0.20)
	draw_circle(bow_center + Vector2(-loop_r * 0.85, 0), loop_r, style.nameplate_accent)
	draw_circle(bow_center + Vector2(loop_r * 0.85, 0), loop_r, style.nameplate_accent)
	draw_circle(bow_center, loop_r * 0.62, style.nameplate_bg)
	draw_colored_polygon(PackedVector2Array([
		bow_center + Vector2(-2, loop_r * 0.5), bow_center + Vector2(-7, loop_r * 1.8), bow_center + Vector2(0, loop_r * 1.3)
	]), Color(style.nameplate_accent, 0.85))
	draw_colored_polygon(PackedVector2Array([
		bow_center + Vector2(2, loop_r * 0.5), bow_center + Vector2(7, loop_r * 1.8), bow_center + Vector2(0, loop_r * 1.3)
	]), Color(style.nameplate_accent, 0.85))

func _blade_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r.position.x, r.position.y),
		Vector2(r.end.x, r.position.y + r.size.y * 0.12),
		Vector2(r.end.x - r.size.y * 0.06, r.end.y),
		Vector2(r.position.x + r.size.y * 0.04, r.end.y - r.size.y * 0.08),
	])

func _draw_tapered_line(x1: float, x2: float, y: float, color: Color, fade_from_left: bool) -> void:
	# 用多层连续线模拟渐变，避免 1px 分段在缩放后像虚线。
	var yy := floorf(y) + 0.5
	var a := Vector2(x1, yy)
	var b := Vector2(x2, yy)
	var low := 0.18
	var mid := 0.42
	var high := 0.78
	if fade_from_left:
		draw_line(a, b, Color(color, color.a * low), 1.0, true)
		draw_line(a.lerp(b, 0.30), b, Color(color, color.a * mid), 1.0, true)
		draw_line(a.lerp(b, 0.60), b, Color(color, color.a * high), 1.0, true)
	else:
		draw_line(a, b, Color(color, color.a * low), 1.0, true)
		draw_line(a, a.lerp(b, 0.70), Color(color, color.a * mid), 1.0, true)
		draw_line(a, a.lerp(b, 0.40), Color(color, color.a * high), 1.0, true)

func _draw_crescent(center: Vector2, radius: float, color: Color, flip: bool) -> void:
	# 粗弧线构成月牙，避免自交多边形导致三角化失败；开口方向由起止角控制。
	var from := deg_to_rad(60.0 if not flip else 240.0)
	var to := deg_to_rad(300.0 if not flip else 480.0)
	draw_arc(center, radius * 0.82, from, to, 24, color, maxf(2.0, radius * 0.72), true)

func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0),
	]), color)

# ── v5 新样式 ─────────────────────────────────────────────

## 铜铭板（Codex）：渐变底 + 内框细线 + 顶部高光，称号由 title_label 承担。
func _draw_plaque() -> void:
	var r := _panel_rect()
	if style.nameplate_shadow_color.a > 0.0:
		var sr := Rect2(style.nameplate_shadow_offset, size)
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = style.nameplate_shadow_color
		ssb.set_corner_radius_all(style.nameplate_radius)
		draw_style_box(ssb, sr)
	# 纵向渐变牌面：nameplate_bg 顶部提亮到底部暗化。
	var steps := 16
	var top := Color(style.nameplate_bg, style.nameplate_bg.a).lightened(0.18)
	var bottom := style.nameplate_bg.darkened(0.22)
	for i in steps:
		var t := float(i) / float(steps - 1)
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * t, r.size.x, r.size.y / float(steps) + 1.0), top.lerp(bottom, t), true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = style.nameplate_border
	sb.set_border_width_all(maxi(1, style.nameplate_border_width))
	sb.set_corner_radius_all(style.nameplate_radius)
	draw_style_box(sb, r)
	var inner := _panel_rect().grow(-4.0)
	if inner.size.x > 2.0 and inner.size.y > 2.0:
		draw_rect(inner, Color(style.nameplate_accent, 0.55), false, 1.0)
	_draw_speaker_tracked()

## 方形朱印（Ink）：固定约 54px 见方实底 + 内白描边；名字竖排逐字阴文（最多 3 字，
## 超长自动缩字号但不低于 14）；旋转由 nameplate_rotation 承担。
func _draw_seal_plate() -> void:
	var side := SEAL_SIDE
	var r := Rect2(Vector2((size.x - side) * 0.5, 0), Vector2(side, side))
	if style.nameplate_shadow_color.a > 0.0:
		draw_rect(Rect2(r.position + style.nameplate_shadow_offset, r.size), style.nameplate_shadow_color, true)
	draw_rect(r, style.nameplate_bg, true)
	draw_rect(r.grow(-2.5), Color(1, 1, 1, 0.5), false, 1.0)
	# 竖排：最多取 3 字上下堆叠；按可用高度压缩字号（下限 14）。
	var chars := _speaker
	if chars.length() > 3:
		chars = chars.substr(0, 3)
	var n := maxi(1, chars.length())
	var cell := (side - 10.0) / float(n)
	var fs := clampi(int(minf(float(style.speaker_font_size), cell * 0.92)), 14, style.speaker_font_size)
	var total := float(fs) * float(n)
	var y := r.position.y + (side - total) * 0.5
	for i in n:
		var ch := chars[i]
		var cw := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(r.position.x + (side - cw) * 0.5, y + _font.get_ascent(fs)),
			ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, style.nameplate_text_color)
		y += float(fs)

## 无底悬浮（Frost）：无牌面，仅文字与称号；带一圈极淡的背光保证可读。
func _draw_floating() -> void:
	var r := _panel_rect()
	var glow := Color(style.nameplate_bg, minf(0.35, style.nameplate_bg.a))
	if glow.a > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = glow
		sb.set_corner_radius_all(int(r.size.y * 0.5))
		draw_style_box(sb, r.grow(-2.0))
	_draw_speaker_tracked()

## 两段式呼号（Tactical）：实底名块 + 右侧描边代号框。
func _draw_callsign() -> void:
	var r := _panel_rect()
	var pad_x := float(style.nameplate_padding_x) + 6.0
	var name_w := pad_x + _text_width + 6.0
	if style.nameplate_shadow_color.a > 0.0:
		var sr := Rect2(style.nameplate_shadow_offset, size)
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = style.nameplate_shadow_color
		ssb.set_corner_radius_all(style.nameplate_radius)
		draw_style_box(ssb, sr)
	# 名块：实底反色。
	draw_rect(Rect2(r.position, Vector2(name_w, r.size.y)), style.nameplate_bg, true)
	# 代号框：仅描边的第二段。
	var tag_r := Rect2(r.position.x + name_w + 2.0, r.position.y + 3.0, r.size.x - name_w - 5.0, r.size.y - 6.0)
	if _tag.strip_edges() != "" and tag_r.size.x > 4.0:
		draw_rect(tag_r, Color(style.nameplate_accent, 0.9), false, 1.0)
		draw_string(_font, Vector2(tag_r.position.x + 7.0, tag_r.position.y + (tag_r.size.y + _tag_font_size) * 0.5 - 1.0),
			_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, _tag_font_size, style.nameplate_accent)
	# 名块文字用实底反色绘制（此时 label 的字体色是暗色，需要描边底）。
	_draw_speaker_tracked()

## 聊天头部（Nocturne）：顶栏横条 + 左侧头像点 + 名字与称号。
func _draw_phone() -> void:
	var r := _panel_rect()
	var sb := StyleBoxFlat.new()
	sb.bg_color = style.nameplate_bg
	sb.border_color = style.nameplate_border
	sb.set_border_width_all(style.nameplate_border_width)
	sb.corner_radius_top_left = style.nameplate_radius
	sb.corner_radius_top_right = style.nameplate_radius
	draw_style_box(sb, r)
	# 左侧头像点与状态短线，模拟聊天应用顶栏。
	var cy := r.size.y * 0.5
	draw_circle(Vector2(r.position.x + 8.0, cy), 3.0, Color(style.nameplate_accent, 0.9))
	draw_line(Vector2(r.end.x - 26.0, cy), Vector2(r.end.x - 14.0, cy), Color(style.nameplate_accent, 0.55), 2.0, true)
	_draw_speaker_tracked()

## 字距开启时逐字绘制说话人（Label 已置空）；水平居中样式按其 Label 对齐。
func _draw_speaker_tracked() -> void:
	if _tracking_px() <= 0.0 or _speaker == "" or _font == null or label == null:
		return
	var fs := style.speaker_font_size
	var x := label.position.x
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = label.position.x + maxf(0.0, (label.size.x - _text_width) * 0.5)
	var baseline := label.position.y + (label.size.y - _font.get_height(fs)) * 0.5 + _font.get_ascent(fs)
	var color := style.nameplate_text_color
	for i in _speaker.length():
		var ch := _speaker[i]
		draw_string(_font, Vector2(x, baseline), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + _tracking_px()
