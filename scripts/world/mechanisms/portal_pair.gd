@tool
class_name PortalPair
extends Node2D
## 传送对(structures.md §5 规划转实装):成对直角门,进 A 出 B,
## 速度矢量完整保留(动量穿越);出口沿门法线外推 46px + 0.5s 冷却,
## 防乒乓循环(调研结论 2026-09-11:出口偏移是反循环标准解)。
## 两端各一块感应区;双向可穿(A↔B)。
## @tool:A/B 门 AnimatedSprite2D 随 a/b/gate_size 实时重排(所见即所得);
## 门环三帧循环动画 = data/mech/portal_frames.tres(4fps 循环,
## 静置也呼吸,标识"这里能传")。

@export var a := Vector2.ZERO            # A 门中心(相对本节点)
@export var b := Vector2(240, 0)         # B 门中心(相对本节点)
@export var gate_size := Vector2(90.0, 170.0)
var _cooldown := {}              # body -> 剩余冷却秒
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

## 门环布局:门心落在 a/b,占位框(113×113 方框)非均匀拉满 gate_size。
func _layout_door(spr: AnimatedSprite2D, end: Vector2) -> void:
	var used: Rect2i = T_FRAME.get_image().get_used_rect()
	spr.position = end
	spr.scale = gate_size / Vector2(used.size)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)

## 编辑器预览同步:a/b/gate_size 变化才重排。
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
