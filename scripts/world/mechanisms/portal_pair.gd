class_name PortalPair
extends Node2D
## 传送对(structures.md §5 规划转实装):成对直角门,进 A 出 B,
## 速度矢量完整保留(动量穿越);出口沿门法线外推 46px + 0.5s 冷却,
## 防乒乓循环(调研结论 2026-09-11:出口偏移是反循环标准解)。
## 两端各一块感应区;双向可穿(A↔B)。

var a := Vector2.ZERO            # A 门中心
var b := Vector2.ZERO            # B 门中心
var gate_size := Vector2(90.0, 170.0)
var _cooldown := {}              # body -> 剩余冷却秒
var _areas: Array = []

const EXIT_PUSH := 46.0
const COOLDOWN := 0.5

func _ready() -> void:
	z_index = 4
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
	(body as Player).global_position = other + outward * EXIT_PUSH
	Sfx.play("switch", -6.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	for k in _cooldown.keys():
		_cooldown[k] = float(_cooldown[k]) - delta
		if float(_cooldown[k]) <= 0.0:
			_cooldown.erase(k)
	queue_redraw()   # 门内粒子/呼吸逐帧

func _draw() -> void:
	# 双门:取景框语言(目标角色色双线框)改用传送青蓝,雪佛龙指向对面
	for end: Vector2 in [a, b]:
		var local := end - position
		var r := Rect2(local - gate_size / 2.0, gate_size)
		draw_rect(r, Color("4E86D8", 0.18))
		draw_rect(r, Color("4E86D8", 0.9), false, 2.0)
		draw_rect(r.grow(-6.0), Color(Palette.PAPER, 0.5), false, 1.0)
		var dir: float = signf(b.x - a.x)
		var cx := local.x
		for k in 2:
			var off := -10.0 + 20.0 * float(k)
			draw_polyline(PackedVector2Array([
				Vector2(cx + dir * off - dir * 8.0, local.y - 18.0),
				Vector2(cx + dir * off + dir * 8.0, local.y),
				Vector2(cx + dir * off - dir * 8.0, local.y + 18.0)]),
				Color(Palette.PAPER, 0.7), 2.0)
		# 端点刻度
		draw_rect(Rect2(Vector2(local.x - 4.0, local.y - gate_size.y / 2.0 - 8.0),
			Vector2(8, 4)), Color(Palette.RED, 0.8))
