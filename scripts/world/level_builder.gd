class_name LevelBuilder
## 把 LevelDef 数据实例化为节点树:平台 / 曲面跳跃板 / 加速门 / 门 / 几何体 / 相机。
## 渲染规范:棱角分明的平面石板 + 硬投影,无圆角无柔光。
## 关卡背景带 1 格 = 100 px 的定位网格(与 HUD 坐标读数对齐)。


static func build(def: LevelDef) -> Node2D:
	var root := Node2D.new()
	root.name = "Level"

	# —— 定位网格(最底层装饰,坐标与 HUD 读数对齐) ——
	var grid := GridLayer.new()
	grid.level_size = def.size
	root.add_child(grid)

	# —— 平台 ——
	var plats: Array = def.platforms
	# 左右隐形墙(仅碰撞,不绘制)
	var walls := [
		Rect2(-40, -700, 40, def.size.y + 1400),
		Rect2(def.size.x, -700, 40, def.size.y + 1400),
	]

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.z_index = 1
	for r in plats + walls:
		var cs := CollisionShape2D.new()
		cs.position = r.get_center()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		body.add_child(cs)
	root.add_child(body)

	var renderer := PlatformRenderer.new()
	renderer.rects = plats
	root.add_child(renderer)

	# —— 曲面跳跃板 ——
	for r in def.ramps:
		var ramp := Ramp.new()
		ramp.pts = PackedVector2Array(r["pts"])
		ramp.base_y = r["base"]
		root.add_child(ramp)

	# —— 加速门 ——
	for g in def.gates:
		var gate := SpeedGate.new()
		gate.center = g[0]
		gate.zone_size = g[1]
		root.add_child(gate)

	# —— 移动构件:单轴往返的动平台(轨道线画在世界坐标,石板随身体移动) ——
	for mv in def.movers:
		var r: Rect2 = mv["rect"]
		var track := MoverTrack.new()
		track.center = r.get_center()
		track.travel = mv.get("offset", Vector2.ZERO)
		root.add_child(track)
		var mover := Mover.new()
		mover.rect = r
		mover.travel = mv.get("offset", Vector2.ZERO)
		mover.period = mv.get("period", 3.0)
		mover.phase = mv.get("phase", 0.0)
		root.add_child(mover)

	# —— 出口门 ——
	for e in def.exits:
		var door := ExitDoor.new()
		door.geo_index = e[0]
		door.center = e[1]
		root.add_child(door)

	# —— 几何体 ——
	for idx in def.roster:
		var cd: GeometryDef = Geometries.ALL[idx]
		var p := Player.new()
		p.def = cd
		p.index = idx
		p.spawn_pos = def.spawns[idx]
		p.position = def.spawns[idx]
		root.add_child(p)

	# —— 相机 ——
	var cam := CameraRig.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(def.size.x)
	cam.limit_bottom = int(def.size.y)
	root.add_child(cam)
	return root


## 绘制全部平台:硬投影 + 平面石板 + 顶缘亮线,全部直角。
class PlatformRenderer extends Node2D:
	var rects: Array = []
	var _base: StyleBoxFlat
	var _slab: StyleBoxFlat

	func _ready() -> void:
		z_index = 1
		_base = StyleBoxFlat.new()
		_base.bg_color = Color("262B34")
		_slab = StyleBoxFlat.new()
		_slab.bg_color = Color("313845")

	func _draw() -> void:
		for r in rects:
			# 硬投影:整体位移的实心暗块,无模糊
			draw_rect(Rect2(r.position + Vector2(7, 8), r.size), Color(0, 0, 0, 0.38))
			# 主体
			draw_style_box(_base, r)
			# 上层亮面板
			var slab := minf(r.size.y * 0.4, 22.0)
			if slab > 2.0:
				draw_style_box(_slab, Rect2(r.position, Vector2(r.size.x, slab)))
			# 顶缘亮线(锐利 1px)
			draw_rect(Rect2(r.position + Vector2(0, 0), Vector2(r.size.x, 2)),
				Color(Ui.PAPER, 0.30))
			# 左缘红色刻度块(构成主义强调点,每 480px 一处)
			var mark_x := 40.0
			while mark_x < r.size.x - 20.0:
				draw_rect(Rect2(r.position + Vector2(mark_x, 0), Vector2(14, 3)),
					Color(Ui.RED, 0.55))
				mark_x += 480.0


## 曲面跳跃板:折线曲面(碰撞 = 逐段实心凸四边形),几何体沿面滑行,末端沿切线飞出。
class Ramp extends StaticBody2D:
	var pts := PackedVector2Array()
	var base_y := 1000.0
	const THICKNESS := 48.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		z_index = 1
		add_to_group("ramp")   # 玩家据此识别"站在曲面上"(加速 + 减重 buff)
		# 逐段实心四边形:顶边为曲面,向下加厚;避免薄线段的双面碰撞把球弹开
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var cs := CollisionShape2D.new()
			var shape := ConvexPolygonShape2D.new()
			shape.points = PackedVector2Array([
				a, b, b + Vector2(0, THICKNESS), a + Vector2(0, THICKNESS),
			])
			cs.shape = shape
			add_child(cs)

	func _draw() -> void:
		if pts.size() < 2:
			return
		# 硬投影
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + Vector2(7, 8))
		shadow.append(Vector2(pts[pts.size() - 1].x + 7, base_y + 8))
		shadow.append(Vector2(pts[0].x + 7, base_y + 8))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.38))
		# 主体填充(曲面到基线)
		var poly := PackedVector2Array(pts)
		poly.append(Vector2(pts[pts.size() - 1].x, base_y))
		poly.append(Vector2(pts[0].x, base_y))
		draw_colored_polygon(poly, Color("262B34"))
		# 表层亮面板(沿曲面下移的带状)
		var band := PackedVector2Array(pts)
		for i in range(pts.size() - 1, -1, -1):
			band.append(pts[i] + Vector2(0, 14))
		draw_colored_polygon(band, Color("313845"))
		# 顶缘亮线
		draw_polyline(pts, Color(Ui.PAPER, 0.35), 2.0)
		# 红色刻度块(每段中点)
		for i in pts.size() - 1:
			var mid := (pts[i] + pts[i + 1]) * 0.5
			draw_rect(Rect2(mid - Vector2(7, 8), Vector2(14, 3)), Color(Ui.RED, 0.55))


## 移动构件:单轴往返的动平台(AnimatableBody2D + sync_to_physics,
## 站立者由平台速度自然携带)。行程用余弦缓动 —— 两端减速、中段匀速,
## 落点时刻可预判(docs/design/levels.md §3 动态地图原则)。
class Mover extends AnimatableBody2D:
	var rect := Rect2()
	var travel := Vector2.ZERO
	var period := 3.0
	var phase := 0.0
	var _t := 0.0

	func _ready() -> void:
		sync_to_physics = true
		collision_layer = 1
		collision_mask = 0
		z_index = 1
		var cs := CollisionShape2D.new()
		cs.position = Vector2.ZERO
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		cs.shape = shape
		add_child(cs)
		var renderer := MoverSlab.new()
		renderer.size = rect.size
		add_child(renderer)

	func _physics_process(delta: float) -> void:
		_t += delta
		# 余弦往返:s ∈ [0,1],端点速度为零
		var s := 0.5 - 0.5 * cos(TAU * (_t / maxf(period, 0.1) + phase))
		position = rect.get_center() + travel * s


## 移动石板外观:与静态平台同语言(硬投影 + 亮面板 + 顶缘亮线),
## 侧缘红色刻度块标出"正在移动"的身份。
class MoverSlab extends Node2D:
	var size := Vector2.ZERO
	var _base: StyleBoxFlat
	var _slab: StyleBoxFlat

	func _ready() -> void:
		z_index = 1
		_base = StyleBoxFlat.new()
		_base.bg_color = Color("2B3140")
		_slab = StyleBoxFlat.new()
		_slab.bg_color = Color("3A4254")

	func _draw() -> void:
		var r := Rect2(-size / 2.0, size)
		draw_rect(Rect2(r.position + Vector2(7, 8), r.size), Color(0, 0, 0, 0.38))
		draw_style_box(_base, r)
		var slab := minf(size.y * 0.4, 22.0)
		if slab > 2.0:
			draw_style_box(_slab, Rect2(r.position, Vector2(size.x, slab)))
		draw_rect(Rect2(r.position, Vector2(size.x, 2)), Color(Ui.PAPER, 0.42))
		# 左右缘红色移动刻度(与静态平台的左侧刻度区分)
		draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(8, 3)), Color(Ui.RED, 0.8))
		draw_rect(Rect2(Vector2(r.end.x - 8, r.position.y + 3), Vector2(8, 3)),
			Color(Ui.RED, 0.8))


## 移动构件轨道:世界坐标里的细线路径 + 两端终点刻度,提前预告行程。
class MoverTrack extends Node2D:
	var center := Vector2.ZERO
	var travel := Vector2.ZERO

	func _ready() -> void:
		z_index = 0

	func _draw() -> void:
		if travel == Vector2.ZERO:
			return
		var a := center - travel * 0.5
		var b := center + travel * 0.5
		draw_line(a, b, Color(Ui.PAPER, 0.10), 1.0)
		for p: Vector2 in [a, b]:
			draw_rect(Rect2(p + Vector2(-2.5, -14.0), Vector2(5, 5)), Color(Ui.RED, 0.55))
			draw_rect(Rect2(p + Vector2(-2.5, 9.0), Vector2(5, 5)), Color(Ui.RED, 0.55))


## 镜头:始终以受控几何体为画面中心,带左右前瞻偏移与速度变焦;
## 切换几何体时快速平移 + 缩放脉冲过渡(不再要求全员在视野内)。
class CameraRig extends Camera2D:
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
		var slot: int = clampi(m._active_slot, 0, m.players.size() - 1)
		var p: Player = m.players[slot]
		if p == null:
			return

		if not _snapped:
			position = p.position
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

		# 左右前瞻:随水平速度偏移一点,增加行驶感与手感
		var look_target := Vector2(
			clampf(p.velocity.x * 0.24, -130.0, 130.0),
			clampf(p.velocity.y * 0.06, -40.0, 56.0))
		_look = _look.lerp(look_target, 1.0 - exp(-4.0 * delta))

		# 变焦:速度越快视野略拉远;切换瞬间轻微收缩再回弹
		var speed_mult := absf(p.velocity.x) / Geometries.RUN_SPEED
		var target_zoom := clampf(1.02 - 0.085 * maxf(speed_mult, p.def.base_speed),
			0.80, 1.0)
		if _pulse > 0.0:
			target_zoom *= 0.94

		var k := 1.0 - exp((-9.0 if _pulse > 0.0 else -5.5) * delta)
		position = position.lerp(p.position + _look, k)
		var z := lerpf(zoom.x, target_zoom, 1.0 - exp(-3.5 * delta))
		zoom = Vector2(z, z)


## 定位网格:1 格 = 100 px 的世界坐标网格,次格细线、5 格主线、
## 左缘红色刻度块与 HUD 坐标读数(单位:格)一一对齐。
class GridLayer extends Node2D:
	var level_size := Vector2.ZERO

	func _ready() -> void:
		z_index = 0

	func _draw() -> void:
		if level_size == Vector2.ZERO:
			return
		var unit := Geometries.UNIT_PX
		var w := int(level_size.x / unit)
		var h := int(level_size.y / unit)
		# 次格:每 1 格一条细线
		for gx in w + 1:
			var a := 0.045 if gx % 5 != 0 else 0.085
			draw_line(Vector2(gx * unit, 0), Vector2(gx * unit, level_size.y),
				Color(Ui.PAPER, a), 1.0)
		for gy in h + 1:
			var a := 0.045 if gy % 5 != 0 else 0.085
			draw_line(Vector2(0, gy * unit), Vector2(level_size.x, gy * unit),
				Color(Ui.PAPER, a), 1.0)
		# 左缘红色格点刻度(每 1 格,构成主义强调点)
		for gy in h + 1:
			draw_rect(Rect2(-6, gy * unit - 1.5, 12, 3), Color(Ui.RED, 0.5))
		# 原点十字
		draw_line(Vector2(0, 0), Vector2(26, 0), Color(Ui.RED, 0.55), 2.0)
		draw_line(Vector2(0, 0), Vector2(0, 26), Color(Ui.RED, 0.55), 2.0)
