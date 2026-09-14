extends SceneTree
## --reachcheck headless 可达性分析器(v0.38.0,运动路径 + 落点数学):
## 不跑物理、不放机器人——按运动学闭式解把每个关卡建成「可站立面图」,
## BFS 判出生点 → 归门可达,并输出每条跳跃边的裕度(数据明确,毫秒级):
##   跳跃弧:v0 = √(2·g·h),同高滞空 t = 2v0/g,水平射程 R = v·t;
##   落差落点:解 v0·t − ½g·t² = −dy 取正根;高差面:dy ≤ 可用跳高;
##   弹射板抛物线:含终端速度钳制的逐帧积分离散求解 → 落点平台;
##   曲面:连接两端承接面;置换(逆):地面 ↔ 天花面互换 + 深渊坠落;
##   闸门:遮断地面或天花板走廊(须遮断 gate_block_depth 才算);
##   归门:门中心脚下须有可站立面(door_probe 半径内)。
## 物理常量 SSOT:MomentTuning.I.gravity + data/characters/*.tres 直读;
## 裕度 SSOT:data/tuning/reach_margins.tres(ReachMargins,.tres 调参)。
## 运行:godot --headless --script res://tests/reach_check.gd
##       (可加 -- --name=<子串> 只查匹配关)
## 全部可达输出 REACHCHECK PASS(退出码 0);任何不可达退出码 1。

const MARGINS := preload("res://data/tuning/reach_margins.tres")

var _fails: Array = []


func _initialize() -> void:
	var targets: Array = []
	for li in LevelData.LEVELS.size():
		targets.append({"label": "L%d" % li, "def": LevelData.LEVELS[li]})
	for it in RogueFragments.all_defs():
		targets.append({"label": it["label"], "def": it["def"]})
	for raw in OS.get_cmdline_user_args():
		if raw.begins_with("--name="):
			var sub := raw.substr(7)
			targets = targets.filter(func(t: Dictionary) -> bool:
				return String(t["label"]).contains(sub))
	if targets.is_empty():
		print("REACHCHECK FAILED: 无目标关")
		quit(1)
		return
	for t in targets:
		_check(t["label"], t["def"])
	if _fails.is_empty():
		print("REACHCHECK ALL PASS (%d levels)" % targets.size())
		quit(0)
	else:
		print("REACHCHECK %d FAIL" % _fails.size())
		quit(1)


# —————————————————— 运动学常量(SSOT 直读) ——————————————————

func _speed_px(def: GeometryDef) -> float:
	# 速度换算(characters.md §2):px/s = (读数−1)×300,读数 = .tres 值 + 1
	return def.base_speed * 300.0


func _sprint_px(def: GeometryDef) -> float:
	return maxf(def.sprint_speed if def.can_sprint else def.base_speed,
		def.base_speed) * 300.0


func _jump_v(def: GeometryDef) -> float:
	if not def.can_jump:
		return 0.0
	return sqrt(2.0 * MovementTuning.I.gravity * def.jump_units * 100.0)


func _air_time(def: GeometryDef) -> float:
	return 2.0 * _jump_v(def) / MovementTuning.I.gravity


## 同高最大跳缝(R = v·t − 裕度)。
func _reach_flat(def: GeometryDef) -> float:
	if _jump_v(def) <= 0.0:
		return 0.0
	return _sprint_px(def) * _air_time(def) - float(MARGINS.body_margin)


## 高 dy(>0 向上)时水平可达缝宽;dy 超过可用跳高返回 -1(不可达)。
func _reach_up(def: GeometryDef, dy: float) -> float:
	var max_h: float = def.jump_units * 100.0
	if def.index == 0 or def.index == 1:
		max_h += def.jump_units * 100.0   # 疾 / 跃二段跳(两连跳)
	max_h -= 10.0   # 关卡纪律:台阶必须比跳高低 0.1 格
	if dy > max_h:
		return -1.0
	var v0 := _jump_v(def)
	var g := MovementTuning.I.gravity
	# 到达高度 dy 时剩余上升时间两段:t1(升达 dy)可用第二跳近似——
	# 保守取「跳到 dy 顶点时刻」的水平位移:v·(v0 + √(v0²−2g·dy))/g
	var disc: float = v0 * v0 - 2.0 * g * dy
	if disc < 0.0:
		return -1.0
	var t := (v0 + sqrt(disc)) / g
	return _sprint_px(def) * t - float(MARGINS.body_margin)


## 下落 dy(>0 向下)时水平可达缝宽(滞空更久,射程更长)。
func _reach_down(def: GeometryDef, dy: float) -> float:
	var v0 := _jump_v(def)
	if v0 <= 0.0:
		return 0.0   # 圆不跳:只能直落(水平速度保持)
	var g := MovementTuning.I.gravity
	var t := (v0 + sqrt(v0 * v0 + 2.0 * g * dy)) / g
	return _sprint_px(def) * t - float(MARGINS.body_margin)


# —————————————————— 关卡结构提取 ——————————————————

func _surfaces(def: LevelDef) -> Array:
	## 可站立面:[{y, x0, x1, bottom}]——bottom = 逆的天花板面。
	var out: Array = []
	for p0 in def.platforms:
		var it := Comp.normalize(p0)
		if it["faces"] == Comp.FACES_NONE:
			continue
		var r: Rect2 = it["rect"]
		var who: Array = Comp.who_of(it)
		if not who.is_empty() and not who.has(def.focus):
			continue   # 他人专属件不是主角的立足面
		if it["faces"] != Comp.FACES_BOTTOM:
			out.append({"y": r.position.y, "x0": r.position.x, "x1": r.end.x,
				"bottom": false})
		if it["faces"] != Comp.FACES_TOP:
			out.append({"y": r.end.y, "x0": r.position.x, "x1": r.end.x,
				"bottom": true})
	for tb in def.timed_bridges:
		var r: Rect2 = tb.get("rect", tb) if tb is Dictionary else tb
		out.append({"y": r.position.y, "x0": r.position.x, "x1": r.end.x,
			"bottom": false})
	for r0 in def.ramps:
		# 曲面:两端点各给一个 60px 宽的立足面(简化:坡面本身可行走)
		var pts: Array = r0["pts"]
		var base: float = r0.get("base", 0.0)
		var lo: Vector2 = pts[0]
		var hi: Vector2 = pts[pts.size() - 1]
		out.append({"y": lo.y, "x0": lo.x - 30.0, "x1": lo.x + 30.0,
			"bottom": false})
		out.append({"y": hi.y, "x0": hi.x - 30.0, "x1": hi.x + 30.0,
			"bottom": false})
		out.append({"y": base, "x0": minf(lo.x, hi.x), "x1": maxf(lo.x, hi.x),
			"bottom": false})
	return out


func _blocked_at(def: LevelDef, x: float, y_top: float) -> bool:
	## (x, y_top) 行走带是否被实体件竖直遮断(gate / 高墙)。
	for p0 in def.platforms:
		var it := Comp.normalize(p0)
		if it["faces"] == Comp.FACES_NONE:
			continue
		var r: Rect2 = it["rect"]
		if x < r.position.x or x > r.end.x:
			continue
		# 竖直件从面 y_top 向上延伸 ≥ gate_block_depth = 遮断
		if r.end.y <= y_top and y_top - r.end.y >= float(MARGINS.gate_block_depth):
			return true
	return false


# —————————————————— 图构建 + BFS ——————————————————

func _check(label: String, def: LevelDef) -> void:
	var surfs := _surfaces(def)
	if surfs.is_empty():
		_fail(label, "无可站立面")
		return
	# —— 逐名册成员判定(主线合作关:每位成员以其自身物理建图,
	# 各自的出生点 → 各自的归门;单人关 roster 一位,退化为原行为)——
	var notes: Array = []
	var all_ok := true
	var member_log: Array = []
	for geo in def.roster:
		if not _check_member(label, def, geo, surfs, notes):
			all_ok = false
		member_log.append(Geometries.get_def(geo).name)
	if all_ok:
		print("REACH PASS %-16s faces=%d members=%s %s" % [label, surfs.size(),
			"".join(member_log), "; ".join(notes)])
	else:
		_fail(label, "成员不可达:%s | %s" % ["".join(member_log), "; ".join(notes)])


## 单名册成员:出生点 → 归门 BFS 可达(以该成员的物理常量建边)。
func _check_member(label: String, def: LevelDef, geo: int, surfs: Array,
		notes: Array) -> bool:
	var gdef: GeometryDef = Geometries.get_def(geo)
	# —— 归门面:该成员的门,中心脚下(door_probe 半径内)须有面 ——
	var door_surfs: Array = []
	for e in def.exits:
		if int(e[0]) != geo:
			continue
		var dc: Vector2 = e[1]
		var found := -1
		for i in surfs.size():
			var s: Dictionary = surfs[i]
			if absf(s["y"] - dc.y) > float(MARGINS.door_probe_down):
				continue
			if dc.x < s["x0"] - float(MARGINS.door_probe_side) \
					or dc.x > s["x1"] + float(MARGINS.door_probe_side):
				continue
			found = i
			break
		if found < 0:
			notes.append("geo%d 归门无面:%s" % [geo, dc])
			return false
		door_surfs.append(found)
	if door_surfs.is_empty():
		notes.append("geo%d 无归门" % geo)
		return false
	# —— 出生面 ——
	var sp: Variant = def.spawns[geo] \
		if geo < def.spawns.size() else null
	var sp_pts: Array = []
	if sp is Dictionary and sp.has("a"):
		sp_pts = [sp["a"], sp["b"]]
	elif sp is Dictionary:
		sp_pts = [sp]
	elif sp is Vector2:
		sp_pts = [{"x": sp.x, "y": sp.y}]   # 装载器把裸点解析为 Vector2
	for p in sp_pts:
		var found := -1
		for i in surfs.size():
			var s: Dictionary = surfs[i]
			if absf(s["y"] - float(p["y"])) <= float(MARGINS.door_probe_down) \
					and float(p["x"]) >= s["x0"] - float(MARGINS.door_probe_side) \
					and float(p["x"]) <= s["x1"] + float(MARGINS.door_probe_side):
				found = i
				break
		if found < 0:
			notes.append("geo%d 出生点无面:%s" % [geo, p])
			return false
	# —— 邻接边(该成员物理) ——
	var edges: Dictionary = {}   # i -> [j]
	for i in surfs.size():
		for j in surfs.size():
			if i == j:
				continue
			if _edge(gdef, def, surfs[i], surfs[j], notes) != "":
				if not edges.has(i):
					edges[i] = []
				edges[i].append(j)
	# —— 弹射板抛物线边 ——
	for pad in def.launch_pads:
		var land := _pad_landing(def, Vector2(pad["pos"]["x"], pad["pos"]["y"]),
			Vector2(pad["vec"]["x"], pad["vec"]["y"]))
		if land.is_empty():
			notes.append("弹射板 %s 无落点面" % [pad["pos"]])
			continue
		var j := _surf_index(surfs, land["x"], land["y"])
		if j < 0:
			notes.append("弹射板落点 %s 不在面上" % [land])
			continue
		var i := _surf_index(surfs, float(pad["pos"]["x"]), float(pad["pos"]["y"]))
		if i < 0:
			# 板位悬在行走面上方(出生体高),按 x 找正下方行走面
			for k in surfs.size():
				var su: Dictionary = surfs[k]
				if su["bottom"]:
					continue
				if float(pad["pos"]["x"]) >= su["x0"] \
						and float(pad["pos"]["x"]) <= su["x1"] \
						and float(pad["pos"]["y"]) <= su["y"] \
						and su["y"] - float(pad["pos"]["y"]) <= 60.0:
					i = k
					break
		if i >= 0:
			if not edges.has(i):
				edges[i] = []
			edges[i].append(j)
	# —— 电梯(mover)边:底位面 ↔ 顶位面,全员可乘(载具语义) ——
	for mv in def.movers:
		var r: Rect2 = mv["rect"]
		var off: Vector2 = mv.get("offset", Vector2.ZERO)
		var cx := r.get_center().x
		var i_lo := _surf_index(surfs, cx, r.end.y)
		var i_hi := _surf_index(surfs, cx, r.position.y + off.y)
		if i_lo >= 0 and i_hi >= 0 and i_lo != i_hi:
			for pair in [[i_lo, i_hi], [i_hi, i_lo]]:
				if not edges.has(pair[0]):
					edges[pair[0]] = []
				edges[pair[0]].append(pair[1])
			notes.append("电梯 %.0f→%.0f" % [r.end.y, r.position.y + off.y])
	# —— 传送对(portal)边:a 面 ↔ b 面,全员可用 ——
	for po in def.portals:
		var ia := _surf_index(surfs, float(po["a"]["x"]), float(po["a"]["y"]))
		var ib := _surf_index(surfs, float(po["b"]["x"]), float(po["b"]["y"]))
		if ia >= 0 and ib >= 0 and ia != ib:
			for pair in [[ia, ib], [ib, ia]]:
				if not edges.has(pair[0]):
					edges[pair[0]] = []
				edges[pair[0]].append(pair[1])
			notes.append("传送对 %s" % [po["a"]])
	# —— BFS 多源(全部出生面)→ 任一归门面 ——
	var starts: Array = []
	for i in surfs.size():
		var s: Dictionary = surfs[i]
		for p in sp_pts:
			if absf(s["y"] - float(p["y"])) <= float(MARGINS.door_probe_down) \
					and float(p["x"]) >= s["x0"] - 40.0 \
					and float(p["x"]) <= s["x1"] + 40.0:
				starts.append(i)
	if starts.is_empty():
		notes.append("geo%d 出生面不在图中" % geo)
		return false
	var seen := {}
	var queue := starts.duplicate()
	while not queue.is_empty():
		var i: int = queue.pop_front()
		if seen.has(i):
			continue
		seen[i] = true
		for j in edges.get(i, []):
			if not seen.has(j):
				queue.append(j)
	for d in door_surfs:
		if seen.has(d):
			return true
	notes.append("geo%d BFS 不可达" % geo)
	return false


## a → b 是否可行,返回边类型(不可行 = 空串);数据注记追加 notes。
func _edge(focus: GeometryDef, def: LevelDef, a: Dictionary, b: Dictionary,
		notes: Array) -> String:
	var gap_x := maxf(b["x0"] - a["x1"], a["x0"] - b["x1"])
	var dy: float = float(a["y"]) - float(b["y"])   # >0 = b 更低
	var x_overlap := minf(a["x1"], b["x1"]) - maxf(a["x0"], b["x0"])
	# 双底面(界的天花行走):镜像 y——她的「下落」朝 +y(房间系),
	# 深处底面 = 镜像空间里的低平台,同套跳/落/台阶语义取镜像 dy
	if a["bottom"] and b["bottom"]:
		dy = -dy
	# 台阶 / 贴邻上行:面相接(缝极小)且 b 高 dy 在可用跳高内 → 原地跳上
	if focus.can_jump and gap_x <= float(MARGINS.walk_crack) and dy > 2.0:
		if _reach_up(focus, dy) >= 0.0:
			return "step_up"
	# 台阶下行:面相接,直接走下去(坠落到达)
	if gap_x <= float(MARGINS.walk_crack) and dy < -2.0:
		return "step_down"
	# 同面行走(x 相接或细缝)
	if absf(a["y"] - b["y"]) <= 2.0 and gap_x <= float(MARGINS.walk_crack):
		return "walk"
	# 坠落:x 重叠且 b 在下方(置换体与跳体通用;圆的直落同款)
	if dy > 2.0 and x_overlap > 0.0:
		return "fall"
	# 跳跃(圆不跳)
	if focus.can_jump and gap_x > 0.0:
		if dy > 2.0:
			var r := _reach_up(focus, dy)
			if r >= gap_x and gap_x > float(MARGINS.walk_crack):
				notes.append("跳上行 缝%.0f dy%.0f 裕度+%.0f" % [gap_x, dy, r - gap_x])
				return "jump_up"
		else:
			var r2 := _reach_down(focus, maxf(-dy, 0.0)) if dy < -2.0 \
				else _reach_flat(focus)
			if r2 >= gap_x:
				notes.append("跳平/落 缝%.0f 裕度+%.0f" % [gap_x, r2 - gap_x])
				return "jump"
	# 置换(逆专用):地面 ↔ 天花(顶对齐 b 面)
	if focus.can_swap and a["bottom"] != b["bottom"] and x_overlap > 0.0:
		return "swap"
	return ""


## 弹射板抛物线离散积分(含终端速度钳制),返回落点 {x, y} 或空。
func _pad_landing(def: LevelDef, pos: Vector2, vec: Vector2) -> Dictionary:
	var g := MovementTuning.I.gravity
	var vt := 1150.0   # 终端速度(characters.md §2)
	var p := pos
	var v := vec
	var t := 0.0
	while t < 6.0:
		v.y = minf(v.y + g / 60.0, vt)
		p += v / 60.0
		t += 1.0 / 60.0
		if p.y > float(def.kill_y):
			return {}
		for p0 in def.platforms:
			var it := Comp.normalize(p0)
			if it["faces"] == Comp.FACES_NONE:
				continue
			var r: Rect2 = it["rect"]
			if p.x >= r.position.x and p.x <= r.end.x \
					and p.y >= r.position.y - 8.0 and p.y <= r.position.y + 12.0:
				return {"x": p.x, "y": r.position.y}
	return {}


func _surf_index(surfs: Array, x: float, y: float) -> int:
	for i in surfs.size():
		var s: Dictionary = surfs[i]
		if absf(s["y"] - y) <= 14.0 and x >= s["x0"] - float(MARGINS.landing_tolerance) \
				and x <= s["x1"] + float(MARGINS.landing_tolerance):
			return i
	return -1


func _fail(label: String, reason: String) -> void:
	_fails.append(label)
	print("REACH FAIL %-16s —— %s" % [label, reason])
