class_name TerrainKit


const SURFACE_MISS := INF

# 列索引缓存(v0.66.0 正面增益):floor/ceil 查询由「逐层全格扫描」改为
# 「按列桶直取」——建索引一次 O(全格),查询 O(该列格数)。层体 TileMapLayer
# changed 信号(画瓦 / 擦瓦 / 场景数据变更)置脏,帧末一次性合并重建
# (同帧 N 次画瓦只重建一次索引,progen/编辑器批量作关不抖);查询路径
# 遇脏即时重建保证运行期真值。运行期无画瓦者(progen 落盘后静态关卡)
# 行为不变,native_check 兜底。层释放后弱引用失效自动弃缓存。
static var _col_cache := {}   # layer 实例 id -> {"layer": WeakRef, "cols": Dictionary}
static var _dirty := {}       # layer 实例 id -> true(changed 置脏,待合并重建)
static var _rebuilt_at := {}  # layer 实例 id -> 最近重建的 process_frame(同帧只重建一次)


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


static func _cols_of(layer: TileMapLayer) -> Dictionary:
	var key := layer.get_instance_id()
	var entry: Dictionary = _col_cache.get(key, {})
	if not entry.is_empty() and (entry["layer"] as WeakRef).get_ref() == layer:
		if not _dirty.has(key):
			return entry["cols"]
		var fr := Engine.get_process_frames()
		if int(_rebuilt_at.get(key, -1)) == fr:
			# 同帧已重建过:画瓦风暴中先用现行索引顶住,帧末合并兜底。
			return entry["cols"]
		_rebuilt_at[key] = fr
		_dirty.erase(key)
		_fill_cols(layer, entry["cols"])
		return entry["cols"]
	_dirty.erase(key)
	var cols := {}
	_fill_cols(layer, cols)
	_col_cache[key] = {"layer": weakref(layer), "cols": cols}
	var bound := _on_layer_changed.bind(key)
	if not layer.changed.is_connected(bound):
		layer.changed.connect(bound)
	return cols


static func _fill_cols(layer: TileMapLayer, cols: Dictionary) -> void:
	cols.clear()
	var ts := 100.0
	if layer.tile_set != null:
		ts = maxf(float(layer.tile_set.tile_size.x), 1.0)
	for c: Vector2i in layer.get_used_cells():
		var td := layer.get_cell_tile_data(c)
		if td == null or not _has_phys(td):
			continue
		var center: Vector2 = layer.map_to_local(c)
		var left: float = center.x - ts * 0.5
		cols.get_or_add(int(floorf(left / ts)), []).append({
			"top": center.y - ts * 0.5,
			"bottom": center.y + ts * 0.5,
		})


static func _on_layer_changed(key: int) -> void:
	if _dirty.has(key):
		return
	_dirty[key] = true
	var entry: Dictionary = _col_cache.get(key, {})
	if entry.is_empty():
		return
	var layer := (entry["layer"] as WeakRef).get_ref() as TileMapLayer
	if layer == null or not is_instance_valid(layer):
		return
	if not layer.is_inside_tree():
		return  # 层体正在移树/释放(get_tree 会打引擎错误),无帧末可排;查询路径兜底
	var tree := layer.get_tree()
	# 帧末合并重建:同帧 N 次画瓦只排定一次(process_frame 一次性连接)。
	var merge := func() -> void: _merge_dirty(key)
	tree.process_frame.connect(merge, CONNECT_ONE_SHOT)


static func _merge_dirty(key: int) -> void:
	if not _dirty.has(key):
		return  # 查询路径已先重建
	_dirty.erase(key)
	var entry: Dictionary = _col_cache.get(key, {})
	if entry.is_empty():
		return
	var layer := (entry["layer"] as WeakRef).get_ref() as TileMapLayer
	if layer == null or not is_instance_valid(layer):
		_col_cache.erase(key)
		_rebuilt_at.erase(key)
		return
	_rebuilt_at[key] = Engine.get_process_frames()
	_fill_cols(layer, entry["cols"])


static func _column_at(layer: TileMapLayer, cols: Dictionary, x: float) -> Array:
	var ts := 100.0
	if layer.tile_set != null:
		ts = maxf(float(layer.tile_set.tile_size.x), 1.0)
	return cols.get(int(floorf(x / ts)), [])


static func _layer_floor_top(layer: TileMapLayer, x: float, y: float,
		drop: float) -> float:
	var best := SURFACE_MISS
	for e: Dictionary in _column_at(layer, _cols_of(layer), x):
		var top: float = e["top"]
		if top < y - 2.0 or top > y + drop:
			continue
		best = minf(best, top)
	return best


static func _layer_ceil_bottom(layer: TileMapLayer, x: float, y: float,
		rise: float) -> float:
	var best := -SURFACE_MISS
	for e: Dictionary in _column_at(layer, _cols_of(layer), x):
		var bottom: float = e["bottom"]
		if bottom > y + 2.0 or bottom < y - rise:
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
