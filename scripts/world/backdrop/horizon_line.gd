extends Node2D

# 折线地平(五带之「中景」0.66):种子程序直角折线剪影(Polygon2D 填充 +
# Line2D 纸缘),硬直角跌落替代旧山脊斜线;幅高由 BackdropPreset 下发
# (set_amplitude 同 seed 同拓扑仅换高差,切幕短 Tween 过渡);
# pulse_energy() 纸缘提亮一次性脉冲(事件驱动,单 Tween,进行中不叠加);
# 瓦片 2600 横向重复,内容左上对齐 (0,0)。

const TILE_W := 2600.0
const SEG_N := 9
const EDGE_A := 0.05
const EDGE_PEAK := 0.24

@export var base_y := 1010.0
@export var color := Color("1E222B")
@export var line_seed := 1
@export var amplitude := 120.0

var _poly: Polygon2D
var _line: Line2D
var _pulse_tween: Tween
var _anim := true


func _ready() -> void:
	_rebuild()


func _levels() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = line_seed
	var out := PackedFloat32Array()
	for i in SEG_N:
		out.append(base_y - (0.2 + rng.randf() * 0.8) * amplitude)
	return out


func _rebuild() -> void:
	var lv := _levels()
	var seg := TILE_W / float(SEG_N)
	var pts := PackedVector2Array()
	for i in SEG_N:
		pts.append(Vector2(i * seg, lv[i]))
	pts.append(Vector2(TILE_W, lv[0]))
	if _poly == null:
		_poly = Polygon2D.new()
		_poly.color = color
		add_child(_poly)
		_line = Line2D.new()
		_line.width = 1.5
		_line.default_color = Color(Palette.I.paper, EDGE_A)
		add_child(_line)
	var fill := PackedVector2Array(pts)
	fill.append(Vector2(TILE_W, base_y + 3200.0))
	fill.append(Vector2(0, base_y + 3200.0))
	_poly.polygon = fill
	_line.points = pts


func set_amplitude(a: float) -> void:
	amplitude = a
	if _poly != null:
		_rebuild()


func set_animated(on: bool) -> void:
	_anim = on
	if not on:
		if _pulse_tween != null:
			_pulse_tween.kill()
			_pulse_tween = null
		if _line != null:
			_line.default_color = Color(Palette.I.paper, EDGE_A)


## 纸缘脉冲(事件活化,一次性):提亮后回落,进行中不叠加。
func pulse_energy() -> void:
	if not _anim or _line == null or _pulse_tween != null:
		return
	_line.default_color = Color(Palette.I.paper, EDGE_PEAK)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_line, "default_color",
		Color(Palette.I.paper, EDGE_A), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.finished.connect(func() -> void: _pulse_tween = null)
