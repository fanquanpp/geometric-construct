@icon("res://assets/editor/checkpoint_beacon.svg")
@tool
class_name CheckpointBeacon
extends Area2D


## 记录点索引(负值 = 未登记,检查器黄条提示)。
@export var beacon_id := 0:
	set(v):
		beacon_id = v
		update_configuration_warnings()

var _on := false
var _lit := {}
var _t := 0.0
var _acc := 0.0

# 激活态呼吸重绘节流(deep_space 惯例 0.125s 桶):脉冲半径 20+6·pulse
# 在 8Hz 采样下每步 ≤0.94px,与星阵闪烁同一纪律。
const REDRAW_STEP := 0.125


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
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


func _process(delta: float) -> void:
	if not _on:
		return
	_t += delta
	_acc += delta
	if _acc >= REDRAW_STEP:
		_acc = 0.0
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player == false:
		return

	if NetSession.I != null and NetSession.I.is_net() and not NetSession.I.is_host():
		return
	_register(body as Player)


func _register(p: Player) -> void:
	var key := p.index
	if Main.I != null:
		Main.I.set_checkpoint(key, position)
	if _lit.has(key):
		return
	_lit[key] = true
	_set_on(true)
	Sfx.play("arrive")
	if NetSession.I != null and NetSession.I.is_host():
		NetSession.I.emit_event(NetSession.EV_CHECKPOINT, beacon_id, 0)


func net_apply_activate() -> void:
	if _on:
		return
	_set_on(true)
	Sfx.play("arrive")


func _set_on(v: bool) -> void:
	_on = v
	queue_redraw()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if beacon_id < 0:
		out.append("beacon_id 不能为负(记录点索引)。")
	return out


func _draw() -> void:
	if Palette.I == null:
		return
	var base_y := 14.0
	draw_rect(Rect2(Vector2(-30, base_y), Vector2(60, 6)), Color(Palette.I.paper, 0.35))
	draw_rect(Rect2(Vector2(-3, base_y - 84), Vector2(6, 84)),
		Color(Palette.I.paper, 0.5))
	var head := Vector2(0, base_y - 96)
	if _on:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		# 激活语义收敛:黄只在菱首实心 + 呼吸脉冲环(柱身保持纸体,
		# 消「黄角色门」误读);叠加静环构成双环形态差——激活/未激活
		# 靠环数与实心/空心可辨,不依赖色相(WCAG 1.4.1)。
		DrawKit.ngon_fill(self, head, 13.0, 4, Color(Palette.I.yellow, 0.95), PI / 4.0)
		DrawKit.ngon_line(self, head, 19.0, 12, Color(Palette.I.paper, 0.5), 1.5)
		DrawKit.ngon_line(self, head, 20.0 + 6.0 * pulse, 12,
			Color(Palette.I.yellow, 0.55 - 0.3 * pulse), 2.0)
	else:
		DrawKit.ngon_line(self, head, 13.0, 4, Color(Palette.I.paper, 0.45), 2.0, PI / 4.0)
		draw_circle(head, 3.0, Color(Palette.I.paper, 0.4))
	draw_rect(Rect2(Vector2(-30, base_y), Vector2(60, 6)),
		Color(Palette.I.paper, 0.35))
