@icon("res://assets/editor/resonance_pedal.svg")
@tool
class_name ResonancePedal
extends Area2D


## 共鸣踏板:驻场机关。非活跃角色驻留探测区 → 显形桥(碰撞层 0 → 1);
## 驻留体切走 / 阵亡 / 离板 → 收桥为 8% 幽灵线。
## 节点原点 = 地表点:踏板上半露出地表作触发区(站立者身体与其重叠),
## 桥沿 +x 自踏板右缘延伸,桥面与地表齐平,接续步行面。
## 联机:speed_gate 同款主机裁决 + EV_RESONANCE 广播,客机只走 net_apply。


@export var channel := 0
@export var detect_size := Vector2(120, 40)
@export var bridge_size := Vector2(320, 24)

var bridge: StaticBody2D
var _bodies := {}
var _resident: Player = null
var _on := false


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("resonance_pedal")
	set_meta("resonance_channel", channel)
	collision_layer = 0
	collision_mask = 2
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = detect_size
	bridge = get_node_or_null("Bridge") as StaticBody2D
	if bridge == null:
		bridge = StaticBody2D.new()
		bridge.name = "Bridge"
		add_child(bridge)
	bridge.collision_layer = 0
	bridge.collision_mask = 0
	var bcs := bridge.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if bcs == null:
		bcs = CollisionShape2D.new()
		bridge.add_child(bcs)
	if bcs.shape == null:
		bcs.shape = RectangleShape2D.new()
	bcs.shape.size = bridge_size
	bcs.position = _bridge_offset()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


# 桥板偏移:x 自踏板右缘起铺,y 顶面与地表(节点原点)齐平。
func _bridge_offset() -> Vector2:
	return Vector2(detect_size.x * 0.5 + bridge_size.x * 0.5,
		bridge_size.y * 0.5)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# 客机不裁决:桥态全由 EV_RESONANCE 广播驱动(speed_gate 同款守卫)
	if NetSession.I != null and NetSession.I.is_net() \
			and not NetSession.I.is_host():
		return
	_set_resident(_pick_resident())


func _pick_resident() -> Player:
	for b in _bodies:
		var p := b as Player
		if p != null and is_instance_valid(p) and not p.is_active \
				and not p.dying and not p.in_exit:
			return p
	return null


func _on_body_entered(body: Node2D) -> void:
	if body is Player == false:
		return
	if NetSession.I != null and NetSession.I.is_net() \
			and not NetSession.I.is_host():
		return
	_bodies[body] = true


func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)


func _set_resident(resident: Player) -> void:
	if resident == _resident:
		return
	_resident = resident
	var on := resident != null
	if on != _on:
		_apply_on(on)
		# 主机侧状态变化广播给客机(emit_event 自带 is_host 守卫)
		if NetSession.I != null and NetSession.I.is_host() and Main.I != null:
			NetSession.I.emit_event(NetSession.EV_RESONANCE, channel,
				1 if on else 0)
	else:
		queue_redraw()


func _apply_on(v: bool) -> void:
	_on = v
	if bridge != null:
		bridge.collision_layer = 1 if v else 0
	queue_redraw()


## 联机:客机端按 EV 广播应用桥态(EV_CHECKPOINT 同款路径,不回发)
func net_apply(on: bool) -> void:
	_apply_on(on)


func _exit_tree() -> void:
	_bodies.clear()
	_resident = null


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if channel < 0:
		out.append("共鸣通道 channel 不能为负(联机按通道广播)")
	return out


func _draw() -> void:
	if Palette.I == null:
		return
	var editor := Engine.is_editor_hint()
	var pad := Rect2(-detect_size / 2.0, detect_size)
	var plank := Rect2(_bridge_offset() - bridge_size / 2.0, bridge_size)
	# 踏板:纸面墨线 + 内角括弧
	draw_rect(pad, Color(Palette.I.ink, 0.55))
	draw_rect(pad, Color(Palette.I.paper, 0.55), false, 2.0)
	DrawKit.brackets(self, pad.grow(-5.0), Color(Palette.I.paper, 0.65), 9.0)
	# 驻留体 def.color 双色带,一眼读出谁在供电
	if _resident != null and is_instance_valid(_resident):
		var band_y := pad.get_center().y
		draw_rect(Rect2(pad.position.x + 8.0, band_y - 6.0,
			pad.size.x - 16.0, 4.0), Color(_resident.def.color, 0.9))
		draw_rect(Rect2(pad.position.x + 8.0, band_y + 2.0,
			pad.size.x - 16.0, 4.0), Color(Palette.I.paper, 0.45))
	# 桥:显形 = 纸面墨线 + 色缘 + 内角括弧;收桥 = 8% 幽灵线
	if _on or editor:
		draw_rect(plank, Color(Palette.I.ink_2, 0.97))
		draw_rect(plank, Color(Palette.I.paper, 0.5), false, 2.0)
		draw_rect(Rect2(plank.position, Vector2(plank.size.x, 4.0)),
			Color(Palette.I.paper, 0.6))
		if _resident != null and is_instance_valid(_resident):
			draw_rect(Rect2(plank.position.x, plank.position.y + 6.0,
				plank.size.x, 3.0), Color(_resident.def.color, 0.75))
		DrawKit.brackets(self, plank.grow(-5.0),
			Color(Palette.I.paper, 0.65), 9.0)
	else:
		draw_rect(plank, Color(Palette.I.paper, 0.08), false, 2.0)
