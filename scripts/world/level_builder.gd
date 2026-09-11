class_name LevelBuilder

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

	# —— 测试关美术层(MapSkin v0.27):aseprite 地图接管地形外观 ——
	# 碰撞照走平台组件;LaneRenderer 让位(机构物 / 玩家照常引擎绘制);
	# z=-1 沉到网格之下(网格线仍覆在美术上,与 HUD 读数对齐)
	if not def.art.is_empty():
		var tex: Texture2D = load(def.art)
		if tex != null:
			var skin := Sprite2D.new()
			skin.texture = tex
			skin.centered = false
			skin.scale = Vector2(2, 2)   # aseprite 半分辨率绘制 ×2(1 像素 = 2 引擎像素)
			skin.z_index = -1
			root.add_child(skin)

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
			root.add_child(TerrainKit.rect_occluder(it["rect"]))
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
		if not def.art.is_empty():
			continue   # 美术层接管地形外观(碰撞不变)
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
			"rect": TerrainKit.ramp_bounds(ramp.pts, ramp.base_y)})

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
		gate.gate_id = li
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

	# —— 推箱 / 滑雪带 / 传送对 / 弹射板(v0.27 机制群,structures.md §7)——
	for pb in def.push_boxes:
		var box := PushBox.new()
		box.cell = pb["cell"]
		box.z_index = Comp.LAYER_Z[Comp.LAYER_MAIN]
		root.add_child(box)
		focus_entries.append({"node": box,
			"item": {"layer": Comp.LAYER_MAIN, "who": []},
			"rect": Rect2(box.cell - Vector2(50, 50), Vector2(100, 100))})
	for sp in def.ski_patches:
		var ski := SkiPatch.new()
		ski.rect = sp
		root.add_child(ski)
	for pp in def.portals:
		var portal := PortalPair.new()
		portal.a = pp["a"]
		portal.b = pp["b"]
		root.add_child(portal)
	for lp in def.launch_pads:
		var pad := LaunchPad.new()
		pad.pos = lp["pos"]
		pad.launch_vec = lp["vec"]
		root.add_child(pad)

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

	# 推箱层(bit31)并入全员 mask:箱体占位时挡人(Sprint 机制群)
	if not def.push_boxes.is_empty():
		for child in root.get_children():
			if child is Player:
				(child as Player).world_mask |= 1 << 31

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
## (bottom 阻挡面朝下 —— 逆的重力天花板)。
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
			# 4.7 起直接设方向免旋转节点(GH-104736):旧实现 rotation = PI,
			# 等价于把局部阻挡方向 (0,1) 旋到 (0,-1),行为逐位一致
			cs.one_way_collision_direction = Vector2(0, -1)
	return cs
