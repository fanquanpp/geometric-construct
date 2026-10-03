extends SceneTree

# 新分类图集物理哨兵(v0.66.0):抽查四源关键形状的碰撞不变量。
#   godot --headless --path . --script res://tools/check_tiledata.gd
const FULL := [Vector2(-50, -50), Vector2(50, -50), Vector2(50, 50), Vector2(-50, 50)]


func _initialize() -> void:
	var ts: TileSet = load("res://data/tiles/native_tileset.tres")
	var fails := 0
	# 地面 source 0:任意变体必须整格物理
	var ground: TileSetAtlasSource = ts.get_source(0)
	for coord: Vector2i in [Vector2i(5, 1), Vector2i(0, 0), Vector2i(6, 4)]:
		fails += _expect_poly(ground, coord, FULL, false)
	# 平台 source 1:顶板单向
	var plat: TileSetAtlasSource = ts.get_source(1)
	fails += _expect_poly(plat, Vector2i(2, 0), [
		Vector2(-50, -50), Vector2(50, -50), Vector2(50, -26),
		Vector2(-50, -26)], true)
	# 装饰 source 2:必须零物理
	var decor: TileSetAtlasSource = ts.get_source(2)
	var dtd := decor.get_tile_data(Vector2i(0, 0), 0)
	if dtd.get_collision_polygons_count(0) != 0:
		print("DECOR FAIL (0,0): 有物理")
		fails += 1
	# 异形 source 3:坡 / 垂板
	var special: TileSetAtlasSource = ts.get_source(3)
	fails += _expect_poly(special, Vector2i(0, 0), [
		Vector2(-50, 50), Vector2(50, -50), Vector2(50, 50)], false)
	print("TILEDATA %s" % ("ALL PASS" if fails == 0 else "FAIL(%d)" % fails))
	quit(0 if fails == 0 else 1)


func _expect_poly(src: TileSetAtlasSource, coord: Vector2i,
		points: Array, oneway: bool) -> int:
	if not src.has_tile(coord):
		print("FAIL %s: 无瓦" % coord)
		return 1
	var td := src.get_tile_data(coord, 0)
	if td.get_collision_polygons_count(0) < 1:
		print("FAIL %s: 无物理" % coord)
		return 1
	var pts := td.get_collision_polygon_points(0, 0)
	if pts.size() != points.size():
		print("FAIL %s: 点数 %d != %d" % [coord, pts.size(), points.size()])
		return 1
	for i in points.size():
		if (pts[i] as Vector2).distance_squared_to(points[i]) > 0.01:
			print("FAIL %s: %s" % [coord, pts])
			return 1
	if td.is_collision_polygon_one_way(0, 0) != oneway:
		print("FAIL %s: oneway 应为 %s" % [coord, oneway])
		return 1
	return 0
