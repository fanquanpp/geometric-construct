@tool
class_name PortalPair
extends Node2D


@export var a := Vector2.ZERO
@export var b := Vector2(240, 0)
@export var gate_size := Vector2(90.0, 170.0)
var _cooldown := {}
var _areas: Array = []

const EXIT_PUSH := 46.0
const COOLDOWN := 0.5
const T_FRAME := preload("res://assets/archive/mech_portal.png")

@onready var _door_a: AnimatedSprite2D = $DoorA
@onready var _door_b: AnimatedSprite2D = $DoorB
var _sig := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	for cfg: Array in [[_door_a, a], [_door_b, b]]:
		_layout_door(cfg[0], cfg[1])
		cfg[0].play("default")
	for end: Vector2 in [a, b]:
		var area := Area2D.new()
		area.position = end
		area.collision_layer = 0
		area.collision_mask = 2
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = gate_size * 0.7
		cs.shape = shape
		area.add_child(cs)
		area.body_entered.connect(_on_enter.bind(end))
		add_child(area)
		_areas.append(area)


func _layout_door(spr: AnimatedSprite2D, end: Vector2) -> void:
	var used: Rect2i = T_FRAME.get_image().get_used_rect()
	spr.position = end
	spr.scale = gate_size / Vector2(used.size)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	var s := str(a) + "|" + str(b) + "|" + str(gate_size)
	if not force and s == _sig:
		return
	_sig = s
	_layout_door(_door_a, a)
	_layout_door(_door_b, b)

func _on_enter(body: Node2D, end: Vector2) -> void:
	if not (body is Player):
		return
	if float(_cooldown.get(body, 0.0)) > 0.0:
		return
	var other: Vector2 = b if end == a else a
	var outward: Vector2 = (other - end).normalized()
	_cooldown[body] = COOLDOWN
	(body as Player).global_position = global_position + other + outward * EXIT_PUSH
	Sfx.play("switch", -6.0)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for k in _cooldown.keys():
		_cooldown[k] = float(_cooldown[k]) - delta
		if float(_cooldown[k]) <= 0.0:
			_cooldown.erase(k)

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if a == b:
		w.append("A/B 两门中心重合,传送无位移。")
	return w
