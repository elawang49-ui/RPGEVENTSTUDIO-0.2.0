@tool
class_name DialogueNameplate
extends Control
## 跨框铭牌：形状/阴影/角标由本组件绘制，文字使用真实 Label（便于主题字号、
## 字体与颜色统一）。非 column 模式时铭牌浮在面板上方，不占正文空间；
## column 模式时 DialoguePresenter 会在内容行里留出等宽栏位，铭牌压在留白上，
## 因此永远不会遮住正文。

var style: RpgEventStudioTheme:
	set(value):
		style = value
		_apply_style()
		queue_redraw()

var label: Label

var _speaker := ""
var _tag := ""
var _glyph_width := 0.0
var _tag_width := 0.0
var _font: Font
var _tag_font_size := 12

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.name = "SpeakerLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	_apply_style()

func set_style(value: RpgEventStudioTheme) -> void:
	style = value

func set_speaker(speaker: String, tag: String = "") -> void:
	_speaker = speaker
	_tag = tag if tag != "" else (style.nameplate_tag if style != null else "")
	if label == null:
		return
	label.text = speaker
	label.visible = speaker.strip_edges() != ""
	fit_to_content()
	queue_redraw()

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
	var font_size := style.speaker_font_size
	_glyph_width = 0.0
	if style.nameplate_glyph.strip_edges() != "":
		_glyph_width = _font.get_string_size(style.nameplate_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 6.0
	_tag_width = 0.0
	if _tag.strip_edges() != "" and style.nameplate_style != "column":
		_tag_width = _font.get_string_size(_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, _tag_font_size).x + 12.0
	# 不依赖 Label 的布局缓存：直接用字体测量，避免首帧字体尚未 shape 时
	# get_combined_minimum_size() 返回 0，导致铭牌被裁成一个小方块。
	var text_width := _font.get_string_size(_speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_height := maxf(_font.get_height(font_size), float(font_size + 4))
	label.text = _speaker
	if style.nameplate_style == "column":
		var w := float(style.nameplate_column_width)
		var h := text_height + float(_tag_font_size) + 10.0
		custom_minimum_size = Vector2(w, h)
		size = custom_minimum_size
		label.position = Vector2(_glyph_width + 2.0, 2.0)
		label.size = Vector2(maxf(4.0, w - _glyph_width - 10.0), text_height)
	else:
		var w := text_width + _glyph_width + _tag_width + float(style.nameplate_padding_x) * 2.0 + 8.0
		var h := text_height + float(style.nameplate_padding_y) * 2.0
		custom_minimum_size = Vector2(w, h)
		size = custom_minimum_size
		label.position = Vector2(float(style.nameplate_padding_x) + _glyph_width, float(style.nameplate_padding_y))
		label.size = Vector2(text_width + 2.0, text_height)
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
	if style.nameplate_style == "column":
		_draw_column()
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
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(maxf(0.0, style.nameplate_radius if style.nameplate_style != "capsule" else r.size.y * 0.5)))
	if style.nameplate_style == "wood":
		sb.set_corner_radius_all(style.nameplate_radius)
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
