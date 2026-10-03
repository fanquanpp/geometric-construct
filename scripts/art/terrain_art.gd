@icon("res://assets/editor/terrain_art.svg")
@tool
class_name TerrainArt
extends Node2D


@export var edge_alpha := 0.50
@export var band_alpha := 0.16
@export var feature_outline_alpha := 0.35
@export var decor_fill_alpha := 0.50

var _decor: Array = []
var _solids: Array = []


func _ready() -> void:
	z_index = -1
	_rebuild()
	if Engine.is_editor_hint():
		# 所见即所得作关(v0.65.0):编辑器里实时渲染程序化地形,
		# 画瓦片即见成品;TileMapLayer 数据变更( painting /擦除 )随画随刷。
		var parent := get_parent()
		if parent != null:
			for child in parent.get_children():
				if child is TileMapLayer:
					(child as TileMapLayer).changed.connect(_rebuild)


func _rebuild() -> void:
	_decor.clear()
	_solids.clear()
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is TileMapLayer:
			_collect(child as TileMapLayer)
	queue_redraw()


func _collect(layer: TileMapLayer) -> void:
	var per := {}
	var decor_cells: Array = []
	var solid_cells: Array = []
	for c: Vector2i in layer.get_used_cells():
		var td := layer.get_cell_tile_data(c)
		if td == null:
			continue
		per[c] = true
		var entry := {
			"cell": c,
			"atlas": layer.get_cell_atlas_coords(c),
			"polys": _tile_polys(td),
			"oneway": _tile_oneways(td),
			"center": layer.map_to_local(c),
			"per": per,
		}
		if (entry["polys"] as Array).is_empty():
			decor_cells.append(entry)
		else:
			solid_cells.append(entry)
	if decor_cells.is_empty() and solid_cells.is_empty():
		return
	layer.visible = false
	if not decor_cells.is_empty():
		_decor.append(decor_cells)
	if not solid_cells.is_empty():
		_solids.append(solid_cells)


func _tile_polys(td: TileData) -> Array:
	var out: Array = []
	for i in td.get_collision_polygons_count(0):
		var pts := td.get_collision_polygon_points(0, i)
		if pts.size() >= 3:
			out.append(pts)
	return out


func _tile_oneways(td: TileData) -> Array:
	var out: Array = []
	for i in td.get_collision_polygons_count(0):
		out.append(td.is_collision_polygon_one_way(0, i))
	return out


func _draw() -> void:
	if Palette.I == null:
		return
	for cells: Array in _decor:
		for e: Dictionary in cells:
			_draw_decor(e)
	for cells: Array in _solids:
		for e: Dictionary in cells:
			_draw_solid(e)


func _side_open(e: Dictionary, dir: Vector2i) -> bool:
	var per: Dictionary = e["per"]
	return per.is_empty() or not per.has((e["cell"] as Vector2i) + dir)


func _draw_decor(e: Dictionary) -> void:
	var atlas: Vector2i = e["atlas"]
	var center: Vector2 = e["center"]
	var r := Rect2(center - Vector2(50, 50), Vector2(100, 100))
	match atlas:
		Vector2i(4, 2):
			DrawKit.brackets(self, r.grow(-8.0), Color(Palette.I.paper, 0.45), 20.0, 2.0)
		Vector2i(9, 2):
			DrawKit.ngon_line(self, center, 32.0, 12, Color(Palette.I.paper, 0.30), 2.0)
			DrawKit.ngon_line(self, center, 24.0, 12, Color(Palette.I.paper, 0.18), 1.0)
		Vector2i(10, 2):
			for k in 3:
				draw_rect(Rect2(r.position + Vector2(10, 26 + k * 20),
					Vector2(80, 8)), Color(Palette.I.paper, 0.16))
		Vector2i(1, 3):
			for k in 3:
				draw_rect(Rect2(r.position + Vector2(8, 30 + k * 16),
					Vector2(84, 6)), Color(Palette.I.red, 0.5))
		Vector2i(2, 3):
			draw_rect(Rect2(r.position, Vector2(30, 30)), Color(Palette.I.red, 0.55))
			draw_rect(Rect2(r.position, Vector2(30, 30)),
				Color(Palette.I.paper, 0.4), false, 1.0)
		Vector2i(14, 3):
			draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)),
				Color(Palette.I.red, 0.85))
		Vector2i(12, 7), Vector2i(13, 7), Vector2i(14, 7), Vector2i(15, 7):
			var cols := [Palette.I.red, Palette.I.yellow, Palette.I.blue, Palette.I.paper]
			_tick_columns(center, cols[clampi(atlas.x - 12, 0, 3)])
		_:
			_decor_panel(e, r)


func _decor_panel(e: Dictionary, r: Rect2) -> void:
	draw_rect(r, Color(Palette.I.paper, 0.06))
	var edge := Color(Palette.I.paper, 0.14)
	var pts := PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y),
		r.end, Vector2(r.position.x, r.end.y), r.position])
	draw_polyline(pts, edge, 1.5, true)


func _tick_columns(center: Vector2, col: Color) -> void:
	for k in 3:
		var x := center.x - 30.0 + k * 30.0
		draw_rect(Rect2(Vector2(x - 3, center.y - 40), Vector2(6, 80)),
			Color(col, 0.55))
		for t in 5:
			draw_rect(Rect2(Vector2(x - 9, center.y - 40 + t * 18),
				Vector2(12, 2)), Color(col, 0.85))


const FACE_FULL := Color("262b34")
const FACE_TOP := Color("2b3140")
const FACE_SHOULDER := Color("3a4254")
const FACE_SHOULDER_DIM := Color("313845")
const CEIL_BLUE := Color("4e86d8")


func _draw_solid(e: Dictionary) -> void:
	var polys: Array = e["polys"]
	var center: Vector2 = e["center"]
	var atlas: Vector2i = e["atlas"]
	if polys.is_empty():
		return
	if _is_full_square(polys):
		_draw_full_block(e, center, atlas)
		return
	var oneways: Array = e["oneway"]
	for pi in polys.size():
		var pts := PackedVector2Array()
		for p: Vector2 in polys[pi]:
			pts.append(center + p)
		var oneway: bool = pi < oneways.size() and oneways[pi]
		var bottom_ceiling := _is_bottom_poly(polys[pi])
		draw_colored_polygon(pts,
			FACE_TOP if oneway and not bottom_ceiling else FACE_FULL)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(Palette.I.paper, feature_outline_alpha), 1.5, true)
		var top := _poly_top_segment(polys[pi])
		if oneway and not bottom_ceiling:
			draw_line(center + (top[0] as Vector2) + Vector2(0, 1.0),
				center + (top[1] as Vector2) + Vector2(0, 1.0),
				Color(Palette.I.paper, 0.75), 4.0)
			# 单向板差分:下缘幽灵虚线 = 「自下可穿」的判定语言
			var obot := _poly_bottom_segment(polys[pi])
			draw_dashed_line(
				center + (obot[0] as Vector2) - Vector2(0, 2.0),
				center + (obot[1] as Vector2) - Vector2(0, 2.0),
				Color(Palette.I.paper, 0.22), 2.0, 10.0)
		if bottom_ceiling:
			var bot := _poly_bottom_segment(polys[pi])
			draw_line(center + (bot[0] as Vector2) - Vector2(0, 1.0),
				center + (bot[1] as Vector2) - Vector2(0, 1.0),
				Color(CEIL_BLUE, 0.65), 3.0)


func _is_full_square(polys: Array) -> bool:
	for pts: PackedVector2Array in polys:
		var lo := pts[0]
		var hi := pts[0]
		for p in pts:
			lo = lo.min(p)
			hi = hi.max(p)
		if absf(hi.x - lo.x - 100.0) < 2.0 and absf(hi.y - lo.y - 100.0) < 2.0:
			return true
	return false


func _is_bottom_poly(pts: PackedVector2Array) -> bool:
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return lo.y > 20.0


func _poly_bottom_segment(pts: PackedVector2Array) -> Array:
	var worst_y := -INF
	for p in pts:
		worst_y = maxf(worst_y, p.y)
	var xs: Array = []
	for p in pts:
		if absf(p.y - worst_y) < 1.0:
			xs.append(p.x)
	xs.sort()
	return [Vector2(xs[0], worst_y), Vector2(xs[xs.size() - 1], worst_y)]


func _poly_top_segment(pts: PackedVector2Array) -> Array:
	var best_y := INF
	for p in pts:
		best_y = minf(best_y, p.y)
	var xs: Array = []
	for p in pts:
		if absf(p.y - best_y) < 1.0:
			xs.append(p.x)
	xs.sort()
	return [Vector2(xs[0], best_y), Vector2(xs[xs.size() - 1], best_y)]


func _draw_full_block(e: Dictionary, center: Vector2, atlas: Vector2i) -> void:
	var r := Rect2(center - Vector2(50, 50), Vector2(100, 100))
	match atlas:
		Vector2i(4, 0):
			draw_rect(r, Color(Palette.I.red, 0.85))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 8)),
				Color(Palette.I.paper, 0.35))
			draw_rect(Rect2(r.position.x, r.end.y - 10, r.size.x, 10),
				Color(Palette.I.ink, 0.30))
			return
		Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1):
			draw_rect(r, Color(Palette.I.ink_2, 1.0))
			draw_rect(Rect2(Vector2(r.position.x, r.end.y - 3.0),
				Vector2(r.size.x, 3)), Color(CEIL_BLUE, 0.65))
			draw_rect(Rect2(r.position.x, r.end.y - 10.0,
				r.size.x, 7.0), Color(FACE_SHOULDER_DIM, 1.0))
			return
		Vector2i(1, 0):
			draw_rect(r, FACE_FULL)
			draw_rect(Rect2(center + Vector2(-16, -50), Vector2(32, 6)),
				Color(Palette.I.red, 0.85))
		_:
			draw_rect(r, FACE_FULL)
	if _side_open(e, Vector2i(0, -1)):
		var slab := minf(100.0 * 0.4, 22.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x, slab)),
			Color(FACE_SHOULDER, 1.0))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)),
			Color(Palette.I.paper, edge_alpha))
		_red_rules(r)
		_color_accent(e, r)
	if _side_open(e, Vector2i(0, 1)):
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - 4),
			Vector2(r.size.x, 4)), Color(Palette.I.paper, 0.05))
	if _side_open(e, Vector2i(-1, 0)):
		draw_rect(Rect2(r.position, Vector2(2, r.size.y)),
			Color(Palette.I.paper, 0.12))
	if _side_open(e, Vector2i(1, 0)):
		draw_rect(Rect2(Vector2(r.end.x - 2, r.position.y),
			Vector2(2, r.size.y)), Color(Palette.I.paper, 0.12))
	_skirt(e, r)


## 角色色点缀(v0.60.0,用户令「地块可以和几何体一样的色彩装饰,
## 不要喧宾夺主」):约 1/9 的承重面、按格坐标确定性取红/黄/蓝,
## 顶缘下方一道 2px 短线(30% 宽、α0.28),远观无痕、近读有色。
func _color_accent(e: Dictionary, r: Rect2) -> void:
	var h := hash(Vector2i(r.position))
	if h % 9 != 0:
		return
	var cols: Array[Color] = [Palette.I.red, Palette.I.yellow, Palette.I.blue]
	var c: Color = cols[(h / 9) % 3]
	var aw := r.size.x * 0.30
	var ax := r.position.x + 6.0 + float((h / 9) % 23)
	ax = minf(ax, r.end.x - 4.0 - aw)
	draw_rect(Rect2(ax, r.position.y + 4.0, aw, 2.0), Color(c, 0.28))


func _red_rules(r: Rect2) -> void:
	var wx := r.position.x
	var k := ceilf(wx / 480.0)
	var mark_x := k * 480.0
	while mark_x < wx + r.size.x:
		var lx := mark_x - wx
		if lx >= 0.0 and lx <= r.size.x - 14.0:
			draw_rect(Rect2(Vector2(lx, r.position.y), Vector2(14, 3)),
				Color(Palette.I.red, 0.55))
		k += 1.0
		mark_x = k * 480.0


func _skirt(e: Dictionary, r: Rect2) -> void:
	var down := not _side_open(e, Vector2i(0, 1))
	if not down:
		return
	var f := 16.0
	var by := r.end.y
	if _side_open(e, Vector2i(-1, 0)):
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.position.x, by - f), Vector2(r.position.x, by),
			Vector2(r.position.x - f, by)]), Color(FACE_FULL, 1.0))
	if _side_open(e, Vector2i(1, 0)):
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.end.x, by - f), Vector2(r.end.x, by),
			Vector2(r.end.x + f, by)]), Color(FACE_FULL, 1.0))
