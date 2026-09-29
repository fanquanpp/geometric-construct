extends Node2D

# 山脊折线由种子程序生成,子节点(Polygon2D/Line2D)运行时组装(procedural-art)。
# 幅高可由 BackdropPreset 下发(set_amplitude 重建多边形,同 seed 同拓扑仅换高差)。

const TILE_W := 2600.0
const SEG_N := 9

@export var base_y := 1000.0
@export var color := Color("1A1E26")
@export var ridge_seed := 1
@export var amplitude := 120.0

var _poly: Polygon2D
var _line: Line2D


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = ridge_seed

	var n := SEG_N
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

	_poly = Polygon2D.new()
	_poly.polygon = poly_pts
	_poly.color = color
	add_child(_poly)

	_line = Line2D.new()
	_line.points = pts
	_line.width = 1.5
	_line.default_color = Color(Palette.I.paper, 0.05)
	add_child(_line)


func set_amplitude(a: float) -> void:
	amplitude = a
	if _poly == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = ridge_seed
	var seg := TILE_W / float(SEG_N)
	var pts := PackedVector2Array()
	for i in SEG_N:
		var x := i * seg
		var y := base_y - rng.randf_range(0.15, 1.0) * amplitude
		pts.append(Vector2(x, y))
	pts.append(Vector2(TILE_W, pts[0].y))
	var poly_pts := PackedVector2Array(pts)
	poly_pts.append(Vector2(TILE_W, base_y + 3200.0))
	poly_pts.append(Vector2(0, base_y + 3200.0))
	_poly.polygon = poly_pts
	_line.points = pts
