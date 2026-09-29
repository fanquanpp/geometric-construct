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
	if Engine.is_editor_hint():
		visible = false
		return
	z_index = -1
	_rebuild()


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
	draw_rect(r, Color(Palette.I.ink_3, decor_fill_alpha))
	var edge := Color(Palette.I.paper, 0.12)
	if _side_open(e, Vector2i(0, -1)):
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), edge)
	if _side_open(e, Vector2i(0, 1)):
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - 2),
			Vector2(r.size.x, 2)), edge)
	if _side_open(e, Vector2i(-1, 0)):
		draw_rect(Rect2(r.position, Vector2(2, r.size.y)), edge)
	if _side_open(e, Vector2i(1, 0)):
		draw_rect(Rect2(Vector2(r.end.x - 2, r.position.y),
			Vector2(2, r.size.y)), edge)


func _tick_columns(center: Vector2, col: Color) -> void:
	for k in 3:
		var x := center.x - 30.0 + k * 30.0
		draw_rect(Rect2(Vector2(x - 3, center.y - 40), Vector2(6, 80)),
			Color(col, 0.55))
		for t in 5:
			draw_rect(Rect2(Vector2(x - 9, center.y - 40 + t * 18),
				Vector2(12, 2)), Color(col, 0.85))


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
		draw_colored_polygon(pts,
			Color(Palette.I.ink_2, 1.0) if not oneway else Color(Palette.I.ink_3, 1.0))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(Palette.I.paper, feature_outline_alpha), 1.5, true)
		if oneway:
			var top := _poly_top_segment(polys[pi])
			draw_line(center + (top[0] as Vector2) + Vector2(0, 1.0),
				center + (top[1] as Vector2) + Vector2(0, 1.0),
				Color(Palette.I.paper, edge_alpha), 3.0)


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
		Vector2i(1, 0):
			draw_rect(r, Color(Palette.I.ink_2, 1.0))
			draw_rect(Rect2(center + Vector2(-16, -50), Vector2(32, 6)),
				Color(Palette.I.red, 0.85))
		_:
			draw_rect(r, Color(Palette.I.ink_2, 1.0))
	if _side_open(e, Vector2i(0, -1)):
		draw_rect(Rect2(r.position, Vector2(r.size.x, 10)),
			Color(Palette.I.paper, band_alpha))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)),
			Color(Palette.I.paper, edge_alpha))
	if _side_open(e, Vector2i(0, 1)):
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - 4),
			Vector2(r.size.x, 4)), Color(Palette.I.paper, 0.05))
	if _side_open(e, Vector2i(-1, 0)):
		draw_rect(Rect2(r.position, Vector2(2, r.size.y)),
			Color(Palette.I.paper, 0.12))
	if _side_open(e, Vector2i(1, 0)):
		draw_rect(Rect2(Vector2(r.end.x - 2, r.position.y),
			Vector2(2, r.size.y)), Color(Palette.I.paper, 0.12))
