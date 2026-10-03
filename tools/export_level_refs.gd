extends SceneTree

# 关卡参考图导出器 v0.66.0(用户令「程序化生成也导出一份 png,照着描摹、
# 在此基础上人工设计」):把每关 Solid / Decor 瓦片按分类图集直接 blit 合成
# 参考蓝图(不渲染实机画面,纯瓦片真值;出生点 / 终点门 / 记录点 / 提示牌
# 以色标标注)。产物 tools/level_refs/<act>_<s>.png 供人工描摹与评审,
# 不入 res:// 引用面(避免孤儿素材)。
#   godot --headless --path . --script res://tools/export_level_refs.gd
# 取色:data/palette.tres。清废纪律:本目录可随时整目录重建。

const OUT_DIR := "res://tools/level_refs"
const TILE := 100
const MAX_DIM := 4096.0

const INK := Color8(16, 18, 22)
const PAPER := Color8(237, 234, 224)
const RED := Color8(224, 73, 47)
const YELLOW := Color8(232, 179, 58)


func _initialize() -> void:
	var texs := {
		0: (load("res://assets/tiles/ground_tiles.png") as Texture2D).get_image(),
		1: (load("res://assets/tiles/platform_tiles.png") as Texture2D).get_image(),
		2: (load("res://assets/tiles/decor_tiles.png") as Texture2D).get_image(),
		3: (load("res://assets/tiles/special_tiles.png") as Texture2D).get_image(),
	}
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var n := LevelData.campaign_last() + 1
	var fails := 0
	for i in n:
		var path := LevelData.scene_path(i)
		var scene: PackedScene = load(path)
		if scene == null:
			print("REF FAIL: load ", path)
			fails += 1
			continue
		var lvl: NativeLevel = scene.instantiate()
		var act := path.get_base_dir().get_file()
		var lv := path.get_file().get_basename()
		fails += _render(lvl, texs, "%s/%s_%s.png" % [OUT_DIR, act, lv],
			LevelData.scene_name(i))
		lvl.free()
	print("REFS %s (%d levels)" % [
		"ALL PASS" if fails == 0 else "FAIL", n])
	quit(0 if fails == 0 else 1)


func _render(lvl: NativeLevel, texs: Dictionary, out: String,
		title: String) -> int:
	var solid := lvl.get_node_or_null("Solid") as TileMapLayer
	var decor := lvl.get_node_or_null("Decor") as TileMapLayer
	if solid == null:
		print("REF FAIL %s: 无 Solid 层" % out)
		return 1
	var lo := Vector2i(0, 0)
	var hi := Vector2i(0, 0)
	for layer: TileMapLayer in [decor, solid]:
		if layer == null:
			continue
		for c: Vector2i in layer.get_used_cells():
			lo = lo.min(c)
			hi = hi.max(c)
	var cells := hi - lo + Vector2i.ONE
	var img := Image.create_empty(cells.x * TILE, cells.y * TILE, false,
		Image.FORMAT_RGBA8)
	img.fill(INK)
	for layer: TileMapLayer in [decor, solid]:
		if layer == null:
			continue
		for c: Vector2i in layer.get_used_cells():
			var src := layer.get_cell_source_id(c)
			if not texs.has(src):
				continue
			var atlas := layer.get_cell_atlas_coords(c)
			var region := Rect2i(atlas.x * TILE, atlas.y * TILE, TILE, TILE)
			var tile := (texs[src] as Image).get_region(region)
			var at := (c - lo) * TILE
			img.blend_rect(tile, Rect2i(Vector2i.ZERO, Vector2i(TILE, TILE)), at)
	# 组件色标:出生=几何体色块 / 门=纸色框 / 记录点=黄菱形 / 提示=纸十字
	for child in lvl.get_children():
		if child is Node2D:
			_marker(img, (child as Node2D).position - Vector2(lo * TILE),
				child)
	var scale := minf(1.0, MAX_DIM / float(maxi(img.get_width(), img.get_height())))
	if scale < 1.0:
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale),
			Image.INTERPOLATE_NEAREST)
	var err := img.save_png(out)
	print("REF %s %dx%d err=%d %s" % [out, img.get_width(), img.get_height(),
		err, title])
	return 0 if err == OK else 1


func _marker(img: Image, at: Vector2, node: Node) -> void:
	var p := Vector2i(int(at.x), int(at.y))
	if node is SpawnMarker:
		var idx := (node as SpawnMarker).geo_index
		var col: Color = [RED, YELLOW, Color8(78, 134, 216)][clampi(idx, 0, 2)]
		_square(img, p, 22, col)
	elif node is ExitDoor:
		_ring(img, p, 26, PAPER)
	elif node is CheckpointBeacon:
		_diamond(img, p, 18, YELLOW)
	elif node is HintMarker:
		_cross(img, p, 12, PAPER)


func _square(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for y in range(c.y - r, c.y + r):
		for x in range(c.x - r, c.x + r):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)


func _ring(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for a in 360:
		var rad := deg_to_rad(a)
		var p := c + Vector2i(int(cos(rad) * r), int(sin(rad) * r))
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			img.set_pixel(p.x, p.y, col)


func _diamond(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		var w := r - absi(dy)
		for dx in range(-w, w + 1):
			var p := c + Vector2i(dx, dy)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixel(p.x, p.y, col)


func _cross(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for d in range(-r, r + 1):
		for p: Vector2i in [c + Vector2i(d, 0), c + Vector2i(0, d)]:
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixel(p.x, p.y, col)
