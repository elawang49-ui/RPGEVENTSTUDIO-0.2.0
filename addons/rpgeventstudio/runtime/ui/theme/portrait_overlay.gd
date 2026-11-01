@tool
class_name DialoguePortraitOverlay
extends Control
## 立绘框的边框/角标层。单独一层是为了让纹理永远位于边框之下，
## 同时保持 DialoguePortraitSlot 的绘制顺序简单可控。

var slot: DialoguePortraitSlot

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if slot == null or slot.style == null or size.x <= 1.0 or size.y <= 1.0:
		return
	var style := slot.style
	var r := Rect2(Vector2.ZERO, size)
	_draw_border(r)
	_draw_details(r)
	if slot.texture == null and style.portrait_show_placeholder:
		_draw_placeholder(r)

func _draw_border(r: Rect2) -> void:
	var style := slot.style
	var bw := float(style.portrait_border_width)
	if bw <= 0.0 or style.portrait_border_color.a <= 0.0:
		return
	var c := style.portrait_border_color
	match style.portrait_style:
		"circle":
			draw_arc(r.get_center(), minf(r.size.x, r.size.y) * 0.5 - bw * 0.5, 0, TAU, 64, c, bw, true)
		"angular", "blood":
			var p := slot._notch_points(r, 7.0)
			var closed := p.duplicate()
			closed.append(p[0])
			draw_polyline(closed, c, bw, true)
			draw_line(Vector2(1.0, 2.0), Vector2(1.0, r.size.y - 2.0), c, maxf(2.0, bw * 1.5), true)
		"polaroid":
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = c
			sb.set_border_width_all(int(maxf(1.0, bw)))
			sb.set_corner_radius_all(2)
			draw_style_box(sb, r)
		_:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = c
			sb.set_border_width_all(int(maxf(1.0, bw)))
			sb.set_corner_radius_all(slot._radius_px())
			draw_style_box(sb, r)
	if style.portrait_inner_border > 0:
		var inner := r.grow(-float(maxi(1, style.portrait_inner_border)) - bw * 0.5)
		if inner.size.x > 2 and inner.size.y > 2:
			var ib := StyleBoxFlat.new()
			ib.bg_color = Color(0, 0, 0, 0)
			ib.border_color = style.portrait_inner_color
			ib.set_border_width_all(style.portrait_inner_border)
			ib.set_corner_radius_all(maxi(0, slot._radius_px() - style.portrait_inner_border))
			draw_style_box(ib, inner)

func _draw_details(r: Rect2) -> void:
	var style := slot.style
	var font := style.resolve_font()
	match style.portrait_ornament:
		"star":
			_draw_badge(Vector2(r.size.x - 14, 14), 9.0, style.portrait_accent, "✦", font)
		"glyph":
			var glyph := style.portrait_glyph if style.portrait_glyph != "" else "★"
			var pos := Vector2(14, r.size.y - 14) if style.portrait_style == "angular" else Vector2(r.size.x - 14, r.size.y - 14)
			_draw_badge(pos, 9.0, style.portrait_accent, glyph, font)
		"tape":
			var tape := Rect2(r.size.x * 0.5 - 18.0, -5.0, 36.0, 10.0)
			draw_rect(tape, Color(style.accent_color, 0.85), true)
			draw_rect(tape, Color(style.portrait_border_color, 0.35), false, 1.0)
		"cross":
			draw_string(font, Vector2(r.size.x * 0.5 - 5.0, r.size.y * 0.5 + 6.0), "†",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.55))
			draw_line(Vector2(3, 3), Vector2(3, r.size.y - 3), style.portrait_accent, 2.0)
		_:
			pass

func _draw_badge(center: Vector2, radius: float, color: Color, glyph: String, font: Font) -> void:
	draw_circle(center, radius, Color(0, 0, 0, 0.42))
	draw_arc(center, radius, 0, TAU, 20, Color(color, 0.9), 1.0, true)
	var fs := int(radius * 1.4)
	var sz := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, center - sz * 0.5 + Vector2(0, sz.y * 0.35), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

func _draw_placeholder(r: Rect2) -> void:
	var style := slot.style
	var glyph := slot.glyph_override if slot.glyph_override != "" else style.portrait_glyph
	var font := style.resolve_font()
	if glyph.strip_edges() != "":
		var font_size := int(minf(r.size.x, r.size.y) * 0.34)
		var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, r.get_center() - text_size * 0.5 + Vector2(0, text_size.y * 0.35), glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(style.portrait_accent, 0.85))
	else:
		var c := Color(style.portrait_accent, 0.45)
		draw_circle(Vector2(r.size.x * 0.5, r.size.y * 0.36), r.size.x * 0.16, c)
		draw_circle(Vector2(r.size.x * 0.5, r.size.y * 0.84), r.size.x * 0.30, c)
