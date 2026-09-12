class_name CameraRig
extends Camera2D

## 镜头:始终以受控几何体为画面中心,带左右前瞻偏移与速度变焦;
## 切换几何体时快速平移 + 缩放脉冲过渡(不再要求全员在视野内)。

var _look := Vector2.ZERO
var _pulse := 0.0
var _kick := 0.0
var _snapped := false

func _ready() -> void:
	make_current()
	position_smoothing_enabled = false
	if Main.I != null:
		Main.I.camera_rig = self

## 切换几何体:短暂加速平移 + 缩放收缩回弹。
func on_switch() -> void:
	_pulse = 0.4

## 冲击瞬间的镜头微震(死亡 / 重落地),连续冲击可叠加,快速衰减。
func kick(strength := 6.0) -> void:
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

	# 微震:随机方向抖动,幅度指数衰减归零
	if _kick > 0.05:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _kick
		_kick = maxf(_kick - 34.0 * delta, 0.0)
	elif offset != Vector2.ZERO:
		offset = offset.lerp(Vector2.ZERO, 1.0 - exp(-14.0 * delta))

	# 左右前瞻:随水平速度偏移一点,增加行驶感与手感(多目标取均值)
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

	# 变焦:速度越快视野略拉远;切换瞬间轻微收缩再回弹
	# (debug_zoom > 0:调试锁定变焦 —— 网格 LOD / 远景档截图验证用)
	var speed_mult := absf(v_avg.x) / MovementTuning.I.run_speed
	var target_zoom := clampf(1.02 - 0.085 * maxf(speed_mult, v_main.def.base_speed),
		0.80, 1.0)
	if _pulse > 0.0:
		target_zoom *= 0.94
	if m.debug_zoom > 0.0:
		zoom = Vector2(m.debug_zoom, m.debug_zoom)
		target_zoom = m.debug_zoom
	elif targets.size() > 1:
		# 双人动态缩放框(net.md §3):夹住所有取景点,超距拉远到下限
		target_zoom = minf(target_zoom, _fit_zoom(targets))

	var k := 1.0 - exp((-9.0 if _pulse > 0.0 else -5.5) * delta)
	position = position.lerp(_frame_center(targets) + _look, k)
	var z := lerpf(zoom.x, target_zoom, 1.0 - exp(-3.5 * delta))
	zoom = Vector2(z, z)

## 多目标取景中心(单目标 = 其位置)。
func _frame_center(targets: Array) -> Vector2:
	var c := Vector2.ZERO
	for t in targets:
		c += t.position
	return c / targets.size()

## 双人动态缩放框:视口恰好夹住全部目标(+ 边距),钳在 [0.62, 1]。
func _fit_zoom(targets: Array) -> float:
	var vp := get_viewport_rect().size
	var c := _frame_center(targets)
	var need := Vector2.ZERO
	for t in targets:
		need = (need.max((t.position - c).abs() * 2.0
			+ Vector2(320, 260)))
	return clampf(minf(vp.x / maxf(need.x, 1.0), vp.y / maxf(need.y, 1.0)), 0.62, 1.0)
