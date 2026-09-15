@tool
class_name Mover
extends AnimatableBody2D

## 移动构件:单轴往返的动平台(AnimatableBody2D + sync_to_physics,
## 站立者由平台速度自然携带)。行程用余弦缓动 —— 两端减速、中段匀速,
## 落点时刻可预判(docs/design/levels.md §3 动态地图原则)。
## @tool:编辑器内 Visual 精灵随 size 参数实时重排(所见即所得)。

@export var size := Vector2(300, 44)   # 平台尺寸(节点置于行程中点)
@export var travel := Vector2.ZERO     # 单轴往返全行程
@export var period := 3.0
@export var phase := 0.0
@export var sig_value := 1
var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7)
var _t := 0.0
var _base := Vector2.ZERO

const T_FRAME := preload("res://assets/archive/mech_mover.png")

@onready var _visual: Sprite2D = $Visual
var _sig := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	_base = position
	sync_to_physics = true
	collision_layer = sig_value
	collision_mask = 0
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = size
	# 遮挡体(引擎光影 v0.19):居中于石板,随平台一起动,投影由引擎实算
	add_child(TerrainKit.rect_occluder(Rect2(-size / 2.0, size)))
	TerrainKit.mech_layout(_visual, T_FRAME, Rect2(-size / 2.0, size))

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)

## 编辑器预览同步:参数签名变化才重排(避免每帧重解码贴图)。
func _editor_sync(force: bool) -> void:
	var s := str(size) + "|" + str(travel)
	if not force and s == _sig:
		return
	_sig = s
	TerrainKit.mech_layout(_visual, T_FRAME, Rect2(-size / 2.0, size))
	queue_redraw()

func _draw() -> void:
	if Palette.I == null or travel == Vector2.ZERO:
		return
	# 行程预告线 + 端点红刻度(可预读纪律;编辑器内同绘,所见即行程)
	var pa := -travel * 0.5
	var pb := travel * 0.5
	draw_line(pa, pb, Color(Palette.I.paper, 0.10), 1.0)
	for p: Vector2 in [pa, pb]:
		draw_rect(Rect2(p + Vector2(-2.5, -14.0), Vector2(5, 5)), Color(Palette.I.red, 0.55))
		draw_rect(Rect2(p + Vector2(-2.5, 9.0), Vector2(5, 5)), Color(Palette.I.red, 0.55))

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# 联机(net.md §6):两端按共享关卡时钟取值,零带宽零漂移;
	# 单机 = 本地累计(行为不变)。
	if NetSession.I != null and NetSession.I.is_net():
		_t = NetSession.I._clock
	else:
		_t += delta
	# 余弦往返:s ∈ [0,1],端点速度为零
	var s := 0.5 - 0.5 * cos(TAU * (_t / maxf(period, 0.1) + phase))
	position = _base + travel * s
