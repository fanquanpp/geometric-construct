class_name LevelData
## 关卡数据(v0.17 机制完善期):全部演出关卡已清空,
## 仅保留「机制试炼场」单一功能测试关——
## 分层语义 / 双平台置换(逆)/ 双子双平台(伍)/ 全机关物逐区自检;
## 机制全部达到完美与正常后,才开始游戏关卡与剧情设计(用户决策 2026-09-10)。
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
		"hint": "双平台置换 · 双子双平台 · 分层语义 · 全机关物,逐区自检",
		"icon": "buttons/play-flat.svg",
		"levels": [0],
	})
	ACTS.append({
		"name": "关卡设计",
		"title": "未启动",
		"hint": "机制全部完善与正常后,才开始关卡与剧情设计",
		"icon": "icons/lock-flat.svg",
		"levels": [],
	})

	#   v5 管道测试道(aseprite 地图,art 字段接管地形外观):
	#   地板与天花板并行的直通道,机关沿地板一线排开 —— 纯测试不考验玩家。
	#   Z0 出生 | Z1 滑雪带 | Z2 推箱室 | Z3 弹射+传送对 | Z4 机关长廊
	#   (琴键/躲避动板/限时桥坑/气闸门) | Z5 归门(圆丘坡 + 伍壁龛)
	LEVELS.append(_make("机制试炼场", 0,
		"试炼场 v5 · 管道测试道:地板与天花板并行直通道,机关沿地板一线排开。\n纯测试道——机关作用 / 涂装分层 / 几何体数值,不考验玩家。",
		Vector2(6400, 1080), [0, 1, 2, 3, 4],
		[
			# —— 管道主体:地板两段(夹限时桥坑) + 天花板全线 ——
			Rect2(0, 880, 4300, 200),
			Rect2(4700, 880, 1700, 200),
			Rect2(0, 0, 6400, 200),
			# —— 竖隔墙:弹射越墙 / 传送穿墙(墙顶低于天花 100px 给界的
			#   天路让行;底缘全部嵌地 ≥50,共面接缝纪律 levels.md §8.4)——
			Rect2(2600, 280, 100, 650),
			Rect2(3200, 300, 100, 630),
			# —— 伍壁龛:边两级台阶上龛,界自天花经踏步落入(嵌地 ≥50;
			#   龛顶踏步 6100,480 底缘 540 ∈ 门心-15±50,gridcheck §5 双落点)——
			Rect2(6100, 480, 300, 60),
			Rect2(6150, 620, 250, 330),
			Rect2(6320, 760, 80, 190),
		],
		[   # ramps:归门前圆丘双向坡(≤37° 纪律)
			{"pts": [Vector2(4900, 880), Vector2(5300, 640), Vector2(5700, 880)],
				"base": 880.0},
		],
		[[Vector2(2200, 830), Vector2(140, 160)]],   # gates:弹射助跑加速门
		[
			[0, Vector2(5780, 826)],
			[1, Vector2(5870, 826)],
			[2, Vector2(5960, 826)],
			[3, Vector2(6050, 826)],
			[4, Vector2(6220, 574)],   # 伍双体门:壁龛台上,界边同区到站
		],
		[
			Vector2(200, 855),
			Vector2(320, 855),
			Vector2(440, 855),
			Vector2(560, 855),
			{"a": Vector2(300, 215), "b": Vector2(390, 855)},   # 界嵌天花 10px / 边行地面(v4 模式,防磁界扫掠微推)
		],
		[   # movers:长廊躲避动板(纵向往复,择时通过)
			{"rect": Rect2(4150, 640, 260, 60), "offset": Vector2(0, -420),
				"period": 3.0},
		],
		[   # hints
			{"pos": Vector2(300, 700), "text": "试炼场 v5 · 管道测试道:纯测试,不考验玩家"},
			{"pos": Vector2(950, 700), "text": "滑雪带:摩擦骤降,收油慢打"},
			{"pos": Vector2(1850, 700), "text": "推箱:侧面顶入,整格滑动,遇墙即停"},
			{"pos": Vector2(2300, 640), "text": "加速门 + 弹射板:踩上即飞越隔墙"},
			{"pos": Vector2(3050, 560), "text": "传送对:进 A 出 B,速度保留"},
			{"pos": Vector2(3800, 700), "text": "琴键砖:踩踏发声,圆滚过即琶音"},
			{"pos": Vector2(4280, 560), "text": "躲避动板:择时通过;限时桥跨坑"},
			{"pos": Vector2(5000, 460), "text": "气闸门:两侧开关任一踩住即开"},
			{"pos": Vector2(5300, 500), "text": "圆丘坡:双向登顶,圆滚速最快"},
			{"pos": Vector2(6180, 480), "text": "归门:伍两半同区到站(界天花/边台阶)"},
		],
		[   # zones:命名分区(levels.md §8.2)
			{"rect": Rect2(0, 0, 500, 1080), "name": "Z0 出生"},
			{"rect": Rect2(500, 0, 1000, 1080), "name": "Z1 滑雪带"},
			{"rect": Rect2(1500, 0, 900, 1080), "name": "Z2 推箱室"},
			{"rect": Rect2(2400, 0, 1200, 1080), "name": "Z3 弹射传送"},
			{"rect": Rect2(3600, 0, 1600, 1080), "name": "Z4 机关长廊"},
			{"rect": Rect2(5200, 0, 1200, 1080), "name": "Z5 归门"},
		],
	))
	LEVELS[0].art = "res://assets/levels/trial_v5.png"
	LEVELS[0].piano_tiles = [
		{"rect": Rect2(3650, 880, 100, 200), "note": "C4"},
		{"rect": Rect2(3750, 880, 100, 200), "note": "E4"},
		{"rect": Rect2(3850, 880, 100, 200), "note": "G4"},
		{"rect": Rect2(3950, 880, 100, 200), "note": "C5"},
	]
	LEVELS[0].push_boxes = [
		{"cell": Vector2(1650, 830)},
		{"cell": Vector2(1850, 830)},
		{"cell": Vector2(2050, 830)},
	]
	LEVELS[0].ski_patches = [Rect2(600, 830, 760, 50)]
	LEVELS[0].portals = [{"a": Vector2(3050, 760), "b": Vector2(3450, 760)}]
	LEVELS[0].launch_pads = [
		{"pos": Vector2(2450, 850), "vec": Vector2(700, -2000)},
	]
	LEVELS[0].lever_gates = [
		{"levers": [Rect2(4850, 800, 150, 80), Rect2(5150, 800, 150, 80)],
			"door": {"rect": Rect2(5000, 580, 100, 400)}},
	]
	LEVELS[0].timed_bridges = [
		{"rect": Rect2(4300, 880, 400, 60), "on_time": 2.0, "off_time": 2.0,
			"phase": 0.0},
	]
	LEVELS[0].kill_y = 1400.0


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
	if d.has("art"):
		def.art = str(d["art"])
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
		def.ski_patches.append(_json_rect(sp))
	for pp in d.get("portals", []):
		def.portals.append({"a": _json_vec2(pp.get("a", {"x": 0, "y": 0})),
			"b": _json_vec2(pp.get("b", {"x": 0, "y": 0}))})
	for lp in d.get("launch_pads", []):
		def.launch_pads.append({"pos": _json_vec2(lp.get("pos",
				{"x": 0, "y": 0})),
			"vec": _json_vec2(lp.get("vec", {"x": 0, "y": -1400}))})
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


static func _make(name: String, focus: int, intro: String, size: Vector2,
		roster: Array, platforms: Array, ramps: Array, gates: Array, exits: Array,
		spawns: Array, movers: Array = [], hints: Array = [],
		zones: Array = []) -> LevelDef:
	var def := LevelDef.new()
	def.name = name
	def.focus = focus
	def.intro = intro
	def.size = size
	def.roster = roster
	def.platforms = platforms
	def.ramps = ramps
	def.gates = gates
	def.exits = exits
	def.spawns = spawns
	def.movers = movers
	def.hints = hints
	def.zones = zones
	return def
