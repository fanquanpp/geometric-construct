@tool
class_name LaunchPad
extends Area2D
## 弹射板(structures.md §5「弹射板 Launcher」实装,弹弓原型):
## 踩上即获发射速度矢量(愤怒的小鸟式抛物入场的固定向量版)。
## vec 由数据给(测试关:竖直上抛 / 斜抛两种);0.6s 冷却防连触发。
## @tool:发射方向箭头在编辑器内实时预览(方向/力度摆位即所得)。

@export var launch_vec := Vector2(0, -1400)   # 发射速度(px/s)
var _cooldown := 0.0

const T_FRAME := preload("res://assets/archive/mech_launch_pad.png")

@onready var _visual: Sprite2D = $Visual

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
	cs.shape.size = Vector2(140.0, 44.0)
	TerrainKit.mech_layout(_visual, T_FRAME, Rect2(-70.0, -69.0, 140.0, 138.0))
	body_entered.connect(_on_enter)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)

## 编辑器预览同步:发射矢量变化才重排/重绘箭头。
func _editor_sync(force: bool) -> void:
	if force:
		TerrainKit.mech_layout(_visual, T_FRAME, Rect2(-70.0, -69.0, 140.0, 138.0))
	queue_redraw()

func _on_enter(body: Node2D) -> void:
	if _cooldown > 0.0 or not (body is Player):
		return
	_cooldown = 0.6
	(body as Player).velocity = launch_vec
	Sfx.play("switch", -4.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	if Palette.I == null:
		return   # 编辑器极早期:静态资源未就绪,下帧重试
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
