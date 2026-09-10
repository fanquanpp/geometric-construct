class_name MagBoundary
extends StaticBody2D

## 磁力边界(伍·界/边,characters.md §5):两半顶部之间的阻隔线,
## 随两半移动逐帧伸缩;碰撞位 BOUNDARY_BIT(逆与双体自身的 mask 不含它)。
## v1 纪律:线只阻挡不推移——两半快速分开时,原线处的几何体不会被扫飞。

var a: Player
var b: Player
var _seg := SegmentShape2D.new()

func _ready() -> void:
	collision_layer = LevelBuilder.BOUNDARY_BIT
	collision_mask = 0
	var cs := CollisionShape2D.new()
	cs.shape = _seg
	add_child(cs)
	z_index = 4

func _physics_process(_dt: float) -> void:
	if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
		return
	# 任一半死亡 / 进门:磁界收线(两端并拢 = 不再阻隔任何人),
	# 防止重生瞬间线横跨全图把无关几何体挡在半路(对象失效防护)
	if a.dying or b.dying or a.in_exit or b.in_exit:
		_seg.a = Vector2.ZERO
		_seg.b = Vector2.ZERO
		queue_redraw()
		return
	_seg.a = to_local(a.boundary_anchor())
	_seg.b = to_local(b.boundary_anchor())
	queue_redraw()

func _draw() -> void:
	if a == null or b == null:
		return
	var col: Color = a.def.color
	var pa := _seg.a
	var pb := _seg.b
	var d := pb - pa
	if d.length() < 8.0:
		return
	var mid := (pa + pb) * 0.5
	var n := Vector2(-d.y, d.x).normalized()
	var bow := n * clampf(d.length() * 0.08, 4.0, 14.0)
	# 磁力折线:三段硬折(构成主义,不弯曲)
	var pts := PackedVector2Array([pa, pa + d * 0.3 + bow,
		pa + d * 0.7 + bow, pb])
	for i in 3:
		draw_line(pts[i], pts[i + 1], Color(col, 0.85), 2.5)
	# 端点方块 + 折点中块(磁力感)
	draw_rect(Rect2(pa - Vector2(4, 4), Vector2(8, 8)), Color(col, 0.95))
	draw_rect(Rect2(pb - Vector2(4, 4), Vector2(8, 8)), Color(col, 0.95))
	draw_rect(Rect2(mid + bow - Vector2(3, 3), Vector2(6, 6)), Color(Ui.PAPER, 0.9))
