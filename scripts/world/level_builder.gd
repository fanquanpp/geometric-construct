class_name LevelBuilder
## 把 LevelDef 数据实例化为节点树:平台 / 曲面跳跃板 / 加速门 / 门 / 几何体 / 相机。
## 渲染规范:棱角分明的平面石板 + 硬投影,无圆角无柔光。
## 关卡背景带 1 格 = 100 px 的定位网格(与 HUD 坐标读数对齐)。
##
## 组件图层系统(levels.md §7 / ROADMAP §1 M0):
##   构建期把实际出现的 (lane, who) 组合编译为 Godot 碰撞位 —— 位 1 恒为缺省
##   组合(mid/全员,与旧版逐位一致),位 2 预留玩家几何体,其余组合按出场
##   顺序分配 3..31;玩家 collision_mask = 适用组合位并集,出生算定一次。
##   faces 用 one-way 碰撞实现(top 顶面可站 / bottom 底面可站,逆向天花板);
##   lane 决定 z_index 与 modulate 规则(art-style.md §6.6,不重画瓦片)。


static func build(def: LevelDef) -> Node2D:
	var root := Node2D.new()
	root.name = "Level"

	# —— 定位网格(最底层装饰,坐标与 HUD 读数对齐) ——
	var grid := GridLayer.new()
	grid.level_size = def.size
	root.add_child(grid)

	# —— 语义编译:(lane, who) 组合 → 碰撞位(levels.md §7.6) ——
	var combos := _compile_combos(def)

	# —— 每个组合一个静态碰撞体 ——
	var bodies := {}
	for key in combos:
		var c: Dictionary = combos[key]
		var body := StaticBody2D.new()
		body.collision_layer = 1 << (int(c["bit"]) - 1)
		body.collision_mask = 0
		root.add_child(body)
		bodies[key] = body

	# —— 平台:碰撞按组合入位,渲染按 lane 分组 ——
	var lanes := {Comp.LANE_BACK: [], Comp.LANE_MID: [], Comp.LANE_FRONT: []}
	# 左右隐形墙(仅碰撞,不绘制;恒在缺省组合,任何几何体都不可穿出)
	var walls := [
		Rect2(-40, -700, 40, def.size.y + 1400),
		Rect2(def.size.x, -700, 40, def.size.y + 1400),
	]
	for it0 in def.platforms:
		var it := Comp.normalize(it0)
		lanes[it["lane"]].append(it)
		if it["faces"] == Comp.FACES_NONE:
			continue    # 纯装饰,无碰撞(levels.md §7.3)
		bodies[Comp.combo_key(it)].add_child(_rect_shape(it["rect"], it["faces"]))
	for w in walls:
		bodies["mid|all"].add_child(_rect_shape(w, Comp.FACES_FULL))
	for lane in lanes:
		if lanes[lane].is_empty():
			continue
		var renderer := LaneRenderer.new()
		renderer.lane = lane
		renderer.items = lanes[lane]
		renderer.z_index = Comp.LANE_Z[lane]
		root.add_child(renderer)

	# —— 曲面跳跃板 ——
	for r in def.ramps:
		var ramp := Ramp.new()
		ramp.pts = PackedVector2Array(r["pts"])
		ramp.base_y = r["base"]
		ramp.layer_value = _bit_value(combos, r)
		ramp.z_index = Comp.LANE_Z[Comp.lane_of(r)]
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
		mover.layer_value = _bit_value(combos, mv)
		mover.z_index = Comp.LANE_Z[Comp.lane_of(mv)]
		root.add_child(mover)

	# —— 开关门(动态构件:踩踏开关 ↔ 门板 full/none 切换) ——
	for lg in def.lever_gates:
		var gate := LeverGate.new()
		gate.lever_rect = lg["lever"]
		gate.door_item = Comp.normalize(lg["door"])
		gate.invert = lg.get("invert", false)
		gate.layer_bit = combos[Comp.combo_key(lg["door"])]["bit"]
		gate.z_index = Comp.LANE_Z[gate.door_item["lane"]]
		root.add_child(gate)

	# —— 限时桥(动态构件:实心 ↔ 虚化周期切换) ——
	for tb in def.timed_bridges:
		var bridge := TimedBridge.new()
		bridge.slab_rect = tb["rect"]
		bridge.on_time = tb.get("on_time", 2.0)
		bridge.off_time = tb.get("off_time", 2.0)
		bridge.phase = tb.get("phase", 0.0)
		bridge.sync_beat = tb.get("sync_beat", false)
		bridge.layer_bit = combos[Comp.combo_key(tb)]["bit"]
		bridge.z_index = Comp.LANE_Z[Comp.lane_of(tb)]
		root.add_child(bridge)

	# —— 钢琴地板砖(踩踏 / 滚过发声,audio.md §4) ——
	for pt in def.piano_tiles:
		var tile := PianoTile.new()
		tile.slab_rect = pt["rect"]
		tile.note = pt.get("note", "")
		tile.layer_value = _bit_value(combos, pt)
		tile.z_index = Comp.LANE_Z[Comp.lane_of(pt)]
		root.add_child(tile)

	# —— 出口门 ——
	for e in def.exits:
		var door := ExitDoor.new()
		door.geo_index = e[0]
		door.center = e[1]
		root.add_child(door)

	# —— 教学悬浮提示(世界坐标,靠近渐显) ——
	# 浮动轮盘模式下,跳跃域在右半屏:提示词同步换域("点屏"→"右半屏点按")
	var touch := Adaptive.is_touch_mode()
	var wheel: String = Main.I.touch_controls.wheel_mode() \
		if Main.I != null and Main.I.touch_controls != null else ""
	var jump_word := "右半屏点按" if wheel == "float" else "点屏"
	var tap_word := "右半屏轻点" if wheel == "float" else "轻点屏幕"
	for h in def.hints:
		var hm := HintMarker.new()
		hm.position = h["pos"]
		var text := str(h.get("touch", h["text"]) if touch else h["text"])
		if touch:
			text = text.replace("轻点屏幕", tap_word).replace("点屏", jump_word)
		hm.text = text
		root.add_child(hm)

	# —— 几何体:collision_mask = 适用组合位并集,出生算定一次(§7.6) ——
	for idx in def.roster:
		var cd: GeometryDef = Geometries.ALL[idx]
		var p := Player.new()
		p.def = cd
		p.index = idx
		p.spawn_pos = def.spawns[idx]
		p.position = def.spawns[idx]
		p.world_mask = _mask_for(combos, idx)
		root.add_child(p)

	# —— 相机 ——
	var cam := CameraRig.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(def.size.x)
	cam.limit_bottom = int(def.size.y)
	root.add_child(cam)
	return root


## 收集全部组件的 (lane, who) 组合并分配碰撞位:
## 位 1 恒为缺省组合(mid/全员,兼容现状),位 2 预留玩家,其余顺序分配。
static func _compile_combos(def: LevelDef) -> Dictionary:
	var combos := {"mid|all": {"bit": 1, "lane": Comp.LANE_MID, "who": []}}
	var next_bit := 3
	var samples: Array = []
	samples.append_array(def.platforms)
	samples.append_array(def.ramps)
	samples.append_array(def.movers)
	samples.append_array(def.timed_bridges)
	samples.append_array(def.piano_tiles)
	for lg in def.lever_gates:
		samples.append(lg["door"])
	for it in samples:
		var key := Comp.combo_key(it)
		if combos.has(key):
			continue
		if next_bit > 32:
			push_warning("LevelBuilder: 碰撞位预算耗尽(>32 组合),组件被并入缺省位")
			continue
		combos[key] = {
			"bit": next_bit, "lane": Comp.lane_of(it), "who": Comp.who_of(it)}
		next_bit += 1
	return combos


static func _bit_value(combos: Dictionary, item) -> int:
	return 1 << (int(combos[Comp.combo_key(item)]["bit"]) - 1)


## 某几何体的世界碰撞位并集(缺省组合恒适用)。
static func _mask_for(combos: Dictionary, geo_index: int) -> int:
	var mask := 0
	for key in combos:
		var c: Dictionary = combos[key]
		var who: Array = c["who"]
		if who.is_empty() or who.has(geo_index):
			mask |= 1 << (int(c["bit"]) - 1)
	return mask


## 平台碰撞形状:full 四面实心;top / bottom 为单向面
## (bottom 旋转 PI,阻挡面朝下 —— 逆的重力天花板)。
static func _rect_shape(r: Rect2, faces: String) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	cs.position = r.get_center()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	if faces == Comp.FACES_TOP or faces == Comp.FACES_BOTTOM:
		cs.one_way_collision = true
		cs.one_way_collision_margin = 8.0
		if faces == Comp.FACES_BOTTOM:
			cs.rotation = PI
	return cs


## 绘制一组同 lane 平台:硬投影 + 平面石板 + 顶缘亮线,全部直角。
## 组块连接和谐化:
##   1. 投影先全部画完、主体后画 —— 相邻组块的投影不再互相裁切出暗色缝线;
##   2. 坐落在其他组块上的立块,投影只做横向偏移 —— 不在承接面顶缘拖出暗带;
##   3. 立块底缘两侧补 45° 裙角(主体同色的硬折线,非圆角),
##      让"立块 ↔ 承接面"的过渡融为一体。
## lane 视觉规则(art-style.md §6.6,引擎 modulate 实现,不重画瓦片):
##   back = 压亮度至背景红线内;front = 玩家躲入其后时降至 55% 透明度;
##   who 不适用的组件,对当前操控几何体常驻降透明度(0.14s 过渡,M2 档位)。
class LaneRenderer extends Node2D:
	var lane := Comp.LANE_MID
	var items: Array = []            # 归一化组件字典(Comp.normalize)
	var _base: StyleBoxFlat
	var _slab: StyleBoxFlat
	var _alpha: Array = []           # 每件组件的当前透明度系数(0-1)
	const DIM_WHO := 0.30            # who 不适用:常驻降透明度(levels.md §7.7)
	const DIM_FRONT := 0.55          # 前景遮挡:玩家躲入其后
	const TRANS_K := 18.0            # 透明度过渡速率(≈0.16s 收敛,M2 档位)

	func _ready() -> void:
		_base = StyleBoxFlat.new()
		_base.bg_color = Color("262B34")
		_slab = StyleBoxFlat.new()
		_slab.bg_color = Color("313845")
		if lane == Comp.LANE_BACK:
			# 背景红线:PAPER 亮度的 8% 以内(art-style.md §4.1)——
			# 石板基色 ≈0.17 亮度,压到 ×0.45 ≈ 0.077
			modulate = Color(0.45, 0.46, 0.53)
		_alpha.resize(items.size())
		# start_level 装配时序:渲染器 _ready 先于 _collect_players(),
		# players 可能为空 —— active 一律走与 _process 相同的守卫
		var m = Main.I
		var active: int = m._active_slot if m != null and not m.players.is_empty() else -1
		for i in items.size():
			_alpha[i] = _target_alpha(i, active)

	func _target_alpha(i: int, active: int) -> float:
		var m = Main.I
		if lane == Comp.LANE_FRONT:
			if m != null and active >= 0 and active < m.players.size():
				var p: Player = m.players[active]
				if p != null and Comp.rect_of(items[i]).has_point(p.position):
					return DIM_FRONT
			return 1.0
		if active >= 0 and active < m.players.size() \
				and not Comp.applies_to(items[i], m.players[active].index):
			return DIM_WHO
		return 1.0

	func _process(delta: float) -> void:
		var m = Main.I
		var active: int = m._active_slot if m != null and not m.players.is_empty() else -1
		var changed := false
		for i in items.size():
			var t := _target_alpha(i, active)
			if absf(t - _alpha[i]) > 0.003:
				_alpha[i] = lerpf(_alpha[i], t, 1.0 - exp(-TRANS_K * delta))
				if absf(t - _alpha[i]) <= 0.004:
					_alpha[i] = t
				changed = true
		if changed:
			queue_redraw()

	func _draw() -> void:
		var rects: Array = []
		for it in items:
			rects.append(Comp.rect_of(it))
		# —— 第一遍:硬投影(整体位移的实心暗块,无模糊) ——
		for i in items.size():
			var it: Dictionary = items[i]
			if it["faces"] == Comp.FACES_NONE:
				continue
			var r: Rect2 = it["rect"]
			var off := Vector2(7, 8)
			if _rests_on(r):
				off.y = 0.0    # 有承接面:只横向投影,不在对方顶缘留暗带
			draw_rect(Rect2(r.position + off, r.size), Color(0, 0, 0, 0.38 * _alpha[i]))
		# —— 第二遍:主体 + 上层亮面板 + 顶缘亮线(大块先画,小块的顶线不被吞) ——
		var order: Array = []
		for i in items.size():
			order.append(i)
		order.sort_custom(func(a: int, b: int) -> bool:
			var ra: Rect2 = items[a]["rect"]
			var rb: Rect2 = items[b]["rect"]
			return ra.size.x * ra.size.y > rb.size.x * rb.size.y)
		for i0 in order:
			var it: Dictionary = items[i0]
			var r: Rect2 = it["rect"]
			var a: float = _alpha[i0]
			var faces: String = it["faces"]
			if faces == Comp.FACES_NONE:
				# 纯装饰:8% 亮度的线框(与动态构件虚化态同语言)
				draw_rect(r, Color(Ui.PAPER, 0.06 * a))
				draw_rect(r, Color(Ui.PAPER, 0.14 * a), false, 1.5)
				continue
			var is_top := faces == Comp.FACES_TOP
			var is_bottom := faces == Comp.FACES_BOTTOM
			_base.bg_color = Color("2B3140") if is_top \
				else ("232833" if is_bottom else "262B34")
			_base.bg_color.a = a    # who 不适用 / 前景遮挡的降透明(视觉即机制)
			draw_style_box(_base, r)
			var slab := minf(r.size.y * 0.4, 22.0)
			if slab > 2.0:
				_slab.bg_color = Color("3A4254") if is_top else "313845"
				_slab.bg_color.a = a
				draw_style_box(_slab, Rect2(r.position, Vector2(r.size.x, slab)))
			# 顶缘亮线(top 单向板更亮,提示"只有这面是实的")
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)),
				Color(Ui.PAPER, (0.55 if is_top else 0.30) * a))
			# bottom 面:底缘蓝色细线 —— 逆的重力天花板(art-style.md §6.6)
			if is_bottom:
				draw_rect(Rect2(Vector2(r.position.x, r.end.y - 3),
					Vector2(r.size.x, 3)), Color("4E86D8", 0.65 * a))
			# 左缘红色刻度块(构成主义强调点,每 480px 一处)
			var mark_x := 40.0
			while mark_x < r.size.x - 20.0:
				draw_rect(Rect2(r.position + Vector2(mark_x, 0), Vector2(14, 3)),
					Color(Ui.RED, 0.55 * a))
				mark_x += 480.0
		# —— 第三遍:接触裙角 —— 立块底缘两侧的 45° 硬折线小裙边(主体同色),
		# 把立块"种"进承接面,消除生硬的竖直接缝
		for i in items.size():
			var it: Dictionary = items[i]
			var r: Rect2 = it["rect"]
			if it["faces"] == Comp.FACES_NONE or not _rests_on(r):
				continue
			var a: float = _alpha[i]
			var f := 16.0
			var by := r.end.y
			draw_colored_polygon(PackedVector2Array([
				Vector2(r.position.x, by - f), Vector2(r.position.x, by),
				Vector2(r.position.x - f, by)]), Color("262B34", a))
			draw_colored_polygon(PackedVector2Array([
				Vector2(r.end.x, by - f), Vector2(r.end.x, by),
				Vector2(r.end.x + f, by)]), Color("262B34", a))

	## r 是否坐落在同 lane 的另一个组块上(底缘贴着对方顶缘,水平方向有实质搭接)。
	func _rests_on(r: Rect2) -> bool:
		for it in items:
			var u: Rect2 = it["rect"]
			if u == r or u.position.y <= r.position.y:
				continue
			if absf(r.end.y - u.position.y) > 6.0:
				continue
			var overlap := minf(r.end.x, u.end.x) - maxf(r.position.x, u.position.x)
			if overlap >= 6.0:
				return true
		return false


## 曲面跳跃板:折线曲面(碰撞 = 逐段实心凸四边形),几何体沿面滑行,末端沿切线飞出。
class Ramp extends StaticBody2D:
	var pts := PackedVector2Array()
	var base_y := 1000.0
	var layer_value := 1    # 语义组合碰撞位(缺省组合 = 位 1)

	func _ready() -> void:
		collision_layer = layer_value
		collision_mask = 0
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
		# 硬投影(坐落在平台上的曲面只横向偏移,不在承接面顶缘拖出暗带)
		var contact := false
		for p in pts:
			if _over_platform(p.x, base_y):
				contact = true
				break
		var soff := Vector2(7, 0) if contact else Vector2(7, 8)
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + soff)
		shadow.append(Vector2(pts[pts.size() - 1].x + soff.x, base_y + soff.y))
		shadow.append(Vector2(pts[0].x + soff.x, base_y + soff.y))
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

	const THICKNESS := 48.0

	## 曲面是否搭在某块平台之上(x 落在平台范围内,且平台顶缘就在基线附近)。
	func _over_platform(x: float, y: float) -> bool:
		var m = Main.I
		if m == null or m._current < 0:
			return false
		for r0 in LevelData.LEVELS[m._current].platforms:
			var r: Rect2 = r0
			if x >= r.position.x and x <= r.end.x \
					and y >= r.position.y - 8.0 and y <= r.position.y + 60.0:
				return true
		return false


## 移动构件:单轴往返的动平台(AnimatableBody2D + sync_to_physics,
## 站立者由平台速度自然携带)。行程用余弦缓动 —— 两端减速、中段匀速,
## 落点时刻可预判(docs/design/levels.md §3 动态地图原则)。
class Mover extends AnimatableBody2D:
	var rect := Rect2()
	var travel := Vector2.ZERO
	var period := 3.0
	var phase := 0.0
	var layer_value := 1
	var _t := 0.0

	func _ready() -> void:
		sync_to_physics = true
		collision_layer = layer_value
		collision_mask = 0
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


## 限时桥(structures.md §5):周期性实心 ↔ 虚化的桥板 ——
## 虚化期无碰撞(运行时 set_collision_layer_value 切位)、降透明度,
## 保留 8% 亮度线框 + 轨道线,切换状态可预读(可预读纪律)。
## on/off 各 ≥1s 保证可读;sync_beat = 与 BGM 节拍时钟对齐(audio.md §5)。
class TimedBridge extends StaticBody2D:
	var slab_rect := Rect2()
	var on_time := 2.0
	var off_time := 2.0
	var phase := 0.0
	var sync_beat := false
	var layer_bit := 1
	var _t := 0.0
	var _solid := true
	var _beat_phase := 0.0   # 启动时对齐到的节拍相位

	func _ready() -> void:
		collision_layer = 1 << (layer_bit - 1)
		collision_mask = 0
		var cs := CollisionShape2D.new()
		cs.position = slab_rect.get_center()
		var shape := RectangleShape2D.new()
		shape.size = slab_rect.size
		cs.shape = shape
		add_child(cs)
		position = Vector2.ZERO
		if sync_beat and Sfx.beat_period() > 0.0:
			_beat_phase = Sfx.beat_time()
			_t = _beat_phase

	func _physics_process(delta: float) -> void:
		_t += delta
		var cycle := maxf(on_time + off_time, 2.0)
		var t := fposmod(_t + phase, cycle)
		var solid := t < on_time
		if solid != _solid:
			_solid = solid
			# 运行时碰撞位切换(levels.md §7.6):虚化 = 全体不可踩
			set_collision_layer_value(layer_bit, solid)
			queue_redraw()
			if not solid:
				Sfx.play("ui_page", -8.0)
			else:
				Sfx.play("ui_click", -8.0)

	func _draw() -> void:
		var r := Rect2(slab_rect.position, slab_rect.size)
		# 轨道线:桥的行程始终可见(可预读的一部分)
		draw_rect(Rect2(Vector2(r.position.x - 10, r.get_center().y - 1),
			Vector2(4, 2)), Color(Ui.RED, 0.55))
		draw_rect(Rect2(Vector2(r.end.x + 6, r.get_center().y - 1),
			Vector2(4, 2)), Color(Ui.RED, 0.55))
		if _solid:
			draw_rect(Rect2(r.position + Vector2(7, 8), r.size), Color(0, 0, 0, 0.38))
			draw_rect(r, Color("2B3140"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color("3A4254"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Ui.PAPER, 0.42))
			# 实心态刻度:左缘红块(与移动板同语言)
			draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(8, 3)), Color(Ui.RED, 0.8))
		else:
			# 虚化态:8% 亮度线框 + 虚线段(可预读纪律)
			draw_rect(r, Color(Ui.PAPER, 0.08))
			var seg := 14.0
			var x := r.position.x
			while x < r.end.x:
				draw_rect(Rect2(Vector2(x, r.position.y), Vector2(minf(seg, r.end.x - x), 2)),
					Color(Ui.PAPER, 0.30))
				x += seg * 2.0
			draw_rect(r, Color(Ui.PAPER, 0.16), false, 1.0)


## 开关门(structures.md §5):踩踏开关与门板成对 ——
## 有人踩住开关 ↔ 门板碰撞在 full/none 间切换(运行时切位),
## 门板虚化态保留 8% 亮度线框;合作分工新语言:一人踩门一人过。
class LeverGate extends Node2D:
	var lever_rect := Rect2()
	var door_item := {}      # Comp.normalize 后的门板组件字典
	var invert := false      # false:踩下 = 门开;true:踩下 = 门关
	var layer_bit := 1
	var _pressed := false
	var _door_body: StaticBody2D
	var _open := false

	func _ready() -> void:
		var r: Rect2 = door_item["rect"]
		_door_body = StaticBody2D.new()
		_door_body.collision_layer = 1 << (layer_bit - 1)
		_door_body.collision_mask = 0
		var cs := CollisionShape2D.new()
		cs.position = r.get_center()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		_door_body.add_child(cs)
		add_child(_door_body)
		# 踩踏开关:检测几何体站上(检测位 = 玩家层,位 2)
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 2
		var acs := CollisionShape2D.new()
		acs.position = lever_rect.get_center()
		var ashape := RectangleShape2D.new()
		ashape.size = lever_rect.size
		acs.shape = ashape
		area.add_child(acs)
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		add_child(area)
		_apply(_initial_open())

	func _initial_open() -> bool:
		return invert    # 缺省:没人踩 = 门关;invert:没人踩 = 门开

	func _on_body_entered(_body: Node) -> void:
		_pressed = true
		_apply(not invert)
		Sfx.play("ui_click")

	func _on_body_exited(_body: Node) -> void:
		_pressed = false
		_apply(_initial_open())
		Sfx.play("ui_close", -6.0)

	func _apply(open: bool) -> void:
		if _open == open:
			return
		_open = open
		# 运行时碰撞位切换:门板虚化 = 全体不可撞(levels.md §7.6)
		_door_body.set_collision_layer_value(layer_bit, not open)
		queue_redraw()

	func _draw() -> void:
		var r: Rect2 = door_item["rect"]
		if _open:
			# 门板虚化态:8% 亮度线框 + 虚线段(可预读)
			draw_rect(r, Color(Ui.PAPER, 0.06))
			draw_rect(r, Color(Ui.PAPER, 0.14), false, 1.5)
		else:
			draw_rect(Rect2(r.position + Vector2(7, 8), r.size), Color(0, 0, 0, 0.38))
			draw_rect(r, Color("262B34"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color("313845"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Ui.PAPER, 0.30))
		# 踩踏开关:凸 / 凹两态 + 红色刻度(凸 = 待踩,凹 = 踩住)
		var lr := Rect2(lever_rect.position + Vector2(0, lever_rect.size.y - 10),
			Vector2(lever_rect.size.x, 10))
		var pressed := _pressed
		var sink := 4.0 if pressed else 0.0
		draw_rect(Rect2(lr.position + Vector2(-3, 7), lr.size + Vector2(6, 3)),
			Color(0, 0, 0, 0.38))
		draw_rect(Rect2(lr.position + Vector2(0, sink), lr.size),
			Color("313845") if not pressed else Color("3A4254"))
		draw_rect(Rect2(lr.position + Vector2(0, sink),
			Vector2(lr.size.x, 2)), Color(Ui.RED, 0.9 if not pressed else 0.5))
		if pressed:
			draw_rect(Rect2(lever_rect.position + Vector2(lever_rect.size.x * 0.5 - 14,
				lr.position.y - 16), Vector2(28, 3)), Color(Ui.RED, 0.8))


## 钢琴地板砖(audio.md §4):踩踏 / 滚过即发声的平台砖 —— 玩家行为即配乐。
## 音级缺省按格 y 反向映射(越高 = 越高的音,地图即乐谱);
## 触发冷却 0.15s 防连发(圆的 glissando 冷却减半保持音流);
## 落地速度 → 音量;演出 = 顶缘亮线脉冲 + 音符粒子;双几何体同砖 = 和音。
class PianoTile extends StaticBody2D:
	var slab_rect := Rect2()
	var note := ""            # 音名("C4");空 = 按 y 反向映射
	var layer_value := 1
	var _pulse := 0.0         # 顶缘亮线脉冲剩余时间
	var _last_played := {}    # player index -> 上次触发时刻(秒)

	func _ready() -> void:
		collision_layer = layer_value
		collision_mask = 0
		var cs := CollisionShape2D.new()
		cs.position = slab_rect.get_center()
		var shape := RectangleShape2D.new()
		shape.size = slab_rect.size
		cs.shape = shape
		add_child(cs)
		if note.is_empty() and Main.I != null and Main.I._level_def != null:
			note = Sfx.note_for_height(slab_rect.position.y, Main.I._level_def.size.y)

	## 玩家每帧报告接触(由 Player 调用):impact = 落地/滚动速度。
	func strike(player: Player, impact: float) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		var cd := 0.075 if player.def.shape == GeometryDef.Shape.BALL else 0.15
		if _last_played.has(player.index) and now - _last_played[player.index] < cd:
			return
		_last_played[player.index] = now
		_pulse = 0.4
		queue_redraw()
		_note_burst(player)
		var vol := clampf(0.25 + impact / 900.0, 0.25, 1.0)
		Sfx.play_note(note, false, vol)
		if player.rider_of != null or _has_other_rider(player):
			Sfx.play_chord([note, Sfx.note_shift(note, 4)], vol * 0.8)

	## 音符粒子:纸白小方块自砖顶缘散出(audio.md §4 触发演出)。
	func _note_burst(_player: Player) -> void:
		var burst := CPUParticles2D.new()
		burst.one_shot = true
		burst.emitting = true
		burst.amount = 6
		burst.lifetime = 0.35
		burst.explosiveness = 1.0
		burst.spread = 55.0
		burst.direction = Vector2(0, -1)
		burst.gravity = Vector2(0, 240)
		burst.initial_velocity_min = 60.0
		burst.initial_velocity_max = 160.0
		burst.scale_amount_min = 2.0
		burst.scale_amount_max = 3.5
		burst.color = Color(Ui.PAPER, 0.85)
		burst.position = Vector2(0, -slab_rect.size.y * 0.5 - 2.0)
		burst.finished.connect(burst.queue_free)
		add_child(burst)

	## 砖上是否还有另一位几何体(双人同砖 = play_chord 和音,audio.md §4)。
	func _has_other_rider(player: Player) -> bool:
		var m = Main.I
		if m == null:
			return false
		for p in m.players:
			if p != player and is_instance_valid(p) and not p.dying \
					and slab_rect.grow(6.0).has_point(p.position + Vector2(0,
						p.def.size.y * 0.5 * p.gravity_dir)):
				return true
		return false

	func _process(delta: float) -> void:
		if _pulse > 0.0:
			_pulse = maxf(_pulse - delta, 0.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(slab_rect.position, slab_rect.size)
		draw_rect(Rect2(r.position + Vector2(6, 6), r.size), Color(0, 0, 0, 0.30))
		draw_rect(r, Color("262B34"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color("313845"))
		# 顶缘亮线:基态克制,触发时脉冲提亮(motion.md 玩法演出,M5 量级)
		var glow := 0.30 + 0.55 * (_pulse / 0.4)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Ui.PAPER, glow))
		# 音级刻度:左缘红块(触发时展开为双倍宽)
		var mw := 10.0 if _pulse > 0.0 else 5.0
		draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(mw, 3)), Color(Ui.RED, 0.8))


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
		# (debug_zoom > 0:调试锁定变焦 —— 网格 LOD / 远景档截图验证用)
		var speed_mult := absf(p.velocity.x) / Geometries.RUN_SPEED
		var target_zoom := clampf(1.02 - 0.085 * maxf(speed_mult, p.def.base_speed),
			0.80, 1.0)
		if _pulse > 0.0:
			target_zoom *= 0.94
		if m.debug_zoom > 0.0:
			zoom = Vector2(m.debug_zoom, m.debug_zoom)
			target_zoom = m.debug_zoom

		var k := 1.0 - exp((-9.0 if _pulse > 0.0 else -5.5) * delta)
		position = position.lerp(p.position + _look, k)
		var z := lerpf(zoom.x, target_zoom, 1.0 - exp(-3.5 * delta))
		zoom = Vector2(z, z)


## 定位网格:1 格 = 100 px 的世界坐标网格,次格细线、5 格主线、
## 左缘红色刻度块与 HUD 坐标读数(单位:格)一一对齐。
## 三级 LOD(levels.md §8):按视口内"每格像素数"自适应 ——
## 近景 = 1 格细线 + 5 格主线;中景 = 仅 5 格主线;远景 = 10 格点阵 + 缘坐标数字。
class GridLayer extends Node2D:
	var level_size := Vector2.ZERO
	var _tier := 0    # 0 近景 / 1 中景 / 2 远景

	func _ready() -> void:
		z_index = 0

	func _process(_delta: float) -> void:
		var tier := _current_tier()
		if tier != _tier:
			_tier = tier
			queue_redraw()

	func _current_tier() -> int:
		var cam := get_viewport().get_camera_2d()
		var zoom := cam.zoom.x if cam != null else 1.0
		var m = Main.I
		if m != null and m.debug_zoom > 0.0:
			zoom = m.debug_zoom
		var px_per_cell := Geometries.UNIT_PX * zoom
		if px_per_cell >= 56.0:
			return 0
		if px_per_cell >= 26.0:
			return 1
		return 2

	func _draw() -> void:
		if level_size == Vector2.ZERO:
			return
		var unit := Geometries.UNIT_PX
		var w := int(level_size.x / unit)
		var h := int(level_size.y / unit)
		if _tier == 2:
			# 远景:10 格点阵(交点微点比线阵远看不糊)
			var dot := 3.0
			for gx in range(0, w + 1, 10):
				for gy in range(0, h + 1, 10):
					draw_rect(Rect2(gx * unit - dot * 0.5, gy * unit - dot * 0.5,
						dot, dot), Color(Ui.PAPER, 0.16))
			_draw_edge_numbers(w, h, 10)
			return
		# 近景 / 中景:主线 5 格;近景再叠 1 格细线
		var minor_a := 0.045 if _tier == 0 else 0.0
		for gx in w + 1:
			var a := 0.085 if gx % 5 == 0 else minor_a
			if a <= 0.0:
				continue
			draw_line(Vector2(gx * unit, 0), Vector2(gx * unit, level_size.y),
				Color(Ui.PAPER, a), 1.0)
		for gy in h + 1:
			var a := 0.085 if gy % 5 == 0 else minor_a
			if a <= 0.0:
				continue
			draw_line(Vector2(0, gy * unit), Vector2(level_size.x, gy * unit),
				Color(Ui.PAPER, a), 1.0)
		# 左缘红色格点刻度(每 1 格,构成主义强调点)
		for gy in h + 1:
			draw_rect(Rect2(-6, gy * unit - 1.5, 12, 3), Color(Ui.RED, 0.5))
		# 原点十字
		draw_line(Vector2(0, 0), Vector2(26, 0), Color(Ui.RED, 0.55), 2.0)
		draw_line(Vector2(0, 0), Vector2(0, 26), Color(Ui.RED, 0.55), 2.0)

	## 上 / 左双缘坐标数字(levels.md §8.2;游戏内仅远景边缘显示)。
	func _draw_edge_numbers(w: int, h: int, step: int) -> void:
		if Ui.HEAD == null:
			return
		var unit := Geometries.UNIT_PX
		for gx in range(0, w + 1, step):
			var s := str(gx)
			draw_string(Ui.HEAD, Vector2(gx * unit + 4, 14), s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Ui.RED, 0.7))
		for gy in range(step, h + 1, step):
			draw_string(Ui.HEAD, Vector2(4, gy * unit - 4), str(gy),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Ui.RED, 0.7))


## 地图内悬浮文本提示(新手教程):世界坐标里的教学牌 ——
## 一枚红色刻度块 + 基线细线 + 一行说明文字。
## 靠近渐显、远离渐隐(透明度跟随受控几何体的距离);
## 文字自身不做位移动画(物理像素取整会呈不规则 1px 跳步,真机可见卡顿),
## 只做透明度呼吸,动效法则见 docs/design/art-style.md §3。
class HintMarker extends Node2D:
	var text := ""
	var _label: Label
	var _t := randf() * TAU

	func _ready() -> void:
		z_index = 4
		_label = Ui.l(text, 15, Ui.HEAD, Color(Ui.PAPER, 0.92),
			HORIZONTAL_ALIGNMENT_CENTER, true, 0)
		add_child(_label)

	func _process(delta: float) -> void:
		_t += delta
		# 文字水平居中于锚点(每帧校正,宽度随文本/字号缓存而稳)
		var w := _label.get_minimum_size().x
		_label.position = Vector2(-w / 2.0, -36.0)
		# 距离渐显:620px 内线性升到 1.0
		var alpha := 0.0
		var m = Main.I
		if m != null and not m.players.is_empty() \
				and m._active_slot >= 0 and m._active_slot < m.players.size():
			var d: float = m.players[m._active_slot].position.distance_to(global_position)
			alpha = clampf(1.35 - d / 620.0, 0.0, 1.0)
		# 呼吸:透明度 ±8% 波动(周期 ≈2.2s,幅度 ≤10%,M5 动效法则)
		var breathe := 0.92 + 0.08 * sin(_t * 2.85)
		modulate = Color(1, 1, 1, alpha * breathe)

	func _draw() -> void:
		# 锚点刻度:红色小方块 + 基线细线(标注的"落点",与网格刻度同语言)
		draw_rect(Rect2(-5, 0, 10, 10), Color(Ui.RED, 0.9))
		draw_line(Vector2(-52, 18), Vector2(52, 18), Color(Ui.PAPER, 0.22), 1.5)
