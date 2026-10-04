shader_type canvas_item;

render_mode unshaded;

// 速度线(GPU 化,fx 包 v0.68 装饰重设计):单实例一段纸白细线,TIME 驱动
// 硬边段横向流动,宿主零重绘。对照 assets/fx/backdrop_sky.gdshader 模式:
// render_mode unshaded / TIME 驱动 / 取色全经 uniform(shader 内无字面色)/
// anim=0 停帧;禁一切读屏路径(不声明屏幕纹理采样类 uniform)。
// 逐实例相位与长度倍率走 instance uniform(每线独立节奏,宿主经
// CanvasItem.set_instance_shader_parameter 下发);strength 为阈值后强度
// (0=阈下,宿主保证连续趋近,无闪烁残影);dir=±1 流向。

instance uniform float phase = 0.0;
instance uniform float len_mul = 1.0;

uniform vec4 line_color : source_color = vec4(0.929, 0.918, 0.878, 1.0);
uniform float strength = 0.0;
uniform float dir = 1.0;
uniform float anim = 1.0;
uniform float rect_w = 1500.0;

void fragment() {
	float k = clamp(strength, 0.0, 1.0);
	float t = TIME * anim;
	// 段心在矩形内循环(fract 环面距离,接缝处连续,无撕裂):
	// 流速 90+260k px/s 与旧 CPU 版一致,换算为 UV 周期/秒。
	float speed_cycles = (90.0 + 260.0 * k) / rect_w;
	float c = fract(phase + t * speed_cycles * dir);
	float w = UV.x;
	float d = abs(fract(w - c + 0.5) - 0.5);
	// 段长 36+150k px,硬边矩形(构成主义硬折返,不做柔边)。
	float seg = (36.0 + 150.0 * k) * len_mul / rect_w;
	float m = step(d, seg);
	// 强度门:alpha 随 k 单调连续(阈下恒 0),停走切换无闪烁;
	// 峰值与旧 CPU 版一致(k=1 → 0.18)。
	float a = (0.02 * k + 0.16 * k * k) * m;
	COLOR = vec4(line_color.rgb, a * line_color.a);
}
