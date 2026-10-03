@icon("res://assets/editor/speed_gate.svg")
@tool
class_name SpeedGate
extends Area2D


@export var zone_size := Vector2(96, 190)

var _bodies := {}

var _sig := ""

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
	cs.shape.size = zone_size
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	if force:
		queue_redraw()

func _on_body_entered(body: Node2D) -> void:

	if NetSession.I != null and NetSession.I.is_net() and not NetSession.I.is_host():
		return
	if body is Player:
		_bodies[body] = true
		(body as Player).apply_speed_gate()
		queue_redraw()
		if NetSession.I != null and NetSession.I.is_host() and Main.I != null:
			NetSession.I.emit_event(NetSession.EV_BUFFED, Main.I.players.find(body))

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_bodies.erase(body)
		queue_redraw()

func _exit_tree() -> void:
	_bodies.clear()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var live := not _bodies.is_empty()
	if live != get_meta("_live", false):
		set_meta("_live", live)
		queue_redraw()


func _draw() -> void:
	if Palette.I == null:
		return
	var live: bool = get_meta("_live", false) or Engine.is_editor_hint()
	var r := Rect2(-zone_size / 2.0, zone_size)
	var rail := Color(Palette.I.paper, 0.55 if live else 0.35)
	var chev := Color(Palette.I.red if live else Palette.I.paper,
		0.85 if live else 0.5)
	draw_rect(r, Color(Palette.I.ink, 0.45))
	draw_line(r.position, r.position + Vector2(0, r.size.y), rail, 3.0)
	draw_line(Vector2(r.end.x, r.position.y), r.end, rail, 3.0)
	draw_rect(Rect2(r.position - Vector2(4, 0), Vector2(4, r.size.y)),
		Color(Palette.I.paper, 0.25))
	draw_rect(Rect2(r.end, Vector2(4, r.size.y)), Color(Palette.I.paper, 0.25))
	var n := 3
	for k in n:
		var x := lerpf(r.position.x + 18.0, r.end.x - 18.0, float(k) / float(n - 1))
		DrawKit.chevron(self, Vector2(x, r.get_center().y), Vector2(1, 0),
			30.0, chev, 3.0)
	if live:
		draw_rect(r, Color(Palette.I.red, 0.18), false, 2.0)
