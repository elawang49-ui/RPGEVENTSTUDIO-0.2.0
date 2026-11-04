@tool
class_name ThemeDraw
extends RefCounted
## 主题绘制组件共用的抗锯齿工具。
##
## Compatibility 渲染器下 draw_colored_polygon 不做边缘抗锯齿，斜切/菱形/三角在 1080p
## 放大后锯齿明显。这里统一在填充后沿轮廓补一圈同色 1px 抗锯齿描边。
## 透明度很低的填充（软阴影层）不补描边，避免叠出可见的环。

const OUTLINE_MIN_ALPHA := 0.3

static func fill(ci: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	ci.draw_colored_polygon(points, color)
	if color.a >= OUTLINE_MIN_ALPHA:
		ci.draw_polyline(_closed(points), color, 1.0, true)

## 顶点色填充 + 同色抗锯齿描边（渐变面板）。
static func fill_colors(ci: CanvasItem, points: PackedVector2Array, colors: PackedColorArray) -> void:
	if points.size() < 3 or colors.size() != points.size():
		return
	ci.draw_polygon(points, colors)
	var min_a := 1.0
	for c in colors:
		min_a = minf(min_a, c.a)
	if min_a >= OUTLINE_MIN_ALPHA:
		var cc := colors.duplicate()
		cc.append(colors[0])
		ci.draw_polyline_colors(_closed(points), cc, 1.0, true)

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out

## 柳叶形叶片（两段圆弧围成），中心 center、长 length、宽 width、旋转 angle。
static func leaf_points(center: Vector2, length: float, width: float, angle: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := length * 0.5
	# 每侧一段圆弧：弦长 = length，拱高 = width/2；由弦长与拱高求半径。
	var sag := width * 0.5
	var r := (half * half + sag * sag) / (2.0 * sag)
	var a0 := asin(clampf(half / r, -1.0, 1.0))
	var steps := 10
	for side in [1.0, -1.0]:
		var cy: float = (r - sag) * side
		for i in steps + 1:
			var t: float = -a0 + 2.0 * a0 * float(i) / float(steps)
			if side < 0.0:
				t = a0 - 2.0 * a0 * float(i) / float(steps)
			var p := Vector2(r * sin(t), cy - side * r * cos(t))
			pts.append(center + p.rotated(angle))
	return pts
