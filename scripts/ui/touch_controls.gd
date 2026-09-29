class_name TouchControls
extends CanvasLayer


const ICON_SIZE_SMALL := 76.0
const UI_STRIP_TOP := 200.0


const HIT_MARGIN := 18.0

var forced := false
var in_game := false

var _root: Control
var _buttons := {}
var _wheel: WheelPad
var _jump_finger := -1


func _ready() -> void:
	layer = 12

	forced = OS.get_cmdline_user_args().has("--touch")

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.resized.connect(_relayout)
	get_viewport().size_changed.connect(_relayout)

	_add_button("buttons/recall", "buttons/recall-on",
		"recall", "召回")
	_add_button("buttons/pause", "buttons/pause-on",
		"pause", "暂停")

	_wheel = WheelPad.new()
	_root.add_child(_wheel)
	_wheel.wheel_mode = SettingsManager.wheel_mode

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wheel="):
			var m := a.substr(8)
			if m == WheelPad.MODE_FIXED or m == WheelPad.MODE_FLOAT:
				_wheel.wheel_mode = m

	visible = false
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
		if not (b.btn as TouchScreenButton).is_visible_in_tree():
			continue
		if (b.rect as Rect2).grow(HIT_MARGIN).has_point(pos):
			return true
	return false


# 浮动模式不查这里:轮盘不得占满半屏热区,否则按住转向时第二指跳跃被吞。
func _pos_reserved(pos: Vector2) -> bool:
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if not (b.btn as TouchScreenButton).is_visible_in_tree():
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
			vis.x - right - 26.0 - sz.x / 2.0 - k * spacing,
			top + 92.0 + sz.y / 2.0) - sz / 2.0
		b.btn.position = pos
		b.rect = Rect2(pos, sz)

		var label: Label = b.label
		label.position = Vector2(pos.x + sz.x / 2.0 - 40.0, pos.y + sz.y + 4.0)


func _add_button(icon_rel: String, icon_on_rel: String, action: String,
		label_text: String) -> void:
	var btn := TouchScreenButton.new()
	btn.action = action
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	btn.shape = shape
	btn.shape_centered = false
	var s := ICON_SIZE_SMALL / 64.0
	btn.scale = Vector2(s, s)
	btn.modulate = Color(1, 1, 1, 0.66)
	btn.passby_press = true

	btn.pressed.connect(func() -> void: buzz(24))
	_root.add_child(btn)
	var glyph := UiGlyph.Node2DGlyph.new(icon_rel, 32.0)
	glyph.position = Vector2(32, 32)
	btn.add_child(glyph)
	var label := Ui.l(label_text, 12, Ui.LIGHT, Color(Palette.I.paper, 0.8),
		HORIZONTAL_ALIGNMENT_CENTER)
	label.size = Vector2(80, 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	_buttons[action] = {"btn": btn, "label": label, "icon_px": ICON_SIZE_SMALL,
		"rect": Rect2(), "glyph": glyph, "icon": icon_rel, "icon_on": icon_on_rel}


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
		var btn: TouchScreenButton = b.btn
		var target := 1.0 if btn.is_pressed() else 0.66
		btn.modulate.a = move_toward(btn.modulate.a, target, 0.12)
		var ltarget := 1.0 if btn.is_pressed() else 0.72
		var label: Label = b.label
		label.modulate.a = move_toward(label.modulate.a, ltarget, 0.12)
		var key: String = (b.icon_on if btn.is_pressed() else b.icon) as String
		var g: UiGlyph.Node2DGlyph = b.glyph
		if g.glyph_key != key:
			g.set_key(key)


class WheelPad extends Control:
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
		_knob_r = clampf(half_h * 0.72, 18.0, 30.0)
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
		TouchControls.buzz(12)
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

		var idle_a := 0.18 if (wheel_mode == MODE_FLOAT and _finger == -1) else 1.0
		if idle_a != _idle_a:
			_idle_a = idle_a
			queue_redraw()

	func _draw() -> void:
		if Palette.I == null:
			return
		var a := _idle_a
		var r := Rect2(Vector2.ZERO, size)
		var mid_y := size.y / 2.0
		draw_rect(r, Color(Palette.I.ink_3, 0.55 * a))
		draw_rect(r, Color(Palette.I.red if sprinting else Palette.I.paper,
			(0.6 if sprinting else 0.30) * a), false, 2.0)
		draw_rect(Rect2(Vector2(size.x / 2.0 - 2, mid_y - 9), Vector2(4, 18)),
			Color(Palette.I.paper, 0.22 * a))
		if strength > 0.0:
			DrawKit.chevron(self, Vector2(size.x - 20.0, mid_y), Vector2(1, 0),
				18.0, Color(Palette.I.red if sprinting else Palette.I.paper,
					0.85 * a), 3.0)
		elif strength < 0.0:
			DrawKit.chevron(self, Vector2(20.0, mid_y), Vector2(-1, 0),
				18.0, Color(Palette.I.red if sprinting else Palette.I.paper,
					0.85 * a), 3.0)
		var kc := Vector2(size.x / 2.0 + _knob_x, mid_y)
		DrawKit.ngon_fill(self, kc, _knob_r, 16,
			Color(Palette.I.red if sprinting else Palette.I.paper, 0.9 * a))
		DrawKit.ngon_line(self, kc, _knob_r, 16, Color(Palette.I.ink, 0.45 * a), 2.0)
		draw_circle(kc, _knob_r * 0.3, Color(Palette.I.ink, 0.55 * a))
