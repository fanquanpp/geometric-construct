class_name MagBoundary
extends Node2D


var a: Player
var b: Player


@export var hint_span := Vector2(320, 0)

var _seg_a := Vector2.ZERO
var _seg_b := Vector2.ZERO
var _active := false


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	z_index = 4
	process_physics_priority = -10


func _project_bodies(dt: float) -> void:
	var players: Array = Main.I.players if Main.I != null else []
	if players.is_empty():
		return
	var d := _seg_b - _seg_a
	var length := d.length()
	if length < 8.0:
		return
	var dn := d / length
	for node in players:
		var p := node as Player
		if p == null or p == a or p == b:
			continue

		if p.pair_half >= 0 or p.def.can_pass_boundary:
			continue

		if p.remote_driven:
			continue
		var r := minf(p.def.size.x, p.def.size.y) * 0.5
		var now := p.global_position - _seg_a
		var side_now := dn.cross(now)
		var side_nxt := dn.cross(now + p.velocity * dt)

		if side_now > -r and side_now < r:
			continue

		if (side_now > 0.0) == (side_nxt > 0.0):
			continue
		if absf(side_now) < r:
			continue

		var t_c := side_now / (side_now - side_nxt)
		var u := now.lerp(now + p.velocity * dt, t_c).dot(dn)
		if u < -r or u > length + r:
			continue

		p.velocity = p.velocity.project(dn)


func _draw() -> void:
	if Engine.is_editor_hint():

		var hcol := Color(0.518, 0.333, 0.651, 0.85)
		var hpb := hint_span
		draw_line(Vector2.ZERO, hpb, hcol, 2.5)
		var hn := Vector2(-hpb.y, hpb.x).normalized() * 7.0
		for i in 5:
			var hm := hpb * ((i + 0.5) / 5.0)
			draw_line(hm - hn, hm + hn, hcol, 2.0)
		draw_rect(Rect2(Vector2(-4, -4), Vector2(8, 8)), hcol)
		draw_rect(Rect2(hpb - Vector2(4, 4), Vector2(8, 8)), hcol)
		return
	if a == null or b == null or not _active:
		return
	var col: Color = a.def.color
	var pa := _seg_a
	var pb := _seg_b
	var d := pb - pa
	if d.length() < 8.0:
		return
	var mid := (pa + pb) * 0.5
	var n := Vector2(-d.y, d.x).normalized()
	var bow := n * clampf(d.length() * 0.08, 4.0, 14.0)

	var pts := PackedVector2Array([pa, pa + d * 0.3 + bow,
		pa + d * 0.7 + bow, pb])
	for i in 3:
		draw_line(pts[i], pts[i + 1], Color(col, 0.85), 2.5)

	draw_rect(Rect2(pa - Vector2(4, 4), Vector2(8, 8)), Color(col, 0.95))
	draw_rect(Rect2(pb - Vector2(4, 4), Vector2(8, 8)), Color(col, 0.95))
	draw_rect(Rect2(mid + bow - Vector2(3, 3), Vector2(6, 6)), Color(Palette.I.paper, 0.9))
