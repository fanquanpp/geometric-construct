class_name Backdrop
extends CanvasLayer

# 结构全部落 scenes/world/backdrop.tscn(节点化,编辑器可视);
# 本脚本只负责陀螺仪视差接线与派生色回填(色值 SSOT = data/palette.tres)。

const GYRO_DEPTH := {"sun": 3.0, "planes": 6.0, "marks": 8.0}
var _gyro_layers: Array = []
var _gyro_off := Vector2.ZERO
var _accel_lp := Vector3.ZERO

@onready var _sky: ColorRect = %Sky
@onready var _sun: Parallax2D = %Sun
@onready var _planes: Parallax2D = %Planes
@onready var _marks: Parallax2D = %Marks
@onready var _motes_far: CPUParticles2D = %MotesFar
@onready var _motes_near: CPUParticles2D = %MotesNear

func _ready() -> void:
	_sky.color = Palette.I.ink
	_motes_far.color = Color(Palette.I.paper, 0.09)
	_motes_near.color = Color(Palette.I.paper, 0.15)
	_gyro_layers = [
		{"node": _sun, "depth": GYRO_DEPTH["sun"]},
		{"node": _planes, "depth": GYRO_DEPTH["planes"]},
		{"node": _marks, "depth": GYRO_DEPTH["marks"]},
	]

func _process(delta: float) -> void:
	if not OS.has_feature("mobile"):
		set_process(false)
		return
	var accel := Input.get_accelerometer()
	if accel == Vector3.ZERO:
		return

	_accel_lp = _accel_lp.lerp(accel, clampf(3.0 * delta, 0.0, 1.0))
	var g := _accel_lp
	var target := Vector2(
		clampf(-g.y / 9.81, -1.0, 1.0), clampf(g.x / 9.81, -1.0, 1.0))
	_gyro_off = _gyro_off.lerp(target, 1.0 - exp(-3.0 * delta))
	for entry: Dictionary in _gyro_layers:
		(entry["node"] as Parallax2D).scroll_offset = _gyro_off * entry["depth"]
