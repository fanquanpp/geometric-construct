extends Node2D

# 星阵由种子程序生成,数量形态运行时确定(procedural-art)。

const TILE := Vector2(2600, 1300)
var _stars: Array = []
var _t := 0.0
var _acc := 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 470913
	for i in 120:
		_stars.append(_mk_star(rng, Vector2(
			rng.randf_range(0.0, TILE.x), rng.randf_range(0.0, TILE.y)),
			rng.randf_range(0.08, 0.30), rng))

	for i in 130:
		var x := rng.randf_range(0.0, TILE.x)
		var cy := 950.0 - x * (600.0 / 2600.0)
		var y := cy + (rng.randf_range(-1.0, 1.0)
			+ rng.randf_range(-1.0, 1.0)) * 75.0
		_stars.append(_mk_star(rng, Vector2(x, y),
			rng.randf_range(0.05, 0.13), rng, true))

	for i in 2:
		var x := 380.0 + i * 1180.0
		var cy := 950.0 - x * (600.0 / 2600.0)
		var quad := PackedVector2Array([
			Vector2(x, cy), Vector2(x + 300.0, cy - 46.0),
			Vector2(x + 430.0, cy + 42.0), Vector2(x + 130.0, cy + 88.0),
		])
		_stars.append({"quad": quad,
			"col": Color(Palette.I.paper, 0.016 + i * 0.006),
			"cross": false, "quad_a": true})

	for i in 6:
		var p := Vector2(rng.randf_range(100.0, TILE.x - 100.0),
			rng.randf_range(100.0, TILE.y - 100.0))
		var col := Color(Palette.I.blue, 0.30) if i == 0 \
			else Color(Palette.I.paper, rng.randf_range(0.20, 0.34))
		_stars.append({"pos": p, "size": rng.randf_range(4.0, 6.0),
			"col": col, "spd": rng.randf_range(0.4, 0.9),
			"ph": rng.randf_range(0.0, TAU), "cross": true})

func _mk_star(rng: RandomNumberGenerator, pos: Vector2, a: float,
		rng2: RandomNumberGenerator, band := false) -> Dictionary:
	var col := Color(Palette.I.paper, a)
	if not band and rng2.randf() < 0.08:
		col = Color(Palette.I.blue, a * 0.9)
	return {"pos": pos, "size": rng.randf_range(1.0, 2.2),
		"col": col, "spd": rng.randf_range(0.25, 0.8),
		"ph": rng.randf_range(0.0, TAU), "cross": false}

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= 0.125:
		_acc = 0.0
		queue_redraw()

func _draw() -> void:
	for st in _stars:
		if st.has("quad_a"):
			draw_colored_polygon(st["quad"], st["col"])
			continue
		var tw: float = st["col"].a * (0.75 + 0.25 \
			* sin(_t * st["spd"] * TAU + st["ph"]))
		var c := Color(st["col"].r, st["col"].g, st["col"].b, tw)
		if st["cross"]:
			var s: float = st["size"]
			draw_line(st["pos"] + Vector2(-s, 0), st["pos"] + Vector2(s, 0), c, 1.2)
			draw_line(st["pos"] + Vector2(0, -s), st["pos"] + Vector2(0, s), c, 1.2)
		else:
			draw_rect(Rect2(st["pos"] - Vector2(st["size"], st["size"]) / 2.0,
				Vector2(st["size"], st["size"])), c)
