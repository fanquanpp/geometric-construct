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
	sky.color = Palette.I.ink
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	# —— 深空星野(v0.37:最远视差带,银河带 + 十字亮星 + 低频闪烁) ——
	var deep := Parallax2D.new()
	deep.scroll_scale = Vector2(0.04, 0.2)
	deep.repeat_size = Vector2(2600, 1300)
	deep.repeat_times = 2
	deep.add_child(DeepSpace.new())
	add_child(deep)

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
	motes.color = Color(Palette.I.paper, alpha)
	motes.emitting = true
	return motes


## 深空星野(v0.37,atmosphere.md §1.1 天体带最远端):稀疏星点 +
## 斜向银河带(点簇,无渐变)+ 逆蓝点缀 + 十字亮星;~8Hz 低频闪烁
## (「越远越静」判据内的唯一微动,与方尘的 M5 呼吸同量级)。
class DeepSpace extends Node2D:
	const TILE := Vector2(2600, 1300)
	var _stars: Array = []      # {pos, size, col, base_a, spd, ph, cross}
	var _t := 0.0
	var _acc := 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 470913
		for i in 120:
			_stars.append(_mk_star(rng, Vector2(
				rng.randf_range(0.0, TILE.x), rng.randf_range(0.0, TILE.y)),
				rng.randf_range(0.08, 0.30), rng))
		# 银河带:对角点簇(中心线 (0,950)→(2600,350),±150 高斯散布)
		for i in 130:
			var x := rng.randf_range(0.0, TILE.x)
			var cy := 950.0 - x * (600.0 / 2600.0)
			var y := cy + (rng.randf_range(-1.0, 1.0)
				+ rng.randf_range(-1.0, 1.0)) * 75.0
			_stars.append(_mk_star(rng, Vector2(x, y),
				rng.randf_range(0.05, 0.13), rng, true))
		# 带内两片低亮度云斑(实色低对比平行四边形,禁渐变纪律)
		for i in 2:
			var x := 380.0 + i * 1180.0
			var cy := 950.0 - x * (600.0 / 2600.0)
			var quad := PackedVector2Array([
				Vector2(x, cy), Vector2(x + 300.0, cy - 46.0),
				Vector2(x + 430.0, cy + 42.0), Vector2(x + 130.0, cy + 88.0),
			])
			_stars.append({"quad": quad,
				"col": Color(Palette.I.paper, 0.016 + i * 0.006),
				"cross": false, "quad_a": true})
		# 十字亮星(构成主义深空信标,含一枚逆蓝)
		for i in 6:
			var p := Vector2(rng.randf_range(100.0, TILE.x - 100.0),
				rng.randf_range(100.0, TILE.y - 100.0))
			var col := Color(Palette.I.blue, 0.30) if i == 0 				else Color(Palette.I.paper, rng.randf_range(0.20, 0.34))
			_stars.append({"pos": p, "size": rng.randf_range(4.0, 6.0),
				"col": col, "spd": rng.randf_range(0.4, 0.9),
				"ph": rng.randf_range(0.0, TAU), "cross": true})

	func _mk_star(rng: RandomNumberGenerator, pos: Vector2, a: float,
			rng2: RandomNumberGenerator, band := false) -> Dictionary:
		var col := Color(Palette.I.paper, a)
		if not band and rng2.randf() < 0.08:
			col = Color(Palette.I.blue, a * 0.9)   # 逆蓝点缀
		return {"pos": pos, "size": rng.randf_range(1.0, 2.2),
			"col": col, "spd": rng.randf_range(0.25, 0.8),
			"ph": rng.randf_range(0.0, TAU), "cross": false}

	func _process(delta: float) -> void:
		_t += delta
		_acc += delta
		if _acc >= 0.125:   # 8Hz 重绘:闪烁是星野唯一的"活"
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		for st in _stars:
			if st.has("quad_a"):
				draw_colored_polygon(st["quad"], st["col"])
				continue
			var tw: float = st["col"].a * (0.75 + 0.25 				* sin(_t * st["spd"] * TAU + st["ph"]))
			var c := Color(st["col"].r, st["col"].g, st["col"].b, tw)
			if st["cross"]:
				var s: float = st["size"]
				draw_line(st["pos"] + Vector2(-s, 0), st["pos"] + Vector2(s, 0), c, 1.2)
				draw_line(st["pos"] + Vector2(0, -s), st["pos"] + Vector2(0, s), c, 1.2)
			else:
				draw_rect(Rect2(st["pos"] - Vector2(st["size"], st["size"]) / 2.0,
					Vector2(st["size"], st["size"])), c)


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
			var col := Color(Palette.I.paper, rng.randf_range(0.018, 0.032))
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
		draw_arc(center, 120.0, 0.0, TAU, 64, Color(Palette.I.paper, 0.14), 2.0)
		draw_arc(center, 78.0, 0.0, TAU, 48, Color(Palette.I.paper, 0.07), 1.0)
		draw_line(center + Vector2(-170, 0), center + Vector2(170, 0), Color(Palette.I.red, 0.30), 3.0)


## 方块与十字刻点。
class GeoMarks extends Node2D:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20250905
		for i in 90:
			var p := Vector2(rng.randf_range(0.0, 2400.0), rng.randf_range(-600.0, 1800.0))
			var s := rng.randf_range(1.6, 3.4)
			var a := rng.randf_range(0.10, 0.42)
			var c := Color(Palette.I.red, a * 0.9) if rng.randf() < 0.10 else Color(Palette.I.paper, a)
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
		line.default_color = Color(Palette.I.paper, 0.05)
		add_child(line)
