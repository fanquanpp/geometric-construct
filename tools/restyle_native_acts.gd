extends SceneTree


const SCENES := [
	"res://levels_native/act2/s02.tscn", "res://levels_native/act2/s03.tscn",
	"res://levels_native/act2/s04.tscn", "res://levels_native/act2/s05.tscn",
	"res://levels_native/act2/s06.tscn",
	"res://levels_native/act3/s01.tscn", "res://levels_native/act3/s02.tscn",
	"res://levels_native/act3/s03.tscn", "res://levels_native/act3/s04.tscn",
	"res://levels_native/act3/s05.tscn",
	"res://levels_native/act4/s01.tscn", "res://levels_native/act4/s02.tscn",
	"res://levels_native/act4/s03.tscn", "res://levels_native/act4/s04.tscn",
	"res://levels_native/act4/s05.tscn",
	"res://levels_native/act5/s01.tscn", "res://levels_native/act5/s02.tscn",
	"res://levels_native/act5/s03.tscn", "res://levels_native/act5/s04.tscn",
]

const ACT_FOCUS := {2: Vector2i(13, 7), 3: Vector2i(14, 7), 4: Vector2i(12, 7), 5: Vector2i(15, 7)}

const FAM := Vector2i(0, 4)
const DARK_PLATES := [Vector2i(0, 2), Vector2i(4, 2), Vector2i(9, 2), Vector2i(10, 2)]
const RED_MARKS := [Vector2i(2, 3), Vector2i(14, 3), Vector2i(1, 3)]


func _initialize() -> void:
	for path: String in SCENES:
		_restyle(path)
	quit(0)


func _restyle(path: String) -> void:
	var sc: PackedScene = load(path)
	if sc == null:
		print("LOAD FAIL ", path)
		return
	var root: Node = sc.instantiate()
	if root.get_script() == null:

		root.set_script(load("res://scripts/world/native_level.gd"))
		print("  script repaired")
	var solid := root.get_node_or_null("Solid") as TileMapLayer
	var decor := root.get_node_or_null("Decor") as TileMapLayer
	if solid == null:
		print("NO SOLID ", path)
		root.free()
		return
	var seed_v: int = hash(path)
	var upgraded := 0
	var cells := solid.get_used_cells()
	var has := {}
	for c: Vector2i in cells:
		has[c] = true
	for c: Vector2i in cells:
		var n := has.has(c + Vector2i(0, -1))
		var e := has.has(c + Vector2i(1, 0))
		var s := has.has(c + Vector2i(0, 1))
		var w := has.has(c + Vector2i(-1, 0))
		var atlas := _variant(n, e, s, w,
			has.has(c + Vector2i(-1, -1)), has.has(c + Vector2i(1, -1)),
			has.has(c + Vector2i(-1, 1)), has.has(c + Vector2i(1, 1)))
		if atlas != Vector2i(0, 0):
			solid.set_cell(c, solid.get_cell_source_id(c), atlas)
			upgraded += 1
	var painted := 0
	if decor != null:
		painted = _paint_decor(path, solid, decor, seed_v, root)
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, path)
	print(("OK  " if err == OK else "SAVE FAIL ") , path, " solid=", cells.size(),
		" upgraded=", upgraded, " decor=", painted)
	root.free()


func _variant(n: bool, e: bool, s: bool, w: bool, nw: bool, ne: bool, sw: bool, se: bool) -> Vector2i:
	var en := not n
	var ee := not e
	var es := not s
	var ew := not w
	var cnt := int(en) + int(ee) + int(es) + int(ew)
	if cnt == 0:

		if not nw:
			return FAM + Vector2i(0, 3)
		if not ne:
			return FAM + Vector2i(1, 3)
		if not sw:
			return FAM + Vector2i(2, 3)
		if not se:
			return FAM + Vector2i(3, 3)
		return FAM + Vector2i(1, 1)
	if cnt == 4:
		return FAM + Vector2i(3, 0)
	if en and ee and es:
		return FAM + Vector2i(2, 0)
	if en and ee and ew:
		return FAM + Vector2i(2, 0)
	if en and es and ew:
		return FAM + Vector2i(0, 0)
	if ee and es and ew:
		return FAM + Vector2i(2, 2)
	if en and ee:
		return FAM + Vector2i(2, 0)
	if en and ew:
		return FAM + Vector2i(0, 0)
	if es and ee:
		return FAM + Vector2i(2, 2)
	if es and ew:
		return FAM + Vector2i(0, 2)
	if en and es:
		return FAM + Vector2i(3, 1)
	if ee and ew:
		return FAM + Vector2i(3, 2)
	if en:
		return FAM + Vector2i(1, 0)
	if ee:
		return FAM + Vector2i(2, 1)
	if es:
		return FAM + Vector2i(1, 2)
	return FAM + Vector2i(0, 1)


func _paint_decor(path: String, solid: TileMapLayer, decor: TileMapLayer,
		seed_v: int, root: Node) -> int:
	var act: int = int(path.substr(path.find("/act") + 4, 1))
	var runs: Array = []
	var cells := solid.get_used_cells()
	var top := {}
	for c: Vector2i in cells:
		if solid.get_cell_source_id(c + Vector2i(0, -1)) == -1:
			top[c] = true

	var by_row := {}
	for c: Vector2i in top.keys():
		if not by_row.has(c.y):
			by_row[c.y] = []
		(by_row[c.y] as Array).append(c.x)
	for y: int in by_row.keys():
		var xs: Array = by_row[y]
		xs.sort()
		var run_start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size() + 1):
			if i < xs.size() and xs[i] == prev + 1:
				prev = xs[i]
				continue
			runs.append([prev - run_start + 1, Vector2i(run_start, y)])
			if i < xs.size():
				run_start = xs[i]
				prev = xs[i]
	runs.sort_custom(func(a, b): return a[0] > b[0])
	if runs.is_empty():
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var painted := 0
	var free_check := func(c: Vector2i) -> bool:
		return decor.get_cell_source_id(c) == -1

	var main: Array = runs[0]
	var focus_c: Vector2i = Vector2i((main[1] as Vector2i).x + (main[0] as int) / 2,
		(main[1] as Vector2i).y - 3)
	var focus_atlas: Vector2i = ACT_FOCUS.get(act, Vector2i(15, 7))
	if free_check.call(focus_c):
		decor.set_cell(focus_c, 0, focus_atlas)
		painted += 1

	if runs.size() > 1 and (runs[1][0] as int) >= 4:
		var rc: Vector2i = Vector2i((runs[1][1] as Vector2i).x + (runs[1][0] as int) / 2,
			(runs[1][1] as Vector2i).y - 2)
		if free_check.call(rc):
			decor.set_cell(rc, 0, RED_MARKS[rng.randi() % RED_MARKS.size()])
			painted += 1

	var plate_i := rng.randi() % DARK_PLATES.size()
	for ri in [2, 3]:
		if runs.size() > ri and (runs[ri][0] as int) >= 3:
			var dc: Vector2i = Vector2i((runs[ri][1] as Vector2i).x + (runs[ri][0] as int) / 2,
				(runs[ri][1] as Vector2i).y - 2)
			if free_check.call(dc):
				decor.set_cell(dc, 0, DARK_PLATES[(plate_i + ri) % DARK_PLATES.size()])
				painted += 1
	return painted
