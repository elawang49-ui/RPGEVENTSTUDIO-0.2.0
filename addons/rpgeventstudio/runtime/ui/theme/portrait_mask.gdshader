shader_type canvas_item;
// 立绘框遮罩：在 GPU 上裁切圆窗/八角/斜切，不修改源图片，也不依赖角色资源系统。
// shape: 0 矩形，1 圆角，2 圆形，3 八角，4 切角/斜切。
uniform int shape = 0;
uniform float round_radius = 0.0;
uniform float notch = 0.14;

void fragment() {
	vec2 uv = UV;
	float a = 1.0;
	if (shape == 1) {
		vec2 p = abs(uv - vec2(0.5)) - vec2(0.5 - round_radius);
		float d = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - round_radius;
		a = 1.0 - smoothstep(-0.0025, 0.0025, d);
	} else if (shape == 2) {
		float d = length(uv - vec2(0.5)) - 0.5;
		a = 1.0 - smoothstep(-0.0025, 0.0025, d);
	} else if (shape == 3) {
		vec2 p = abs(uv - vec2(0.5));
		float d = max(max(p.x, p.y), (p.x + p.y) * 0.70710678);
		a = 1.0 - smoothstep(0.5 - 0.0025, 0.5 + 0.0025, d);
	} else if (shape == 4) {
		if ((uv.x < notch && uv.y < notch && uv.x + uv.y < notch) ||
			(uv.x > 1.0 - notch && uv.y > 1.0 - notch && (1.0 - uv.x) + (1.0 - uv.y) < notch)) {
			a = 0.0;
		}
	}
	COLOR.a *= a;
}
