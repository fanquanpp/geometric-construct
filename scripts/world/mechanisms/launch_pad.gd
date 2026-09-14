class_name LaunchPad
extends Area2D
## 弹射板(structures.md §5「弹射板 Launcher」实装,弹弓原型):
## 踩上即获发射速度矢量(愤怒的小鸟式抛物入场的固定向量版)。
## vec 由数据给(测试关:竖直上抛 / 斜抛两种);0.6s 冷却防连触发。

@export var launch_vec := Vector2(0, -1400)   # 发射速度(px/s)
var _cooldown := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(140.0, 44.0)
	cs.shape = shape
	add_child(cs)
	add_child(TerrainKit.mech_sprite(preload("res://assets/archive/mech_launch_pad.png"),
		Rect2(-70.0, -69.0, 140.0, 138.0)))
	body_entered.connect(_on_enter)
	z_index = 3

func _on_enter(body: Node2D) -> void:
	if _cooldown > 0.0 or not (body is Player):
		return
	_cooldown = 0.6
	(body as Player).velocity = launch_vec
	Sfx.play("switch", -4.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	# 发射方向箭头(构成主义雪佛龙,箭头长度按 |vec| 缩放;正典帧底座之上)
	var dir := launch_vec.normalized()
	var arrow := clampf(launch_vec.length() / 280.0, 26.0, 64.0)
	var tip := dir * arrow
	var n := Vector2(-dir.y, dir.x)
	draw_line(Vector2(0, -18), tip, Color(Palette.I.paper, 0.85), 3.0)
	draw_colored_polygon(PackedVector2Array([
		tip, tip - dir * 14.0 + n * 9.0, tip - dir * 14.0 - n * 9.0]),
		Color(Palette.I.paper, 0.85))
	if _cooldown > 0.0:
		draw_rect(Rect2(-70.0, -14.0, 140.0, 28.0), Color(Palette.I.paper, 0.2))
