@tool
class_name DialoguePortraitSlot
extends Control
## 立绘框：只负责“如何显示一张 Texture2D”，不负责角色/表情资源管理。
##
## 与角色系统解耦的运行时接口：
##   presenter.set_dialogue_portrait(texture)   # 传当前说话人的立绘
##   presenter.clear_dialogue_portrait()
## 角色资源、立绘切换、表情差分属于后续独立系统；主题只定义框体样式、
## 比例、裁切与装饰。
##
## 绘制顺序：本组件画阴影/底色 → 遮罩后的 TextureRect → overlay 画边框/角标。
## 这样立绘永远不会盖住边框，也不需要改源图片。

const MASK_SHADER := preload("res://addons/rpgeventstudio/runtime/ui/theme/portrait_mask.gdshader")
const OVERLAY_SCRIPT := preload("res://addons/rpgeventstudio/runtime/ui/theme/portrait_overlay.gd")

var style: RpgEventStudioTheme:
	set(value):
		style = value
		_apply_style()
var texture: Texture2D:
	set(value):
		texture = value
		_apply_texture()
var glyph_override := ""

var _texture_rect: TextureRect
var _overlay: Control
var _material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect = TextureRect.new()
	_texture_rect.name = "PortraitTexture"
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_material = ShaderMaterial.new()
	_material.shader = MASK_SHADER
	_texture_rect.material = _material
	add_child(_texture_rect)
	_overlay = OVERLAY_SCRIPT.new()
	_overlay.name = "PortraitOverlay"
	_overlay.set("slot", self)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_apply_style()

func set_style(value: RpgEventStudioTheme) -> void:
	style = value

func set_portrait(value: Texture2D) -> void:
	texture = value

func set_glyph(value: String) -> void:
	glyph_override = value
	if _overlay != null:
		_overlay.queue_redraw()
	queue_redraw()

func _apply_texture() -> void:
	if _texture_rect == null:
		return
	_texture_rect.texture = texture
	_texture_rect.visible = texture != null
	if _overlay != null:
		_overlay.queue_redraw()
	queue_redraw()

func _apply_style() -> void:
	if style == null:
		return
	var h := float(style.portrait_size)
	var w := h * style.portrait_aspect
	custom_minimum_size = Vector2(w, h)
	size = custom_minimum_size
	rotation_degrees = float(style.portrait_rotation)
	pivot_offset = custom_minimum_size * 0.5
	modulate = style.portrait_tint
	_layout_texture()
	_apply_mask()
	if _overlay != null:
		_overlay.queue_redraw()
	queue_redraw()

func _layout_texture() -> void:
	if _texture_rect == null or style == null:
		return
	var pad := float(style.portrait_padding)
	var inset := pad + float(style.portrait_border_width)
	_texture_rect.position = Vector2(inset, inset)
	_texture_rect.size = size - Vector2(inset * 2.0, inset * 2.0)
	_texture_rect.visible = texture != null

func _apply_mask() -> void:
	if _material == null or style == null:
		return
	var shape := 0
	var radius := 0.0
	var notch := 0.14
	var min_side := maxf(1.0, minf(size.x, size.y))
	match style.portrait_style:
		"rounded":
			shape = 1
			radius = float(style.portrait_corner_radius) / min_side
		"capsule":
			shape = 1
			radius = 0.5
		"circle":
			shape = 2
		"octagon":
			shape = 3
		"polaroid":
			shape = 1
			radius = 2.0 / min_side
		"angular":
			shape = 4
			notch = 0.16
		"blood":
			shape = 4
			notch = 0.13
		_:
			shape = 0
	_material.set_shader_parameter("shape", shape)
	_material.set_shader_parameter("round_radius", radius)
	_material.set_shader_parameter("notch", notch)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_texture()
		_apply_mask()
		queue_redraw()

func _draw() -> void:
	if style == null or size.x <= 1.0 or size.y <= 1.0:
		return
	var r := Rect2(Vector2.ZERO, size)
	_draw_shadow(r)
	_draw_backdrop(r)

func _draw_shadow(r: Rect2) -> void:
	if style.portrait_shadow_color.a <= 0.0:
		return
	var sr := Rect2(r.position + style.portrait_shadow_offset, r.size)
	var c := style.portrait_shadow_color
	match style.portrait_style:
		"circle":
			draw_circle(sr.get_center(), minf(sr.size.x, sr.size.y) * 0.5, c)
		"angular", "blood":
			draw_colored_polygon(_notch_points(sr, 7.0), c)
		_:
			var sb := StyleBoxFlat.new()
			sb.bg_color = c
			sb.set_corner_radius_all(_radius_px())
			draw_style_box(sb, sr)

func _draw_backdrop(r: Rect2) -> void:
	match style.portrait_style:
		"circle":
			draw_circle(r.get_center(), minf(r.size.x, r.size.y) * 0.5, style.portrait_bg)
		"angular", "blood":
			draw_colored_polygon(_notch_points(r, 7.0), style.portrait_bg)
		"polaroid":
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 1, 1, 1)
			sb.set_corner_radius_all(2)
			draw_style_box(sb, r)
		_:
			var sb := StyleBoxFlat.new()
			sb.bg_color = style.portrait_bg
			sb.set_corner_radius_all(_radius_px())
			draw_style_box(sb, r)

func _radius_px() -> int:
	match style.portrait_style:
		"capsule":
			return int(size.y * 0.5)
		"circle":
			return int(minf(size.x, size.y) * 0.5)
		_:
			return style.portrait_corner_radius

func _notch_points(r: Rect2, n: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r.position.x + n, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.end.y - n),
		Vector2(r.end.x - n, r.end.y),
		Vector2(r.position.x, r.end.y),
		Vector2(r.position.x, r.position.y + n),
	])
