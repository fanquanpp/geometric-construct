shader_type canvas_item;

render_mode unshaded;

// 地块主题色掩膜染色(tiles 工坊 v0.70):TileMapLayer(Solid/Decor)按
// 「登记表精确匹配」把染域源色整色替换为主题重算色——掩膜色对由宿主按
// TileAtlas.THEME_TINT_RECIPES × 当幕主题算好下发(map_src/map_dst),
// shader 零颜色知识、零字面色(取色全经 uniform,与 fx 包 shader 同律)。
// 精确匹配含 alpha 通道(±THEME_MATCH_TOL),禁模糊色相域判定——第四幕
// 主题恰为 Palette.red,色相域掩膜会把待染肩带误判入语义红排除域。
// 未命中像素(排除域:纸缘/暗板/黄蓝纸柱/CEIL_BLUE/累积阶梯)原样透传。
// 静态染色无 TIME 依赖;遍历上限 32 条,实际条数由 map_n 收口。

uniform vec4 theme_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int map_n = 0;
uniform vec4 map_src[32];
uniform vec4 map_dst[32];
uniform float match_tol = 0.0047; // = TileAtlas.THEME_MATCH_TOL(±1.2/255)

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 out_c = c;
	if (c.a > 0.001 && map_n > 0) {
		for (int i = 0; i < map_n; i++) {
			if (abs(c.r - map_src[i].r) <= match_tol
					&& abs(c.g - map_src[i].g) <= match_tol
					&& abs(c.b - map_src[i].b) <= match_tol
					&& abs(c.a - map_src[i].a) <= match_tol) {
				out_c = map_dst[i];
				break;
			}
		}
	}
	COLOR = out_c;
}
