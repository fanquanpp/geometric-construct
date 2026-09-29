@tool
class_name PushBox
extends StaticBody2D


@export var cell := Vector2.ZERO
var hl_color := Color(0, 0, 0, 0)
var _sliding := false
var _area: Area2D
const CELL := 100.0
const SLIDE_TIME := 0.18

var _sig := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	position = cell
	collision_layer = 1 << 31
	collision_mask = 0
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2(CELL, CELL)
	queue_redraw()

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var acs := CollisionShape2D.new()
	var ashape := RectangleShape2D.new()
	ashape.size = Vector2(CELL + 56.0, CELL + 40.0)
	acs.shape = ashape
	_area.add_child(acs)
	add_child(_area)
	add_to_group("push_box")

func _notification(what: int) -> void:

	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		if cell != position:
			cell = position

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	var s := str(cell) + "|" + str(position)
	if not force and s == _sig:
		return
	_sig = s
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _sliding:
		return
	for body in _area.get_overlapping_bodies():
		if not (body is Player):
			continue
		var p := body as Player
		if absf(p.velocity.x) < 10.0:
			continue
		var side: float = signf(p.position.x - position.x)
		if absf(p.position.x - position.x) < 20.0:
			continue
		_try_slide(Vector2(-side, 0))
		break

func _try_slide(dir: Vector2) -> void:
	var target := cell + dir * CELL
	if _blocked(target):
		return
	_sliding = true
	cell = target
	Sfx.play("ui_page", -10.0)
	var tw := create_tween()
	tw.tween_property(self, "position", target, SLIDE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: _sliding = false)


func _blocked(target: Vector2) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL - 8.0, CELL - 8.0)
	params.shape = shape
	params.transform = Transform2D(0, target)
	params.collision_mask = 0xFFFFFFFD
	params.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()

func _draw() -> void:
	if Palette.I == null:
		return
	var off := cell - position if Engine.is_editor_hint() else Vector2.ZERO
	var r := Rect2(off - Vector2(CELL / 2.0, CELL / 2.0), Vector2(CELL, CELL))

	draw_rect(r, Color(Palette.I.ink_3, 1.0))
	draw_rect(r, Color(Palette.I.paper, 0.55), false, 2.0)
	draw_line(r.position + Vector2(10, 10), r.end - Vector2(10, 10),
		Color(Palette.I.paper, 0.18), 2.0)
	draw_line(Vector2(r.end.x - 10, r.position.y + 10),
		Vector2(r.position.x + 10, r.end.y - 10), Color(Palette.I.paper, 0.18), 2.0)
	draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 5)),
		Color(Palette.I.paper, 0.4))

	for side: float in [-1.0, 1.0]:
		var cx := off.x + side * (CELL / 2.0 - 14.0)
		var cy := off.y
		draw_polyline(PackedVector2Array([
			Vector2(cx - side * 6.0, cy - 14.0), Vector2(cx + side * 6.0, cy),
			Vector2(cx - side * 6.0, cy + 14.0)]), Color(Palette.I.paper, 0.55), 2.0)

	TerrainKit.draw_focus(self, r, hl_color)
