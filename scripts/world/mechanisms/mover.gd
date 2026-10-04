@icon("res://assets/editor/mover.svg")
@tool
class_name Mover
extends AnimatableBody2D


@export_group("外形")
@export var size := Vector2(300, 44)
@export var sig_value := 1
@export_group("行程")
## 往复行程向量(相对初始位);ZERO = 静置平台(检查器黄条提示)。
@export var travel := Vector2.ZERO:
	set(v):
		travel = v
		update_configuration_warnings()
@export_range(0.2, 20.0, 0.1) var period := 3.0
@export_range(0.0, 1.0, 0.01) var phase := 0.0
## 检查器「预演行程」:2 秒高亮行程轨道/端点/方向(纯 _draw,不动场景树)。
@export_tool_button("预演行程")
var preview_travel: Callable = _editor_preview_travel
var hl_color := Color(0, 0, 0, 0)
var _t := 0.0
var _base := Vector2.ZERO
var _preview_until_msec := 0

var _sig := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	_base = position
	sync_to_physics = true
	collision_layer = sig_value
	collision_mask = 0
	MechKit.ensure_rect_shape(self, size)

	add_child(TerrainKit.rect_occluder(Rect2(-size / 2.0, size)))
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if _preview_until_msec != 0 and Time.get_ticks_msec() > _preview_until_msec:
			_preview_until_msec = 0
			queue_redraw()
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	var s := str(size) + "|" + str(travel)
	if not force and s == _sig:
		return
	_sig = s
	queue_redraw()


## 检查器工具按钮回调:纯绘制预演,不位移本节点、不动场景树。
func _editor_preview_travel() -> void:
	if not Engine.is_editor_hint():
		return
	_preview_until_msec = Time.get_ticks_msec() + 2000
	queue_redraw()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if travel == Vector2.ZERO:
		out.append("travel 为 ZERO:平台静置不往复(静置平台可忽略此提示)。")
	return out

func _draw() -> void:
	if Palette.I == null:
		return
	var body := Rect2(-size / 2.0, size)
	draw_rect(body, Color(Palette.I.ink_2, 1.0))
	draw_rect(body, Color(Palette.I.paper, 0.5), false, 2.0)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 5)),
		Color(Palette.I.paper, 0.6))
	draw_rect(Rect2(body.position.x + 8, body.end.y - 8,
		body.size.x - 16, 4), Color(Palette.I.paper, 0.14))
	if travel == Vector2.ZERO:
		return

	var pa := -travel * 0.5
	var pb := travel * 0.5
	draw_line(pa, pb, Color(Palette.I.paper, 0.10), 1.0)
	# 行程端点刻 = 装饰标记,降为 dim 低显著(不与「将塌」red 同权)。
	for p: Vector2 in [pa, pb]:
		draw_rect(Rect2(p + Vector2(-2.5, -14.0), Vector2(5, 5)), Color(Palette.I.dim, 0.75))
		draw_rect(Rect2(p + Vector2(-2.5, 9.0), Vector2(5, 5)), Color(Palette.I.dim, 0.75))
	if _preview_until_msec != 0 and Time.get_ticks_msec() < _preview_until_msec:
		# 「预演行程」高亮:轨道提亮 + 方向箭头 + 端点括弧。
		draw_line(pa, pb, Color(Palette.I.paper, 0.45), 2.0)
		DrawKit.arrow(self, Vector2.ZERO, pb, Color(Palette.I.paper, 0.85), 2.0, 10.0)
		for q: Vector2 in [pa, pb]:
			DrawKit.brackets(self, Rect2(q - Vector2(10, 10), Vector2(20, 20)),
				Color(Palette.I.paper, 0.8), 7.0, 1.5)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if NetSession.I != null and NetSession.I.is_net():
		_t = NetSession.I._clock
	else:
		_t += delta

	var s := 0.5 - 0.5 * cos(TAU * (_t / maxf(period, 0.1) + phase))
	position = _base + travel * s
