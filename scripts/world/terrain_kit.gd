class_name TerrainKit


const SURFACE_MISS := INF


static func floor_top_at(root: Node, x: float, y: float, drop := 320.0) -> float:
	var best := SURFACE_MISS
	for child in root.get_children():
		if child is TileMapLayer:
			best = minf(best, _layer_floor_top(child as TileMapLayer, x, y, drop))
	return best


static func ceil_bottom_at(root: Node, x: float, y: float, rise := 320.0) -> float:
	var best := -SURFACE_MISS
	for child in root.get_children():
		if child is TileMapLayer:
			best = maxf(best, _layer_ceil_bottom(child as TileMapLayer, x, y, rise))
	return best


static func _has_phys(td: TileData) -> bool:
	for i in td.get_collision_polygons_count(0):
		if td.get_collision_polygon_points(0, i).size() >= 3:
			return true
	return false


static func _layer_floor_top(layer: TileMapLayer, x: float, y: float,
		drop: float) -> float:
	var best := SURFACE_MISS
	for c: Vector2i in layer.get_used_cells():
		var td := layer.get_cell_tile_data(c)
		if td == null or not _has_phys(td):
			continue
		var top: float = layer.map_to_local(c).y - 50.0
		if top < y - 2.0 or top > y + drop:
			continue
		var left: float = layer.map_to_local(c).x - 50.0
		if x < left or x > left + 100.0:
			continue
		best = minf(best, top)
	return best


static func _layer_ceil_bottom(layer: TileMapLayer, x: float, y: float,
		rise: float) -> float:
	var best := -SURFACE_MISS
	for c: Vector2i in layer.get_used_cells():
		var td := layer.get_cell_tile_data(c)
		if td == null or not _has_phys(td):
			continue
		var bottom: float = layer.map_to_local(c).y + 50.0
		if bottom > y + 2.0 or bottom < y - rise:
			continue
		var left: float = layer.map_to_local(c).x - 50.0
		if x < left or x > left + 100.0:
			continue
		best = maxf(best, bottom)
	return best


static func draw_focus(c: CanvasItem, r: Rect2, col: Color) -> void:
	if col.a <= 0.0:
		return
	var pl := 0.7 if SettingsManager.reduced_motion \
		else 0.55 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	c.draw_rect(r.grow(3.0), Color(col.r, col.g, col.b, col.a * pl), false, 2.0)


static func rect_occluder(r: Rect2) -> LightOccluder2D:
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y),
		r.end, Vector2(r.position.x, r.end.y)])
	poly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
	occ.occluder = poly
	return occ


static func ramp_bounds(pts: PackedVector2Array, base_y: float) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo + Vector2(0, base_y - lo.y))
