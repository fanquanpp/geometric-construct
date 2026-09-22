class_name CameraRig
extends Camera2D


var _look := Vector2.ZERO
var _pulse := 0.0
var _kick := 0.0
var _snapped := false

func _ready() -> void:
	add_to_group("camera_rig")
	make_current()
	position_smoothing_enabled = false
	if Main.I != null:
		Main.I.camera_rig = self


func on_switch() -> void:
	_pulse = 0.4


func freeze(dur := 0.12) -> void:
	if SettingsManager.reduced_motion or Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	var t := get_tree().create_timer(dur, true, false, true)
	t.timeout.connect(func() -> void: Engine.time_scale = 1.0)


func kick(strength := 6.0) -> void:
	if SettingsManager.reduced_motion:
		return
	_kick = minf(_kick + strength, 12.0)

func _physics_process(delta: float) -> void:
	var m = Main.I
	if m == null or m.players.is_empty():
		return
	var targets: Array = m.camera_targets()
	if targets.is_empty():
		return

	if not _snapped:
		position = _frame_center(targets)
		_look = Vector2.ZERO
		_snapped = true
		return
	_pulse = maxf(_pulse - delta, 0.0)

	if _kick > 0.05:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _kick
		_kick = maxf(_kick - 34.0 * delta, 0.0)
	elif offset != Vector2.ZERO:
		offset = offset.lerp(Vector2.ZERO, 1.0 - exp(-14.0 * delta))

	var look_target := Vector2.ZERO
	var v_avg := Vector2.ZERO
	var v_main: Player = targets[0]
	for t in targets:
		v_avg += t.velocity
	v_avg /= targets.size()
	look_target = Vector2(
		clampf(v_avg.x * 0.24, -130.0, 130.0),
		clampf(v_avg.y * 0.06, -40.0, 56.0))
	_look = _look.lerp(look_target, 1.0 - exp(-4.0 * delta))

	var speed_mult := absf(v_avg.x) / MovementTuning.I.run_speed
	var target_zoom := clampf(1.02 - 0.085 * maxf(speed_mult, v_main.def.base_speed),
		0.80, 1.0)
	if _pulse > 0.0:
		target_zoom *= 0.94
	if m.debug_zoom > 0.0:
		zoom = Vector2(m.debug_zoom, m.debug_zoom)
		target_zoom = m.debug_zoom
	elif targets.size() > 1:

		target_zoom = minf(target_zoom, _fit_zoom(targets))

	var k := 1.0 - exp((-9.0 if _pulse > 0.0 else -5.5) * delta)
	position = position.lerp(_frame_center(targets) + _look, k)
	var z := lerpf(zoom.x, target_zoom, 1.0 - exp(-3.5 * delta))
	zoom = Vector2(z, z)


func _frame_center(targets: Array) -> Vector2:
	var c := Vector2.ZERO
	for t in targets:
		c += t.position
	return c / targets.size()


func _fit_zoom(targets: Array) -> float:
	var vp := get_viewport_rect().size
	var c := _frame_center(targets)
	var need := Vector2.ZERO
	for t in targets:
		need = (need.max((t.position - c).abs() * 2.0
			+ Vector2(320, 260)))
	return clampf(minf(vp.x / maxf(need.x, 1.0), vp.y / maxf(need.y, 1.0)), 0.62, 1.0)
