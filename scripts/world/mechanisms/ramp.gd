@tool
class_name Ramp
extends StaticBody2D


@export var pts := PackedVector2Array()
@export var base_y := 1000.0
var sig_value := 1
var hl_color := Color(0, 0, 0, 0)

const T_FRAME := preload("res://assets/archive/mech_ramp.png")

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	collision_layer = sig_value
	collision_mask = 0
	add_to_group("ramp")

	if pts.size() >= 2:
		var spr := Sprite2D.new()
		spr.show_behind_parent = true
		TerrainKit.mech_layout(spr, T_FRAME, _frame_zone())
		add_child(spr)

	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var cs := CollisionShape2D.new()
		var shape := ConvexPolygonShape2D.new()
		shape.points = PackedVector2Array([
			a, b, b + Vector2(0, THICKNESS), a + Vector2(0, THICKNESS),
		])
		cs.shape = shape
		add_child(cs)

	if pts.size() >= 2:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
		var body := PackedVector2Array(pts)
		body.append(Vector2(pts[pts.size() - 1].x, base_y))
		body.append(Vector2(pts[0].x, base_y))
		poly.polygon = body
		occ.occluder = poly
		add_child(occ)


func _frame_zone() -> Rect2:
	var flo: Vector2 = pts[0]
	var fhi: Vector2 = pts[0]
	for p in pts:
		flo = flo.min(p)
		fhi = fhi.max(p)
	flo.y = minf(flo.y, base_y)
	fhi.y = maxf(fhi.y, base_y)
	return Rect2(flo, fhi - flo)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)

var _sig := ""


func _editor_sync(force: bool) -> void:
	var s := str(pts) + "|" + str(base_y)
	if not force and s == _sig:
		return
	_sig = s
	var prev := get_node_or_null("EditorPreview")
	if prev != null:
		prev.queue_free()
	if pts.size() < 2:
		return
	var box := Node2D.new()
	box.name = "EditorPreview"
	var spr := Sprite2D.new()
	spr.show_behind_parent = true
	TerrainKit.mech_layout(spr, T_FRAME, _frame_zone())
	box.add_child(spr)
	add_child(box)
	queue_redraw()

func _draw() -> void:
	if Palette.I == null:
		return
	if pts.size() < 2:
		if Engine.is_editor_hint():

			var hcol := Color(Palette.I.dim, 0.7)
			for i in 6:
				var t0 := i / 6.0
				draw_line(Vector2(t0 * 200.0, -t0 * 100.0),
					Vector2((t0 + 0.08) * 200.0, -(t0 + 0.08) * 100.0), hcol, 2.0)
			draw_line(Vector2(-10, 0), Vector2(210, 0),
				Color(Palette.I.paper, 0.25), 2.0)
		return

	draw_polyline(pts, Color(Palette.I.paper, 0.35), 2.0)

	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := (b - a).normalized()
		var mid := (a + b) * 0.5
		draw_line(mid - d * 7.0, mid + d * 7.0, Color(Palette.I.red, 0.55), 3.0)

	TerrainKit.draw_focus(self, TerrainKit.ramp_bounds(pts, base_y), hl_color)

const THICKNESS := 48.0

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if pts.size() < 2:
		w.append("pts 至少需要 2 个折线点(Inspector 逐点编辑)。")
	return w
