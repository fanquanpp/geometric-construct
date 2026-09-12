shader_type canvas_item;
// 阶跃溶解转场(fx-light 卷三白名单 · 阶跃溶解,v0.37 登记实装)。
// 逐块硬边:UV 分格,每格 hash 与阈值 step 比较——无平滑、无溶解渐变;
// 阈值前沿 0.06 窗口内的块染构成红(前进波);肉鸽节奏用红色刻度块语言。
// 联网核对(GodotShaders / dev.to):逐格 hash vs threshold 是 canvas_item
// 块溶解的标准做法,Threshold 由 Tween 逐帧驱动。

uniform float progress : hint_range(0.0, 2.0) = 0.0;
uniform vec2 blocks = vec2(24.0, 14.0);
uniform vec4 fill_color : source_color = vec4(0.055, 0.066, 0.082, 1.0);
uniform vec4 edge_color : source_color = vec4(0.878, 0.286, 0.184, 1.0);

float hash(vec2 c) {
	return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * blocks);
	float h = hash(cell);
	float t = progress <= 1.0 ? progress : 2.0 - progress;
	t = clamp(t, 0.0, 1.0);
	float filled = step(h, t);
	float lead = step(t - 0.06, h) * step(h, t)
		* step(0.002, progress) * step(progress, 1.998);
	vec3 rgb = mix(fill_color.rgb, edge_color.rgb, lead * 0.85);
	COLOR = vec4(rgb, filled * fill_color.a);
}
