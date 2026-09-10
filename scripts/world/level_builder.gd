class_name LevelBuilder

## 磁力边界碰撞位(伍·界/边专用;组件签名位只占 3..29,bit30 起为特权位)。
const BOUNDARY_BIT := 1 << 30
## 碰撞签名位分配上限(bit29,共 27 槽):与磁界等特权位彻底隔离,
## 超限构建期报错并丢弃多余签名(§7.10 位上限守卫)。
const MAX_COMBO_BIT := 29

## —— 引擎光影参数(v0.19,art-style.md §8)——
## 亮度模型:最终色 = 本体色 ×(环境档 + 光照档)。
## 受光区 ≈ AMBIENT + SUN(约 1.0,色板还原且带轻微冷暖分离);
## 阴影区只剩 AMBIENT(冷色压暗)= 引擎实算的硬边投影。
## 方向:rotation 0 = 光正下;负角把光转向右上 → 影子投向右下
## (沿袭旧硬投影 offset(7,8) 的方向约定)。
const LIGHT_AMBIENT := Color(0.68, 0.71, 0.82)
const LIGHT_SUN_COLOR := Color(1.0, 0.97, 0.9)
const LIGHT_SUN_ENERGY := 0.36
const LIGHT_SUN_ROTATION := -0.70   # rad ≈ -40°
## L1/L2 深远景(基础透明度 ≤0.34)不挂遮挡体:雾化剪影若投出全强度
## 硬影会与档位失配;L3 起的可见实体件均挂(所见即所影)。
## 把 LevelDef 数据实例化为节点树:平台 / 曲面跳跃板 / 加速门 / 门 / 几何体 / 相机。
## 渲染规范:棱角分明的平面石板,直角硬边;投影一律由引擎光影实算
## (CanvasModulate 压暗 + DirectionalLight2D 抬亮 + LightOccluder2D 遮挡,
## shadow_filter NONE 硬边,art-style.md §8),不再手绘偏移暗块。
## 关卡背景带 1 格 = 100 px 的定位网格(与 HUD 坐标读数对齐)。
##
## 分层语义 v3(levels.md §7.10):八层定值 × 双归属 + 组件编号 ——
##   组件 = {id, layer(1..8), faces, who 集合, tags};实体性写入层表
##   (L4–L7 实体,L1–L3 / L8 景观纯视觉)。构建期把实体层组件实际出现的
##   (layer, who) 签名编译为 Godot 碰撞位(位 1 弃用,位 2 = 玩家几何体,
##   签名位 3..29 按出场顺序分配);玩家 collision_mask = 适用签名位并集,
##   出生算定一次。faces 用 one-way 碰撞实现(top 顶面可站 / bottom 底面
##   可站,逆向天花板)。渲染每层一个 LaneRenderer,实体层组件按高亮
##   三档呈现(专属亮 / 共享常 / 无关暗);机关物由 FocusDriver 驱动同款
##   三档呈现,切换受控几何体时按距离波次交叉淡化。


static func build(def: LevelDef) -> Node2D:
	var root := Node2D.new()
	root.name = "Level"

	# —— 引擎光影 rig(v0.19 art-style §8):环境冷档 + 定向平行光,
	#    遮挡体处实算硬边投影(方向恒定,沿用旧硬投影的右下约定) ——
	var ambient := CanvasModulate.new()
	ambient.color = LIGHT_AMBIENT
	root.add_child(ambient)
	var sun := DirectionalLight2D.new()
	sun.rotation = LIGHT_SUN_ROTATION
	sun.color = LIGHT_SUN_COLOR
	sun.energy = LIGHT_SUN_ENERGY
	sun.shadow_enabled = true
	sun.shadow_filter = DirectionalLight2D.SHADOW_FILTER_NONE   # 禁模糊纪律:硬边
	root.add_child(sun)

	# —— 定位网格(最底层装饰,坐标与 HUD 读数对齐;§8.2 分区标注) ——
	var grid := GridLayer.new()
	grid.level_size = def.size
	grid.zones = def.zones
	root.add_child(grid)

	# —— 语义编译:分层语义 v3(§7.10),签名 = (layer, who),仅实体层占位 ——
	var geos: int = Geometries.ALL.size()
	var combos := _compile_combos(def, geos)

	# —— 每个签名一个静态碰撞体 ——
	var bodies := {}
	for key in combos:
		var c: Dictionary = combos[key]
		var body := StaticBody2D.new()
		body.collision_layer = 1 << (int(c["bit"]) - 1)
		body.collision_mask = 0
		root.add_child(body)
		bodies[key] = body

	# —— 平台:碰撞按签名入位,渲染按八层定值表分组(§7.10) ——
	var items: Array = []
	var used_ids := {}
	var layer_seq := {}
	# 左右隐形墙(仅碰撞,不绘制;对全员恒实体,任何几何体都不可穿出)
	var walls := [
		Rect2(-40, -700, 40, def.size.y + 1400),
		Rect2(def.size.x, -700, 40, def.size.y + 1400),
	]
	for it0 in def.platforms:
		var it := Comp.normalize(it0)
		_assign_id(it, used_ids, layer_seq)
		items.append(it)
		if it["faces"] != Comp.FACES_NONE \
				and int(it["layer"]) >= Comp.LAYER_BACK:
			root.add_child(_rect_occluder(it["rect"]))
		if not Comp.is_solid_layer(it["layer"]) \
				or it["faces"] == Comp.FACES_NONE:
			continue    # 景观层 / 纯装饰:无碰撞(所见即所碰)
		var ckey := Comp.sig_key(it)
		if not combos.has(ckey):
			continue    # 位耗尽被丢弃的签名(构建期已报错)
		bodies[ckey].add_child(_rect_shape(it["rect"], it["faces"]))
	for w in walls:
		bodies["walls"].add_child(_rect_shape(w, Comp.FACES_FULL))
	# 每层一个渲染器,只画自己层的组件 —— 实体层按高亮三档呈现
	# (专属亮 / 共享常 / 无关暗),档间转移走交叉淡化(§7.10)
	for layer in [1, 2, 3, 4, 5, 6, 7, 8]:
		var renderer := LaneRenderer.new()
		renderer.layer = layer
		renderer.items = items.filter(func(it: Dictionary) -> bool:
			return it["layer"] == layer)
		renderer.z_index = Comp.LAYER_Z[layer]
		root.add_child(renderer)

	# —— 机关物的高亮三档呈现由 FocusDriver 统一驱动(§7.10) ——
	var focus_entries: Array = []

	# —— 曲面跳跃板 ——
	for r in def.ramps:
		var ramp := Ramp.new()
		ramp.pts = PackedVector2Array(r["pts"])
		ramp.base_y = r["base"]
		ramp.layer_value = _bit_value(combos, Comp.sig_key(r))
		ramp.z_index = Comp.LAYER_Z[Comp.layer_of(r)]
		root.add_child(ramp)
		focus_entries.append({"node": ramp,
			"item": {"layer": Comp.layer_of(r), "who": Comp.who_of(r)},
			"rect": _ramp_bounds(ramp.pts, ramp.base_y)})

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
		mover.layer_value = _bit_value(combos, Comp.sig_key(mv))
		mover.z_index = Comp.LAYER_Z[Comp.layer_of(mv)]
		root.add_child(mover)
		focus_entries.append({"node": mover,
			"item": {"layer": Comp.layer_of(mv), "who": Comp.who_of(mv)},
			"rect": r})

	# —— 开关门(动态构件:踩踏开关 ↔ 门板 full/none 切换) ——
	# 一门可配多只开关(levers,任一踩住即开):气闸式互让题的数据形态
	for li in def.lever_gates.size():
		var lg = def.lever_gates[li]
		var gate := LeverGate.new()
		var levers: Array = lg.get("levers", [])
		if levers.is_empty():
			levers = [lg["lever"]]
		gate.lever_rects = levers
		gate.door_item = Comp.normalize(lg["door"])
		gate.invert = lg.get("invert", false)
		gate.layer_bit = combos["dyn:lg:%d" % li]["bit"]
		gate.z_index = Comp.LAYER_Z[gate.door_item["layer"]]
		root.add_child(gate)
		focus_entries.append({"node": gate, "item": gate.door_item,
			"rect": gate.door_item["rect"]})

	# —— 限时桥(动态构件:实心 ↔ 虚化周期切换) ——
	for ti in def.timed_bridges.size():
		var tb = def.timed_bridges[ti]
		var bridge := TimedBridge.new()
		bridge.slab_rect = tb["rect"]
		bridge.on_time = tb.get("on_time", 2.0)
		bridge.off_time = tb.get("off_time", 2.0)
		bridge.phase = tb.get("phase", 0.0)
		bridge.sync_beat = tb.get("sync_beat", false)
		bridge.layer_bit = combos["dyn:tb:%d" % ti]["bit"]
		bridge.z_index = Comp.LAYER_Z[Comp.layer_of(tb)]
		root.add_child(bridge)
		focus_entries.append({"node": bridge,
			"item": {"layer": Comp.layer_of(tb), "who": Comp.who_of(tb)},
			"rect": tb["rect"]})

	# —— 钢琴地板砖(踩踏 / 滚过发声,audio.md §4) ——
	for pt in def.piano_tiles:
		var tile := PianoTile.new()
		tile.slab_rect = pt["rect"]
		tile.note = pt.get("note", "")
		tile.layer_value = _bit_value(combos, Comp.sig_key(pt))
		tile.z_index = Comp.LAYER_Z[Comp.layer_of(pt)]
		root.add_child(tile)
		focus_entries.append({"node": tile,
			"item": {"layer": Comp.layer_of(pt), "who": Comp.who_of(pt)},
			"rect": pt["rect"]})

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
		# spawns 契约:按下标索引;缺项退回原点并告警(spawns 按下标的坑,
		# layer_check 教训;数据契约见 levels.md)
		if idx >= def.spawns.size():
			push_warning("LevelBuilder: spawns[%d] 缺项(名册 %s)—— 退回原点" %
				[idx, cd.name])
			while def.spawns.size() <= idx:
				def.spawns.append(Vector2.ZERO)
		if cd.paired:
			# 双子(伍):界生于天花板(a,重力反向挂顶面),边生于地面(b);
			# 两顶之间张成磁力边界,横跨上下两层(characters.md §5)
			var halves: Array = []
			var pa: Vector2
			var pb: Vector2
			if def.spawns[idx] is Dictionary:
				pa = def.spawns[idx]["a"]
				pb = def.spawns[idx]["b"]
			else:
				# 数据契约:paired 几何体必须给 {a,b} 双点;裸点 = 界从地面
				# 兜底点起飞(设计契约见 levels.md,JSON 同构亦支持字典)
				push_warning("LevelBuilder: 双子(%s)spawns[%d] 未给 {a,b} 字典"
					% [cd.name, idx] + " —— 界将从地面兜底点起飞")
				pa = def.spawns[idx]
				pb = pa + Vector2(90, 0)
			for half in 2:
				var hp := Player.new()
				hp.def = cd
				hp.index = idx
				hp.pair_half = half
				hp.spawn_pos = pa if half == 0 else pb
				hp.position = hp.spawn_pos
				hp.world_mask = _mask_for(combos, idx)
				root.add_child(hp)
				halves.append(hp)
			(halves[0] as Player).partner = halves[1]
			(halves[1] as Player).partner = halves[0]
			var mb := MagBoundary.new()
			mb.a = halves[0]
			mb.b = halves[1]
			root.add_child(mb)
			continue
		var p := Player.new()
		p.def = cd
		p.index = idx
		p.spawn_pos = def.spawns[idx]
		p.position = def.spawns[idx]
		p.world_mask = _mask_for(combos, idx)
		root.add_child(p)

	# —— 高亮三档驱动:机关物的专属亮 / 共享常 / 无关暗(§7.10) ——
	var focus := FocusDriver.new()
	focus.entries = focus_entries
	root.add_child(focus)

	# —— 坐标化调试叠加层(--debug-grid:组件 id·层 标注,§8.3) ——
	root.set_meta("items", items)   # HUD 层签名读数经此取组件
	var dbg := DebugGridOverlay.new()
	dbg.items = items
	dbg.entries = focus_entries
	dbg.z_index = 20
	root.add_child(dbg)

	# —— 相机 ——
	var cam := CameraRig.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(def.size.x)
	cam.limit_bottom = int(def.size.y)
	root.add_child(cam)
	return root


## 分层语义 v3(levels.md §7.10):碰撞位编译。
## 签名 = (layer, who 集合),仅实体层(L4–L7)组件参与 —— 景观层纯视觉
## 不占位;同签名共享碰撞位;动态构件(限时桥 / 开关门板)逐实例独占位,
## 防运行时切换误伤共享位。签名位 3..29(MAX_COMBO_BIT)超限报错丢弃,
## 保证永不侵占 bit30 起的磁界等特权位。
static func _compile_combos(def: LevelDef, geos: int) -> Dictionary:
	var combos := {}
	var next_bit := 3
	# 关卡边界隐形墙优先占位:对全员恒实体,无论签名多挤都不得被挤到特权位
	var all: Array = []
	for g in geos:
		all.append(g)
	combos["walls"] = {"bit": next_bit, "midset": all}
	next_bit += 1
	var samples: Array = []
	samples.append_array(def.platforms)
	samples.append_array(def.ramps)
	samples.append_array(def.movers)
	samples.append_array(def.piano_tiles)
	for it0 in samples:
		var it: Dictionary = it0 if it0 is Dictionary else {"rect": it0}
		if not Comp.is_solid_layer(Comp.layer_of(it)):
			continue    # 景观层:纯视觉,不占位
		var key := Comp.sig_key(it)
		if combos.has(key):
			continue
		if next_bit > MAX_COMBO_BIT:
			push_error("LevelBuilder: 碰撞签名位耗尽(上限 bit29,§7.10)"
				+ "—— 签名 %s 起被丢弃" % key)
			break
		combos[key] = {"bit": next_bit, "midset": _expand(Comp.who_of(it), geos)}
		next_bit += 1
	for i in def.timed_bridges.size():
		var tb: Dictionary = def.timed_bridges[i]
		if next_bit <= MAX_COMBO_BIT:
			combos["dyn:tb:%d" % i] = {
				"bit": next_bit, "midset": _expand(Comp.who_of(tb), geos)}
			next_bit += 1
		else:
			push_error("LevelBuilder: 限时桥 %d 碰撞位耗尽被丢弃(§7.10)" % i)
	for i in def.lever_gates.size():
		var door := Comp.normalize(def.lever_gates[i]["door"])
		if next_bit <= MAX_COMBO_BIT:
			combos["dyn:lg:%d" % i] = {
				"bit": next_bit, "midset": _expand(Comp.who_of(door), geos)}
			next_bit += 1
		else:
			push_error("LevelBuilder: 开关门 %d 碰撞位耗尽被丢弃(§7.10)" % i)
	return combos


## who 集合展开为实际可碰撞几何体下标集合(空 = 全员)。
static func _expand(who: Array, geos: int) -> Array:
	var out: Array = []
	for g in geos:
		if who.is_empty() or who.has(g):
			out.append(g)
	return out


## 组件编号分配(§7.10):显式 id 优先(登记占用);缺省按层分段自动编
## (L4 首件 = 401),段内撞号退回负数临时号。
static func _assign_id(it: Dictionary, used: Dictionary, seq: Dictionary) -> void:
	if int(it["id"]) != 0:
		used[int(it["id"])] = true
		return
	var layer: int = it["layer"]
	var n: int = int(seq.get(layer, 0)) + 1
	seq[layer] = n
	var cand: int = layer * 100 + n
	if used.has(cand):
		cand = -(used.size() + 1)
	it["id"] = cand
	used[cand] = true


## 曲面跳跃板的包围框(FocusDriver 波次排序用)。
static func _ramp_bounds(pts: PackedVector2Array, base_y: float) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo + Vector2(0, base_y - lo.y))


## 组件碰撞层值;无签名(纯视觉层)= 0(不与任何几何体碰撞)。
static func _bit_value(combos: Dictionary, key: String) -> int:
	var c: Dictionary = combos.get(key)
	if c == null:
		return 0
	return 1 << (int(c["bit"]) - 1)


## 某几何体的世界碰撞位并集(仅收集对自己是 mid 的签名)。
static func _mask_for(combos: Dictionary, geo_index: int) -> int:
	var mask := 0
	for key in combos:
		if (combos[key]["midset"] as Array).has(geo_index):
			mask |= 1 << (int(combos[key]["bit"]) - 1)
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


## 矩形遮挡体(引擎光影 v0.19,art-style.md §8):世界坐标矩形 →
## 顺时针绕行的闭合遮挡多边形;cull_mode 挡掉自身受影(平台顶面
## 不被自己的遮挡体压出暗带)。
static func _rect_occluder(r: Rect2) -> LightOccluder2D:
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y),
		r.end, Vector2(r.position.x, r.end.y)])
	poly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
	occ.occluder = poly
	return occ


## 绘制一层平台:平面石板 + 顶缘亮线,全部直角;投影由引擎光影实算
## (Level 根节点的 CanvasModulate + DirectionalLight2D + 平台遮挡体,
## art-style.md §8)。八层定值表(§7.10):每层一个渲染器,items 已按层
## 过滤,只画本层组件。实体层(L4–L7)组件按高亮三档呈现:
##   专属(who 含受控者)= 专属色描边脉冲;共享(who 空)= 常亮;
##   无关 = 幽灵暗度(所见即所碰);景观层常驻,深度梯度由 modulate /
##   基础透明度表达(L1 最暗 → L3 背景压亮度,L8 前景躲入降透明)。
## 切换受控几何体时按距离波次交叉淡化(近处先动,≤0.3s)。
class LaneRenderer extends Node2D:
	var layer := Comp.LAYER_MAIN
	var items: Array = []            # 本层归一化组件字典(构建期按 layer 过滤)
	var _base: StyleBoxFlat
	var _slab: StyleBoxFlat
	var _alpha: Array = []           # 每件组件当前透明度系数(0-1)
	var _hl: Array = []              # 每件组件是否处于"专属高亮"
	var _hl_col: Array = []          # 高亮色(受控几何体专属色)
	var _delay: Array = []           # 切换波次剩余延时(近处先动)
	var _last_slot := -1
	const GHOST := 0.35              # 无关件幽灵暗度(§7.10)
	const DIM_FRONT := 0.55          # 前景遮挡:玩家躲入其后
	const STAGGER_PER_PX := 0.00019  # 波次:每 100px 迟 0.019s
	const STAGGER_MAX := 0.30
	const TRANS_K := 18.0            # 透明度过渡速率(≈0.16s 收敛,M2 档位)

	func _ready() -> void:
		_base = StyleBoxFlat.new()
		_base.bg_color = Color("262B34")
		_slab = StyleBoxFlat.new()
		_slab.bg_color = Color("313845")
		# 景观层深度梯度:渗雾冷色(L1/L2)与背景压亮度(L3)(art-style.md §4.1)
		match layer:
			Comp.LAYER_DEEP:
				modulate = Color(0.42, 0.46, 0.58)
			Comp.LAYER_FAR:
				modulate = Color(0.62, 0.66, 0.78)
			Comp.LAYER_BACK:
				# 背景红线:PAPER 亮度的 8% 以内 —— 石板基色 ≈0.17 亮度,压到 ×0.45
				modulate = Color(0.45, 0.46, 0.53)
		var n := items.size()
		_alpha.resize(n)
		_hl.resize(n)
		_hl_col.resize(n)
		_delay.resize(n)
		# start_level 装配时序:渲染器 _ready 先于 _collect_players(),
		# players 可能为空 —— active 一律走与 _process 相同的守卫
		var m = Main.I
		var slot: int = m._active_slot if m != null and not m.players.is_empty() else -1
		_last_slot = slot
		var geo := _geo_of(slot)
		for i in n:
			_hl[i] = false
			_hl_col[i] = Color(0, 0, 0, 0)
			_delay[i] = 0.0
			_alpha[i] = _target_alpha(i, slot, geo)

	func _geo_of(slot: int) -> int:
		var m = Main.I
		if m == null or slot < 0 or slot >= m.players.size():
			return -1
		var p: Player = m.players[slot]
		return p.index if p != null else -1

	func _target_alpha(i: int, slot: int, geo: int) -> float:
		var it: Dictionary = items[i]
		var base: float = Comp.LAYER_BASE_ALPHA.get(layer, 1.0)
		# 景观层:常驻深度档;仅 L8 前景在玩家躲入其后降透明
		if not Comp.is_solid_layer(layer):
			if layer == Comp.LAYER_FRONT and geo >= 0:
				var m = Main.I
				if m != null and slot >= 0 and slot < m.players.size():
					var p: Player = m.players[slot]
					if p != null and (it["rect"] as Rect2).has_point(p.position):
						return DIM_FRONT
			return base
		# 实体层:无关件 → 幽灵暗度(所见即所碰);专属 / 共享 → 常亮
		if geo >= 0 and Comp.display_role(it, geo) == Comp.ROLE_DIM:
			return GHOST
		return base

	func _process(delta: float) -> void:
		var m = Main.I
		var slot: int = m._active_slot if m != null and not m.players.is_empty() else -1
		var geo := _geo_of(slot)
		if slot != _last_slot:
			_last_slot = slot
			if geo >= 0:
				var ppos: Vector2 = m.players[slot].position
				# 切换波次:按与受控几何体的距离排延时,近处先升降
				for i in items.size():
					var d: float = (items[i]["rect"] as Rect2).get_center() \
						.distance_to(ppos)
					_delay[i] = clampf(d * STAGGER_PER_PX, 0.0, STAGGER_MAX)
		var changed := false
		var any_hl := false
		for i in items.size():
			if _delay[i] > 0.0:
				_delay[i] = maxf(_delay[i] - delta, 0.0)
				continue    # 波次未到:保持旧透明度
			var tgt := _target_alpha(i, slot, geo)
			if absf(tgt - _alpha[i]) > 0.003:
				_alpha[i] = lerpf(_alpha[i], tgt, 1.0 - exp(-TRANS_K * delta))
				if absf(tgt - _alpha[i]) <= 0.004:
					_alpha[i] = tgt
				changed = true
			var hl: bool = geo >= 0 and Comp.is_solid_layer(layer) \
				and Comp.display_role(items[i], geo) == Comp.ROLE_FOCUS
			if hl != _hl[i]:
				_hl[i] = hl
				changed = true
			if hl:
				_hl_col[i] = (m.players[slot] as Player).def.color
				any_hl = true
			elif _hl_col[i].a > 0.0:
				_hl_col[i] = Color(0, 0, 0, 0)
				changed = true
		if changed or any_hl:
			queue_redraw()   # 高亮呼吸脉冲需逐帧重绘

	func _visible(i: int) -> bool:
		return _alpha[i] > 0.012

	func _draw() -> void:
		# —— 第一遍:主体 + 上层亮面板 + 顶缘亮线(大块先画,小块的顶线不被吞) ——
		var order: Array = []
		for i in items.size():
			if _visible(i):
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
			_base.bg_color.a = a    # 档位透明度 / 前景遮挡的降透明(视觉即机制)
			draw_style_box(_base, r)
			var slab := minf(r.size.y * 0.4, 22.0)
			if slab > 2.0:
				_slab.bg_color = Color("3A4254") if is_top else "313845"
				_slab.bg_color.a = a
				draw_style_box(_slab, Rect2(r.position, Vector2(r.size.x, slab)))
			# 顶缘亮线(top 单向板更亮,提示"只有这面是实的")
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)),
				Color(Ui.PAPER, (0.55 if is_top else 0.30) * a))
			# bottom 面:底缘蓝色细线 —— 逆的重力天花板(art-style.md §6)
			if is_bottom:
				draw_rect(Rect2(Vector2(r.position.x, r.end.y - 3),
					Vector2(r.size.x, 3)), Color("4E86D8", 0.65 * a))
			# 左缘红色刻度块(构成主义强调点,每 480px 一处)
			var mark_x := 40.0
			while mark_x < r.size.x - 20.0:
				draw_rect(Rect2(r.position + Vector2(mark_x, 0), Vector2(14, 3)),
					Color(Ui.RED, 0.55 * a))
				mark_x += 480.0
		# —— 第二遍:专属高亮描边(呼吸脉冲,受控几何体专属色,§7.10) ——
		for i in items.size():
			if _hl[i] and _visible(i):
				LevelBuilder.draw_focus(self, items[i]["rect"], _hl_col[i])
		# —— 第三遍:接触裙角 —— 立块底缘两侧的 45° 硬折线小裙边(主体同色),
		# 把立块"种"进承接面,消除生硬的竖直接缝
		for i in items.size():
			if not _visible(i) or items[i]["faces"] == Comp.FACES_NONE:
				continue
			if not _rests_on(i):
				continue
			var r: Rect2 = items[i]["rect"]
			var a: float = _alpha[i]
			var f := 16.0
			var by := r.end.y
			draw_colored_polygon(PackedVector2Array([
				Vector2(r.position.x, by - f), Vector2(r.position.x, by),
				Vector2(r.position.x - f, by)]), Color("262B34", a))
			draw_colored_polygon(PackedVector2Array([
				Vector2(r.end.x, by - f), Vector2(r.end.x, by),
				Vector2(r.end.x + f, by)]), Color("262B34", a))

	## items[i] 是否坐落在**同层且可见**的另一个组块上(底缘贴着对方顶缘,
	## 水平方向有实质搭接)—— 承接块淡出后,裙角随之还原为落地态。
	func _rests_on(i: int) -> bool:
		var r: Rect2 = items[i]["rect"]
		for j in items.size():
			if j == i or not _visible(j):
				continue
			var u: Rect2 = items[j]["rect"]
			if u.position.y <= r.position.y:
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
	var layer_value := 1    # 语义签名碰撞位(景观层 = 0:纯视觉)
	var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7.10)

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
		# 遮挡体(引擎光影 v0.19):与绘制主体同形的实体多边形
		if pts.size() >= 2:
			var occ := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			poly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
			var body := PackedVector2Array(pts)
			body.append(Vector2(pts[pts.size() - 1].x, base_y))
			body.append(Vector2(pts[0].x, base_y))
			poly.polygon = body
			occ.occluder = poly
			add_child(occ)

	func _draw() -> void:
		if pts.size() < 2:
			return
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
		# 专属高亮描边(呼吸脉冲,§7.10)
		LevelBuilder.draw_focus(self, LevelBuilder._ramp_bounds(pts, base_y), hl_color)

	const THICKNESS := 48.0


## 移动构件:单轴往返的动平台(AnimatableBody2D + sync_to_physics,
## 站立者由平台速度自然携带)。行程用余弦缓动 —— 两端减速、中段匀速,
## 落点时刻可预判(docs/design/levels.md §3 动态地图原则)。
class Mover extends AnimatableBody2D:
	var rect := Rect2()
	var travel := Vector2.ZERO
	var period := 3.0
	var phase := 0.0
	var layer_value := 1
	var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7.10)
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
		# 遮挡体(引擎光影 v0.19):居中于石板,随平台一起动,投影由引擎实算
		add_child(LevelBuilder._rect_occluder(Rect2(-rect.size / 2.0, rect.size)))
		var renderer := MoverSlab.new()
		renderer.size = rect.size
		add_child(renderer)

	func _physics_process(delta: float) -> void:
		_t += delta
		# 余弦往返:s ∈ [0,1],端点速度为零
		var s := 0.5 - 0.5 * cos(TAU * (_t / maxf(period, 0.1) + phase))
		position = rect.get_center() + travel * s


## 移动石板外观:与静态平台同语言(亮面板 + 顶缘亮线),
## 侧缘红色刻度块标出"正在移动"的身份;投影由引擎光影实算。
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
		draw_style_box(_base, r)
		var slab := minf(size.y * 0.4, 22.0)
		if slab > 2.0:
			draw_style_box(_slab, Rect2(r.position, Vector2(size.x, slab)))
		draw_rect(Rect2(r.position, Vector2(size.x, 2)), Color(Ui.PAPER, 0.42))
		# 左右缘红色移动刻度(与静态平台的左侧刻度区分)
		draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(8, 3)), Color(Ui.RED, 0.8))
		draw_rect(Rect2(Vector2(r.end.x - 8, r.position.y + 3), Vector2(8, 3)),
			Color(Ui.RED, 0.8))
		# 专属高亮描边(读宿主 Mover 的 hl_color,呼吸脉冲,§7.10)
		var mv := get_parent() as Mover
		if mv != null:
			LevelBuilder.draw_focus(self, r, mv.hl_color)


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
	var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7.10)
	var _t := 0.0
	var _solid := true
	var _beat_phase := 0.0   # 启动时对齐到的节拍相位
	var _occ: LightOccluder2D   # 遮挡体随实/虚切换(虚化 = 不投影)

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
		_occ = LevelBuilder._rect_occluder(slab_rect)
		add_child(_occ)
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
			_occ.visible = solid   # 虚化态不投影(与线框虚化语言一致)
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
		# 专属高亮描边(呼吸脉冲,§7.10)
		LevelBuilder.draw_focus(self, r, hl_color)


## 开关门(structures.md §5):踩踏开关与门板成对 ——
## 有人踩住任一开关 ↔ 门板碰撞在 full/none 间切换(运行时切位),
## 门板虚化态保留 8% 亮度线框;合作分工新语言:一人踩门一人过。
## 一门多开关(v0.15):门两侧各一只开关 = 气闸式互让题(先过者踩住
## 对侧开关,接留守者过来),任一开关被踩即算"踩下"。
class LeverGate extends Node2D:
	var lever_rects: Array = []   # Array[Rect2] 踩踏开关板(≥1)
	var door_item := {}      # Comp.normalize 后的门板组件字典
	var invert := false      # false:踩下 = 门开;true:踩下 = 门关
	var layer_bit := 1
	var hl_color := Color(0, 0, 0, 0)   # 门板专属高亮色(FocusDriver 写入,§7.10)
	var _riders: Array = []  # 每只开关上的几何体集合({body: true})
	var _door_body: StaticBody2D
	var _door_occ: LightOccluder2D   # 门板遮挡体随开关切换(门开 = 不投影)
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
		_door_occ = LevelBuilder._rect_occluder(Rect2(-r.size / 2.0, r.size))
		_door_body.add_child(_door_occ)
		# 踩踏开关:检测几何体站上(检测位 = 玩家层,位 2),逐只开关记录乘员
		for i in lever_rects.size():
			var lever_rect: Rect2 = lever_rects[i]
			_riders.append({})
			var area := Area2D.new()
			area.collision_layer = 0
			area.collision_mask = 2
			var acs := CollisionShape2D.new()
			acs.position = lever_rect.get_center()
			var ashape := RectangleShape2D.new()
			ashape.size = lever_rect.size
			acs.shape = ashape
			area.add_child(acs)
			area.body_entered.connect(_on_body_entered.bind(i))
			area.body_exited.connect(_on_body_exited.bind(i))
			add_child(area)
		_apply(_initial_open())

	func _initial_open() -> bool:
		return invert    # 缺省:没人踩 = 门关;invert:没人踩 = 门开

	func _any_pressed() -> bool:
		for riders in _riders:
			if not (riders as Dictionary).is_empty():
				return true
		return false

	func _on_body_entered(body: Node, i: int) -> void:
		_riders[i][body] = true
		_apply(not invert)
		Sfx.play("ui_click")
		queue_redraw()

	func _on_body_exited(body: Node, i: int) -> void:
		_riders[i].erase(body)
		if not _any_pressed():
			_apply(_initial_open())
			Sfx.play("ui_close", -6.0)
		queue_redraw()

	func _apply(open: bool) -> void:
		if _open == open:
			return
		_open = open
		# 运行时碰撞位切换:门板虚化 = 全体不可撞(levels.md §7.6)
		_door_body.set_collision_layer_value(layer_bit, not open)
		_door_occ.visible = not open   # 门开不投影(与线框虚化语言一致)
		queue_redraw()

	func _draw() -> void:
		var r: Rect2 = door_item["rect"]
		if _open:
			# 门板虚化态:8% 亮度线框 + 虚线段(可预读)
			draw_rect(r, Color(Ui.PAPER, 0.06))
			draw_rect(r, Color(Ui.PAPER, 0.14), false, 1.5)
		else:
			draw_rect(r, Color("262B34"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color("313845"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Ui.PAPER, 0.30))
		# 踩踏开关:凸 / 凹两态 + 红色刻度(凸 = 待踩,凹 = 踩住);
		# 开关与门之间画一条 8% 亮度的地面连线,标出"这只开关管这扇门"
		for i in lever_rects.size():
			var lever_rect: Rect2 = lever_rects[i]
			var lr := Rect2(lever_rect.position + Vector2(0, lever_rect.size.y - 10),
				Vector2(lever_rect.size.x, 10))
			var pressed: bool = not (_riders[i] as Dictionary).is_empty()
			var sink := 4.0 if pressed else 0.0
			var link_y := lr.end.y - 2.0
			var lx0 := minf(lr.get_center().x, r.get_center().x)
			var lx1 := maxf(lr.get_center().x, r.get_center().x)
			draw_rect(Rect2(Vector2(lx0, link_y), Vector2(lx1 - lx0, 2)),
				Color(Ui.RED if pressed else Ui.PAPER, 0.22 if pressed else 0.10))
			draw_rect(Rect2(Vector2(lr.position.x - 3, lr.end.y - 3),
				Vector2(lr.size.x + 6, 3)), Color(0, 0, 0, 0.38))
			draw_rect(Rect2(lr.position + Vector2(0, sink), lr.size),
				Color("313845") if not pressed else Color("3A4254"))
			draw_rect(Rect2(lr.position + Vector2(0, sink),
				Vector2(lr.size.x, 2)), Color(Ui.RED, 0.9 if not pressed else 0.5))
			if pressed:
				draw_rect(Rect2(lever_rect.position + Vector2(lever_rect.size.x * 0.5 - 14,
					lr.position.y - 16), Vector2(28, 3)), Color(Ui.RED, 0.8))
		# 门板专属高亮描边(呼吸脉冲,§7.10)
		LevelBuilder.draw_focus(self, r, hl_color)


## 钢琴地板砖(audio.md §4):踩踏 / 滚过即发声的平台砖 —— 玩家行为即配乐。
## 音级缺省按格 y 反向映射(越高 = 越高的音,地图即乐谱);
## v0.16 触发重构:接触沿触发一次,持续接触仅圆的滚奏(移动中)按 0.075s
## 重触发(glissando)——静止压砖不再"机关枪式"连响;
## 落地速度 → 音量;演出 = 顶缘亮线脉冲 + 音符粒子;双几何体同砖 = 和音。
## 磁力边界(伍·界/边,characters.md §5):两半顶部之间的阻隔线,
## 随两半移动逐帧伸缩;碰撞位 BOUNDARY_BIT(逆与双体自身的 mask 不含它)。
## v1 纪律:线只阻挡不推移——两半快速分开时,原线处的几何体不会被扫飞。
class MagBoundary extends StaticBody2D:
	var a: Player
	var b: Player
	var _seg := SegmentShape2D.new()

	func _ready() -> void:
		collision_layer = LevelBuilder.BOUNDARY_BIT
		collision_mask = 0
		var cs := CollisionShape2D.new()
		cs.shape = _seg
		add_child(cs)
		z_index = 4

	func _physics_process(_dt: float) -> void:
		if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
			return
		# 任一半死亡 / 进门:磁界收线(两端并拢 = 不再阻隔任何人),
		# 防止重生瞬间线横跨全图把无关几何体挡在半路(对象失效防护)
		if a.dying or b.dying or a.in_exit or b.in_exit:
			_seg.a = Vector2.ZERO
			_seg.b = Vector2.ZERO
			queue_redraw()
			return
		_seg.a = to_local(a.boundary_anchor())
		_seg.b = to_local(b.boundary_anchor())
		queue_redraw()

	func _draw() -> void:
		if a == null or b == null:
			return
		var col: Color = a.def.color
		var pa := _seg.a
		var pb := _seg.b
		var d := pb - pa
		if d.length() < 8.0:
			return
		var mid := (pa + pb) * 0.5
		var n := Vector2(-d.y, d.x).normalized()
		var bow := n * clampf(d.length() * 0.08, 4.0, 14.0)
		# 磁力折线:三段硬折(构成主义,不弯曲)
		var pts := PackedVector2Array([pa, pa + d * 0.3 + bow,
			pa + d * 0.7 + bow, pb])
		for i in 3:
			draw_line(pts[i], pts[i + 1], Color(col, 0.85), 2.5)
		# 端点方块 + 折点中块(磁力感)
		draw_rect(Rect2(pa - Vector2(4, 4), Vector2(8, 8)), Color(col, 0.95))
		draw_rect(Rect2(pb - Vector2(4, 4), Vector2(8, 8)), Color(col, 0.95))
		draw_rect(Rect2(mid + bow - Vector2(3, 3), Vector2(6, 6)), Color(Ui.PAPER, 0.9))


class PianoTile extends StaticBody2D:
	var slab_rect := Rect2()
	var note := ""            # 音名("C4");空 = 按 y 反向映射
	var layer_value := 1
	var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7.10)
	var _pulse := 0.0         # 顶缘亮线脉冲剩余时间
	var _last_played := {}    # 体身份键(body_key)-> 上次触发时刻(秒)
	var _in_contact := {}    # 体身份键 -> 是否接触中(接触沿判定,v0.16;
	                         # 双体两半各占一键,互不吞接触沿)

	func _ready() -> void:
		collision_layer = layer_value
		collision_mask = 0
		var cs := CollisionShape2D.new()
		cs.position = slab_rect.get_center()
		var shape := RectangleShape2D.new()
		shape.size = slab_rect.size
		cs.shape = shape
		add_child(cs)
		add_child(LevelBuilder._rect_occluder(slab_rect))   # 引擎光影遮挡体(v0.19)
		if note.is_empty() and Main.I != null and Main.I._level_def != null:
			note = Sfx.note_for_height(slab_rect.position.y, Main.I._level_def.size.y)

	## 玩家每帧报告接触(由 Player 调用):impact = 落地/滚动速度。
	## 接触沿触发一次;持续接触仅圆的滚奏(移动中)按 0.075s 重触发。
	func strike(player: Player, impact: float) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		var bk: int = player.body_key()
		var entering: bool = not _in_contact.get(bk, false)
		_in_contact[bk] = true
		if not entering:
			var rolling: bool = player.def.shape == GeometryDef.Shape.BALL 				and absf(player.velocity.x) > 60.0
			if not rolling or _last_played.has(bk) 					and now - _last_played[bk] < 0.075:
				return
		_last_played[bk] = now
		_pulse = 0.4
		queue_redraw()
		_note_burst(player)
		var vol := clampf(0.25 + impact / 900.0, 0.25, 1.0)
		Sfx.play_note(note, false, vol)
		if player.rider_of != null or _has_other_rider(player):
			Sfx.play_chord([note, Sfx.note_shift(note, 4)], vol * 0.8)

	## 玩家离砖(由 Player 在接触结束时调用):复位接触沿,下次踩上重新触发。
	## key = 体身份键(body_key):双体两半的接触沿互不牵连。
	func release(key: int) -> void:
		_in_contact[key] = false

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
		draw_rect(r, Color("262B34"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color("313845"))
		# 顶缘亮线:基态克制,触发时脉冲提亮(motion.md 玩法演出,M5 量级)
		var glow := 0.30 + 0.55 * (_pulse / 0.4)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Ui.PAPER, glow))
		# 音级刻度:左缘红块(触发时展开为双倍宽)
		var mw := 10.0 if _pulse > 0.0 else 5.0
		draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(mw, 3)), Color(Ui.RED, 0.8))
		# 专属高亮描边(呼吸脉冲,§7.10)
		LevelBuilder.draw_focus(self, r, hl_color)


## 专属高亮描边(高亮三档,levels.md §7.10):几何体专属色 2px 外框 +
## 呼吸脉冲;col.a = 0 时不画(LaneRenderer 与机关物 _draw 共用)。
static func draw_focus(c: CanvasItem, r: Rect2, col: Color) -> void:
	if col.a <= 0.0:
		return
	var pl := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	c.draw_rect(r.grow(3.0), Color(col.r, col.g, col.b, col.a * pl), false, 2.0)


## 高亮三档驱动(§7.10):机关物(Ramp / Mover / PianoTile / LeverGate /
## TimedBridge)不走 LaneRenderer —— 本节点逐帧按 (layer, who) × 受控
## 几何体计算 modulate 透明度与专属高亮色,写回各机关的 hl_color 并触发
## 重绘;碰撞归属仍由构建期签名位决定,这里只管呈现。景观层机关走
## Comp.LAYER_BASE_ALPHA 基础透明度。
class FocusDriver extends Node2D:
	## {node: Node2D(带 hl_color 属性), item: {layer, who}, rect: Rect2}
	var entries: Array = []
	var _hl: Array = []
	var _last_slot := -1
	const GHOST := 0.35
	const TRANS_K := 14.0

	func _ready() -> void:
		_hl.resize(entries.size())
		for i in _hl.size():
			_hl[i] = false
		var m = Main.I
		_last_slot = m._active_slot if m != null and not m.players.is_empty() else -1

	func _process(delta: float) -> void:
		var m = Main.I
		var slot: int = m._active_slot if m != null and not m.players.is_empty() else -1
		var geo := -1
		if m != null and slot >= 0 and slot < m.players.size() \
				and m.players[slot] != null:
			geo = m.players[slot].index
		for i in entries.size():
			var e: Dictionary = entries[i]
			var node = e["node"]           # 故意不标类型:hl_color 为鸭子属性
			var role := Comp.display_role(e["item"], geo)
			var tgt: float = Comp.LAYER_BASE_ALPHA.get(
				Comp.layer_of(e["item"]), 1.0)
			if role == Comp.ROLE_DIM:
				tgt = GHOST
			node.modulate.a = lerpf(node.modulate.a, tgt,
				1.0 - exp(-TRANS_K * delta))
			var want := Color(0, 0, 0, 0)
			if role == Comp.ROLE_FOCUS and geo >= 0:
				want = (m.players[slot] as Player).def.color
			var was_hl: bool = _hl[i]
			var changed := false
			if node.hl_color != want:
				node.hl_color = want
				changed = true
			_hl[i] = want.a > 0.0
			if _hl[i] or changed or was_hl:
				node.queue_redraw()   # 高亮脉冲逐帧重绘;退出高亮补一帧清框


## 坐标化调试叠加层(--debug-grid,levels.md §8.3):组件左上格点标注
## `id·层`,who 非空组件加首位几何体色点并附 who 名单;机关物同款。
## 默认关闭,命令行 `--debug-grid` 开启后逐帧重绘。
class DebugGridOverlay extends Node2D:
	var items: Array = []    # 归一化平台组件(Comp.normalize)
	var entries: Array = []  # 机关物条目 {item: {layer, who, id?}, rect}
	var _on := false

	func _process(_delta: float) -> void:
		var m = Main.I
		var on: bool = m != null and m.debug_grid
		if on != _on:
			_on = on
		if on:
			queue_redraw()

	func _draw() -> void:
		if not _on:
			return
		for it in items:
			var r: Rect2 = it["rect"]
			var who: Array = it["who"]
			var mark := str(it["id"]) + "·L" + str(it["layer"])
			if not who.is_empty():
				var names := PackedStringArray()
				for g in who:
					names.append(Geometries.ALL[clampi(int(g), 0,
						Geometries.ALL.size() - 1)].name)
				mark += "·{" + "+".join(names) + "}"
				var gc: Color = Geometries.ALL[clampi(int(who[0]), 0,
					Geometries.ALL.size() - 1)].color
				draw_circle(r.position + Vector2(-5, -5), 3.5, Color(gc, 0.9))
			draw_string(Ui.HEAD, r.position + Vector2(5, 13), mark,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Ui.PAPER, 0.6))
		for e in entries:
			var er: Rect2 = e["rect"]
			var it2: Dictionary = e["item"]
			draw_string(Ui.HEAD, er.position + Vector2(5, 13),
				str(int(it2.get("id", 0))) + "·L" + str(Comp.layer_of(it2)),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Ui.PAPER, 0.6))


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
	var zones: Array = []   # 命名分区 [{rect, name, layer}](levels.md §8.2)
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
		# —— 分区坐标系(§8.2):边界竖线 + 分区名(近景 LOD 显示)——
		if _tier == 0:
			for z in zones:
				var zr: Rect2 = z["rect"]
				draw_line(Vector2(zr.position.x, 0),
					Vector2(zr.position.x, level_size.y), Color(Ui.PAPER, 0.13), 1.0)
				if Ui.HEAD != null:
					draw_string(Ui.HEAD, zr.position + Vector2(10, 30),
						str(z["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
						Color(Ui.PAPER, 0.30))

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
## 一枚红色刻度块 + 基线细线 + 一行说明文字,文字垫在墨色实心底板上
## (构成主义底板 + 红色左缘刻度,v0.15:真机户外可读性优先)。
## 靠近渐显、远离渐隐(透明度跟随受控几何体的距离);
## 文字自身不做位移动画(物理像素取整会呈不规则 1px 跳步,真机可见卡顿),
## 只做透明度呼吸,动效法则见 docs/design/art-style.md §3。
class HintMarker extends Node2D:
	var text := ""
	var _label: Label
	var _plate: PanelContainer
	var _t := randf() * TAU
	const FADE_RADIUS := 780.0    # 渐显半径(px):7.8 格内线性升到 1.0

	func _ready() -> void:
		z_index = 4
		var touch := Adaptive.is_touch_mode()
		_plate = PanelContainer.new()
		_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate.add_theme_stylebox_override("panel",
			Ui.sb(Color(Ui.INK, 0.72), 0, Color(Ui.PAPER, 0.14), 1, 12, 5))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 9)
		var mark := ColorRect.new()
		mark.color = Ui.RED
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.custom_minimum_size = Vector2(4, 16 if touch else 14)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		_label = Ui.l(text, 17 if touch else 15, Ui.HEAD, Color(Ui.PAPER, 0.94),
			HORIZONTAL_ALIGNMENT_CENTER, true, 0)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_label)
		_plate.add_child(row)
		add_child(_plate)

	func _process(delta: float) -> void:
		_t += delta
		# 底板水平居中于锚点、悬在刻度块之上(每帧校正,宽度随文本/字号缓存而稳)
		var s := _plate.get_combined_minimum_size()
		_plate.position = Vector2(-s.x / 2.0, -s.y - 26.0)
		# 距离渐显:FADE_RADIUS 内线性升到 1.0
		var alpha := 0.0
		var m = Main.I
		if m != null and not m.players.is_empty() \
				and m._active_slot >= 0 and m._active_slot < m.players.size():
			var d: float = m.players[m._active_slot].position.distance_to(global_position)
			alpha = clampf(1.35 - d / FADE_RADIUS, 0.0, 1.0)
		# 呼吸:透明度 ±8% 波动(周期 ≈2.2s,幅度 ≤10%,M5 动效法则)
		var breathe := 0.92 + 0.08 * sin(_t * 2.85)
		modulate = Color(1, 1, 1, alpha * breathe)

	func _draw() -> void:
		# 锚点刻度:红色小方块 + 基线细线 + 到底板的竖向牵引线(标注的"落点")
		draw_rect(Rect2(-5, 0, 10, 10), Color(Ui.RED, 0.9))
		draw_line(Vector2(-52, 18), Vector2(52, 18), Color(Ui.PAPER, 0.22), 1.5)
		draw_line(Vector2(0, -24), Vector2(0, -2), Color(Ui.PAPER, 0.30), 1.5)
