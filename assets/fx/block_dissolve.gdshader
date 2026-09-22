shader_type canvas_item;


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
