@tool
class_name Mover
extends AnimatableBody2D


@export var size := Vector2(300, 44)
@export var travel := Vector2.ZERO
@export var period := 3.0
@export var phase := 0.0
@export var sig_value := 1
var hl_color := Color(0, 0, 0, 0)
var _t := 0.0
var _base := Vector2.ZERO

var _sig := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	_base = position
	sync_to_physics = true
	collision_layer = sig_value
	collision_mask = 0
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = size

	add_child(TerrainKit.rect_occluder(Rect2(-size / 2.0, size)))
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	var s := str(size) + "|" + str(travel)
	if not force and s == _sig:
		return
	_sig = s
	queue_redraw()

func _draw() -> void:
	if Palette.I == null:
		return
	var body := Rect2(-size / 2.0, size)
	draw_rect(body, Color(Palette.I.ink_2, 1.0))
	draw_rect(body, Color(Palette.I.paper, 0.5), false, 2.0)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 5)),
		Color(Palette.I.paper, 0.6))
	draw_rect(Rect2(body.position.x + 8, body.end.y - 8,
		body.size.x - 16, 4), Color(Palette.I.paper, 0.14))
	if travel == Vector2.ZERO:
		return

	var pa := -travel * 0.5
	var pb := travel * 0.5
	draw_line(pa, pb, Color(Palette.I.paper, 0.10), 1.0)
	for p: Vector2 in [pa, pb]:
		draw_rect(Rect2(p + Vector2(-2.5, -14.0), Vector2(5, 5)), Color(Palette.I.red, 0.55))
		draw_rect(Rect2(p + Vector2(-2.5, 9.0), Vector2(5, 5)), Color(Palette.I.red, 0.55))

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if NetSession.I != null and NetSession.I.is_net():
		_t = NetSession.I._clock
	else:
		_t += delta

	var s := 0.5 - 0.5 * cos(TAU * (_t / maxf(period, 0.1) + phase))
	position = _base + travel * s
