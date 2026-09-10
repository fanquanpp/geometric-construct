class_name Mover
extends AnimatableBody2D

## 移动构件:单轴往返的动平台(AnimatableBody2D + sync_to_physics,
## 站立者由平台速度自然携带)。行程用余弦缓动 —— 两端减速、中段匀速,
## 落点时刻可预判(docs/design/levels.md §3 动态地图原则)。

var rect := Rect2()
var travel := Vector2.ZERO
var period := 3.0
var phase := 0.0
var layer_value := 1
var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7.10)
var _t := 0.0

func _ready() -> void:
	sync_to_physics = true
	collision_layer = layer_value
	collision_mask = 0
	var cs := CollisionShape2D.new()
	cs.position = Vector2.ZERO
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	add_child(cs)
	# 遮挡体(引擎光影 v0.19):居中于石板,随平台一起动,投影由引擎实算
	add_child(LevelBuilder._rect_occluder(Rect2(-rect.size / 2.0, rect.size)))
	var renderer := MoverSlab.new()
	renderer.size = rect.size
	add_child(renderer)

func _physics_process(delta: float) -> void:
	# 联机(net.md §6):两端按共享关卡时钟取值,零带宽零漂移;
	# 单机 = 本地累计(行为不变)。
	if NetSession.I != null and NetSession.I.is_net():
		_t = NetSession.I._clock
	else:
		_t += delta
	# 余弦往返:s ∈ [0,1],端点速度为零
	var s := 0.5 - 0.5 * cos(TAU * (_t / maxf(period, 0.1) + phase))
	position = rect.get_center() + travel * s
