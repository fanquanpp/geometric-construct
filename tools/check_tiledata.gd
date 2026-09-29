extends SceneTree
func _initialize() -> void:
	var ts: TileSet = load("res://data/tiles/native_tileset.tres")
	var src: TileSetAtlasSource = ts.get_source(ts.get_source_id(0))
	for coords: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(12, 4), Vector2i(12, 1)]:
		var td := src.get_tile_data(coords, 0)
		if td == null:
			print(coords, " no tile")
			continue
		var parts := []
		for i in td.get_collision_polygons_count(0):
			var pts := td.get_collision_polygon_points(0, i)
			var oneway := td.is_collision_polygon_one_way(0, i)
			parts.append("%s pts=%s oneway=%s" % [i, pts, oneway])
		print(coords, " -> ", " | ".join(parts))
	quit(0)
