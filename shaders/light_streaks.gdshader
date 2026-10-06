shader_type canvas_item;

render_mode unshaded;

// 流光层(fx 包 v0.68 装饰重设计):五条横向纸光带,速度阈值以上随
// TIME 横流(方向随 dir),硬边段 + 环面距离(接缝连续)。与
// speed_lines.gdshader 同一 res://shaders/ 模式(硬边、无柔边):
// render_mode unshaded / TIME 驱动 /
// 取色全经 uniform / anim=0 停帧;禁一切读屏路径(不采样屏幕纹理)。
// strength=0 时全透明(阈下不出现),宿主平滑下发,停走切换无闪烁。

uniform vec4 col_paper : source_color = vec4(0.929, 0.918, 0.878, 1.0);
uniform vec4 col_accent : source_color = vec4(0.306, 0.525, 0.847, 1.0);
uniform float strength = 0.0;
uniform float dir = 1.0;
uniform float anim = 1.0;

// 廉价确定性哈希:行序号 → 稳定伪随机(纯函数,无纹理采样)。
float h1(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	float k = clamp(strength, 0.0, 1.0);
	float t = TIME * anim;
	// 五行离散:行 id 由 UV.y 分桶,行心与带高各行异构。
	float row = floor(UV.y * 5.0);
	float ry = (row + 0.5) / 5.0 + (h1(row + 1.0) - 0.5) * 0.12;
	float band = step(abs(UV.y - ry), 0.006 + 0.005 * h1(row + 7.0));
	// 段心横流:各行速度异构,方向随 dir(fract 对负数亦成环)。
	float c = fract(h1(row * 3.1 + 2.0)
		+ t * (0.012 + 0.05 * k) * (0.5 + h1(row + 3.0)) * dir);
	float d = abs(fract(UV.x - c + 0.5) - 0.5);
	float seg = step(d, (0.14 + 0.22 * h1(row + 11.0)) * 0.5);
	// 纸色与幕强调色按行混抹(远景纱层,峰值 alpha ≈ 0.09)。
	vec3 col = mix(col_paper.rgb, col_accent.rgb, 0.35 * h1(row + 5.0));
	float a = band * seg * (k * k * 0.09);
	COLOR = vec4(col, a);
}
