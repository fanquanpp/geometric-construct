@tool
class_name SpeedGate
extends Area2D


@export var zone_size := Vector2(96, 190)

var _bodies := {}

const T_IDLE := preload("res://assets/archive/mech_speed_gate.png")
const T_LIVE := preload("res://assets/archive/mech_speed_gate_f2.png")

@onready var _spr_idle: Sprite2D = $Visual
@onready var _spr_live: Sprite2D = $VisualLive
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
	TerrainKit.mech_layout(_spr_idle, T_IDLE, Rect2(-zone_size / 2.0, zone_size))
	TerrainKit.mech_layout(_spr_live, T_LIVE, Rect2(-zone_size / 2.0, zone_size))
	_spr_live.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	var s := str(zone_size)
	if not force and s == _sig:
		return
	_sig = s
	var zone := Rect2(-zone_size / 2.0, zone_size)
	TerrainKit.mech_layout(_spr_idle, T_IDLE, zone)
	TerrainKit.mech_layout(_spr_live, T_LIVE, zone)

func _on_body_entered(body: Node2D) -> void:

	if NetSession.I != null and NetSession.I.is_net() and not NetSession.I.is_host():
		return
	if body is Player:
		_bodies[body] = true
		(body as Player).apply_speed_gate()
		if NetSession.I != null and NetSession.I.is_host() and Main.I != null:
			NetSession.I.emit_event(NetSession.EV_BUFFED, Main.I.players.find(body))

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_bodies.erase(body)

func _exit_tree() -> void:
	_bodies.clear()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var live := not _bodies.is_empty()
	if _spr_live.visible != live:
		_spr_live.visible = live
		_spr_idle.visible = not live
