class_name CameraRig
extends Camera2D


## 双目标取景下限(audit ⑧;具名常量供 ui 包 edge_indicator 跨包读取,
## 取代散落字面量):两体拉到极限距离时镜头至多拉远到此 zoom——
## 「提示 + 压镜头上限」方案,不做动态分屏。
const MIN_FIT_ZOOM := 0.62

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
	if not SettingsManager.screen_shake:
		return
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
	# 前瞻与速度系数全 targets 化(audit ⑧):不再 v_avg 单看一头——双目标
	# 按速度加权(更快者话语权大),速度系数取全员最快者;单人单目标
	# 权重恒 1,与旧式完全一致。
	var ws := _target_weights(targets)
	var v_w := Vector2.ZERO
	for i in targets.size():
		v_w += (targets[i] as Player).velocity * float(ws[i])
	look_target = Vector2(
		clampf(v_w.x * 0.24, -130.0, 130.0),
		clampf(v_w.y * 0.06, -40.0, 56.0))
	_look = _look.lerp(look_target, 1.0 - exp(-4.0 * delta))

	var speed_factor := 0.0
	for t in targets:
		speed_factor = maxf(speed_factor,
			absf((t as Player).velocity.x) / MovementTuning.I.run_speed)
		speed_factor = maxf(speed_factor, (t as Player).def.base_speed)
	var target_zoom := clampf(1.02 - 0.085 * speed_factor, 0.80, 1.0)
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


## 双目标权重(audit ⑧):速度大者权重大——取景中心与前瞻偏向更快者,
## 落后者不再把镜头拽回(算术平均的病灶);全员静止退化为等权,单目标
## 由调用方短路,和恒为 1。
func _target_weights(targets: Array) -> Array:
	var ws: Array = []
	var total := 0.0
	for t in targets:
		var w := 1.0 + absf((t as Player).velocity.x) / MovementTuning.I.run_speed
		ws.append(w)
		total += w
	for i in ws.size():
		var w2: float = ws[i]
		ws[i] = w2 / total
	return ws


## 取景中心:单目标直取;双目标按 _target_weights 加权(总权重 1,
## 全员静止 = 算术平均)。
func _frame_center(targets: Array) -> Vector2:
	if targets.size() == 1:
		return (targets[0] as Player).position
	var ws := _target_weights(targets)
	var c := Vector2.ZERO
	for i in targets.size():
		c += (targets[i] as Player).position * float(ws[i])
	return c


## 双目标间距只读接口(audit ⑧;ui 差值读数消费):当前取景目标两两
## 最大距离 px,单目标/无目标 = 0。
func targets_spread() -> float:
	var m = Main.I
	if m == null:
		return 0.0
	var targets: Array = m.camera_targets()
	if targets.size() < 2:
		return 0.0
	var d := 0.0
	for i in targets.size():
		for j in range(i + 1, targets.size()):
			d = maxf(d, (targets[i] as Player).position \
				.distance_to((targets[j] as Player).position))
	return d


func _fit_zoom(targets: Array) -> float:
	var vp := get_viewport_rect().size
	var c := _frame_center(targets)
	var need := Vector2.ZERO
	for t in targets:
		need = (need.max(((t as Player).position - c).abs() * 2.0
			+ Vector2(320, 260)))
	return clampf(minf(vp.x / maxf(need.x, 1.0), vp.y / maxf(need.y, 1.0)),
		MIN_FIT_ZOOM, 1.0)
