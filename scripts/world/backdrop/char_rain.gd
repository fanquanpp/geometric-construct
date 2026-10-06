extends Node2D

# 字符雨(五带之「远景」0.24):ink 版面上等宽像素字形(3×5 点阵,程序
# 生成,不经字体子系统)离散下落,15fps 步进节流重绘(重绘守卫合规);
# 尾迹 paper 微光、头部 accent,透明度硬上限 0.2;Ambience SPECIAL 拍
# 触发列簇提亮包络(半波 0.45s 场毕归零,拍缺席回退自由步进)。
# 密度倍率 set_density 事件级重绘;瓦片 2600 横向重复,内容左上对齐。

const TILE_W := 2600.0
const COL_N := 22
const STEP := 1.0 / 15.0
const CELL_H := 16.0
const SPAN := 1140.0
const SPAN_TOP := 420.0
const ALPHA_MAX := 0.2
const ALPHA_TRAIL := 0.09
const BEAT_S := 0.45
const SEED := 60604

# 3×5 点阵字形(逐行 3 位掩码):数字与记号集,等宽自证。
const GLYPHS := [
	[2, 5, 5, 5, 2],
	[2, 6, 2, 2, 7],
	[7, 1, 7, 4, 7],
	[0, 2, 7, 2, 0],
	[0, 7, 0, 7, 0],
	[0, 0, 2, 0, 0],
	[7, 1, 2, 2, 2],
	[5, 5, 7, 5, 5],
]

var density := 1.0
var accent := Color(0.306, 0.525, 0.847, 1.0):
	set(v):
		if accent != v:
			accent = v
			queue_redraw()

var _cols: Array = []
var _t := 0.0
var _acc := 0.0
var _beat := 0.0
var _anim := true


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in COL_N:
		_cols.append({
			"x": 90.0 + i * (TILE_W - 180.0) / float(COL_N - 1)
				+ rng.randf_range(-40.0, 40.0),
			"y0": rng.randf_range(0.0, SPAN),
			"spd": rng.randf_range(26.0, 58.0),
			"len": rng.randi_range(5, 9),
			"g": _glyph_seq(rng),
		})


func _glyph_seq(rng: RandomNumberGenerator) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in 9:
		out.append(rng.randi_range(0, GLYPHS.size() - 1))
	return out


func set_density(m: float) -> void:
	density = m
	queue_redraw()


func set_animated(on: bool) -> void:
	_anim = on
	set_process(on)
	if not on:
		_acc = 0.0
		_beat = 0.0
		queue_redraw()


## Beat 转发入口:远带只绑 SPECIAL 拍(半波提亮包络)。
func on_beat(kind: int, _index: int) -> void:
	if _anim and kind == Ambience.BeatKind.SPECIAL:
		_beat = 1.0


func _process(delta: float) -> void:
	if not _anim:
		return
	_t += delta
	if _beat > 0.0:
		_beat = maxf(0.0, _beat - delta / BEAT_S)
	_acc += delta
	if _acc >= STEP:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var paper := Palette.I.paper
	var env := sin(_beat * PI)
	var n := int(round(COL_N * density))
	for i in mini(n, _cols.size()):
		var c: Dictionary = _cols[i]
		var x: float = c["x"]
		var y0: float = c["y0"]
		var spd: float = c["spd"]
		var len: int = c["len"]
		var g: PackedInt32Array = c["g"]
		var head := SPAN_TOP + fposmod(y0 + _t * spd, SPAN)
		for k in len:
			var p := Vector2(x, head - k * CELL_H)
			if k == 0:
				var a := minf(ALPHA_MAX, 0.16 + 0.04 * env)
				_glyph(p, g[k], Color(accent.r, accent.g, accent.b, a))
			elif env > 0.3 and k % 3 == 0:
				_glyph(p, g[k], Color(accent.r, accent.g, accent.b, 0.14))
			else:
				var tw := 0.75 + 0.25 * sin(_t * 0.9 + float(i + k))
				_glyph(p, g[k], Color(paper, ALPHA_TRAIL * tw))


func _glyph(p: Vector2, gi: int, c: Color) -> void:
	var rows: Array = GLYPHS[gi % GLYPHS.size()]
	for r in 5:
		var bits: int = rows[r]
		for b in 3:
			if (bits >> (2 - b)) & 1 == 1:
				draw_rect(Rect2(p + Vector2(b * 2.0, r * 2.0),
					Vector2(2, 2)), c)
