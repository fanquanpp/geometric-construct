@tool
class_name SkiPatch
extends Area2D


@export var size := Vector2(300, 60)
var _grace := {}

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
	cs.shape.size = size
	queue_redraw()
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	var s := str(size)
	if not force and s == _sig:
		return
	_sig = s
	queue_redraw()

func _on_enter(body: Node2D) -> void:
	if body is Player:
		(body as Player).skiing = true

func _on_exit(body: Node2D) -> void:
	if body is Player:
		_grace[body] = 0.2

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for k in _grace.keys():
		_grace[k] = float(_grace[k]) - delta
		if float(_grace[k]) <= 0.0:
			if is_instance_valid(k) and not overlaps_body(k):
				(k as Player).skiing = false
			_grace.erase(k)


func _draw() -> void:
	if Palette.I == null:
		return
	var r := Rect2(-size / 2.0, size)
	draw_rect(r, Color(Palette.I.blue, 0.16))
	DrawKit.hatch45(self, r, Color(Palette.I.blue, 0.30), 9.0, 1.5)
	draw_rect(r, Color(Palette.I.blue, 0.5), false, 2.0)
	DrawKit.chevron(self, Vector2(-24, r.get_center().y), Vector2(1, 0),
		18.0, Color(Palette.I.paper, 0.55), 2.0)
	DrawKit.chevron(self, Vector2(24, r.get_center().y), Vector2(1, 0),
		18.0, Color(Palette.I.paper, 0.55), 2.0)
