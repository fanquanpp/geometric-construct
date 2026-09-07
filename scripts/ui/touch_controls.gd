class_name TouchControls
extends CanvasLayer
## 移动端虚拟操控(自适应 + 安全区避让):
##   左下 轮盘:左右方向模拟量 —— 轻推慢走、松手即停;拉到最大自动加速
##   (替代加速按钮,PC 端仍用 Shift);
##   屏幕任意空白处 点按 / 长按:跳跃(长按 = 按住,用于贴墙攀爬与高弹跳),
##   轮盘触控区与右上小按钮除外;
##   右上小按钮:切换 / 重来 / 暂停。
## 全部输出经 Input.action_press 注入 InputMap 动作,与键盘 / 手柄同一条输入
## 通路(player.gd 只读动作,不区分来源)。
## 轮盘为扁平六边形轮廓:只暗示左右滑动,不产生纵向拖拽的错觉。
## 布局锚定可见区四角并内避安全区,旋转 / 改变窗口时自动重排。

const ICON_SIZE_SMALL := 46.0

var forced := false
var in_game := false

var _root: Control
var _buttons := {}          # action -> {btn: TouchScreenButton, icon_px: float, rect: Rect2}
var _wheel: WheelPad
var _jump_finger := -1      # 占据"空白处跳跃"的手指


func _ready() -> void:
	layer = 12
	# 命令行 --touch 强制开启(桌面调试 / 截图)
	forced = OS.get_cmdline_user_args().has("--touch")

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.resized.connect(_relayout)
	get_viewport().size_changed.connect(_relayout)

	# —— 右上:切换 / 重来 / 暂停(小按钮行) ——
	_add_button("keys/key-tab-flat.svg", "switch_next", ICON_SIZE_SMALL)
	_add_button("buttons/restart-flat.svg", "restart", ICON_SIZE_SMALL)
	_add_button("buttons/pause-flat.svg", "pause", ICON_SIZE_SMALL)

	# —— 左下:左右方向轮盘(拉满自动加速) ——
	_wheel = WheelPad.new()
	_root.add_child(_wheel)

	# 游戏初始在标题菜单;进入关卡时由 Main 开启
	visible = false
	_relayout.call_deferred()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var t := event as InputEventScreenTouch
	if t == null:
		return
	if t.pressed:
		# 空白处按下 = 跳跃;轮盘触控区与小按钮各自处理,不抢占
		if _jump_finger == -1 and not _pos_reserved(t.position):
			_jump_finger = t.index
			Input.action_press("jump")
			get_viewport().set_input_as_handled()
	elif t.index == _jump_finger:
		_jump_finger = -1
		Input.action_release("jump")


## 该位置已被其他控件占用(轮盘触控区 / 右上小按钮)。
func _pos_reserved(pos: Vector2) -> bool:
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if (b.rect as Rect2).grow(12.0).has_point(pos):
			return true
	return _wheel != null and _wheel.holds_point(pos)


## 应用被系统抢占(切后台 / 来电)时 UP 事件可能丢失,立即松开全部输入。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_jump_finger = -1
		Input.action_release("jump")
		if _wheel != null:
			_wheel.force_release()


## 进入 / 离开关卡:只在游戏进行中显示(触摸屏设备或强制开启时)。
func set_in_game(on: bool) -> void:
	in_game = on
	if on:
		visible = DisplayServer.is_touchscreen_available() or forced
	else:
		_release_all()
		visible = false


## 暂停菜单的"虚拟按键"开关:切换强制显示。
func toggle() -> void:
	forced = not forced
	var on := in_game and (forced or DisplayServer.is_touchscreen_available())
	if not on:
		_release_all()
	visible = on


func is_forced() -> bool:
	return forced


func _exit_tree() -> void:
	_release_all()


func _release_all() -> void:
	_jump_finger = -1
	Input.action_release("jump")
	if _wheel != null:
		_wheel.force_release()


## 按可见区尺寸与安全区重排(旋转 / 改窗口自适应)。
func _relayout() -> void:
	if _root == null or _wheel == null:
		return
	var vis := Adaptive.visible_size(get_viewport())
	var ins := Adaptive.safe_insets(get_viewport())
	var left := ins.x
	var top := ins.y
	var right := ins.z
	var bottom := ins.w

	# 轮盘:扁平六边形,贴左下角;高度刻意压扁,只暗示左右滑动
	var half_w := clampf(vis.x * 0.085, 108.0, 148.0)
	var half_h := clampf(half_w * 0.30, 24.0, 40.0)
	var wheel_center := Vector2(left + 26.0 + half_w, vis.y - bottom - 18.0 - half_h)
	_wheel.setup(half_w, half_h, wheel_center)

	# 右上小按钮行:切换 / 重来 / 暂停
	var order := ["switch_next", "restart", "pause"]
	var spacing := ICON_SIZE_SMALL + 10.0
	for k in order.size():
		var action: String = order[k]
		var b: Dictionary = _buttons[action]
		var sz := Vector2(b.icon_px, b.icon_px)
		var pos := Vector2(
			vis.x - right - 26.0 - sz.x / 2.0 - k * spacing,
			top + 96.0 + sz.y / 2.0) - sz / 2.0
		b.btn.position = pos
		b.rect = Rect2(pos, sz)


## 生成一个 TouchScreenButton:图标 + InputMap 动作,位置由 _relayout 决定。
func _add_button(icon_rel: String, action: String, icon_px: float) -> void:
	var tex := Ui.icon(icon_rel)
	var btn := TouchScreenButton.new()
	btn.texture_normal = tex
	btn.texture_pressed = tex
	btn.action = action
	# TouchScreenButton 是 Node2D:按图标原始尺寸缩放到位
	var base := maxf(tex.get_width(), 1.0)
	var s := icon_px / base
	btn.scale = Vector2(s, s)
	btn.modulate = Color(1, 1, 1, 0.62)
	btn.passby_press = true
	_root.add_child(btn)
	_buttons[action] = {"btn": btn, "icon_px": icon_px, "rect": Rect2()}


func _process(_delta: float) -> void:
	# 按下高亮:压住的按钮更实、更亮
	for action in _buttons:
		var btn: TouchScreenButton = (_buttons[action] as Dictionary)["btn"]
		var target := 0.95 if btn.is_pressed() else 0.62
		btn.modulate.a = move_toward(btn.modulate.a, target, 0.12)


## 左右方向轮盘:扁平六边形底盘,滑钮仅沿横轴移动。
## 触控区为轮廓外扩的扁长条;死区内回中;拉到最大自动加速(带滞回防抖)。
class WheelPad extends Control:
	const DEADZONE := 0.14
	const SPRINT_ON := 0.96      # 拉到最大 → 自动加速
	const SPRINT_OFF := 0.86     # 滞回:低于此才退出加速,避免边缘抖动

	var half_w := 120.0          # 六边形半宽
	var half_h := 36.0           # 六边形半高(刻意压扁)
	var strength := 0.0          # 死区处理后的输出 -1..1
	var sprinting := false       # 轮盘拉满触发的自动加速
	var _center := Vector2(160, 160)
	var _travel := 90.0          # 滑钮最大偏移
	var _knob_r := 26.0
	var _knob_x := 0.0           # 原始滑钮偏移(画布 px)
	var _finger := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## 布局:半宽 / 半高与圆心(画布坐标)。
	func setup(p_half_w: float, p_half_h: float, center: Vector2) -> void:
		half_w = p_half_w
		half_h = p_half_h
		_center = center
		_knob_r = clampf(half_h * 0.72, 18.0, 30.0)
		_travel = half_w - _knob_r - 12.0
		size = Vector2(half_w, half_h) * 2.0 + Vector2(12, 12)
		position = center - size / 2.0
		queue_redraw()

	## 是否落在轮盘触控区(轮廓外扩的扁长条)。
	func holds_point(pos: Vector2) -> bool:
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
		else:
			var d := event as InputEventScreenDrag
			if d != null and d.index == _finger:
				_follow(d.position)

	## 滑钮跟随手指(仅水平),并注入移动 / 加速动作。
	func _follow(pos: Vector2) -> void:
		_knob_x = clampf(pos.x - _center.x, -_travel, _travel)
		var pull := absf(_knob_x) / _travel
		var s := _knob_x / _travel
		if absf(s) < DEADZONE:
			s = 0.0
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
		queue_redraw()

	## 拉到最大自动加速(滞回阈值,防止在边缘来回抖动)。
	func _update_sprint(pull: float) -> void:
		if not sprinting and pull >= SPRINT_ON:
			sprinting = true
			Input.action_press("sprint")
		elif sprinting and pull < SPRINT_OFF:
			sprinting = false
			Input.action_release("sprint")

	func _release_move() -> void:
		Input.action_release("move_left")
		Input.action_release("move_right")

	## 无条件复位(切后台 / 隐藏 / 退出):松开全部由轮盘注入的动作。
	func force_release() -> void:
		_finger = -1
		strength = 0.0
		_knob_x = 0.0
		sprinting = false
		_release_move()
		Input.action_release("sprint")
		queue_redraw()

	func _process(_delta: float) -> void:
		if _finger != -1:
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		# 扁六边形轮廓(拉满加速时描红)
		var edge := Color(Ui.RED, 0.9) if sprinting else Color(Ui.PAPER, 0.34)
		var hex := PackedVector2Array([
			c + Vector2(-half_w, 0), c + Vector2(-half_w * 0.46, -half_h),
			c + Vector2(half_w * 0.46, -half_h), c + Vector2(half_w, 0),
			c + Vector2(half_w * 0.46, half_h), c + Vector2(-half_w * 0.46, half_h),
			c + Vector2(-half_w, 0),
		])
		draw_polyline(hex, edge, 2.0, true)
		# 水平中线 + 中心刻度:强调只有左右一个维度
		draw_line(c + Vector2(-half_w * 0.7, 0), c + Vector2(half_w * 0.7, 0),
			Color(Ui.PAPER, 0.10), 1.5)
		draw_circle(c, 2.5, Color(Ui.PAPER, 0.35))
		# 左右方向箭头(沿中线,随方向点亮)
		for dir: int in [-1, 1]:
			var tip := c + Vector2(dir * (half_w - 13.0), 0)
			var wing := 8.0
			var tri := PackedVector2Array([
				tip + Vector2(dir * wing, 0),
				tip + Vector2(-dir * wing * 0.5, -wing),
				tip + Vector2(-dir * wing * 0.5, wing),
			])
			var lit := signf(strength) == dir
			var col := Ui.PAPER if lit else Color(Ui.PAPER, 0.4)
			if lit and sprinting:
				col = Ui.RED
			draw_colored_polygon(tri, col)
		# 滑钮(仅沿横轴;拉满加速时描红)
		var knob := c + Vector2(_knob_x, 0)
		var ring := Color(Ui.PAPER, 0.85)
		if sprinting:
			ring = Ui.RED
		elif strength != 0.0:
			ring = Color(Ui.PAPER, 0.95)
		draw_circle(knob, _knob_r, Color(Ui.INK_2, 0.80))
		draw_arc(knob, _knob_r, 0.0, TAU, 40, ring, 2.0, true)
		draw_circle(knob, 3.5, Color(Ui.PAPER, 0.9))
