shader_type canvas_item;
// 斜向扫掠转场(fx-light 卷三白名单 · 斜向扫掠,v0.37 登记实装)。
// 45° 硬边对角扫入扫出:progress 0→1 覆盖,1→2 揭开(同向续走,不回卷);
// 扫掠前沿一道构成红细线(硬边,无羽化)。直线沿 = M3 直线优先。

uniform float progress : hint_range(0.0, 2.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.055, 0.066, 0.082, 1.0);
uniform vec4 edge_color : source_color = vec4(0.878, 0.286, 0.184, 1.0);

void fragment() {
	float d = (SCREEN_UV.x + SCREEN_UV.y) * 0.5;
	float t = progress <= 1.0 ? progress : 2.0 - progress;
	t = clamp(t, 0.0, 1.0);
	float filled = step(d, t);
	// 前沿红线:阈值两侧 0.012 窗口,转场进行中才可见
	float edge = (1.0 - step(0.012, abs(d - t)))
		* step(0.002, progress) * step(progress, 1.998);
	vec3 rgb = mix(fill_color.rgb, edge_color.rgb, edge * 0.9);
	COLOR = vec4(rgb, max(filled, edge) * fill_color.a);
}
