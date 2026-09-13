extends SceneTree
## --gridcheck headless 校验器(levels.md §8.4,坐标化辅助设计):
## 装载 LevelData.LEVELS + 肉鸽片段库(RogueFragments,v0.38.0 起)逐关检查
## 数据纪律:
##   1. 吸附:全部数值必须为整数像素(硬性 FAIL);对齐 0.1 格(10px)
##      为建议(FAIL 不计,仅 WARN 计数)
##   2. 净空:可行走面(faces=full/top 顶面 + faces=bottom 底面)沿
##      who 集合内行走者的体高 + 0.2 格余量,检查实体侵入头顶带;
##      贴合面(高度差 ≤2px,叠放结构)与曲面坡带不视为侵入
##   3. 行程:mover 扫掠包围盒不得与任何实体相交(placement 纪律)
##   4. 越界:组件 / 出生点 / 门 / 曲面折点不得出关卡边界
##   5. 伍门可达:双体门 ±50 区内须同时存在边(顶面落点)与
##      界(天花底面落点)——防 v3 布局死局复发
##   6. 共面接缝:墙状竖直件(宽 ≤2.6 格、高 ≥1.2 格)底缘与可行走面
##      齐平或嵌入不足 0.5 格 = 违规(防高速贴地转角穿模)
## 运行:godot --headless --path . --script res://tests/grid_check.gd
##       (可加 -- --level=N 只查单关;--levels-only 跳过肉鸽片段)
## 全部通过输出 GRIDCHECK PASS(退出码 0);任何 FAIL 退出码 1。

var _fails: Array = []
var _warns := 0


func _initialize() -> void:
	var levels := LevelData.LEVELS
	var only := -1
	var levels_only := false
	for raw in OS.get_cmdline_user_args():
		if raw.begins_with("--level="):
			only = int(raw.substr(8))
		elif raw == "--levels-only":
			levels_only = true
	if levels.is_empty():
		print("GRIDCHECK FAILED: LevelData.LEVELS 为空")
		quit(1)
		return
	var checked := 0
	for li in levels.size():
		if only >= 0 and li != only:
			continue
		_check_level(li, levels[li])
		checked += 1
	# —— 肉鸽片段库(静态纪律同关卡;缺文件在装载期即报错)——
	if not levels_only and only < 0:
		for it in RogueFragments.all_defs():
			_check_level(it["label"], it["def"])
			checked += 1
	if _fails.is_empty():
		print("GRIDCHECK PASS (levels=%d, warns=%d)" % [checked, _warns])
		quit(0)
	else:
		print("GRIDCHECK FAILED: %d 项" % _fails.size())
		quit(1)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("GRIDCHECK FAIL: ", msg)


func _warn(msg: String) -> void:
	_warns += 1
	print("GRIDCHECK WARN: ", msg)


func _snap_check(li: Variant, id: String, v: float) -> void:
	if v != floorf(v):
		_fail("[%s] %s 吸附:非整数像素 %.2f" % [li, id, v])
	elif int(v) % 10 != 0:
		_warn("[%s] %s 建议对齐 0.1 格:%.0f" % [li, id, v])


func _body_need(who: Array, inverted: bool) -> float:
	## 头顶带需求 = who 集合内行走者最大体高 + 0.2 格。
	## 倒行面(天花底)只有 逆/伍 会走;正行面按 who 全员计(空 = 全员)。
	var need := 0.0
	for g in who:
		var cd: GeometryDef = Geometries.ALL[clampi(int(g), 0, Geometries.ALL.size() - 1)]
		if inverted and not (int(g) == 2 or int(g) == 4):
			continue
		need = maxf(need, cd.size.y)
	return (need + 20.0) if need > 0.0 else 0.0


func _check_level(li: Variant, def: LevelDef) -> void:
	# —— 收集实体件(净空/接缝检查对象)与运动件包围盒 ——
	var solids: Array = []
	for p0 in def.platforms:
		var it := Comp.normalize(p0)
		if Comp.is_solid_layer(it["layer"]) and it["faces"] != Comp.FACES_NONE:
			solids.append(it)
	for pt in def.piano_tiles:
		var it := Comp.normalize(pt)
		if it["faces"] != Comp.FACES_NONE:
			solids.append(it)
	for tb in def.timed_bridges:
		var it := Comp.normalize(tb)
		if it["faces"] != Comp.FACES_NONE:
			solids.append(it)
	for lg in def.lever_gates:
		var it := Comp.normalize(lg["door"])
		if it["faces"] != Comp.FACES_NONE:
			solids.append(it)
	var mover_boxes: Array = []
	for mv in def.movers:
		var r: Rect2 = mv["rect"]
		var off: Vector2 = mv.get("offset", Vector2.ZERO)
		var sweep := Rect2(r.position + Vector2(minf(off.x, 0), minf(off.y, 0)),
			r.size + Vector2(absf(off.x), absf(off.y)))
		mover_boxes.append({"rect": sweep, "id": 0})
	# 曲面坡带(碰撞 = 沿面薄带)不参与净空侵入判定;仅越界 / 吸附
	var ramp_pts: Array = []
	for r in def.ramps:
		ramp_pts.append(r["pts"])

	# —— 1. 吸附 + 4. 越界 ——
	var bounds := Rect2(Vector2.ZERO, def.size)

	var snap_rect := func(id: String, r: Rect2) -> void:
		for v in [r.position.x, r.position.y, r.end.x, r.end.y]:
			_snap_check(li, id, v)
		if not bounds.encloses(r):
			_fail("[%s] %s 越界:%s 出关卡边界 %s" % [li, id, r, bounds])

	for i in def.platforms.size():
		var r := Comp.rect_of(def.platforms[i])
		snap_rect.call("组件#%d" % i, r)
	for r in def.ramps:
		var i := 0
		for pnt in r["pts"]:
			_snap_check(li, "曲面折点#%d.%d" % [0, i], pnt.x)
			_snap_check(li, "曲面折点#%d.%d" % [0, i], pnt.y)
			if not bounds.has_point(pnt):
				_fail("[%s] 曲面折点越界:%s" % [li, pnt])
			i += 1
	for i in def.movers.size():
		var r: Rect2 = def.movers[i]["rect"]
		snap_rect.call("摆渡#%d" % i, r)
	for i in def.piano_tiles.size():
		snap_rect.call("琴键#%d" % i, Comp.rect_of(def.piano_tiles[i]))
	for i in def.spawns.size():
		var sp = def.spawns[i]
		var pts: Array = [sp] if sp is Vector2 \
			else ([sp["a"], sp["b"]] if sp is Dictionary else [])
		for pnt in pts:
			_snap_check(li, "出生点#%d" % i, pnt.x)
			_snap_check(li, "出生点#%d" % i, pnt.y)
			if not bounds.has_point(pnt):
				_fail("[%s] 出生点#%d 越界:%s" % [li, i, pnt])
	for e in def.exits:
		_snap_check(li, "门#%d" % e[0], e[1].x)
		_snap_check(li, "门#%d" % e[0], e[1].y)
	for i in def.checkpoints.size():
		var cp: Vector2 = def.checkpoints[i]["pos"]
		_snap_check(li, "信标#%d" % i, cp.x)
		_snap_check(li, "信标#%d" % i, cp.y)
		if not bounds.has_point(cp):
			_fail("[%s] 信标#%d 越界:%s" % [li, i, cp])
	for z in def.zones:
		snap_rect.call("分区 %s" % z.get("name", "?"), z["rect"])

	# —— 2. 净空:可行走面头顶带侵入检查 ——
	for c in solids:
		var cr: Rect2 = c["rect"]
		var faces: String = c["faces"]
		var faces_list: Array = [cr.position.y, cr.end.y] \
			if faces == Comp.FACES_FULL else \
			([cr.position.y] if faces == Comp.FACES_TOP \
			else [cr.end.y] if faces == Comp.FACES_BOTTOM else [])
		for face_y in faces_list:
			var inverted: bool = face_y == cr.end.y and faces != Comp.FACES_TOP
			var dir: float = 1.0 if inverted else -1.0
			var need := _body_need(Comp.who_of(c), inverted)
			if need <= 0.0:
				continue
			var band_lo: float = minf(face_y, face_y + dir * need)
			var band_hi: float = maxf(face_y, face_y + dir * need)
			for d in solids:
				if d == c:
					continue
				var dr: Rect2 = d["rect"]
				var overlap: float = minf(cr.end.x, dr.end.x) - maxf(cr.position.x, dr.position.x)
				if overlap < 20.0:
					continue
				var edge: float = dr.end.y if dir < 0.0 else dr.position.y
				if absf(edge - face_y) <= 2.0:
					continue    # 贴合叠放(承台 / 吊挂),非侵入
				if edge > band_lo and edge < band_hi:
					_fail("[%s] 净空不足:组件 %d(%s)顶/底面 y%.0f 被 %d 侵入(需 %.0f)"
						% [li, Comp.id_of(c), faces, face_y, Comp.id_of(d), need])

	# —— 3. 行程:mover 扫掠包围盒 vs 实体 ——
	for mi in mover_boxes.size():
		var box: Rect2 = mover_boxes[mi]["rect"]
		for s in solids:
			var inter: Rect2 = (box as Rect2).intersection(s["rect"])
			if inter.size.x > 2.0 and inter.size.y > 2.0:
				_fail("[%s] 摆渡#%d 行程扫掠与实体 %d 相交:%s"
					% [li, mi, Comp.id_of(s), inter])

	# —— 5. 伍门可达:双体门 ±50 区内边(顶面)与界(底面)双落点 ——
	for e in def.exits:
		if not Geometries.ALL[clampi(int(e[0]), 0, Geometries.ALL.size() - 1)].paired:
			continue
		var center: Vector2 = e[1]
		var zone := Rect2(center - Vector2(86, 50), Vector2(172, 100))
		var has_ground := false
		var has_ceiling := false
		for s in solids:
			var who: Array = Comp.who_of(s)
			if not (who.is_empty() or who.has(4)):
				continue
			var sr: Rect2 = s["rect"]
			if not sr.grow(2.0).intersects(zone):
				continue
			if s["faces"] != Comp.FACES_BOTTOM \
					and absf(sr.position.y - 15.0 - center.y) <= 50.0:
				has_ground = true
			if s["faces"] != Comp.FACES_TOP \
					and absf(sr.end.y + 15.0 - center.y) <= 50.0:
				has_ceiling = true
		if not (has_ground and has_ceiling):
			_fail("[%s] 伍门(%s)不可达:门区内边落点=%s / 界落点=%s"
				% [li, center, has_ground, has_ceiling])

	# —— 6. 共面接缝:墙状竖直件底缘嵌入不足 0.5 格 ——
	for w in solids:
		var wr: Rect2 = w["rect"]
		if wr.size.x > 260.0 or wr.size.y < 120.0:
			continue
		for s in solids:
			if s == w:
				continue
			var sr: Rect2 = s["rect"]
			if s["faces"] == Comp.FACES_NONE or s["faces"] == Comp.FACES_BOTTOM:
				continue
			var overlap: float = minf(wr.end.x, sr.end.x) - maxf(wr.position.x, sr.position.x)
			if overlap < 20.0:
				continue
			var sink: float = wr.end.y - sr.position.y
			if sink >= 0.0 and sink < 50.0:
				_fail("[%s] 共面接缝:竖直件 %d %s 底缘嵌入仅 %.0fpx(需 ≥50,levels.md §8.4)"
					% [li, Comp.id_of(w), wr, sink])
