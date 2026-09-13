class_name LevelData
## 关卡数据(v0.38.1):幕 0「机制试炼场」= 机关全览 + 伍试水;
## 幕 1「第一幕 · 各自的路上」= 五位几何体的机关课六场
## (疾速 / 弹阶 / 对面 / 坡道 / 双生阶 + 合演终场),
## 全部走 aseprite 分层管线(L3 背景剪影 + L4 主实体),逐成员可达门禁。
## 数值标准:1 格 = 100 px;可跳台阶高必须比 jump_units 低 0.1。

static var LEVELS: Array[LevelDef] = []

## 幕目录:主页剧目行按此渲染。levels 为空 = 尚未上演的占位幕。
## 幕归属 / 场次号一律由本表推导(act_index_of / scene_no_of)。
static var ACTS: Array[Dictionary] = []


## 关卡所属幕的下标(不在任何幕 = -1)。
static func act_index_of(level: int) -> int:
	for i in ACTS.size():
		if (ACTS[i]["levels"] as Array).has(level):
			return i
	return -1


## 关卡在所属幕内的场次号(1 起;不属于任何幕时退回全局序号)。
static func scene_no_of(level: int) -> int:
	var a := act_index_of(level)
	if a < 0:
		return level + 1
	return (ACTS[a]["levels"] as Array).find(level) + 1


## 某幕的首场关卡下标(空幕 = -1)。
static func first_level_of_act(act: int) -> int:
	if act < 0 or act >= ACTS.size():
		return -1
	var levels: Array = ACTS[act]["levels"]
	return int(levels[0]) if not levels.is_empty() else -1


static func _static_init() -> void:
	ACTS.append({
		"name": "机制试炼场",
		"title": "功能测试",
		"hint": "机关全览 · 双子试水 —— 一切机制的可玩目录",
		"icon": "buttons/play-flat.svg",
		"levels": [0, 1],
	})
	ACTS.append({
		"name": "第一幕",
		"title": "各自的路上",
		"hint": "五位几何体的机关课:疾速 / 弹阶 / 对面 / 坡道 / 双生阶,终场合演",
		"icon": "buttons/play-flat.svg",
		"levels": [2, 3, 4, 5, 6, 7],
	})

	#   SSOT = levels/*.json(v0.39.0 起地图皮与语义层管线整体退役,
	#   JSON 即唯一事实源,直接手编 / 工具直出;本文件不再硬编码任何关卡数据)。
	#   levels/pair_trial.json 为纯 JSON 手写关;v0.38.0 起修复五项
	#   gridcheck 违规并入编幕 0 第 2 场。
	var files := [
		"res://levels/trial_v5.json", "res://levels/pair_trial.json",
		"res://levels/act1/a1_dash.json", "res://levels/act1/a1_spring.json",
		"res://levels/act1/a1_fall.json", "res://levels/act1/a1_roll.json",
		"res://levels/act1/a1_pair.json", "res://levels/act1/a1_finale.json",
	]
	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		assert(f != null, "level json missing: %s" % path)
		LEVELS.append(from_json_text(f.get_as_text()))


## 关卡 JSON 契约版本(levels.md §0 / speed-dev data-contract.md §5):
## 读取侧接受缺失(视作 1)与当前版本;更高版本拒绝装载(未来契约
## 不得静默误读)。
const SCHEMA_VERSION := 1


## JSON 同构装载(关卡编辑器数据契约前置,editor-plan.md §2 / levels.md §0):
## 字段名与 LevelDef 一致;Vector2 = {x,y}、Rect2 = {x,y,w,h};
## 组件 = 语义字典(rect 必填,id/layer/faces/who/tags 可选);spawns 缺项 = Vector2.ZERO。
static func from_json_text(text: String) -> LevelDef:
	var parsed = JSON.parse_string(text)
	assert(parsed is Dictionary, "level json: root must be object")
	var d: Dictionary = parsed
	assert(int(d.get("version", 1)) <= SCHEMA_VERSION,
		"level json: schema v%d 高于本构建支持的 v%d,拒绝装载" %
		[int(d.get("version", 1)), SCHEMA_VERSION])
	var def := LevelDef.new()
	def.name = str(d.get("name", ""))
	def.focus = int(d.get("focus", 0))
	def.intro = str(d.get("intro", ""))
	var sz: Dictionary = d.get("size", {"x": 1600, "y": 900})
	def.size = Vector2(float(sz.get("x", 1600)), float(sz.get("y", 900)))
	def.kill_y = float(d.get("kill_y", 1500.0))
	def.top_kill_y = float(d.get("top_kill_y", -420.0))
	for r in d.get("roster", []):
		def.roster.append(int(r))
	for p in d.get("platforms", []):
		def.platforms.append(_json_comp(p))
	for r in d.get("ramps", []):
		var pts: Array = []
		for pt in r.get("pts", []):
			pts.append(_json_vec2(pt))
		def.ramps.append({"pts": pts, "base": float(r.get("base", 0.0))})
	for lg in d.get("lever_gates", []):
		var levers: Array = []
		for lv in lg.get("levers", []):
			levers.append(_json_rect(lv))
		var door = _json_comp(lg.get("door", {}))
		def.lever_gates.append({"levers": levers, "door": door,
			"invert": bool(lg.get("invert", false))})
	for tb in d.get("timed_bridges", []):
		def.timed_bridges.append({"rect": _json_rect(tb.get("rect",
				{"x": 0, "y": 0, "w": 100, "h": 20})),
			"on_time": float(tb.get("on_time", 2.0)),
			"off_time": float(tb.get("off_time", 2.0)),
			"phase": float(tb.get("phase", 0.0)),
			"sync_beat": bool(tb.get("sync_beat", false))})
	for m in d.get("movers", []):
		var md: Dictionary = _json_comp(m)
		md["offset"] = _json_vec2(m.get("offset", {"x": 0, "y": -100}))
		md["period"] = float(m.get("period", 3.0))
		md["phase"] = float(m.get("phase", 0.0))
		def.movers.append(md)
	for t in d.get("piano_tiles", []):
		var td: Dictionary = _json_comp(t)
		if t.has("note"):
			td["note"] = str(t["note"])
		def.piano_tiles.append(td)
	for pb in d.get("push_boxes", []):
		def.push_boxes.append({"cell": _json_vec2(pb.get("cell",
				{"x": 0, "y": 0}))})
	for sp in d.get("ski_patches", []):
		# ase2level 产物为 {rect: …} 包裹;裸 {x,y,w,h}(编辑器契约)亦兼容
		def.ski_patches.append(_json_rect(sp.get("rect", sp)))
	for pp in d.get("portals", []):
		def.portals.append({"a": _json_vec2(pp.get("a", {"x": 0, "y": 0})),
			"b": _json_vec2(pp.get("b", {"x": 0, "y": 0}))})
	for lp in d.get("launch_pads", []):
		def.launch_pads.append({"pos": _json_vec2(lp.get("pos",
				{"x": 0, "y": 0})),
			"vec": _json_vec2(lp.get("vec", {"x": 0, "y": -1400}))})
	for cp in d.get("checkpoints", []):
		def.checkpoints.append({"pos": _json_vec2(cp.get("pos",
				{"x": 0, "y": 0}))})
	for g in d.get("gates", []):
		def.gates.append([_json_vec2(g[0]), _json_vec2(g[1])])
	for e in d.get("exits", []):
		def.exits.append([int(e[0]), _json_vec2(e[1])])
	var spawns: Array = []
	var raw_spawns: Array = d.get("spawns", [])
	for i in maxi(raw_spawns.size(), def.roster.size()):
		var sp = raw_spawns[i] if i < raw_spawns.size() else null
		if sp == null:
			spawns.append(Vector2.ZERO)
		elif sp is Dictionary and sp.has("a"):
			# 双子(伍)双体出生点 {a: 界(天花), b: 边(地面)} —— JSON 同构
			spawns.append({"a": _json_vec2(sp["a"]), "b": _json_vec2(sp["b"])})
		else:
			spawns.append(_json_vec2(sp))
	def.spawns = spawns
	for h in d.get("hints", []):
		var hd := {"pos": _json_vec2(h.get("pos", {"x": 0, "y": 0})),
			"text": str(h.get("text", ""))}
		if h.has("touch"):
			hd["touch"] = str(h["touch"])
		def.hints.append(hd)
	for z in d.get("zones", []):
		def.zones.append({"rect": _json_rect(z.get("rect",
				{"x": 0, "y": 0, "w": 100, "h": 100})),
			"name": str(z.get("name", "")), "layer": int(z.get("layer", 4))})
	return def


static func _json_vec2(v) -> Vector2:
	if v is Vector2:
		return v
	var d: Dictionary = v
	return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))


static func _json_rect(r) -> Rect2:
	if r is Rect2:
		return r
	var d: Dictionary = r
	return Rect2(float(d.get("x", 0.0)), float(d.get("y", 0.0)),
		float(d.get("w", 0.0)), float(d.get("h", 0.0)))


static func _json_comp(p) -> Dictionary:
	if p is Rect2:
		return p
	var d: Dictionary = p.duplicate()
	d["rect"] = _json_rect(d.get("rect", {"x": 0, "y": 0, "w": 100, "h": 100}))
	return d
