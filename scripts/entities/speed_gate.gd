class_name SpeedGate
extends Area2D
## 加速门(光电门):穿过时立即把速度抬到门后上限,并永久提升速度上限
## (对"圆"为 2.5×、"逆"为 2.0×,直至死亡重生)。
## 视觉:门柱 + 顶梁 + 循环滚动的雪佛龙箭头,有人强化时箭头变红加速。

@export var zone_size := Vector2(96, 190)

var _bodies := {}
var _spr_idle: Sprite2D
var _spr_live: Sprite2D

const T_IDLE := preload("res://assets/archive/mech_speed_gate.png")
const T_LIVE := preload("res://assets/archive/mech_speed_gate_f2.png")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 3

	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = zone_size
	_spr_idle = TerrainKit.mech_sprite(T_IDLE, Rect2(-zone_size / 2.0, zone_size))
	_spr_live = TerrainKit.mech_sprite(T_LIVE, Rect2(-zone_size / 2.0, zone_size))
	_spr_live.visible = false
	add_child(_spr_idle)
	add_child(_spr_live)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	# 联机:强化只在主机判定,客机经事件复现(net.md §6)
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



func _process(_delta: float) -> void:
	var live := not _bodies.is_empty()
	if _spr_live.visible != live:
		_spr_live.visible = live
		_spr_idle.visible = not live
