class_name TouchControls
extends CanvasLayer


const ICON_SIZE_SMALL := 84.0
const UI_STRIP_TOP := 200.0


const HIT_MARGIN := 18.0

var forced := false
var in_game := false

@onready var _root: Control = %Root
@onready var _wheel: WheelPad = %Wheel
var _buttons := {}
var _jump_finger := -1


func _ready() -> void:
	layer = 12

	forced = OS.get_cmdline_user_args().has("--touch")

	# 结构(Root/双钮/字形/标签/轮盘)在 touch_controls.tscn;
	# 调色派生样式与输入接线在代码。瞬态点击爆点/涟漪仍为运行时实体(豁免)。
	_root.resized.connect(_relayout)
	get_viewport().size_changed.connect(_relayout)

	_wire_button("recall", %RecallBtn, %RecallGlyph, %RecallLabel,
		"buttons/recall", "buttons/recall-on")
	_wire_button("pause", %PauseBtn, %PauseGlyph, %PauseLabel,
		"buttons/pause", "buttons/pause-on")

	_wheel.wheel_mode = SettingsManager.wheel_mode

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wheel="):
			var m := a.substr(8)
			if m == WheelPad.MODE_FIXED or m == WheelPad.MODE_FLOAT:
				_wheel.wheel_mode = m

	_relayout.call_deferred()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var t := event as InputEventScreenTouch
	if t == null:
		return
	if t.pressed:
		if _wheel != null and _wheel.wheel_mode == WheelPad.MODE_FLOAT:

			if _is_on_button(t.position):
				return
			var vis := Adaptive.visible_size(get_viewport())
			if t.position.x <= vis.x * 0.5:

				_wheel.float_begin(t.index, t.position)
				get_viewport().set_input_as_handled()
				return

			if _jump_finger == -1 and t.position.y > UI_STRIP_TOP:
				_jump_finger = t.index
				Input.action_press("jump")
				tap_burst_at(t.position)
				get_viewport().set_input_as_handled()
			return

		if _jump_finger == -1 and t.position.y > UI_STRIP_TOP 			and not _pos_reserved(t.position):
			_jump_finger = t.index
			Input.action_press("jump")
			tap_burst_at(t.position)
			get_viewport().set_input_as_handled()
	elif t.index == _jump_finger:
		_jump_finger = -1
		Input.action_release("jump")


func _is_on_button(pos: Vector2) -> bool:
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if not (b.btn as Control).is_visible_in_tree():
			continue
		if (b.rect as Rect2).grow(HIT_MARGIN).has_point(pos):
			return true
	return false


# 浮动模式不查这里:轮盘不得占满半屏热区,否则按住转向时第二指跳跃被吞。
func _pos_reserved(pos: Vector2) -> bool:
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if not (b.btn as Control).is_visible_in_tree():
			continue
		if (b.rect as Rect2).grow(HIT_MARGIN).has_point(pos):
			return true
	return _wheel != null and _wheel.holds_point(pos)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_jump_finger = -1
		Input.action_release("jump")
		if _wheel != null:
			_wheel.force_release()


func set_in_game(on: bool) -> void:
	in_game = on
	if on:
		visible = DisplayServer.is_touchscreen_available() or forced
	else:
		_release_all()
		visible = false


func toggle() -> void:
	forced = not forced
	var on := in_game and (forced or DisplayServer.is_touchscreen_available())
	if not on:
		_release_all()
	visible = on


func is_forced() -> bool:
	return forced


func wheel_mode() -> String:
	return _wheel.wheel_mode if _wheel != null else SettingsManager.wheel_mode


func set_switch_available(_on: bool) -> void:
	pass


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


func _relayout() -> void:
	if _root == null or _wheel == null:
		return
	var vis := Adaptive.visible_size(get_viewport())
	var ins := Adaptive.safe_insets(get_viewport())
	var left := ins.x
	var top := ins.y
	var right := ins.z

	var half_w := clampf(vis.x * 0.085, 108.0, 148.0)
	var half_h := clampf(half_w * 0.30, 24.0, 40.0)

	var wheel_center := Vector2(left + 26.0 + half_w, vis.y * 3.0 / 4.0)
	_wheel.setup(half_w, half_h, wheel_center)

	var order := ["recall", "pause"]
	var spacing := ICON_SIZE_SMALL + 14.0
	for k in order.size():
		var action: String = order[k]
		var b: Dictionary = _buttons[action]
		var sz := Vector2(b.icon_px, b.icon_px)
		var pos := Vector2(
			vis.x - right - 26.0 - sz.x - k * spacing,
			top + 76.0)
		var btn: Button = b.btn
		btn.position = pos
		btn.size = sz
		b.rect = Rect2(pos, sz)

		var label: Label = b.label
		label.position = Vector2(pos.x + sz.x / 2.0 - 40.0, pos.y + sz.y + 2.0)


func _wire_button(action: String, btn: Button, glyph: UiGlyph, label: Label,
		icon_rel: String, icon_on_rel: String) -> void:
	# v0.55.1:改用引擎 Button 控件(R0 引擎自带优先):命中即整键,
	# 触屏经 emulate_mouse_from_touch 走引擎命中;动作语义保持 Input.action_*
	# 管线不变(is_action_just_pressed 消费方无感)。
	# v0.65.0 项目风格重置:硬投影键帽 + 按压红缘下沉 + 缩放回弹手感。
	var tick: ColorRect = btn.get_node_or_null("RecallTick")
	if tick == null:
		tick = btn.get_node_or_null("PauseTick")
	if tick != null:
		tick.color = Color(Palette.I.red, 0.9)
	btn.add_theme_stylebox_override("normal", _keycap_style(0.78, 0.30, 4.0, 0.50))
	btn.add_theme_stylebox_override("hover", _keycap_style(0.84, 0.45, 4.0, 0.50))
	btn.add_theme_stylebox_override("pressed", _keycap_style(0.92, 0.85, 1.0, 0.40,
		Palette.I.red))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pivot_offset = btn.size / 2.0
	btn.button_down.connect(func() -> void:
		buzz(24)
		Input.action_press(action)
		_flash_icon(action, true)
		_press_pop(btn, 0.92))
	btn.button_up.connect(func() -> void:
		Input.action_release(action)
		_flash_icon(action, false)
		_press_pop(btn, 1.0))
	Ui.style(label, 12, Ui.LIGHT, Color(Palette.I.paper, 0.8),
		HORIZONTAL_ALIGNMENT_CENTER)
	_buttons[action] = {"btn": btn, "label": label, "icon_px": ICON_SIZE_SMALL,
		"rect": Rect2(), "glyph": glyph, "icon": icon_rel, "icon_on": icon_on_rel}


static func _keycap_style(bg_a: float, edge_a: float, shadow_off := 4.0,
		shadow_a := 0.50, edge_col: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.I.ink_2, bg_a)
	sb.border_color = edge_col if edge_col.a > 0.0 else Color(Palette.I.paper, edge_a)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(0)
	sb.shadow_color = Color(Palette.I.ink, shadow_a)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(shadow_off, shadow_off)
	return sb


## 按压缩放回弹(手感):pivot 中心,短 tween 弹回。
func _press_pop(btn: Button, target: float) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE * target, 0.06) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _flash_icon(action: String, on: bool) -> void:
	var b: Dictionary = _buttons.get(action, {})
	if b.is_empty():
		return
	var key: String = (b.icon_on if on else b.icon) as String
	var g: UiGlyph = b.glyph
	if g.glyph_key != key:
		g.set_key(key)


static func buzz(ms := 24) -> void:
	if SettingsManager.vibration:
		Input.vibrate_handheld(ms)


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
	ramp.colors = PackedColorArray([Palette.I.paper, Palette.I.paper, Palette.I.red])
	burst.color_initial_ramp = ramp
	burst.position = pos
	burst.finished.connect(burst.queue_free)
	_root.add_child(burst)
	var ring := TapRing.new()
	ring.position = pos
	_root.add_child(ring)


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
		draw_polyline(pts, Color(Palette.I.paper, a), 2.0, true)


func _process(_delta: float) -> void:

	for action in _buttons:
		var b: Dictionary = _buttons[action]
		var btn: Button = b.btn
		var target := 1.0 if btn.is_hovered() or btn.is_pressed() else 0.85
		btn.self_modulate.a = move_toward(btn.self_modulate.a, target, 0.12)
		var ltarget := 1.0 if btn.is_pressed() else 0.72
		var label: Label = b.label
		label.modulate.a = move_toward(label.modulate.a, ltarget, 0.12)
