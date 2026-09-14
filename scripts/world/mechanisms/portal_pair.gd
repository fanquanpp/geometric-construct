class_name PortalPair
extends Node2D
## 传送对(structures.md §5 规划转实装):成对直角门,进 A 出 B,
## 速度矢量完整保留(动量穿越);出口沿门法线外推 46px + 0.5s 冷却,
## 防乒乓循环(调研结论 2026-09-11:出口偏移是反循环标准解)。
## 两端各一块感应区;双向可穿(A↔B)。

@export var a := Vector2.ZERO            # A 门中心(相对本节点)
@export var b := Vector2(240, 0)         # B 门中心(相对本节点)
@export var gate_size := Vector2(90.0, 170.0)
var _cooldown := {}              # body -> 剩余冷却秒
var _areas: Array = []
var _frames: Array = []
var _sprs: Array = []
var _anim_t := 0.0

const EXIT_PUSH := 46.0
const COOLDOWN := 0.5

func _ready() -> void:
	z_index = 4
	_frames = [
		preload("res://assets/archive/mech_portal.png"),
		preload("res://assets/archive/mech_portal_f2.png"),
		preload("res://assets/archive/mech_portal_f3.png"),
	]
	for end: Vector2 in [a, b]:
		for k in 3:
			var spr := TerrainKit.mech_sprite(_frames[k],
				Rect2(end - gate_size / 2.0, gate_size))
			spr.visible = k == 0
			add_child(spr)
			_sprs.append(spr)
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
	queue_redraw()

func _physics_process(delta: float) -> void:
	for k in _cooldown.keys():
		_cooldown[k] = float(_cooldown[k]) - delta
		if float(_cooldown[k]) <= 0.0:
			_cooldown.erase(k)
	# 门环三帧循环(图鉴正典动画;静置也呼吸,标识"这里能传")
	_anim_t += delta
	var fi := int(_anim_t / 0.25) % 3
	for i in range(_sprs.size()):
		_sprs[i].visible = i % 3 == fi
