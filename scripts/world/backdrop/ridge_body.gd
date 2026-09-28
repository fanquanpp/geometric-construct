extends Node2D

# 动态生成豁免:山脊折线由种子程序生成,子节点(Polygon2D/Line2D)运行时组装(R1)。

const TILE_W := 2600.0

@export var base_y := 1000.0
@export var color := Color("1A1E26")
@export var ridge_seed := 1
@export var amplitude := 120.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = ridge_seed

	var n := 9
	var seg := TILE_W / float(n)
	var pts := PackedVector2Array()
	for i in n:
		var x := i * seg
		var y := base_y - rng.randf_range(0.15, 1.0) * amplitude
		pts.append(Vector2(x, y))
	pts.append(Vector2(TILE_W, pts[0].y))

	var poly_pts := PackedVector2Array(pts)
	poly_pts.append(Vector2(TILE_W, base_y + 3200.0))
	poly_pts.append(Vector2(0, base_y + 3200.0))

	var poly := Polygon2D.new()
	poly.polygon = poly_pts
	poly.color = color
	add_child(poly)

	var line := Line2D.new()
	line.points = pts
	line.width = 1.5
	line.default_color = Color(Palette.I.paper, 0.05)
	add_child(line)
