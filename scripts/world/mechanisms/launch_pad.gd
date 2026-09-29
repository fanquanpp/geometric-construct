@tool
class_name LaunchPad
extends Area2D


@export var launch_vec := Vector2(0, -1400)
var _cooldown := 0.0
var _flush_off := 0.0


func _calc_flush() -> void:
	var gtop := TerrainKit.floor_top_at(get_parent(), global_position.x,
		global_position.y - 22.0 + 2.0, 60.0)
	if gtop != TerrainKit.SURFACE_MISS:
		_flush_off = clampf(gtop - (global_position.y - 22.0), 0.0, 44.0)


func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	collision_layer = 0
	collision_mask = 2
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2(140.0, 44.0)
	_calc_flush()
	body_entered.connect(_on_enter)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	queue_redraw()

func _on_enter(body: Node2D) -> void:
	if _cooldown > 0.0 or not (body is Player):
		return
	_cooldown = 0.6
	(body as Player).velocity = launch_vec
	Sfx.play("switch", -4.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	if Palette.I == null:
		return

	var base := Rect2(-70.0, -22.0 + _flush_off, 140.0, 44.0)
	draw_rect(base, Color(Palette.I.ink_3, 1.0))
	draw_rect(base, Color(Palette.I.paper, 0.5), false, 2.0)
	draw_rect(Rect2(base.position, Vector2(base.size.x, 6)),
		Color(Palette.I.paper, 0.6))
	for k in 3:
		var x := -42.0 + k * 42.0
		draw_line(Vector2(x, 4 + _flush_off), Vector2(x - 6, 14 + _flush_off),
			Color(Palette.I.paper, 0.35), 2.0)
		draw_line(Vector2(x - 6, 14 + _flush_off), Vector2(x, 24 + _flush_off),
			Color(Palette.I.paper, 0.35), 2.0)
		draw_line(Vector2(x, 24 + _flush_off), Vector2(x - 6, 34 + _flush_off),
			Color(Palette.I.paper, 0.35), 2.0)
	if _cooldown > 0.0:
		draw_rect(base, Color(Palette.I.paper, 0.3))

	var oy := _flush_off
	var dir := launch_vec.normalized()
	var arrow := clampf(launch_vec.length() / 280.0, 26.0, 64.0)
	var tip := dir * arrow
	var n := Vector2(-dir.y, dir.x)
	draw_line(Vector2(0, -18 + oy), tip + Vector2(0, oy),
		Color(Palette.I.paper, 0.85), 3.0)
	var oy2 := Vector2(0, oy)
	draw_colored_polygon(PackedVector2Array([
		tip + oy2, tip - dir * 14.0 + n * 9.0 + oy2,
		tip - dir * 14.0 - n * 9.0 + oy2]),
		Color(Palette.I.paper, 0.85))
