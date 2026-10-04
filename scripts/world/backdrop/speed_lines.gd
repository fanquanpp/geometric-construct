extends Node2D

# 移速星线(v0.68 GPU 化重做,五层深度带之「前景」1.1-1.6):纸白细线改为
# canvas_item shader 驱动(shaders/speed_lines.gdshader,TIME 横流硬边段),
# 逐实例相位/长度走 instance_shader_parameter,宿主零重绘零逐帧分配;
# 宿主只做速度采样与强度平滑下发(THRESHOLD 以下 strength 恒 0 不出现)。
# 速度阈值穿越发 crossed 信号(事件级,Backdrop 用于静态层活化);
# 动画关 = strength/anim 双 0 停帧,速度照常拉取但不下发。

signal crossed(on: bool)

const THRESHOLD := 420.0
const FULL := 900.0
const COUNT := 14
const TILE_W := 2600.0
const LINE_W := 1500.0

const LINE_SHADER := preload("res://shaders/speed_lines.gdshader")

var _cur := 0.0
var _dir := 1.0
var _over := false
var _lines: Array = []
var _animated := true
var _last_k := -1.0
var _last_dir := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in COUNT:
		var rect := ColorRect.new()
		rect.size = Vector2(LINE_W, 2.0)
		rect.position = Vector2(
			rng.randf_range(0.0, TILE_W - LINE_W), rng.randf_range(56.0, 660.0))
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = LINE_SHADER
		rect.material = mat
		rect.set_instance_shader_parameter("phase", rng.randf_range(0.0, 1.0))
		rect.set_instance_shader_parameter("len_mul", rng.randf_range(0.6, 1.4))
		add_child(rect)
		_lines.append(rect)


func set_animated(on: bool) -> void:
	_animated = on
	set_process(on)
	_cur = 0.0
	_last_k = -1.0
	if on:
		_push_line_param("anim", 1.0)
	else:
		_over = false
		_push_line_param("strength", 0.0)
		_push_line_param("anim", 0.0)


func _process(delta: float) -> void:
	if not _animated:
		return
	var target := 0.0
	var main = Main.I
	if main != null and main.roster != null and not main.roster.players.is_empty():
		var p = main.roster.players[main.roster.active_slot]
		if p != null and not p.in_exit and not p.dying:
			target = absf(p.velocity.x)
			if absf(p.velocity.x) > 10.0:
				_dir = signf(p.velocity.x)
	_cur = lerpf(_cur, target, 1.0 - exp(-6.0 * delta))
	var k := clampf((_cur - THRESHOLD) / (FULL - THRESHOLD), 0.0, 1.0)
	var over := k > 0.01
	if over != _over:
		_over = over
		crossed.emit(over)
	if absf(k - _last_k) > 0.0005:
		_last_k = k
		_push_line_param("strength", k)
	if not is_equal_approx(_last_dir, _dir):
		_last_dir = _dir
		_push_line_param("dir", _dir)


func _push_line_param(param: String, v: float) -> void:
	for ln in _lines:
		var mat := (ln as ColorRect).material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter(param, v)


## 当前流向(±1):Backdrop 在阈值穿越时读取,供流光纱层同向。
func current_dir() -> float:
	return _dir
