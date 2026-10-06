class_name Backdrop
extends CanvasLayer

# 背景层(常驻 CanvasLayer -10):「极简几何·构成主义·方框与数据流」五带
# 视差重设计(v0.70 整体清退旧自然天文语义:星阵/太阳/三角巨面/柔边云)。
# - 五带深度(scroll_scale.x 沿用 v0.68 深度语义):
#   网格纸基座 0.05 → 大楔形 0.08(每屏唯一大几何体,利西茨基动势)→
#   数据流网络 0.16 → 字符雨 0.24 → 方框轨道群 0.32 → 折线地平 0.66 →
#   前景速度带 1.25(事件驱动);
# - 结构全部落 scenes/world/backdrop.tscn;取色 SSOT = data/palette.tres,
#   幕变奏参数经 data/backdrop/*.tres(BackdropPreset)下发给装饰脚本;
#   GPU 层颜色一律经 uniform(shaders/speed_lines.gdshader、
#   shaders/light_streaks.gdshader);
# - 多彩纪律:每幕 accent 单路(menu=paper、act1-4 = blue/yellow/orange/red
#   槽位现值);远带降阶 _far_band(明度收 15%+饱和 ×0.3-0.45+向冷端
#   hue 12° 环距偏移)只施加 accent,绝不施加语义色;语义红只进死亡事件层
#   (red_wave),背景装饰永不出现正红实块;
# - 节拍化:远带装饰只绑 Ambience.SPECIAL 拍(MAIN 拍留给玩法感知);
#   拍缺席(headless/独立实例)或门控关时自由节奏回退:信号在途/方点巡行/
#   字符步进恒在,拍只叠加拍相不替代慢巡;
# - 动效卫生:常驻位移走节点 transform(零重绘),字符雨 15fps 步进节流,
#   sweep/纸缘脉冲为事件级单场;事件脉冲一次性 Tween(同属性 kill 旧再建);
# - 双门控:SettingsManager.background_fx ∧ ¬reduced_motion,任一关闭 =
#   停帧保静态轮廓(网格纸基座/大楔形/地平剪影保留,含 GPU 速度线停帧);
# - 视差对偶:移动端陀螺仪 / 桌面端鼠标(同组层同深度表,按所在带
#   scroll_scale 等比重标),headless 跳过。

const PRESETS := {
	-1: "res://data/backdrop/menu.tres",
	0: "res://data/backdrop/act1.tres",
	1: "res://data/backdrop/act2.tres",
	2: "res://data/backdrop/act3.tres",
	3: "res://data/backdrop/act4.tres",
}
# 视差对偶深度系数:按所在带 scroll_scale.x 等比重标(旧基准
# sun 0.08→3 / planes 0.16→6 / marks 0.24→8,≈25 倍;顶部 0.66 带 ≈16,
# 即旧最大值 ×2 量级)。基座网格与折线地平不入表(纸面本体与大剪影免抖)。
const GYRO_DEPTH := {"wedge": 2.0, "net": 4.0, "rain": 6.0, "tracks": 8.0}
const FAR_V_SQUEEZE := 0.85
const FAR_HUE := 12.0 / 360.0
const COLD_ANCHOR := 0.55

var _off_layers: Array = []
var _off := Vector2.ZERO
var _accel_lp := Vector3.ZERO
var _current_act := -99

var _streak_tween: Tween
var _flash_tween: Tween
var _layers_tween: Tween
var _land_tween: Tween
var _horizon_tween: Tween
var _wedge_rot_tween: Tween
var _beat_wired := false

var _preset: BackdropPreset

@onready var _field: ColorRect = %Field
@onready var _grid_band: Parallax2D = %GridBand
@onready var _wedge_band: Parallax2D = %WedgeBand
@onready var _net_band: Parallax2D = %NetBand
@onready var _rain_band: Parallax2D = %RainBand
@onready var _track_band: Parallax2D = %TrackBand
@onready var _horizon_band: Parallax2D = %HorizonBand
@onready var _wedge = %MegaWedge
@onready var _net = %DataNet
@onready var _rain = %CharRain
@onready var _tracks = %BoxTracks
@onready var _horizon_far = %HorizonFar
@onready var _horizon_near = %HorizonNear
@onready var _speed_lines = %SpeedLines
@onready var _streaks: ColorRect = %Streaks
@onready var _red_wave = %RedWave
@onready var _flash: ColorRect = %Flash


func _ready() -> void:
	_field.color = Palette.I.ink
	_off_layers = [
		{"node": _wedge_band, "depth": GYRO_DEPTH["wedge"]},
		{"node": _net_band, "depth": GYRO_DEPTH["net"]},
		{"node": _rain_band, "depth": GYRO_DEPTH["rain"]},
		{"node": _track_band, "depth": GYRO_DEPTH["tracks"]},
	]
	_speed_lines.crossed.connect(_on_speed_crossed)
	apply_act(-1)


func _fx_enabled() -> bool:
	return SettingsManager.background_fx and not SettingsManager.reduced_motion


## 门控变化入口(Main 载入设置后、设置面板切换后调用)。
func refresh_gate() -> void:
	_wire_beat()
	var on := _fx_enabled()
	set_process(on)
	_wedge.set_animated(on)
	_net.set_animated(on)
	_rain.set_animated(on)
	_tracks.set_animated(on)
	_horizon_far.set_animated(on)
	_horizon_near.set_animated(on)
	_speed_lines.set_animated(on)
	_set_streak(0.0, true)
	var smat := _streaks.material as ShaderMaterial
	if smat != null:
		smat.set_shader_parameter("anim", 1.0 if on else 0.0)
	if not on:
		_kill_event_tweens()
		for entry: Dictionary in _off_layers:
			(entry["node"] as Parallax2D).scroll_offset = Vector2.ZERO


## 门控关:事件级一次性 Tween 全数清算,停帧保静态轮廓。
func _kill_event_tweens() -> void:
	if _streak_tween != null:
		_streak_tween.kill()
		_streak_tween = null
	if _flash_tween != null:
		_flash_tween.kill()
		_flash_tween = null
	if _layers_tween != null:
		_layers_tween.kill()
		_layers_tween = null
	if _land_tween != null:
		_land_tween.kill()
		_land_tween = null
	if _horizon_tween != null:
		_horizon_tween.kill()
		_horizon_tween = null
	if _wedge_rot_tween != null:
		_wedge_rot_tween.kill()
		_wedge_rot_tween = null
	_flash.modulate.a = 0.0
	_horizon_far.position = Vector2.ZERO
	_horizon_near.position = Vector2.ZERO


## 节拍接线(信号订阅,非轮询):Main.tscn 中 Backdrop 先于 Ambience 装配,
## 故推迟到首次 refresh_gate(彼时全部子节点 _ready 已先行)。无 Ambience
## (headless 检查/独立实例)不订阅,自由节奏回退(信号/巡行/步进恒在)。
func _wire_beat() -> void:
	if _beat_wired or Ambience.I == null:
		return
	_beat_wired = true
	Ambience.I.beat.connect(_on_ambience_beat)


func _on_ambience_beat(kind: int, index: int) -> void:
	if not _fx_enabled():
		return
	# 远带装饰只绑 SPECIAL 拍,MAIN 拍留给玩法感知。
	if kind == Ambience.BeatKind.SPECIAL:
		_net.on_beat(kind, index)
		_rain.on_beat(kind, index)
		_tracks.on_beat(kind, index)


## 速度阈值穿越(speed_lines 事件):阈值上流入光纱层缓起,阈值下缓落;
## 上穿同时做静态层活化(数据网络轻扫 + 地平纸缘脉冲)。
func _on_speed_crossed(on: bool) -> void:
	_set_streak(1.0 if on else 0.0)
	if on:
		var smat := _streaks.material as ShaderMaterial
		if smat != null:
			smat.set_shader_parameter("dir", _speed_lines.current_dir())
	if not on or not _fx_enabled():
		return
	_net.fire_sweep()
	_horizon_far.pulse_energy()
	_horizon_near.pulse_energy()


## 流光纱层强度(0-1):Tween 平滑趋近,instant 用于门控硬切。
func _set_streak(target: float, instant := false) -> void:
	var mat := _streaks.material as ShaderMaterial
	if mat == null:
		return
	if _streak_tween != null:
		_streak_tween.kill()
		_streak_tween = null
	if instant:
		mat.set_shader_parameter("strength", target)
		return
	_streak_tween = create_tween()
	_streak_tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("strength", v),
		float(mat.get_shader_parameter("strength")), target, 0.5)


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


## 幕变奏下发:act_i = 0..3(四幕)/ -1(菜单与幕外)。同档重复跳过。
## 逐幕预设只调参数不改结构;切幕一次性活化:楔形动势角缓转 + 网络轻扫。
func apply_act(act_i: int) -> void:
	if act_i == _current_act:
		return
	var first := _current_act == -99
	_current_act = act_i
	var preset: BackdropPreset = load(PRESETS[act_i])
	_preset = preset

	_wedge.accent = _far_band(preset.accent, 0.45)
	if first:
		_wedge.set_rotation_deg(preset.wedge_rot)
	_net.accent = _far_band(preset.accent, 0.35)
	_net.set_density(preset.net_density)
	_rain.accent = _far_band(preset.accent, 0.3)
	_rain.set_density(preset.rain_density)
	_tracks.accent = _far_band(preset.accent, 0.35)
	_tracks.set_count(preset.tracks)
	var smat := _streaks.material as ShaderMaterial
	if smat != null:
		smat.set_shader_parameter("col_accent", _far_band(preset.accent, 0.35))
	_tween_horizon(preset)
	if not first:
		_tween_wedge_rot(preset.wedge_rot)
		_net.fire_sweep()


## 远景带降阶(五带语言):明度对比压 15%(向中灰收拢)、饱和降至 sat_k
## 倍、追加向冷端(青-蓝锚 0.55)hue 12° 环距偏移;只施加 accent 主色,
## 语义色直用绝不经此(纸色中性玩法元素保持最抢眼)。
func _far_band(c: Color, sat_k: float) -> Color:
	var d := c.h - COLD_ANCHOR
	if d > 0.5:
		d -= 1.0
	elif d < -0.5:
		d += 1.0
	var h := fposmod(c.h - FAR_HUE if d > 0.0 else c.h + FAR_HUE, 1.0)
	var v := 0.5 + (c.v - 0.5) * FAR_V_SQUEEZE
	return Color.from_hsv(h, c.s * sat_k, v, c.a)


## 地平幅高平滑过渡(切幕一次性:同 seed 同拓扑,仅高差缓变)。
func _tween_horizon(preset: BackdropPreset) -> void:
	if _horizon_tween != null:
		_horizon_tween.kill()
	_horizon_tween = create_tween()
	_horizon_tween.set_parallel(true)
	_horizon_tween.tween_method(
		func(a: float) -> void: _horizon_far.set_amplitude(a),
		_horizon_far.amplitude, preset.horizon_far, 0.45)
	_horizon_tween.tween_method(
		func(a: float) -> void: _horizon_near.set_amplitude(a),
		_horizon_near.amplitude, preset.horizon_near, 0.45)


## 大楔形动势角缓转(切幕一次性,0.45s)。
func _tween_wedge_rot(deg: float) -> void:
	if _wedge_rot_tween != null:
		_wedge_rot_tween.kill()
	_wedge_rot_tween = create_tween()
	_wedge_rot_tween.tween_method(
		func(v: float) -> void: _wedge.set_rotation_deg(v),
		_wedge.rotation_degrees, deg, 0.45)


## 落地脉冲:impact 越大,地平下沉越深(BOUNCE 弹回)+ 纸色微闪。
func pulse_land(impact: float) -> void:
	if not _fx_enabled():
		return
	var k := clampf((impact - 120.0) / 1600.0, 0.0, 1.0)
	if k <= 0.01:
		return
	if _land_tween != null:
		_land_tween.kill()
	_horizon_far.position.y = 0.0
	_horizon_near.position.y = 0.0
	_land_tween = create_tween()
	_land_tween.set_parallel(true)
	_land_tween.tween_property(_horizon_far, "position:y", k * 10.0, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_land_tween.tween_property(_horizon_near, "position:y", k * 6.0, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_land_tween.chain().tween_property(
		_horizon_far, "position:y", 0.0, 0.34) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_land_tween.parallel().tween_property(
		_horizon_near, "position:y", 0.0, 0.34) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_flash_burst(Color(Palette.I.paper, 1.0), k * 0.05)


## 切换涟漪:受控体色一闪 + 全景层 alpha 微沉回浮(与聚焦透明度语言同族)。
func pulse_switch(color: Color) -> void:
	if not _fx_enabled():
		return
	_flash_burst(color, 0.05)
	_layers_dip(0.88, 0.06, 0.32)


## 到站光涌:大楔形脉冲(满员更强)+ 幕强调色一闪。
func pulse_arrive(full: bool) -> void:
	if not _fx_enabled():
		return
	_wedge.burst(1.12 if full else 1.05)
	var c := Palette.I.paper if _preset == null else _preset.accent
	_flash_burst(c, 0.08 if full else 0.05)


## 死亡红波:三道折线波横扫(事件层语义红唯一出口)+ 全景层压暗回浮。
func pulse_death() -> void:
	if not _fx_enabled():
		return
	_red_wave.fire(Color(Palette.I.red, 1.0))
	_layers_dip(0.82, 0.12, 0.55)


## 全景层 alpha 微沉回浮(一次性;同属性统一走 _layers_tween 防竞争)。
func _layers_dip(low: float, down_s: float, up_s: float) -> void:
	var layers := [
		_grid_band, _wedge_band, _net_band, _rain_band, _track_band,
		_horizon_band]
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
