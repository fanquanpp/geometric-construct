@tool
class_name PushBox
extends StaticBody2D
## 推箱(推箱子,structures.md §7):格逻辑滑动 —— 玩家从侧面顶入,
## 箱子沿顶入方向滑动整格(100px),遇墙 / 另一箱受阻。确定性优先:
## 不用连续物理推挤,滑动走补间;调研结论(2026-09-11):格逻辑比
## 纯物理推挤可预测,解谜不惩罚实验。
## 碰撞:箱体占位时挡人(层 bit31,构建期并入玩家 mask)。
## @tool:编辑器内 Visual 按 cell 落格位置实时预览(箱体落点即所见)。

@export var cell := Vector2.ZERO      # 当前格心(世界坐标)
var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7)
var _sliding := false
var _area: Area2D
const CELL := 100.0
const SLIDE_TIME := 0.18

const T_FRAME := preload("res://assets/archive/mech_push_box.png")

@onready var _visual: Sprite2D = $Visual
var _sig := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	position = cell
	collision_layer = 1 << 31
	collision_mask = 0
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2(CELL, CELL)
	TerrainKit.mech_layout(_visual, T_FRAME,
		Rect2(Vector2(-CELL / 2.0, -CELL / 2.0), Vector2(CELL, CELL)))
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

func _notification(what: int) -> void:
	# 编辑器内拖箱 = 落格:transform 变化即回写 cell(拖摆即数据,运行时
	# 仍以 cell 为权威、_ready 里 position = cell)。
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		if cell != position:
			cell = position

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)

## 编辑器预览同步:cell 与摆放位置的差值即箱体落格偏移,直接画出来。
func _editor_sync(force: bool) -> void:
	var s := str(cell) + "|" + str(position)
	if not force and s == _sig:
		return
	_sig = s
	var off := cell - position
	TerrainKit.mech_layout(_visual, T_FRAME,
		Rect2(off - Vector2(CELL / 2.0, CELL / 2.0), Vector2(CELL, CELL)))

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
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
	if Palette.I == null:
		return   # 编辑器极早期:静态资源未就绪,下帧重试
	var off := cell - position if Engine.is_editor_hint() else Vector2.ZERO
	var r := Rect2(off - Vector2(CELL / 2.0, CELL / 2.0), Vector2(CELL, CELL))
	# 两侧顶推雪佛龙(指向可推方向)
	for side: float in [-1.0, 1.0]:
		var cx := off.x + side * (CELL / 2.0 - 14.0)
		var cy := off.y
		draw_polyline(PackedVector2Array([
			Vector2(cx - side * 6.0, cy - 14.0), Vector2(cx + side * 6.0, cy),
			Vector2(cx - side * 6.0, cy + 14.0)]), Color(Palette.I.paper, 0.55), 2.0)
	# 专属高亮描边(呼吸脉冲,§7)
	TerrainKit.draw_focus(self, r, hl_color)
