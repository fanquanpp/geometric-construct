shader_type canvas_item;

render_mode unshaded;

// 背景天幕:纵向双色渐变 + 双层无缝噪声云带(TIME 漂移,GPU 持续场零每帧 CPU)。
// 取色经 uniform 由 Backdrop 从 Palette 下发(shader 内无字面色);
// anim=0 时完全停帧(背景动效关 / 减动效)。

uniform vec4 sky_top : source_color = vec4(0.063, 0.071, 0.086, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.086, 0.098, 0.122, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.929, 0.918, 0.878, 1.0);
uniform float cloud_alpha : hint_range(0.0, 0.3) = 0.05;
uniform float cloud_speed = 6.0;
uniform float anim = 1.0;
uniform sampler2D cloud_tex : filter_linear, repeat_enable;

void fragment() {
	vec4 base = mix(sky_bottom, sky_top, UV.y);
	float t = TIME * anim;
	vec2 cuv = UV * vec2(2.6, 1.4)
		+ vec2(t * cloud_speed * 0.004, t * cloud_speed * 0.0016);
	float n = texture(cloud_tex, cuv).r;
	float n2 = texture(cloud_tex,
		UV * vec2(4.2, 2.2) - vec2(t * cloud_speed * 0.009, 0.0)).r;
	float band = smoothstep(0.52, 0.85, n) * 0.68
		+ smoothstep(0.58, 0.9, n2) * 0.32;
	band *= smoothstep(0.12, 0.78, UV.y);
	COLOR = vec4(base.rgb + cloud_color.rgb * band * cloud_alpha, 1.0);
}
