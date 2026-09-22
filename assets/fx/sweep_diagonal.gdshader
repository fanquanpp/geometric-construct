shader_type canvas_item;


uniform float progress : hint_range(0.0, 2.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.055, 0.066, 0.082, 1.0);
uniform vec4 edge_color : source_color = vec4(0.878, 0.286, 0.184, 1.0);

void fragment() {
	float d = (SCREEN_UV.x + SCREEN_UV.y) * 0.5;
	float t = progress <= 1.0 ? progress : 2.0 - progress;
	t = clamp(t, 0.0, 1.0);
	float filled = step(d, t);

	float edge = (1.0 - step(0.012, abs(d - t)))
		* step(0.002, progress) * step(progress, 1.998);
	vec3 rgb = mix(fill_color.rgb, edge_color.rgb, edge * 0.9);
	COLOR = vec4(rgb, max(filled, edge) * fill_color.a);
}
