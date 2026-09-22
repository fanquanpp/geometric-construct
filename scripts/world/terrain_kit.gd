class_name TerrainKit


static func mech_layout(spr: Sprite2D, tex: Texture2D, zone: Rect2) -> void:
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var used: Rect2 = Rect2(img.get_used_rect())
	spr.texture = tex
	spr.centered = false
	spr.scale = zone.size / used.size
	spr.position = zone.position - used.position * spr.scale


static func draw_focus(c: CanvasItem, r: Rect2, col: Color) -> void:
	if col.a <= 0.0:
		return
	var pl := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
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
