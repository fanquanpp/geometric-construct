class_name TouchControls
extends CanvasLayer
## 移动端虚拟操控(自适应 + 安全区避让):
##   左下 轮盘:左右方向模拟量 —— 轻推慢走、松手即停;拉到最大自动加速
##   (替代加速按钮,PC 端仍用 Shift);
##   屏幕任意空白处 点按 / 长按:跳跃(长按 = 按住,用于贴墙攀爬与高弹跳),
##   轮盘触控区与右上小按钮除外;
##   右上小按钮:切换 / 召回 / 暂停。
## 全部输出经 Input.action_press 注入 InputMap 动作,与键盘 / 手柄同一条输入
## 通路(player.gd 只读动作,不区分来源)。
## 轮盘为扁平六边形轮廓:只暗示左右滑动,不产生纵向拖拽的错觉。
## 布局锚定可见区四角并内避安全区,旋转 / 改变窗口时自动重排。
##
## 轮盘位置(设置面板可调,SettingsManager 持久化):
##   fixed —— 固定在左下角,轮盘触控区外空白处点按 = 跳跃;
##   float —— 触控域半屏划分(业界通行方案):左半屏 = 轮盘域,按住就地展开、
##            松手滑回左下待位;右半屏 = 跳跃域,点按 / 长按跳跃 ——
##            两域互不干扰,按住轮盘转向的同时,右半屏照样可跳(v0.10.1 修复:
##            旧实现轮盘占用期间吞掉全屏跳跃触摸)。小按钮热区在两域之外。

const ICON_SIZE_SMALL := 76.0
const UI_STRIP_TOP := 200.0     # 顶层 UI 带:chips/提示/小按钮所在,禁跳
## 触控热区外扩:视觉图标之外保留一圈余量(Material 建议目标 ≥48dp,
## 热区应大于视觉元素,减少误触/空点)。
const HIT_MARGIN := 18.0

var forced := false
var in_game := false

var _root: Control
var _buttons := {}          # action -> {btn, label, icon_px, rect: Rect2}
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

	# 切换已重构(v0.17.2):直接点按左上队伍 chips 切换,不再设切换按钮。
	# —— 右上:召回 / 暂停(方盘按钮行,图标 + 文字标签) ——
	_add_button("buttons/recall-flat.svg", "buttons/recall-flat-on.svg",
		"recall", "召回")
	_add_button("buttons/pause-flat.svg", "buttons/pause-flat-on.svg",
		"pause", "暂停")

	# —— 左下:左右方向轮盘(拉满自动加速) ——
	_wheel = WheelPad.new()
	_root.add_child(_wheel)
	_wheel.wheel_mode = SettingsManager.wheel_mode
	# 开发覆盖(--wheel=fixed / --wheel=float):自动化截图 / 调试不受存档设置影响
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wheel="):
			var m := a.substr(8)
			if m == WheelPad.MODE_FIXED or m == WheelPad.MODE_FLOAT:
				_wheel.wheel_mode = m

	# 游戏初始在标题菜单;进入关卡时由 Main 开启
	visible = false
	_relayout.call_deferred()


## 触控域划分(浮动轮盘模式,业界通行方案 —— 左半屏移动 / 右半屏跳跃):
##   左半屏 = 轮盘域:按住就地展开浮动轮盘;轮盘占用中再来左半屏触摸不产生跳跃;
##   右半屏 = 跳跃域:点按 / 长按跳跃,与轮盘是否被按住完全无关(互不干扰);
##   顶层 UI 带(y < 200 画布px:chips / 提示行 / 重来 / 暂停 / 跳过键)禁跳;
#   两域 exceptions:按在小按钮(重来 / 暂停)热区上时归按钮,
##   不被任何域吞掉。固定轮盘模式维持原行为:轮盘触控区外空白处点按 = 跳跃。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var t := event as InputEventScreenTouch
	if t == null:
		return
	if t.pressed:
		if _wheel != null and _wheel.wheel_mode == WheelPad.MODE_FLOAT:
			# 按钮热区优先:两个域都让路,交给 TouchScreenButton 自行处理
			if _is_on_button(t.position):
				return
			var vis := Adaptive.visible_size(get_viewport())
			if t.position.x <= vis.x * 0.5:
				# 左半屏 · 轮盘域(轮盘占用中则本次触摸落空,不跳跃)
				_wheel.float_begin(t.index, t.position)
				get_viewport().set_input_as_handled()
				return
			# 右半屏 · 跳跃域(顶层 UI 带除外)
			if _jump_finger == -1 and t.position.y > UI_STRIP_TOP:
				_jump_finger = t.index
				Input.action_press("jump")
				tap_burst_at(t.position)
				get_viewport().set_input_as_handled()
			return
		# 固定模式:空白处按下 = 跳跃;轮盘触控区/顶层 UI 带/小按钮不抢占
		if _jump_finger == -1 and t.position.y > UI_STRIP_TOP 			and not _pos_reserved(t.position):
			_jump_finger = t.index
			Input.action_press("jump")
			tap_burst_at(t.position)
			get_viewport().set_input_as_handled()
	elif t.index == _jump_finger:
		_jump_finger = -1
		Input.action_release("jump")


## 按下位置是否落在某个可见小按钮的热区内(热区 = 图标矩形外扩 HIT_MARGIN)。
func _is_on_button(pos: Vector2) -> bool:
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if not (b.btn as TouchScreenButton).is_visible_in_tree():
			continue
		if (b.rect as Rect2).grow(HIT_MARGIN).has_point(pos):
			return true
	return false


## 该位置已被其他控件占用(固定轮盘触控区 / 小按钮);隐藏的按钮不占热区。
## 浮动模式不经过这里:触控域由 _input 按半屏整域划分,轮盘永不"占住"全屏,
## 否则按住轮盘转向时第二根手指的跳跃会被吞掉(v0.10.1 修复的边界冲突)。
func _pos_reserved(pos: Vector2) -> bool:
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if not (b.btn as TouchScreenButton).is_visible_in_tree():
			continue
		if (b.rect as Rect2).grow(HIT_MARGIN).has_point(pos):
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


## 当前生效的轮盘模式(含开发覆盖);HUD / 关卡提示文案据此出词。
func wheel_mode() -> String:
	return _wheel.wheel_mode if _wheel != null else SettingsManager.wheel_mode


## 单人阵容没有切换可言:v0.17.2 起切换走队伍 chips 点按,此钮已移除(接口保留兼容)。
func set_switch_available(_on: bool) -> void:
	pass


## 设置面板改了轮盘模式后同步(切回固定时收拢浮动状态)。
func refresh_settings() -> void:
	if _wheel != null:
		_wheel.wheel_mode = SettingsManager.wheel_mode
		_wheel.force_release()
		_relayout()


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

	# 轮盘:扁平六边形,左缘避安全区;高度刻意压扁,只暗示左右滑动
	var half_w := clampf(vis.x * 0.085, 108.0, 148.0)
	var half_h := clampf(half_w * 0.30, 24.0, 40.0)
	# v0.14.0:常驻位定在屏幕下四分之一处(中心 = 可见区高度 3/4,
	# 拇指自然搭放的高度;v0.13.6 曾试下三分之一 2/3,仍偏高)
	var wheel_center := Vector2(left + 26.0 + half_w, vis.y * 3.0 / 4.0)
	_wheel.setup(half_w, half_h, wheel_center)

	# 右上小按钮行:重来 / 暂停
	var order := ["recall", "pause"]
	var spacing := ICON_SIZE_SMALL + 14.0
	for k in order.size():
		var action: String = order[k]
		var b: Dictionary = _buttons[action]
		var sz := Vector2(b.icon_px, b.icon_px)
		var pos := Vector2(
			vis.x - right - 26.0 - sz.x / 2.0 - k * spacing,
			top + 92.0 + sz.y / 2.0) - sz / 2.0
		b.btn.position = pos
		b.rect = Rect2(pos, sz)
		# 文字标签:钉在图标正下方
		var label: Label = b.label
		label.position = Vector2(pos.x + sz.x / 2.0 - 40.0, pos.y + sz.y + 4.0)


## 生成一个 TouchScreenButton:常态 / 按下两态图标 + InputMap 动作,
## 下挂一枚文字标签(存进 _buttons,由 _relayout 定位)。位置由 _relayout 决定。
func _add_button(icon_rel: String, icon_on_rel: String, action: String,
		label_text: String) -> void:
	var tex := Ui.icon(icon_rel)
	var tex_on := Ui.icon(icon_on_rel)
	var btn := TouchScreenButton.new()
	btn.texture_normal = tex
	btn.texture_pressed = tex_on
	btn.action = action
	# TouchScreenButton 是 Node2D:按图标原始尺寸缩放到位
	var base := maxf(tex.get_width(), 1.0)
	var s := ICON_SIZE_SMALL / base
	btn.scale = Vector2(s, s)
	btn.modulate = Color(1, 1, 1, 0.66)
	btn.passby_press = true
	# 触感反馈:按下瞬间轻震(受设置开关控制;桌面为无害空操作)
	btn.pressed.connect(func() -> void: buzz(24))
	_root.add_child(btn)
	var label := Ui.l(label_text, 12, Ui.LIGHT, Color(Ui.PAPER, 0.8),
		HORIZONTAL_ALIGNMENT_CENTER)
	label.size = Vector2(80, 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	_buttons[action] = {"btn": btn, "label": label, "icon_px": ICON_SIZE_SMALL,
		"rect": Rect2()}


## 触感反馈(受设置开关控制;桌面无振动硬件时为无害空操作)。
static func buzz(ms := 24) -> void:
	if SettingsManager.vibration:
		Input.vibrate_handheld(ms)


## 点按位置的粒子反馈(FX-1 轻微反馈,presentation/00 卷八 · Fragment
## 色块碎片):一圈向外扩张的菱形回包 + 纸白小方块迸散(含一枚构成红)。
## 0.32s 内散尽,全部硬边方块无柔化;跳域点按(双模式)自动触发,
## 开发钩子(--tapshot)亦可程序化调用。
func tap_burst_at(pos: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 10
	burst.lifetime = 0.32
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.damping_min = 40.0
	burst.damping_max = 90.0
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 170.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Palette.PAPER, Palette.PAPER, Palette.RED])
	burst.color_initial_ramp = ramp
	burst.position = pos
	burst.finished.connect(burst.queue_free)
	_root.add_child(burst)
	var ring := TapRing.new()
	ring.position = pos
	_root.add_child(ring)


## 点按回包:向外扩张的 45° 方形轮廓(构成菱,与传送菱标/徽章同母题),
## 0.28s 淡出 —— M2 微交互档、二次缓出(M1 白名单)、M9 时间驱动。
class TapRing extends Node2D:
	const DUR := 0.28
	const R0 := 8.0
	const R1 := 46.0
	var _elapsed := 0.0

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= DUR:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_elapsed / DUR, 0.0, 1.0)
		var ease_k := 1.0 - (1.0 - k) * (1.0 - k)
		var r := lerpf(R0, R1, ease_k)
		var a := 0.7 * (1.0 - k)
		var pts := PackedVector2Array([
			Vector2(r, 0), Vector2(0, r), Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0),
		])
		draw_polyline(pts, Color(Ui.PAPER, a), 2.0, true)


func _process(_delta: float) -> void:
	# 按下高亮:压住的按钮更实、更亮(标签同步提亮)
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		var btn: TouchScreenButton = b.btn
		var target := 1.0 if btn.is_pressed() else 0.66
		btn.modulate.a = move_toward(btn.modulate.a, target, 0.12)
		var ltarget := 1.0 if btn.is_pressed() else 0.72
		var label: Label = b.label
		label.modulate.a = move_toward(label.modulate.a, ltarget, 0.12)


## 左右方向轮盘:扁平六边形底盘,滑钮仅沿横轴移动。
## 触控区为轮廓外扩的扁长条;死区内回中;拉到最大自动加速(带滞回防抖)。
## 两种位置模式(设置面板切换):
##   MODE_FIXED —— 底盘钉在左下角,触控区固定;
##   MODE_FLOAT —— 待位时画在左下角(半透明提示),按住左半屏任意空白处
##                  就地展开,松手滑回待位点。
class WheelPad extends Control:
	const MODE_FIXED := "fixed"
	const MODE_FLOAT := "float"
	const DEADZONE := 0.10
	const SPRINT_ON := 0.96      # 拉到最大 → 自动加速
	const SPRINT_OFF := 0.86     # 滞回:低于此才退出加速,避免边缘抖动
	## 输出曲线 γ(>1):跨出死区后对归一行程做幂映射,轻推段灵敏度压低
	## (微调 / 精确停边更细腻),拉满仍为 1.0 全速不变。样式与行程不变。
	const OUT_CURVE := 1.35

	var wheel_mode := MODE_FIXED
	var strength := 0.0          # 死区处理后的输出 -1..1
	var sprinting := false       # 轮盘拉满触发的自动加速
	var half_w := 120.0          # 六边形半宽
	var half_h := 36.0           # 六边形半高(刻意压扁)
	var _center := Vector2(160, 160)   # 待位点(固定模式 = 使用位置)
	var _home := Vector2(160, 160)     # 左下角待位锚点(_relayout 刷新)
	var _travel := 90.0          # 滑钮最大偏移
	var _knob_r := 26.0
	var _knob_x := 0.0           # 原始滑钮偏移(画布 px)
	var _finger := -1
	var _returning := false      # 浮动模式:松手后滑回待位点的过渡

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## 布局:半宽 / 半高与待位圆心(画布坐标)。
	func setup(p_half_w: float, p_half_h: float, center: Vector2) -> void:
		half_w = p_half_w
		half_h = p_half_h
		_home = center
		if _finger == -1 and not _returning:
			_center = center
		_knob_r = clampf(half_h * 0.72, 18.0, 30.0)
		_travel = half_w - _knob_r - 12.0
		size = Vector2(half_w, half_h) * 2.0 + Vector2(12, 12)
		position = _center - size / 2.0
		queue_redraw()

	## 浮动模式:左半屏空白处按下 → 轮盘就地展开。返回是否接管了这次按下。
	func float_begin(finger: int, pos: Vector2) -> bool:
		if wheel_mode != MODE_FLOAT or _finger != -1:
			return false
		var vis := Adaptive.visible_size(get_viewport())
		if pos.x > vis.x * 0.5:
			return false
		_finger = finger
		_returning = false
		# 展开圆心:按下点,内避屏幕边缘与安全区(留出半盘空间)
		var ins := Adaptive.safe_insets(get_viewport())
		_center = Vector2(
			clampf(pos.x, ins.x + half_w + 10.0, vis.x * 0.5 - 6.0),
			clampf(pos.y, ins.y + half_h * 2.0 + 10.0,
				vis.y - ins.w - half_h * 2.0 - 10.0))
		position = _center - size / 2.0
		_follow(pos)
		TouchControls.buzz(12)
		return true

	## 是否落在轮盘触控区。固定模式:轮廓外扩的扁长条。
	## 浮动模式:恒为 false —— 触控域由 TouchControls 按半屏划分,
	## 轮盘绝不在此占位,按住转向时右半屏跳跃不受影响。
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

	## 浮动模式松手:滑钮归零后,底盘滑回左下角待位点(0.16s)。
	func _float_return() -> void:
		if wheel_mode != MODE_FLOAT:
			return
		_returning = true
		var tw := create_tween()
		tw.tween_property(self, "position", _home - size / 2.0, 0.16) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			_returning = false
			_center = _home
			queue_redraw())

	## 滑钮跟随手指(仅水平),并注入移动 / 加速动作。
	## 输入精度(v0.13.6):死区重映射 —— 跨出死区输出从 0 平滑起步,
	## 消除旧版 0 → 0.14 的速度突跳;再走 γ 幂曲线压低轻推段灵敏度。
	## 冲刺判定用原始行程 pull,阈值行为不变。
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
		_returning = false
		_center = _home
		position = _center - size / 2.0
		_release_move()
		Input.action_release("sprint")
		queue_redraw()

	func _process(_delta: float) -> void:
		if _finger != -1:
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		# 浮动模式待位时更淡(提示"可以在这里按住"),激活 / 固定时常态
		var idle_a := 0.18 if (wheel_mode == MODE_FLOAT and _finger == -1) else 1.0
		# 扁六边形轮廓(拉满加速时描红)
		var edge := Color(Ui.RED, 0.9) if sprinting else Color(Ui.PAPER, 0.34 * idle_a)
		var hex := PackedVector2Array([
			c + Vector2(-half_w, 0), c + Vector2(-half_w * 0.46, -half_h),
			c + Vector2(half_w * 0.46, -half_h), c + Vector2(half_w, 0),
			c + Vector2(half_w * 0.46, half_h), c + Vector2(-half_w * 0.46, half_h),
			c + Vector2(-half_w, 0),
		])
		draw_polyline(hex, edge, 2.0, true)
		# 水平中线 + 中心刻度:强调只有左右一个维度
		# 绘制精度(v0.13.6):全部图元开抗锯齿、圆弧细分为 72 段,
		# 高 DPI 下边缘无锯齿、圆更圆;颜色 / 粗细 / 形状(样式)一律不动
		draw_line(c + Vector2(-half_w * 0.7, 0), c + Vector2(half_w * 0.7, 0),
			Color(Ui.PAPER, 0.10 * idle_a), 1.5, true)
		draw_circle(c, 2.5, Color(Ui.PAPER, 0.35 * idle_a), true, -1.0, true)
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
			var col := Ui.PAPER if lit else Color(Ui.PAPER, 0.4 * idle_a)
			if lit and sprinting:
				col = Ui.RED
			# 多边形本身无抗锯齿:沿闭合边缘补一圈同色 AA 描边,边缘平滑
			draw_colored_polygon(tri, col)
			draw_polyline(PackedVector2Array(
				[tri[0], tri[1], tri[2], tri[0]]), col, 1.4, true)
		# 滑钮(仅沿横轴;拉满加速时描红)
		var knob := c + Vector2(_knob_x, 0)
		var ring := Color(Ui.PAPER, 0.85 * idle_a)
		if sprinting:
			ring = Ui.RED
		elif strength != 0.0:
			ring = Color(Ui.PAPER, 0.95)
		draw_circle(knob, _knob_r, Color(Ui.INK_2, 0.80 * idle_a), true, -1.0, true)
		draw_arc(knob, _knob_r, 0.0, TAU, 72, ring, 2.0, true)
		draw_circle(knob, 3.5, Color(Ui.PAPER, 0.9 * idle_a), true, -1.0, true)
