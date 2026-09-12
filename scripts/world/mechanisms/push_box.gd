class_name PushBox
extends StaticBody2D
## 推箱(推箱子,structures.md §7):格逻辑滑动 —— 玩家从侧面顶入,
## 箱子沿顶入方向滑动整格(100px),遇墙 / 另一箱受阻。确定性优先:
## 不用连续物理推挤,滑动走补间;调研结论(2026-09-11):格逻辑比
## 纯物理推挤可预测,解谜不惩罚实验。
## 碰撞:箱体占位时挡人(层 bit31,构建期并入玩家 mask)。

var cell := Vector2.ZERO      # 当前格心(世界坐标)
var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7.10)
var _sliding := false
var _area: Area2D
const CELL := 100.0
const SLIDE_TIME := 0.18


func _ready() -> void:
	position = cell
	collision_layer = 1 << 31
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL, CELL)
	cs.shape = shape
	add_child(cs)
	# 顶入感应区:比箱体略大,持续读玩家顶入方向(连顶连滑 = 多格推)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2   # 玩家层
	var acs := CollisionShape2D.new()
	var ashape := RectangleShape2D.new()
	ashape.size = Vector2(CELL + 56.0, CELL + 40.0)
	acs.shape = ashape
	_area.add_child(acs)
	add_child(_area)
	add_to_group("push_box")


func _physics_process(_delta: float) -> void:
	if _sliding:
		return
	for body in _area.get_overlapping_bodies():
		if not (body is Player):
			continue
		var p := body as Player
		if absf(p.velocity.x) < 10.0:
			continue
		var side: float = signf(p.position.x - position.x)
		if absf(p.position.x - position.x) < 20.0:
			continue   # 正上站立 / 正下顶头:不算侧推
		_try_slide(Vector2(-side, 0))   # 玩家在箱右向左顶 → 箱向左滑
		break


func _try_slide(dir: Vector2) -> void:
	var target := cell + dir * CELL
	if _blocked(target):
		return
	_sliding = true
	cell = target
	Sfx.play("ui_page", -10.0)
	var tw := create_tween()
	tw.tween_property(self, "position", target, SLIDE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: _sliding = false)


## 目标格是否受阻(墙体 / 另一箱;忽略玩家自身层)。
func _blocked(target: Vector2) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL - 8.0, CELL - 8.0)
	params.shape = shape
	params.transform = Transform2D(0, target)
	params.collision_mask = 0xFFFFFFFD   # 全层即探,唯排除玩家层 bit2
	params.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


func _draw() -> void:
	var r := Rect2(Vector2(-CELL / 2.0, -CELL / 2.0), Vector2(CELL, CELL))
	draw_rect(r, Color("3A4254"))
	draw_rect(r, Color(Palette.I.paper, 0.42), false, 1.5)
	# 两侧顶推雪佛龙(指向可推方向)
	for side: float in [-1.0, 1.0]:
		var cx := side * (CELL / 2.0 - 14.0)
		draw_polyline(PackedVector2Array([
			Vector2(cx - side * 6.0, -14.0), Vector2(cx + side * 6.0, 0.0),
			Vector2(cx - side * 6.0, 14.0)]), Color(Palette.I.paper, 0.55), 2.0)
	# 专属高亮描边(呼吸脉冲,§7.10)
	TerrainKit.draw_focus(self, r, hl_color)
