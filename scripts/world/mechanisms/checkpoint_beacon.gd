class_name CheckpointBeacon
extends Area2D


@export var beacon_id := 0

const T_ON := preload("res://assets/archive/mech_checkpoint_f2.png")
var _on := false
var _lit := {}
@onready var _spr: Sprite2D = $Visual


func _ready() -> void:
	add_to_group("checkpoint")
	set_meta("checkpoint_id", beacon_id)
	collision_layer = 0
	collision_mask = 2
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2(72, 96)
	cs.position = Vector2(0, -32)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player == false:
		return

	if NetSession.I != null and NetSession.I.is_net() and not NetSession.I.is_host():
		return
	_register(body as Player)


func _register(p: Player) -> void:
	var key := p.body_key()
	if Main.I != null:
		Main.I.set_checkpoint(key, position)
	if _lit.has(key):
		return
	_lit[key] = true
	_on = true
	Sfx.play("arrive")
	_spr.texture = T_ON
	if NetSession.I != null and NetSession.I.is_host():
		NetSession.I.emit_event(NetSession.EV_CHECKPOINT, beacon_id, 0)


func net_apply_activate() -> void:
	if _on:
		return
	_on = true
	Sfx.play("arrive")
	_spr.texture = T_ON
