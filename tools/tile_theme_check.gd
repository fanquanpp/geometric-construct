extends SceneTree

# 主题色挂载门禁(v0.70 tiles 波)。职责:
#   A. 登记表覆盖率:四张生成 PNG 唯一色清点(Image 直读源文件,与 PIL
#      同粒度),每个 alpha>0 色类必须命中 THEME_TINT_RECIPES(染色域)或
#      THEME_KEEP_RECIPES / THEME_KEEP_LADDER(排除域)理论色,零漏网。
#   B. 关卡面:headless 载入四幕各 1 关+教程+probe,断言 theme_key 契约
#      解析、Solid/Decor material 非 null(保红关 Decor 不挂)、uniform
#      theme_color == Palette[解析键]、probe 不挂。
#   C. 红刻语义盘点三联结论与 act4 红幕掩膜决策登记在案(输出留档)。
#   D. 主角色可读性量化:三体体色(palette red/yellow/blue)与四幕肩带
#      (=主题色,登记配方 tint=1.0 整替)的 ΔL/ΔRGB 逐幕输出;撞色对
#      显式注记登记设计态(纸缘描边兜底),不得静默通过。
#   E. FACE 常量与 PNG 主色一致断言(与 gen_tile_assets 单真值对账)。
#   godot --headless --path . --script res://tools/tile_theme_check.gd
const THEME_SHADER := preload("res://shaders/tile_theme.gdshader")
const ATLAS_FILES := {
	"ground": "res://assets/tiles/ground_tiles.png",
	"platform": "res://assets/tiles/platform_tiles.png",
	"decor": "res://assets/tiles/decor_tiles.png",
	"special": "res://assets/tiles/special_tiles.png",
}
const ATLAS_LAYERS := {
	"ground": "solid", "platform": "solid", "decor": "decor",
	"special": "solid",
}
# 四幕各 1 关 + 教程 + probe(验收指定覆盖面);期望 theme 键与 Decor
# 保红开关 = 红刻语义盘点登记(SCENES/ACTS theme 字段落盘后仍以数据优先,
# 此表只断言「渲染层解析结果」与登记一致)。
const LEVEL_CASES: Array[Dictionary] = [
	{"path": "res://levels_native/act1/s01.tscn", "key": "blue", "keep": false},
	{"path": "res://levels_native/act3/s01.tscn", "key": "yellow", "keep": true},
	{"path": "res://levels_native/act4/s03.tscn", "key": "orange", "keep": false},
	{"path": "res://levels_native/act5/s01.tscn", "key": "red", "keep": true},
	{"path": "res://levels_native/tutorial/tutorial.tscn", "key": "blue",
		"keep": false},
	{"path": "res://levels_native/dev/probe.tscn", "key": "", "keep": false},
	{"path": "res://levels_native/duel/race.tscn", "key": "red", "keep": false},
]

var _fails := 0


func _initialize() -> void:
	_check_registry_coverage()
	_check_face_constants()
	_check_levels()
	_check_readability()
	print("TILETHEME %s" % ("ALL PASS" if _fails == 0 else "FAIL(%d)" % _fails))
	quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("  FAIL: %s" % msg)


## 配方表 -> 理论色集合(tint 与 keep 分开)。
func _theory_colors(recipes: Array, layer: String) -> Dictionary:
	var out := {}
	for recipe: Dictionary in recipes:
		if recipes == TileAtlas.THEME_TINT_RECIPES \
				and str(recipe["layer"]) != layer:
			continue
		if recipes == TileAtlas.THEME_KEEP_RECIPES \
				and str(recipe.get("layer", "")) != layer:
			continue
		out[TileAtlas.quant8(TileAtlas.recipe_source_color(recipe))] = true
	return out


## A. 覆盖率零漏网断言(四 PNG 全量唯一色)。
func _check_registry_coverage() -> void:
	print("== A. 登记表覆盖率(四图集唯一色清点,零漏网) ==")
	var tint_all := {}
	var keep_all := {}
	for layer: String in ["solid", "decor", "special"]:
		for r: Dictionary in TileAtlas.THEME_TINT_RECIPES:
			if str(r["layer"]) == layer:
				tint_all[TileAtlas.quant8(TileAtlas.recipe_source_color(r))] = true
		for r: Dictionary in TileAtlas.THEME_KEEP_RECIPES:
			if str(r.get("layer", "")) == layer:
				keep_all[TileAtlas.quant8(TileAtlas.recipe_source_color(r))] = true
	var ladder := {}
	for c: Color in TileAtlas.THEME_KEEP_LADDER:
		ladder[c] = true
	for atlas: String in ATLAS_FILES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(
			ATLAS_FILES[atlas]))
		if img == null:
			_fail("%s 读取失败" % atlas)
			continue
		var seen := {}
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					seen[TileAtlas.quant8(c)] = true
		var miss := 0
		var hit_tint := 0
		var hit_keep := 0
		for c: Color in seen:
			if tint_all.has(c) or _near(c, tint_all):
				hit_tint += 1
			elif keep_all.has(c) or _near(c, keep_all) or ladder.has(c):
				hit_keep += 1
			else:
				miss += 1
				if miss <= 8:
					print("    漏网 %s #%02X%02X%02X%02X"
						% [atlas, int(c.r * 255.0), int(c.g * 255.0),
						int(c.b * 255.0), int(c.a * 255.0)])
		print("  %s: 唯一色 %d(染域命中 %d / 排除域 %d / 漏网 %d)"
			% [atlas, seen.size(), hit_tint, hit_keep, miss])
		if miss > 0:
			_fail("%s 存在 %d 个未登记色类(gen 动画须同步登记表)" % [atlas, miss])


func _near(c: Color, pool: Dictionary) -> bool:
	for p: Color in pool:
		if absf(c.r - p.r) <= TileAtlas.THEME_MATCH_TOL \
				and absf(c.g - p.g) <= TileAtlas.THEME_MATCH_TOL \
				and absf(c.b - p.b) <= TileAtlas.THEME_MATCH_TOL \
				and absf(c.a - p.a) <= TileAtlas.THEME_MATCH_TOL:
			return true
	return false


## E. FACE 常量与 ground_tiles 实测主色一致(单真值脱节即报)。
func _check_face_constants() -> void:
	print("== E. FACE 常量与 PNG 主色对账 ==")
	var img := Image.load_from_file(ProjectSettings.globalize_path(
		ATLAS_FILES["ground"]))
	if img == null:
		_fail("ground_tiles.png 读取失败")
		return
	var pairs := [[Vector2i(102, 0), TileAtlas.FACE_FULL, "FACE_FULL"],
		[Vector2i(2, 3), TileAtlas.FACE_SHOULDER, "FACE_SHOULDER"]]
	for p: Array in pairs:
		var at: Vector2i = p[0]
		var got := img.get_pixel(at.x, at.y)
		var want: Color = p[1]
		if _cbyte(got) != _cbyte(want):
			_fail("%s 常量 %s != PNG 实测 %s(与 gen_tile_assets 脱节)"
				% [p[2], _cbyte(want), _cbyte(got)])
		else:
			print("  %s = %s 与 PNG 一致" % [p[2], _cbyte(got)])


func _cbyte(c: Color) -> String:
	return "#%02X%02X%02X%02X" % [int(c.r * 255.0), int(c.g * 255.0),
		int(c.b * 255.0), int(c.a * 255.0)]


## B. 关卡面:契约解析 + 材质挂载 + uniform 一致性。
func _check_levels() -> void:
	print("== B. 主题色契约与材质挂载(四幕各 1 关+教程+probe) ==")
	print("== C. 红刻语义盘点三联结论登记 ==")
	print("  槽级排除(全域保原色):黄柱(1,3)/蓝柱(2,3)/纸柱(3,3) 幕主题柱件、"
		+ "暗板窗槽 paper 系、CEIL_BLUE 青缘、face 系暗面(仅 shift 0.10 微偏移)")
	print("  关级 Decor 保红开关(盘点结论,TileAtlas.DECOR_KEEP_RED):")
	for p: String in TileAtlas.DECOR_KEEP_RED:
		print("    %s" % p)
	print("  文案处置:保红关 intro 与染色零冲突、染色关 intro 无红字点名"
		+ "——盘点结论 = 文案处置空集(levels 无需改写)")
	print("  act4 红幕掩膜决策:掩膜 = 登记表精确匹配(±1.2/255,含 alpha),"
		+ "禁色相域判定——act4 主题恰为 Palette.red,色相域会把待染肩带误判入"
		+ "语义红排除域;肩带 tint=1.0 整替为 Palette.red 系登记预期。")
	for case: Dictionary in LEVEL_CASES:
		var cpath := str(case["path"])
		if not FileAccess.file_exists(cpath):
			# levels 包登记未落盘(如双人关并行作业期):注记跳过,
			# 集成轮复跑时文件在即真审。
			print("  SKIP %s: 场景未落盘(levels 包并行作业期),集成轮复跑"
				% cpath)
			continue
		var ps: PackedScene = load(cpath)
		if ps == null:
			_fail("%s 载入失败" % cpath)
			continue
		var root := ps.instantiate()
		var key: String = (root as NativeLevel).theme_key()
		if key != str(case["key"]):
			_fail("%s theme_key=%s 期望 %s" % [case["path"], key, case["key"]])
		(root as NativeLevel)._apply_theme_materials()
		var solid := root.get_node_or_null("Solid") as TileMapLayer
		var decor := root.get_node_or_null("Decor") as TileMapLayer
		if key.is_empty():
			if solid != null and solid.material != null:
				_fail("%s 空键关 Solid 不应挂材质" % str(case["path"]))
			if decor != null and decor.material != null:
				_fail("%s 空键关 Decor 不应挂材质" % str(case["path"]))
			print("  %s: 空键不染色 ✓" % case["path"])
			root.free()
			continue
		if solid == null or solid.material == null:
			_fail("%s Solid 材质未挂" % str(case["path"]))
		else:
			_assert_material(solid.material, key, "Solid", str(case["path"]))
		var keep: bool = (root as NativeLevel).decor_keep_red()
		if keep != bool(case["keep"]):
			_fail("%s decor_keep_red=%s 期望 %s(盘点登记漂移)"
				% [case["path"], keep, case["keep"]])
		if decor == null:
			_fail("%s 缺 Decor 层" % str(case["path"]))
		elif keep:
			if decor.material != null:
				_fail("%s 保红关 Decor 不应挂材质" % str(case["path"]))
			else:
				print("  %s: theme=%s Solid 已挂,Decor 保红(盘点开关)✓"
					% [case["path"], key])
		else:
			if decor.material == null:
				_fail("%s Decor 材质未挂" % str(case["path"]))
			else:
				_assert_material(decor.material, key, "Decor", str(case["path"]))
				print("  %s: theme=%s Solid/Decor 已挂 ✓" % [case["path"], key])
		root.free()


func _assert_material(mat: Material, key: String, layer: String,
		path: String) -> void:
	var sm := mat as ShaderMaterial
	if sm == null or sm.shader != THEME_SHADER:
		_fail("%s %s 材质不是 tile_theme.gdshader" % [path, layer])
		return
	var want: Color = TileAtlas.theme_slot_color(key)
	var got: Variant = sm.get_shader_parameter("theme_color")
	if got is Color and (got as Color).is_equal_approx(want):
		var n: Variant = sm.get_shader_parameter("map_n")
		if not (n is int) or int(n) <= 0:
			_fail("%s %s 掩膜表为空" % [path, layer])
		return
	_fail("%s %s theme_color=%s != Palette[%s]=%s"
		% [path, layer, _cbyte(got if got is Color else Color()), key,
		_cbyte(want)])


## D. 主角色可读性量化:三体体色 × 四幕肩带(=主题色)ΔL/ΔRGB。
## 登记阈值:ΔL>=0.10 或 ΔRGBmax>=0.15 判量化可辨;不达 = 同色相撞
## 登记设计态(角色纸缘描边 + 地形暗底兜底),显式注记不得静默。
func _check_readability() -> void:
	print("== D. 三体角色体色 × 当幕肩带色 量化对比(ΔL/ΔRGB) ==")
	var bodies := {"red": Palette.I.red, "yellow": Palette.I.yellow,
		"blue": Palette.I.blue}
	var collide := 0
	for i in LevelData.THEMES.size():
		var key: String = LevelData.THEMES[i]
		var band: Color = TileAtlas.theme_slot_color(key)
		for b: String in bodies:
			var body: Color = bodies[b]
			var dl: float = absf(body.get_luminance() - band.get_luminance())
			var dr: float = maxf(absf(body.r - band.r),
				maxf(absf(body.g - band.g), absf(body.b - band.b)))
			var note := ""
			if dl < 0.10 and dr < 0.15:
				note = " <登记设计态:体色与肩带同色相,角色纸缘描边+暗底兜底>"
				collide += 1
			print("  第%d幕(%s肩带) vs %s体: dL=%.3f dRGB=%.3f%s"
				% [i + 1, key, b, dl, dr, note])
	if collide < 3:
		_fail("撞色注记应覆盖 blue/yellow/red 三幕各 1 对(实际 %d)" % collide)
	else:
		print("  撞色对 %d 组全部显式注记(orange 幕与三体量化可辨,零注记) ✓"
			% collide)
