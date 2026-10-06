extends SceneTree

# 分类瓦片资产生成器 v0.66.0(用户令「native 大图集退役,按最新程序化
# _draw 美术为标准,分类多文件、细致分类、编辑器可画」):
#   1. 程序化绘制四类独立图集 PNG(assets/tiles/):
#      ground_tiles.png    47 变体地面地形(取色 / 造型语言 = TerrainArt _draw)
#      platform_tiles.png  8 变体单向平台(顶亮缘 + 底虚线 = 单向判定语言)
#      decor_tiles.png     装饰件(暗板 / 括弧 / 十二边环 / 红刻 / 刻度柱)
#      special_tiles.png   异形件(斜坡 / 半块 / 半柱 / 窄柱 / 垂板)
#   2. 重建 data/tiles/native_tileset.tres(保留原 uid 与 6 物理层):
#      四源归类 + terrain set 0(地面 MATCH_CORNERS_AND_SIDES,47 变体
#      peering bits)+ terrain set 1(平台 MATCH_SIDES)+ 各形状物理。
# headless 运行:
#   godot --headless --path . --script res://tools/gen_tile_assets.gd
# PNG 属生成产物,可随时由本工具重建;风格基准:scripts/art/terrain_art.gd
# 的 _draw 配方与 data/palette.tres(风格常量就地固化并注明来源)。

const TILE := 100

# data/palette.tres(浮点转 8bit,来源唯一)
const INK := Color8(16, 18, 22)
const INK_2 := Color8(22, 25, 31)
const INK_3 := Color8(30, 34, 43)
const PAPER := Color8(237, 234, 224)
const DIM := Color8(142, 141, 133)
const RED := Color8(224, 73, 47)
const YELLOW := Color8(232, 179, 58)
const BLUE := Color8(78, 134, 216)

# scripts/art/terrain_art.gd 面料常量(_draw 美术标准就地沿用)
const FACE_FULL := Color8(38, 43, 52)
const FACE_TOP := Color8(43, 49, 64)
const FACE_SHOULDER := Color8(58, 66, 84)
const FACE_SHOULDER_DIM := Color8(49, 56, 69)
const CEIL_BLUE := Color8(78, 134, 216)

const EDGE_TOP := 0.5    # terrain_art edge_alpha
const EDGE_SIDE := 0.12
const EDGE_BOTTOM := 0.08
const EDGE_INNER := 0.4

const OUT_GROUND := "res://assets/tiles/ground_tiles.png"
const OUT_PLATFORM := "res://assets/tiles/platform_tiles.png"
const OUT_DECOR := "res://assets/tiles/decor_tiles.png"
const OUT_SPECIAL := "res://assets/tiles/special_tiles.png"
const OUT_TILESET := "res://data/tiles/native_tileset.tres"

static var FULL_SQUARE := PackedVector2Array([
	Vector2(-50, -50), Vector2(50, -50), Vector2(50, 50), Vector2(-50, 50)])


func _initialize() -> void:
	var fails := 0
	fails += _gen_ground()
	fails += _gen_platform()
	fails += _gen_decor()
	fails += _gen_special()
	if fails == 0:
		fails += _gen_tileset()
	if fails == 0:
		var n := TileAtlas.variants().size()
		print("TILEASSETS ALL PASS (ground variants=%d)" % n)
	else:
		print("TILEASSETS FAIL(%d)" % fails)
	quit(0 if fails == 0 else 1)


## Porter-Duff over:底透明时保留前景半透明(装饰件依赖),底不透明时
## 等价普通混合(地面 / 平台依赖)。
func _blend(base: Color, over: Color, a: float) -> Color:
	var out_a := a + base.a * (1.0 - a)
	if out_a <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(
		(over.r * a + base.r * base.a * (1.0 - a)) / out_a,
		(over.g * a + base.g * base.a * (1.0 - a)) / out_a,
		(over.b * a + base.b * base.a * (1.0 - a)) / out_a, out_a)


func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			img.set_pixel(xx, yy, c)


func _over(img: Image, x: int, y: int, w: int, h: int, c: Color, a: float) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			img.set_pixel(xx, yy, _blend(img.get_pixel(xx, yy), c, a))


func _px(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, _blend(img.get_pixel(x, y), c, a))


func _line(img: Image, from: Vector2, to: Vector2, c: Color, a: float,
		thick := 1) -> void:
	var steps := int(ceil(from.distance_to(to))) * 2 + 1
	for i in steps + 1:
		var p := from.lerp(to, float(i) / float(steps))
		for ty in thick:
			for tx in thick:
				_px(img, int(p.x) + tx, int(p.y) + ty, c, a)


# ---------------- 地面:47 变体(_draw_full_block 语言) ----------------

func _gen_ground() -> int:
	var variants := TileAtlas.variants()
	if variants.size() != 47:
		push_error("地面正则代表数 %d != 47" % variants.size())
		return 1
	var img := Image.create_empty(TILE * TileAtlas.GROUND_GRID.x,
		TILE * TileAtlas.GROUND_GRID.y, false, Image.FORMAT_RGBA8)
	for i in variants.size():
		var ox := (i % TileAtlas.GROUND_COLS) * TILE
		var oy := floori(i / float(TileAtlas.GROUND_COLS)) * TILE
		_draw_ground_tile(img, ox, oy, variants[i])
	var err := img.save_png(OUT_GROUND)
	print("GROUND png err=%d variants=%d" % [err, variants.size()])
	return 1 if err != OK else 0


func _draw_ground_tile(img: Image, ox: int, oy: int, mask: int) -> void:
	var n := (mask & TileAtlas.BIT_N) != 0
	var e := (mask & TileAtlas.BIT_E) != 0
	var s := (mask & TileAtlas.BIT_S) != 0
	var w := (mask & TileAtlas.BIT_W) != 0
	_fill(img, ox, oy, TILE, TILE, FACE_FULL)
	if not n:  # 承重面:肩带 22px + 纸缘 2px(_draw_full_block 同款)
		_fill(img, ox, oy, TILE, 22, FACE_SHOULDER)
		_over(img, ox, oy, TILE, 2, PAPER, EDGE_TOP)
	if not s:
		_over(img, ox, oy + TILE - 2, TILE, 2, PAPER, EDGE_BOTTOM)
	if not w:
		_over(img, ox, oy, 2, TILE, PAPER, EDGE_SIDE)
	if not e:
		_over(img, ox + TILE - 2, oy, 2, TILE, PAPER, EDGE_SIDE)
	# 内角括弧:两邻侧齐备而角邻缺席时,补 L 形纸缘闭合接缝
	if n and e and not (mask & TileAtlas.BIT_NE):
		_over(img, ox + TILE - 14, oy, 14, 2, PAPER, EDGE_INNER)
		_over(img, ox + TILE - 2, oy, 2, 14, PAPER, EDGE_INNER)
	if n and w and not (mask & TileAtlas.BIT_NW):
		_over(img, ox, oy, 14, 2, PAPER, EDGE_INNER)
		_over(img, ox, oy, 2, 14, PAPER, EDGE_INNER)
	if s and e and not (mask & TileAtlas.BIT_SE):
		_over(img, ox + TILE - 14, oy + TILE - 2, 14, 2, PAPER, EDGE_INNER)
		_over(img, ox + TILE - 2, oy + TILE - 14, 2, 14, PAPER, EDGE_INNER)
	if s and w and not (mask & TileAtlas.BIT_SW):
		_over(img, ox, oy + TILE - 2, 14, 2, PAPER, EDGE_INNER)
		_over(img, ox, oy + TILE - 14, 2, 14, PAPER, EDGE_INNER)


# ---------------- 平台:8 变体(_draw_solid 单向语言) ----------------

func _gen_platform() -> int:
	var img := Image.create_empty(TILE * TileAtlas.PLATFORM_GRID.x,
		TILE * TileAtlas.PLATFORM_GRID.y, false, Image.FORMAT_RGBA8)
	for i in 8:
		var coord := Vector2i(i % TileAtlas.PLATFORM_COLS,
			floori(i / float(TileAtlas.PLATFORM_COLS)))
		_draw_platform_tile(img, coord.x * TILE, coord.y * TILE,
			TileAtlas.platform_mask(coord))
	var err := img.save_png(OUT_PLATFORM)
	print("PLATFORM png err=%d" % err)
	return 1 if err != OK else 0


func _draw_platform_tile(img: Image, ox: int, oy: int, mask: int) -> void:
	var e := (mask & TileAtlas.BIT_E) != 0
	var w := (mask & TileAtlas.BIT_W) != 0
	_fill(img, ox, oy, TILE, 24, FACE_TOP)
	_over(img, ox, oy, TILE, 4, PAPER, 0.75)          # 可踏顶亮缘 4px
	# 单向板差分:底缘虚线 = 「自下可穿」判定语言(10 开 10 收)
	var dash := 0
	while dash < TILE:
		_over(img, ox + dash, oy + 22, mini(10, TILE - dash), 2, PAPER, 0.22)
		dash += 20
	if not w:
		_over(img, ox, oy, 2, 24, PAPER, 0.3)
	if not e:
		_over(img, ox + TILE - 2, oy, 2, 24, PAPER, 0.3)


# ---------------- 装饰:透明底件 ----------------

func _gen_decor() -> int:
	var img := Image.create_empty(TILE * 4, TILE * 4, false, Image.FORMAT_RGBA8)
	var ox := 0
	var oy := 0
	# 行 0:暗板四件(_decor_panel / DrawKit 语言)
	_draw_panel(img, ox, oy, true, false, false)
	_draw_panel(img, ox + TILE, oy, false, true, false)
	_draw_panel(img, ox + TILE * 2, oy, false, false, false)
	_draw_gon_ring(img, ox + TILE * 2, oy)
	_draw_panel(img, ox + TILE * 3, oy, false, false, true)
	# 行 1:窗槽 / 红刻三件(v0.70 tiles 波补伪空槽:(2,1) 原本 0% 不透明
	# 而关卡实摆 3 格(act3/s01、act3/s05、act5/s03,tools/dump_tile_usage
	# 实测)永远画空;(3,1) 仅 1.4% 孤点。补齐为有效装饰件,槽位与全部
	# atlas 坐标逐格不变):
	#   (2,1) 红括弧件:四角 RED@0.45 括弧 + 中心 RED@0.85 锚点(5.3% 不透明)
	#   (3,1) 红刻锚点件:原 12x12 RED@0.85 红点保留,外包 RED@0.5 方框环(6.6%)
	oy = TILE
	for s in 3:   # _win 槽语言(bake 同源)
		var wx := ox + 22 + s * 19
		_over(img, wx, oy + 62, 18, 26, PAPER, 0.22)
	for k in 3:
		_over(img, ox + 8, oy + 30 + k * 16, 84, 6, RED, 0.5)
	_fill(img, ox + TILE + 2, oy + 2, 30, 30, Color(RED, 0.55))
	_over(img, ox + TILE + 2, oy + 2, 30, 30, PAPER, 0.4)
	_draw_red_brackets(img, ox + TILE * 2, oy)
	_fill(img, ox + TILE * 3 + 44, oy + 44, 12, 12, Color(RED, 0.85))
	_over(img, ox + TILE * 3 + 32, oy + 32, 36, 4, RED, 0.5)
	_over(img, ox + TILE * 3 + 32, oy + 64, 36, 4, RED, 0.5)
	_over(img, ox + TILE * 3 + 32, oy + 36, 4, 28, RED, 0.5)
	_over(img, ox + TILE * 3 + 64, oy + 36, 4, 28, RED, 0.5)
	# 行 3:刻度柱四色(_tick_columns 同款)
	oy = TILE * 3
	_draw_ticks(img, ox, oy, RED)
	_draw_ticks(img, ox + TILE, oy, YELLOW)
	_draw_ticks(img, ox + TILE * 2, oy, BLUE)
	_draw_ticks(img, ox + TILE * 3, oy, PAPER)
	var err := img.save_png(OUT_DECOR)
	print("DECOR png err=%d" % err)
	return 1 if err != OK else 0


## decor (2,1) 红括弧件(v0.70 补槽):与 _draw_panel brackets 同语言,
## 取色 RED@0.45 / RED@0.85 与 _gen_decor 红刻同源;色类已登记
## TileAtlas.THEME_TINT_RECIPES(a=0.45 单笔与 0.45×0.45 角部叠笔)。
func _draw_red_brackets(img: Image, ox: int, oy: int) -> void:
	var g := 8
	var arm := 24
	for t in 2:
		_over(img, ox + g, oy + g + t, arm, 1, RED, 0.45)
		_over(img, ox + g + t, oy + g, 1, arm, RED, 0.45)
		_over(img, ox + TILE - g - arm, oy + g + t, arm, 1, RED, 0.45)
		_over(img, ox + TILE - g - t, oy + g, 1, arm, RED, 0.45)
		_over(img, ox + g, oy + TILE - g - t, arm, 1, RED, 0.45)
		_over(img, ox + g + t, oy + TILE - g - arm, 1, arm, RED, 0.45)
		_over(img, ox + TILE - g - arm, oy + TILE - g - t, arm, 1, RED, 0.45)
		_over(img, ox + TILE - g - t, oy + TILE - g - arm, 1, arm, RED, 0.45)
	_fill(img, ox + 44, oy + 44, 12, 12, Color(RED, 0.85))


func _draw_panel(img: Image, ox: int, oy: int, plain: bool, brackets: bool,
		stripes: bool) -> void:
	_fill(img, ox + 1, oy + 1, TILE - 2, TILE - 2, Color(PAPER, 0.06))
	for t in 2:
		_over(img, ox, oy + t, TILE, 1, PAPER, 0.14)
		_over(img, ox, oy + TILE - 1 - t, TILE, 1, PAPER, 0.14)
		_over(img, ox + t, oy, 1, TILE, PAPER, 0.14)
		_over(img, ox + TILE - 1 - t, oy, 1, TILE, PAPER, 0.14)
	if stripes:
		for k in 3:
			_over(img, ox + 10, oy + 26 + k * 20, 80, 8, PAPER, 0.16)
	if brackets:
		var g := 8
		var arm := 20
		for t in 2:
			_over(img, ox + g, oy + g + t, arm, 1, PAPER, 0.45)
			_over(img, ox + g + t, oy + g, 1, arm, PAPER, 0.45)
			_over(img, ox + TILE - g - arm, oy + g + t, arm, 1, PAPER, 0.45)
			_over(img, ox + TILE - g - t, oy + g, 1, arm, PAPER, 0.45)
			_over(img, ox + g, oy + TILE - g - t, arm, 1, PAPER, 0.45)
			_over(img, ox + g + t, oy + TILE - g - arm, 1, arm, PAPER, 0.45)
			_over(img, ox + TILE - g - arm, oy + TILE - g - t, arm, 1, PAPER, 0.45)
			_over(img, ox + TILE - g - t, oy + TILE - g - arm, 1, arm, PAPER, 0.45)


func _draw_gon_ring(img: Image, ox: int, oy: int) -> void:
	var c := Vector2(ox, oy) + Vector2(50, 50)
	for r: float in [32.0, 24.0]:
		var a := 0.30 if r > 28.0 else 0.18
		var prev := Vector2.ZERO
		for k in 13:
			var ang := TAU * k / 12.0 - PI / 2.0
			var p := c + Vector2(cos(ang), sin(ang)) * r
			if k > 0:
				_line(img, prev, p, PAPER, a, 2 if r > 28.0 else 1)
			prev = p


func _draw_ticks(img: Image, ox: int, oy: int, col: Color) -> void:
	for k in 3:
		var x := ox + 20 + k * 30
		_over(img, x - 3, oy + 10, 6, 80, col, 0.55)
		for t in 5:
			_over(img, x - 9, oy + 10 + t * 18, 12, 2, col, 0.85)


# ---------------- 异形件(独立物理) ----------------

func _gen_special() -> int:
	var img := Image.create_empty(TILE * 4, TILE * 2, false, Image.FORMAT_RGBA8)
	# (0,0) 右升 45 度坡:三角 FACE_FULL + 斜边纸缘
	_tri(img, 0, 0, [Vector2(0, 100), Vector2(100, 0), Vector2(100, 100)])
	_line(img, Vector2(0, 100), Vector2(99, 1), PAPER, EDGE_TOP, 2)
	# (1,0) 左升 45 度坡
	_tri(img, TILE, 0, [Vector2(0, 0), Vector2(100, 100), Vector2(0, 100)])
	_line(img, Vector2(TILE + 1, 0), Vector2(TILE * 2 - 1, 99), PAPER, EDGE_TOP, 2)
	# (2,0) 半高块:下半 + 肩带纸缘(可踏台)
	_fill(img, TILE * 2, 50, TILE, 50, FACE_FULL)
	_fill(img, TILE * 2, 50, TILE, 12, FACE_SHOULDER)
	_over(img, TILE * 2, 50, TILE, 2, PAPER, EDGE_TOP)
	# (3,0) 左半柱(物理左 24 宽)
	_fill(img, TILE * 3, 0, 24, TILE, FACE_FULL)
	_over(img, TILE * 3 + 22, 0, 2, TILE, PAPER, EDGE_SIDE)
	# (1,1) 右半柱
	_fill(img, TILE + 76, TILE, 24, TILE, FACE_FULL)
	_over(img, TILE + 76, TILE, 2, TILE, PAPER, EDGE_SIDE)
	# (2,1) 窄柱(52 宽居中)
	_fill(img, TILE * 2 + 24, TILE, 52, TILE, FACE_FULL)
	_over(img, TILE * 2 + 24, TILE, 2, TILE, PAPER, EDGE_SIDE)
	_over(img, TILE * 2 + 74, TILE, 2, TILE, PAPER, EDGE_SIDE)
	# (3,1) 垂板:底 24 + 暗肩 + 青缘(挂板判定语言)
	_fill(img, TILE * 3, TILE + 76, TILE, 24, FACE_FULL)
	_fill(img, TILE * 3, TILE + 76, TILE, 10, FACE_SHOULDER_DIM)
	_over(img, TILE * 3, TILE + 97, TILE, 3, CEIL_BLUE, 0.65)
	var err := img.save_png(OUT_SPECIAL)
	print("SPECIAL png err=%d" % err)
	return 1 if err != OK else 0


func _tri(img: Image, ox: int, oy: int, pts: Array) -> void:
	for yy in TILE:
		for xx in TILE:
			if _in_tri(Vector2(xx + 0.5, yy + 0.5),
					[pts[0], pts[1], pts[2]]):
				img.set_pixel(ox + xx, oy + yy, FACE_FULL)


func _in_tri(p: Vector2, tri: Array) -> bool:
	var a: Vector2 = tri[0]
	var b: Vector2 = tri[1]
	var c: Vector2 = tri[2]
	var d1 := _sign_side(p, a, b)
	var d2 := _sign_side(p, b, c)
	var d3 := _sign_side(p, c, a)
	var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)


func _sign_side(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)


# ---------------- TileSet 重建(保 uid / 保 6 物理层) ----------------

func _gen_tileset() -> int:
	var tex_ground: Texture2D = load(OUT_GROUND)
	if tex_ground == null:
		# 阶段一:PNG 刚落盘尚未 import,本阶段只产出图片;
		# godot --headless --path . --import 后重跑本工具进入阶段二。
		print("TILEASSETS STAGE1: PNG 已生成,待 --import 后重跑以重建 TileSet")
		return 0
	var ts: TileSet = load(OUT_TILESET)
	if ts == null:
		push_error("TileSet 载入失败")
		return 1
	while ts.get_source_count() > 0:
		ts.remove_source(ts.get_source_id(0))
	# 地形集先行:0=地面(角+边),1=平台(边)
	if ts.get_terrain_sets_count() < 1:
		ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	if ts.get_terrains_count(0) < 1:
		ts.add_terrain(0)
	if ts.get_terrain_sets_count() < 2:
		ts.add_terrain_set()
	ts.set_terrain_set_mode(1, TileSet.TERRAIN_MODE_MATCH_SIDES)
	if ts.get_terrains_count(1) < 1:
		ts.add_terrain(1)

	var ground := TileSetAtlasSource.new()
	ground.texture = tex_ground
	ground.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(ground, TileAtlas.SOURCE_GROUND)
	for i in TileAtlas.variants().size():
		var coord := Vector2i(i % TileAtlas.GROUND_COLS,
			floori(i / float(TileAtlas.GROUND_COLS)))
		ground.create_tile(coord)
		var td := ground.get_tile_data(coord, 0)
		td.terrain_set = 0
		td.terrain = 0
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, FULL_SQUARE)
		_set_peering(td, TileAtlas.ground_mask(coord))

	var platform := TileSetAtlasSource.new()
	platform.texture = load(OUT_PLATFORM)
	platform.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(platform, TileAtlas.SOURCE_PLATFORM)
	for i in 8:
		var pc := Vector2i(i % TileAtlas.PLATFORM_COLS,
			floori(i / float(TileAtlas.PLATFORM_COLS)))
		platform.create_tile(pc)
		var ptd := platform.get_tile_data(pc, 0)
		ptd.terrain_set = 1
		ptd.terrain = 0
		ptd.set_collision_polygons_count(0, 1)
		ptd.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-50, -50), Vector2(50, -50), Vector2(50, -26),
			Vector2(-50, -26)]))
		ptd.set_collision_polygon_one_way(0, 0, true)
		_set_peering_4(ptd, TileAtlas.platform_mask(pc))

	var decor := TileSetAtlasSource.new()
	decor.texture = load(OUT_DECOR)
	decor.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(decor, TileAtlas.SOURCE_DECOR)
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
			Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]:
		decor.create_tile(d)

	var special := TileSetAtlasSource.new()
	special.texture = load(OUT_SPECIAL)
	special.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(special, TileAtlas.SOURCE_SPECIAL)
	var shapes := {
		Vector2i(0, 0): PackedVector2Array([Vector2(-50, 50), Vector2(50, -50),
			Vector2(50, 50)]),
		Vector2i(1, 0): PackedVector2Array([Vector2(-50, -50), Vector2(50, 50),
			Vector2(-50, 50)]),
		Vector2i(2, 0): PackedVector2Array([Vector2(-50, 0), Vector2(50, 0),
			Vector2(50, 50), Vector2(-50, 50)]),
		Vector2i(3, 0): PackedVector2Array([Vector2(-50, -50), Vector2(-26, -50),
			Vector2(-26, 50), Vector2(-50, 50)]),
		Vector2i(0, 1): PackedVector2Array([Vector2(26, -50), Vector2(50, -50),
			Vector2(50, 50), Vector2(26, 50)]),
		Vector2i(1, 1): PackedVector2Array([Vector2(-26, -50), Vector2(26, -50),
			Vector2(26, 50), Vector2(-26, 50)]),
		Vector2i(2, 1): PackedVector2Array([Vector2(-50, 26), Vector2(50, 26),
			Vector2(50, 50), Vector2(-50, 50)]),
		Vector2i(3, 1): PackedVector2Array([Vector2(-50, 26), Vector2(50, 26),
			Vector2(50, 50), Vector2(-50, 50)]),
	}
	for sc: Vector2i in shapes:
		special.create_tile(sc)
		var std := special.get_tile_data(sc, 0)
		std.set_collision_polygons_count(0, 1)
		std.set_collision_polygon_points(0, 0, shapes[sc])

	var err := ResourceSaver.save(ts, OUT_TILESET)
	print("TILESET save err=%d sources=%d" % [err, ts.get_source_count()])
	return 1 if err != OK else 0


func _set_peering(td: TileData, mask: int) -> void:
	_set_peering_4(td, mask)
	var corner_map := {
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: TileAtlas.BIT_NE,
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: TileAtlas.BIT_SE,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: TileAtlas.BIT_SW,
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: TileAtlas.BIT_NW,
	}
	for bit: int in corner_map:
		td.set_terrain_peering_bit(bit,
			0 if (mask & corner_map[bit]) else -1)


func _set_peering_4(td: TileData, mask: int) -> void:
	var side_map := {
		TileSet.CELL_NEIGHBOR_TOP_SIDE: TileAtlas.BIT_N,
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE: TileAtlas.BIT_E,
		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: TileAtlas.BIT_S,
		TileSet.CELL_NEIGHBOR_LEFT_SIDE: TileAtlas.BIT_W,
	}
	for bit: int in side_map:
		td.set_terrain_peering_bit(bit,
			0 if (mask & side_map[bit]) else -1)
