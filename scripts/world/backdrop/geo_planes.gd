extends Node2D

# 构成巨面由种子程序生成,数量形态运行时确定(procedural-art)。
# 每面独立子节点错峰浮沉(fandex 星尘漂移参数:9/11/13/15s alternate,幅 3~8px),
# 浮动走 position(零重绘);动画关 = 停浮保姿态。数量由 BackdropPreset 下发。
# 五层深度带之「远景」(scroll_scale.x 0.15-0.25):面体为纸色低 alpha
# 中性色,远景降阶不另处理;慢巡浮沉即无 beat 时的回退节奏。

const SEED := 77
const PERIODS := [9.0, 11.0, 13.0, 15.0, 17.0]

var count := 3
var _planes: Array = []


func _ready() -> void:
	_build(count)


func set_count(n: int) -> void:
	var want := clampi(n, 0, 5)
	if want == count and not _planes.is_empty():
		return
	count = want
	_build(want)


func set_animated(on: bool) -> void:
	for p in _planes:
		p.set_process(on)


func _build(n: int) -> void:
	for c in get_children():
		c.free()
	_planes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in 5:
		var x := 200.0 + i * 520.0 + rng.randf_range(-90.0, 90.0)
		var top := rng.randf_range(240.0, 620.0)
		var w1 := rng.randf_range(260.0, 520.0)
		var w2 := w1 * rng.randf_range(0.3, 0.7)
		var col := Color(Palette.I.paper, rng.randf_range(0.018, 0.032))
		var pts := PackedVector2Array()
		if i % 2 == 0:
			pts = PackedVector2Array([
				Vector2(x, top), Vector2(x + w1, top + rng.randf_range(-60, 60)),
				Vector2(x + w2, top + 900.0),
			])
		else:
			pts = PackedVector2Array([
				Vector2(x, top), Vector2(x + w1, top),
				Vector2(x + w1 * 0.8, top + 900.0), Vector2(x + w1 * 0.2, top + 900.0),
			])
		if i < n:
			var plane := PlaneShape.new()
			plane.pts = pts
			plane.col = col
			plane.period = PERIODS[i]
			plane.amp = 3.0 + float(i % 3) * 2.5
			plane.phase = -float(i) * 2.7
			add_child(plane)
			_planes.append(plane)


class PlaneShape:
	extends Node2D

	var pts := PackedVector2Array()
	var col := Color(1, 1, 1, 0.02)
	var period := 11.0
	var amp := 5.0
	var phase := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		# 构成主义:匀速直线沉浮、端点硬折返(三角波),拒绝正弦柔滑。
		_t += delta
		var x := _t / period + phase
		position.y = (absf(fposmod(x, 1.0) - 0.5) * 4.0 - 1.0) * amp

	func _draw() -> void:
		draw_colored_polygon(pts, col)
