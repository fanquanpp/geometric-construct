extends SceneTree


func _initialize() -> void:
	var ts: TileSet = load("res://data/tiles/native_tileset.tres")
	var usage := {}
	var files := _list_tscn("res://levels_native")
	for fp: String in files:
		var ps: PackedScene = load(fp)
		if ps == null:
			continue
		var root := ps.instantiate()
		_walk(root, fp, usage)
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
	quit(0)


func _walk(n: Node, fp: String, usage: Dictionary) -> void:
	if n is TileMapLayer:
		var layer := n as TileMapLayer
		var sid := layer.tile_set.get_source_id(0)
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
