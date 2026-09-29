class_name Backdrop
extends CanvasLayer

# 背景层(常驻 CanvasLayer -10):五幕变奏 + 装饰活化 + 操作互动。
# 契约见 docs/design/procedural-art.md「背景动效」:
# - 结构全部落 scenes/world/backdrop.tscn;取色 SSOT = data/palette.tres,
#   幕变奏参数经 data/backdrop/*.tres(BackdropPreset)下发给装饰脚本与 shader;
# - 常驻动画走节点 transform(零重绘)/ shader TIME(GPU) / 粒子 speed_scale,
#   事件脉冲走一次性 Tween(同属性 kill 旧再建);
# - 双门控:SettingsManager.background_fx(设置面板「背景动效」)与
#   reduced_motion(总闸),任一关闭 = 停帧保静态(渐变天幕与装饰轮廓保留);
# - 视差对偶:移动端陀螺仪 / 桌面端鼠标(同组层同深度表),headless 跳过。

const PRESETS := {
	-1: "res://data/backdrop/menu.tres",
	0: "res://data/backdrop/act1.tres",
	1: "res://data/backdrop/act2.tres",
	2: "res://data/backdrop/act3.tres",
	3: "res://data/backdrop/act4.tres",
	4: "res://data/backdrop/act5.tres",
}
const GYRO_DEPTH := {"sun": 3.0, "planes": 6.0, "marks": 8.0}
const BASE_MOTES_FAR := 22
const BASE_MOTES_NEAR := 12

var _off_layers: Array = []
var _off := Vector2.ZERO
var _accel_lp := Vector3.ZERO
var _current_act := -99

var _sky_tween: Tween
var _flash_tween: Tween
var _layers_tween: Tween
var _land_tween: Tween

var _preset: BackdropPreset

@onready var _sky: ColorRect = %Sky
@onready var _deep: Parallax2D = %Deep
@onready var _deep_space = %DeepSpace
@onready var _planes_par: Parallax2D = %Planes
@onready var _geo_planes = %GeoPlanes
@onready var _sun_par: Parallax2D = %Sun
@onready var _geo_sun = %GeoSun
@onready var _orbits = %OrbitRings
@onready var _marks_par: Parallax2D = %Marks
@onready var _geo_marks = %GeoMarks
@onready var _ridge_far_par: Parallax2D = %RidgeFar
@onready var _ridge_far = %RidgeFarBody
@onready var _ridge_near_par: Parallax2D = %RidgeNear
@onready var _ridge_near = %RidgeNearBody
@onready var _motes_far: CPUParticles2D = %MotesFar
@onready var _motes_near: CPUParticles2D = %MotesNear
@onready var _speed_lines = %SpeedLines
@onready var _red_wave = %RedWave
@onready var _flash: ColorRect = %Flash


func _ready() -> void:
	_off_layers = [
		{"node": _sun_par, "depth": GYRO_DEPTH["sun"]},
		{"node": _planes_par, "depth": GYRO_DEPTH["planes"]},
		{"node": _marks_par, "depth": GYRO_DEPTH["marks"]},
	]
	apply_act(-1)


func _fx_enabled() -> bool:
	return SettingsManager.background_fx and not SettingsManager.reduced_motion


## 门控变化入口(Main 载入设置后、设置面板切换后调用)。
func refresh_gate() -> void:
	var on := _fx_enabled()
	set_process(on)
	_deep_space.set_animated(on)
	_geo_sun.set_animated(on)
	_geo_planes.set_animated(on)
	_orbits.set_animated(on)
	_speed_lines.set_animated(on)
	var mat := _sky.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("anim", 1.0 if on else 0.0)
	_motes_far.speed_scale = 1.0 if on else 0.0
	_motes_near.speed_scale = 1.0 if on else 0.0
	if not on:
		for entry: Dictionary in _off_layers:
			(entry["node"] as Parallax2D).scroll_offset = Vector2.ZERO


func _process(delta: float) -> void:
	var target := Vector2.ZERO
	if OS.has_feature("mobile"):
		var accel := Input.get_accelerometer()
		if accel == Vector3.ZERO:
			return
		_accel_lp = _accel_lp.lerp(accel, clampf(3.0 * delta, 0.0, 1.0))
		var g := _accel_lp
		target = Vector2(
			clampf(-g.y / 9.81, -1.0, 1.0), clampf(g.x / 9.81, -1.0, 1.0))
	else:
		if DisplayServer.get_name() == "headless":
			return
		var vp := get_viewport()
		var half := vp.get_visible_rect().size * 0.5
		if half.x <= 1.0 or half.y <= 1.0:
			return
		var mp := vp.get_mouse_position()
		target = Vector2(
			clampf((mp.x - half.x) / half.x, -1.0, 1.0),
			clampf((mp.y - half.y) / half.y, -1.0, 1.0))
	_off = _off.lerp(target, 1.0 - exp(-3.0 * delta))
	for entry: Dictionary in _off_layers:
		(entry["node"] as Parallax2D).scroll_offset = _off * entry["depth"]


## 幕变奏下发:act_i = 0..4(五幕)/ -1(菜单与幕外)。同档重复跳过。
func apply_act(act_i: int) -> void:
	if act_i == _current_act:
		return
	_current_act = act_i
	var preset: BackdropPreset = load(PRESETS[act_i])
	_preset = preset

	_tween_sky(preset)
	_geo_sun.spin = preset.sun_spin
	_geo_sun.pulse = preset.sun_pulse
	_geo_planes.set_count(preset.planes)
	_geo_marks.set_density(preset.marks)
	_geo_marks.set_accent(preset.accent)
	_deep_space.set_twinkle(preset.twinkle)
	_orbits.set_count(preset.orbits)
	_orbits.set_accent(Color(preset.accent, 0.4))
	_ridge_far.set_amplitude(preset.ridge_far)
	_ridge_near.set_amplitude(preset.ridge_near)
	_motes_far.amount = int(round(BASE_MOTES_FAR * preset.motes))
	_motes_near.amount = int(round(BASE_MOTES_NEAR * preset.motes))


## 天幕渐变缓变(幕切换 0.8s 过渡;被转场幕布遮盖,属氛围余韵)。
func _tween_sky(preset: BackdropPreset) -> void:
	var mat := _sky.material as ShaderMaterial
	if mat == null:
		return
	var from_top: Color = mat.get_shader_parameter("sky_top")
	var from_bottom: Color = mat.get_shader_parameter("sky_bottom")
	var from_alpha: float = mat.get_shader_parameter("cloud_alpha")
	mat.set_shader_parameter("cloud_speed", preset.cloud_speed)
	if _sky_tween != null:
		_sky_tween.kill()
	_sky_tween = create_tween()
	_sky_tween.set_parallel(true)
	_sky_tween.tween_method(
		func(c: Color) -> void: mat.set_shader_parameter("sky_top", c),
		from_top, preset.sky_top, 0.8)
	_sky_tween.tween_method(
		func(c: Color) -> void: mat.set_shader_parameter("sky_bottom", c),
		from_bottom, preset.sky_bottom, 0.8)
	_sky_tween.tween_method(
		func(a: float) -> void: mat.set_shader_parameter("cloud_alpha", a),
		from_alpha, preset.cloud_alpha, 0.8)


## 落地脉冲:impact 越大,山脊下沉越深(BOUNCE 弹回)+ 天幕微涌。
func pulse_land(impact: float) -> void:
	if not _fx_enabled():
		return
	var k := clampf((impact - 120.0) / 1600.0, 0.0, 1.0)
	if k <= 0.01:
		return
	if _land_tween != null:
		_land_tween.kill()
	_ridge_far_par.scroll_offset.y = 0.0
	_ridge_near_par.scroll_offset.y = 0.0
	_land_tween = create_tween()
	_land_tween.set_parallel(true)
	_land_tween.tween_property(_ridge_far_par, "scroll_offset:y", k * 10.0, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_land_tween.tween_property(_ridge_near_par, "scroll_offset:y", k * 6.0, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_land_tween.chain().tween_property(
		_ridge_far_par, "scroll_offset:y", 0.0, 0.34) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_land_tween.parallel().tween_property(
		_ridge_near_par, "scroll_offset:y", 0.0, 0.34) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_flash_burst(Color(Palette.I.paper, 1.0), k * 0.05)


## 切换涟漪:受控体色一闪 + 全景层 alpha 微沉回浮(与聚焦透明度语言同族)。
func pulse_switch(color: Color) -> void:
	if not _fx_enabled():
		return
	_flash_burst(color, 0.05)
	_layers_dip(0.88, 0.06, 0.32)


## 到站光涌:太阳棱环脉冲(满员更强)+ 幕强调色一闪。
func pulse_arrive(full: bool) -> void:
	if not _fx_enabled():
		return
	_geo_sun.burst(1.12 if full else 1.05)
	var c := Palette.I.paper if _preset == null else _preset.accent
	_flash_burst(c, 0.08 if full else 0.05)


## 死亡红波:三道音波横扫 + 全景层压暗回浮。
func pulse_death() -> void:
	if not _fx_enabled():
		return
	_red_wave.fire(Color(Palette.I.red, 1.0))
	_layers_dip(0.82, 0.12, 0.55)


## 全景层 alpha 微沉回浮(一次性;同属性统一走 _layers_tween 防竞争)。
func _layers_dip(low: float, down_s: float, up_s: float) -> void:
	var layers := [
		_deep, _planes_par, _sun_par, _marks_par, _ridge_far_par, _ridge_near_par]
	if _layers_tween != null:
		_layers_tween.kill()
	_layers_tween = create_tween()
	_layers_tween.set_parallel(true)
	for l: Parallax2D in layers:
		_layers_tween.tween_property(l, "modulate:a", low, down_s) \
			.from_current()
	_layers_tween.chain()
	_layers_tween.tween_property(layers[0], "modulate:a", 1.0, up_s) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in range(1, layers.size()):
		_layers_tween.parallel().tween_property(layers[i], "modulate:a", 1.0, up_s) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _flash_burst(c: Color, peak: float) -> void:
	if peak <= 0.004:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.color = Color(c.r, c.g, c.b, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", peak, 0.05).from(0.0)
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
