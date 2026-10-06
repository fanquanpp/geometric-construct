class_name WheelPad
extends Control
## 触屏轮盘组件(v0.61.0 自 touch_controls 内嵌类抽出,场景节点化)。
## fixed=固定左下角;float=左半屏按下处就地展开。全部绘制走 DrawKit 配方。


const MODE_FIXED := "fixed"
const MODE_FLOAT := "float"
const DEADZONE := 0.10
const SPRINT_ON := 0.96
const SPRINT_OFF := 0.86

const OUT_CURVE := 1.35

var wheel_mode := MODE_FIXED
var strength := 0.0
var sprinting := false
var half_w := 120.0
var half_h := 36.0
var _center := Vector2(160, 160)
var _home := Vector2(160, 160)
var _travel := 90.0
var _knob_r := 26.0
var _knob_x := 0.0
var _finger := -1
var _returning := false

var _idle_a := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_half_w: float, p_half_h: float, center: Vector2) -> void:
	half_w = p_half_w
	half_h = p_half_h
	_home = center
	if _finger == -1 and not _returning:
		_center = center
	# 触点纪律:菱形扳钮对角实宽 2×_knob_r,下限抬到 22(=实体 ≥44px,
	# 与触屏命中 ≥44px 同口径);比例不足时由下限抬平。
	_knob_r = clampf(half_h * 0.72, 22.0, 30.0)
	_travel = half_w - _knob_r - 12.0
	size = Vector2(half_w, half_h) * 2.0 + Vector2(12, 12)
	position = _center - size / 2.0
	queue_redraw()


func _apply_state() -> void:
	queue_redraw()


func float_begin(finger: int, pos: Vector2) -> bool:
	if wheel_mode != MODE_FLOAT or _finger != -1:
		return false
	var vis := Adaptive.visible_size(get_viewport())
	if pos.x > vis.x * 0.5:
		return false
	_finger = finger
	_returning = false

	var ins := Adaptive.safe_insets(get_viewport())
	_center = Vector2(
		clampf(pos.x, ins.x + half_w + 10.0, vis.x * 0.5 - 6.0),
		clampf(pos.y, ins.y + half_h * 2.0 + 10.0,
			vis.y - ins.w - half_h * 2.0 - 10.0))
	position = _center - size / 2.0
	_follow(pos)
	return true


func holds_point(pos: Vector2) -> bool:
	if wheel_mode == MODE_FLOAT:
		return false
	var d := pos - _center
	return absf(d.x) <= half_w * 1.28 + 16.0 \
		and absf(d.y) <= half_h * 2.2 + 16.0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var t := event as InputEventScreenTouch
	if t != null:
		if t.pressed:
			if _finger == -1 and holds_point(t.position):
				_finger = t.index
				_follow(t.position)
				get_viewport().set_input_as_handled()
		elif t.index == _finger:
			_finger = -1
			_follow(Vector2(_center.x, t.position.y))
			_float_return()
	else:
		var d := event as InputEventScreenDrag
		if d != null and d.index == _finger:
			_follow(d.position)


func _float_return() -> void:
	if wheel_mode != MODE_FLOAT:
		return
	_returning = true
	var tw := create_tween()
	tw.tween_property(self, "position", _home - size / 2.0, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_returning = false
		_center = _home)


func _follow(pos: Vector2) -> void:
	_knob_x = clampf(pos.x - _center.x, -_travel, _travel)
	var pull := absf(_knob_x) / _travel
	var s := _knob_x / _travel
	var mag := absf(s)
	if mag < DEADZONE:
		s = 0.0
	else:
		var norm := (mag - DEADZONE) / (1.0 - DEADZONE)
		s = signf(s) * pow(norm, OUT_CURVE)
	strength = s
	_update_sprint(pull)
	if s < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left", -s)
	elif s > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right", s)
	else:
		_release_move()
	_apply_state()


func _update_sprint(pull: float) -> void:
	if not sprinting and pull >= SPRINT_ON:
		sprinting = true
		Input.action_press("sprint")
		_apply_state()
	elif sprinting and pull < SPRINT_OFF:
		sprinting = false
		Input.action_release("sprint")
		_apply_state()


func _release_move() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")


func force_release() -> void:
	_finger = -1
	strength = 0.0
	_knob_x = 0.0
	sprinting = false
	_returning = false
	_center = _home
	position = _center - size / 2.0
	_release_move()
	Input.action_release("sprint")
	queue_redraw()


func _process(_delta: float) -> void:

	# 空闲可见度(NN/g:新手看不见控件):float 空闲 0.18→0.30→0.55。
	# 真机目检 0.30 仍近乎不可辨(强光下全灭),再抬半档;按住即回全亮。
	var idle_a := 0.55 if (wheel_mode == MODE_FLOAT and _finger == -1) else 1.0
	if idle_a != _idle_a:
		_idle_a = idle_a
		queue_redraw()


func _draw() -> void:
	if Palette.I == null:
		return
	var a := _idle_a
	var mid_y := size.y / 2.0
	var cx := size.x / 2.0
	var kx := (size.x - 12.0) / 240.0
	var ky := (size.y - 12.0) / 72.0
	# 结构线可见度(真机 3200×1440 目检:0.30/0.10/0.16 三档在强光实机
	# 近乎全灭,轮盘读作「极暗虚线六边形」)——全体抬到可辨档,红仅出现在
	# 冲刺/激活语义上不动。
	var edge := Color(Palette.I.red if sprinting else Palette.I.paper,
		(0.85 if sprinting else 0.55) * a)
	var hex := PackedVector2Array([
		Vector2(cx - 120.0 * kx, mid_y),
		Vector2(cx - 55.0 * kx, mid_y - 36.0 * ky),
		Vector2(cx + 55.0 * kx, mid_y - 36.0 * ky),
		Vector2(cx + 120.0 * kx, mid_y),
		Vector2(cx + 55.0 * kx, mid_y + 36.0 * ky),
		Vector2(cx - 55.0 * kx, mid_y + 36.0 * ky)])
	hex.append(hex[0])
	draw_polyline(hex, edge, 2.0, true)
	draw_line(Vector2(cx - 84.0 * kx, mid_y - 1.0),
		Vector2(cx + 84.0 * kx, mid_y - 1.0),
		Color(Palette.I.paper, 0.22 * a), 2.0)
	draw_rect(Rect2(cx - 2.5, mid_y - 2.5, 5, 5),
		Color(Palette.I.paper, 0.62 * a))
	DrawKit.chevron(self, Vector2(cx + 103.0 * kx, mid_y), Vector2(1, 0),
		17.0 * ky, Color(Palette.I.paper, 0.32 * a), 2.0)
	DrawKit.chevron(self, Vector2(cx - 103.0 * kx, mid_y), Vector2(-1, 0),
		17.0 * ky, Color(Palette.I.paper, 0.32 * a), 2.0)
	if strength > 0.0:
		DrawKit.chevron(self, Vector2(size.x - 20.0, mid_y), Vector2(1, 0),
			18.0, Color(Palette.I.red if sprinting else Palette.I.paper,
				0.85 * a), 3.0)
	elif strength < 0.0:
		DrawKit.chevron(self, Vector2(20.0, mid_y), Vector2(-1, 0),
			18.0, Color(Palette.I.red if sprinting else Palette.I.paper,
				0.85 * a), 3.0)
	# 扳钮菱形化:16 边近似圆退役,4 边菱形 + 方点(ngon rot=PI/4,
	# 与 TapRing/图鉴菱首同语汇)——触屏 HUD 唯一圆形实体根除。
	var kc := Vector2(size.x / 2.0 + _knob_x, mid_y)
	DrawKit.ngon_fill(self, kc, _knob_r, 4,
		Color(Palette.I.red if sprinting else Palette.I.paper, 0.9 * a),
		PI / 4.0)
	DrawKit.ngon_line(self, kc, _knob_r, 4, Color(Palette.I.ink, 0.45 * a),
		2.0, PI / 4.0)
	var dot := _knob_r * 0.5
	draw_rect(Rect2(kc - Vector2(dot, dot) * 0.5, Vector2(dot, dot)),
		Color(Palette.I.ink, 0.55 * a))
