class_name Backdrop
extends CanvasLayer
## 构成主义几何背景:墨色平面、巨大低对比几何面、折线山脊、
## 方点星阵与几何圆环。无柔光、无渐变,全部由平面色块与细线构成。
##
## 陀螺仪轻量视差(v0.16 V7,仅移动端):设备倾斜 → 各视差层微移(≤8px)。
## v0.17 重写:改用 Input.get_accelerometer()(enable_accelerometer 已开,
## 实测 get_gravity 在部分机型不生效)+ 自建低通滤波归一化;
## 轴向按横屏持机假设,真机校准点仍在(ROADMAP V7)。

const GYRO_DEPTH := {"sun": 3.0, "planes": 6.0, "marks": 8.0}
var _gyro_layers: Array = []   # [{node: Parallax2D, depth: float}]
var _gyro_off := Vector2.ZERO
var _accel_lp := Vector3.ZERO  # 加速度计低通(≈重力方向)


func _ready() -> void:
	layer = -10

	# —— 墨色底 ——
	var sky := ColorRect.new()
	sky.color = Ui.INK
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	# —— 巨大几何面(斜切三角,极低对比) ——
	var planes := Parallax2D.new()
	planes.scroll_scale = Vector2(0.08, 0.4)
	planes.repeat_size = Vector2(2600, 0)
	planes.repeat_times = 3
	planes.add_child(GeoPlanes.new())
	add_child(planes)

	# —— 几何圆环("太阳",细线空圆) ——
	var sun := Parallax2D.new()
	sun.scroll_scale = Vector2(0.06, 0.12)
	sun.add_child(GeoSun.new())
	add_child(sun)

	# —— 方点星阵(方块 / 十字) ——
	var marks := Parallax2D.new()
	marks.scroll_scale = Vector2(0.12, 0.5)
	marks.repeat_size = Vector2(2400, 2400)
	marks.repeat_times = 2
	marks.add_child(GeoMarks.new())
	add_child(marks)

	# —— 折线山脊(两层,锐利直线段,越近越深) ——
	var ridge_far := Ridge.new()
	ridge_far.base_y = 1010.0
	ridge_far.color = Color("1A1E26")
	ridge_far.scroll = 0.32
	ridge_far.ridge_seed = 1
	ridge_far.amplitude = 130.0
	add_child(ridge_far)
	var ridge_near := Ridge.new()
	ridge_near.base_y = 1075.0
	ridge_near.color = Color("14171E")
	ridge_near.scroll = 0.58
	ridge_near.ridge_seed = 5
	ridge_near.amplitude = 90.0
	add_child(ridge_near)

	# —— 漂浮方尘(屏幕空间) ——
	add_child(_motes(22, 2.2, 0.09, 15.0))
	add_child(_motes(12, 3.8, 0.15, 10.0))

	_gyro_layers = [
		{"node": sun, "depth": GYRO_DEPTH["sun"]},
		{"node": planes, "depth": GYRO_DEPTH["planes"]},
		{"node": marks, "depth": GYRO_DEPTH["marks"]},
	]


func _process(delta: float) -> void:
	if not OS.has_feature("mobile"):
		set_process(false)
		return
	var accel := Input.get_accelerometer()
	if accel == Vector3.ZERO:
		return
	# 低通提取重力方向(0.1 截止),再归一化为倾斜量
	_accel_lp = _accel_lp.lerp(accel, clampf(3.0 * delta, 0.0, 1.0))
	var g := _accel_lp
	var target := Vector2(
		clampf(-g.y / 9.81, -1.0, 1.0), clampf(g.x / 9.81, -1.0, 1.0))
	_gyro_off = _gyro_off.lerp(target, 1.0 - exp(-3.0 * delta))
	for entry: Dictionary in _gyro_layers:
		(entry["node"] as Parallax2D).scroll_offset = _gyro_off * entry["depth"]


func _motes(amount: int, scale_max: float, alpha: float, lifetime: float) -> CPUParticles2D:
	var motes := CPUParticles2D.new()
	motes.amount = amount
	motes.lifetime = lifetime
	motes.preprocess = lifetime
	motes.position = Vector2(640, 760)
	motes.emission_rect_extents = Vector2(760, 30)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.direction = Vector2(0, -1)
	motes.spread = 30.0
	motes.gravity = Vector2(0, 0)
	motes.initial_velocity_min = 7.0
	motes.initial_velocity_max = 22.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = scale_max
	motes.color = Color(Ui.PAPER, alpha)
	motes.emitting = true
	return motes


## 大型低对比几何面:斜切三角与梯形,缓慢视差。
class GeoPlanes extends Node2D:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 5:
			var x := 200.0 + i * 520.0 + rng.randf_range(-90.0, 90.0)
			var top := rng.randf_range(240.0, 620.0)
			var w1 := rng.randf_range(260.0, 520.0)
			var w2 := w1 * rng.randf_range(0.3, 0.7)
			var col := Color(Ui.PAPER, rng.randf_range(0.018, 0.032))
			if i % 2 == 0:
				# 斜切三角
				var tri := PackedVector2Array([
					Vector2(x, top), Vector2(x + w1, top + rng.randf_range(-60, 60)),
					Vector2(x + w2, top + 900.0),
				])
				draw_colored_polygon(tri, col)
			else:
				# 梯形
				var quad := PackedVector2Array([
					Vector2(x, top), Vector2(x + w1, top),
					Vector2(x + w1 * 0.8, top + 900.0), Vector2(x + w1 * 0.2, top + 900.0),
				])
				draw_colored_polygon(quad, col)


## 细线空圆 + 一条横切线:构成主义式"几何太阳"。
class GeoSun extends Node2D:
	func _draw() -> void:
		var center := Vector2(1560.0, 240.0)
		draw_arc(center, 120.0, 0.0, TAU, 64, Color(Ui.PAPER, 0.14), 2.0)
		draw_arc(center, 78.0, 0.0, TAU, 48, Color(Ui.PAPER, 0.07), 1.0)
		draw_line(center + Vector2(-170, 0), center + Vector2(170, 0), Color(Ui.RED, 0.30), 3.0)


## 方块与十字刻点。
class GeoMarks extends Node2D:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20250905
		for i in 90:
			var p := Vector2(rng.randf_range(0.0, 2400.0), rng.randf_range(-600.0, 1800.0))
			var s := rng.randf_range(1.6, 3.4)
			var a := rng.randf_range(0.10, 0.42)
			var c := Color(Ui.RED, a * 0.9) if rng.randf() < 0.10 else Color(Ui.PAPER, a)
			if rng.randf() < 0.16:
				# 十字刻度
				draw_line(p + Vector2(-s * 2, 0), p + Vector2(s * 2, 0), c, 1.0)
				draw_line(p + Vector2(0, -s * 2), p + Vector2(0, s * 2), c, 1.0)
			else:
				draw_rect(Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), c)


## 一条无缝平铺的折线山脊:纯直线段,棱角分明。
class Ridge extends Parallax2D:
	const TILE_W := 2600.0

	var base_y := 1000.0
	var color := Color("1A1E26")
	var scroll := 0.4
	var ridge_seed := 1
	var amplitude := 120.0

	func _ready() -> void:
		scroll_scale = Vector2(scroll, 1.0)
		repeat_size = Vector2(TILE_W, 0)
		repeat_times = 3

		var rng := RandomNumberGenerator.new()
		rng.seed = ridge_seed
		# 首尾同高,保证左右无缝
		var n := 9
		var seg := TILE_W / float(n)
		var pts := PackedVector2Array()
		for i in n:
			var x := i * seg
			var y := base_y - rng.randf_range(0.15, 1.0) * amplitude
			pts.append(Vector2(x, y))
		pts.append(Vector2(TILE_W, pts[0].y))

		var poly_pts := PackedVector2Array(pts)
		poly_pts.append(Vector2(TILE_W, base_y + 3200.0))
		poly_pts.append(Vector2(0, base_y + 3200.0))

		var poly := Polygon2D.new()
		poly.polygon = poly_pts
		poly.color = color
		add_child(poly)

		# 山脊顶缘细线,强化折线感
		var line := Line2D.new()
		line.points = pts
		line.width = 1.5
		line.default_color = Color(Ui.PAPER, 0.05)
		add_child(line)
