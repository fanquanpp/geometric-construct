extends SceneTree

# 瓦片使用量 + Decor 可见性核查(v0.70 tiles 波扩展)。三类明细供
# levels 包修复后复跑归零(本工具只读,不改任何场景):
#   ① Decor⊕Solid 同格重叠(Decor z=0 < Solid z=1,同格装饰被地形盖住)
#   ② Decor 越出 Solid 包围盒 / 越出边界墙([0, level_size) 网格域)
#   ③ 空瓦微瓦:atlas 槽不透明像素占比 <5% 且未豁免
#   godot --headless --path . --script res://tools/dump_tile_usage.gd
const TILE := 100.0
const MIN_COVERAGE := 0.05


func _initialize() -> void:
	var ts: TileSet = load("res://data/tiles/native_tileset.tres")
	var usage := {}
	var files := _list_tscn("res://levels_native")
	var overlap_n := 0
	var oob_n := 0
	var micro_n := 0
	var level_n := 0
	var coverage := _decor_slot_coverage()
	for fp: String in files:
		var ps: PackedScene = load(fp)
		if ps == null:
			continue
		var root := ps.instantiate()
		level_n += 1
		_walk(root, fp, usage)
		var hits := _audit_decor_visibility(root, fp, coverage)
		overlap_n += hits["overlap"]
		oob_n += hits["oob"]
		micro_n += hits["micro"]
		root.free()
	var keys := usage.keys()
	keys.sort()
	print("=== solid-ish (has layer0 physics) ===")
	for k: Vector2i in keys:
		if usage[k]["phys"]:
			print("%s x%d" % [k, usage[k]["n"]])
	print("=== decor (no layer0 physics) ===")
	for k: Vector2i in keys:
		if not usage[k]["phys"]:
			print("%s x%d" % [k, usage[k]["n"]])
	print("=== decor visibility (%d levels) ===" % level_n)
	print("overlap(Decor vs Solid same-cell)=%d oob(outside solid bbox/walls)=%d micro(<%d%% opaque, unexempted)=%d"
		% [overlap_n, oob_n, int(MIN_COVERAGE * 100.0), micro_n])
	print("DECOR-VIS %s" % ("ALL CLEAN" if overlap_n + oob_n + micro_n == 0
		else "FAIL(%d)" % (overlap_n + oob_n + micro_n)))
	quit(0)


## Decor 可见性三类审查(只读)。返回 {overlap, oob, micro} 计数,
## 明细逐格打印(关名+格坐标+判据)。
func _audit_decor_visibility(root: Node, fp: String, coverage: Dictionary) -> Dictionary:
	var out := {"overlap": 0, "oob": 0, "micro": 0}
	var solid := root.get_node_or_null("Solid") as TileMapLayer
	var decor := root.get_node_or_null("Decor") as TileMapLayer
	if decor == null:
		return out
	var solid_cells := {}
	var lo := Vector2i(Vector2.INF)
	var hi := Vector2i(-Vector2.INF)
	if solid != null:
		for c: Vector2i in solid.get_used_cells():
			solid_cells[c] = true
			lo = lo.min(c)
			hi = hi.max(c)
	var wall_right := -1
	var wall_bottom := -1
	var size_v: Variant = root.get("level_size")
	if size_v is Vector2:
		wall_right = ceili((size_v as Vector2).x / TILE) - 1
		wall_bottom = ceili((size_v as Vector2).y / TILE) - 1
	for c: Vector2i in decor.get_used_cells():
		var atlas := decor.get_cell_atlas_coords(c)
		var tag := "%s Decor%s(atlas %s)" % [fp, c, atlas]
		if solid_cells.has(c):
			print("  OVERLAP %s: 与 Solid 同格,装饰被地形覆盖" % tag)
			out["overlap"] += 1
		var oob := false
		if solid != null and not solid_cells.is_empty():
			oob = c.x < lo.x or c.x > hi.x or c.y < lo.y or c.y > hi.y
			if oob:
				print("  OOB %s: 越出 Solid 包围盒 %s..%s" % [tag, lo, hi])
		if wall_right >= 0 and (c.x < 0 or c.x > wall_right
				or c.y < 0 or c.y > wall_bottom):
			print("  OOB %s: 越出边界墙网格 [0,%d]x[0,%d]"
				% [tag, wall_right, wall_bottom])
			out["oob"] += 1
		elif oob:
			out["oob"] += 1
		var cov: float = coverage.get(atlas, -1.0)
		if cov >= 0.0 and cov < MIN_COVERAGE \
				and not TileAtlas.DECOR_COVERAGE_EXEMPT.has(atlas):
			print("  MICRO %s: 槽不透明占比 %.1f%% < %d%%"
				% [tag, cov * 100.0, int(MIN_COVERAGE * 100.0)])
			out["micro"] += 1
	return out


## decor_tiles.png 逐槽不透明像素占比(Image 直读源文件,不经 import 缓存)。
func _decor_slot_coverage() -> Dictionary:
	var out := {}
	var img := Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/tiles/decor_tiles.png"))
	if img == null:
		print("DECOR-VIS: decor_tiles.png 读取失败,微瓦检查跳过")
		return out
	var tw := 100
	for sy in range(img.get_height() / tw):
		for sx in range(img.get_width() / tw):
			var opaque := 0
			for yy in range(tw):
				for xx in range(tw):
					if img.get_pixel(sx * tw + xx, sy * tw + yy).a > 0.0:
						opaque += 1
			out[Vector2i(sx, sy)] = float(opaque) / float(tw * tw)
	return out


func _walk(n: Node, fp: String, usage: Dictionary) -> void:
	if n is TileMapLayer:
		var layer := n as TileMapLayer
		for c: Vector2i in layer.get_used_cells():
			var td := layer.get_cell_tile_data(c)
			if td == null:
				continue
			var atlas := layer.get_cell_atlas_coords(c)
			var key := atlas
			if not usage.has(key):
				usage[key] = {"n": 0, "phys": _has_phys(td)}
			usage[key]["n"] += 1
			if _has_phys(td):
				usage[key]["phys"] = true
	for ch in n.get_children():
		_walk(ch, fp, usage)


func _has_phys(td: TileData) -> bool:
	for l in td.get_collision_polygons_count(0):
		if td.get_collision_polygon_points(0, l).size() >= 3:
			return true
	return false


func _list_tscn(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir + "/" + f
		if d.current_is_dir():
			out.append_array(_list_tscn(p))
		elif f.ends_with(".tscn"):
			out.append(p)
		f = d.get_next()
	return out
