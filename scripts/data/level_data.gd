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

	# 机制试炼场 v4(分层语义 v3 全面验收,2026-09-10 重设计):
	# 主路径全连续无硬阻断;每段头顶净空 ≥1.0 格(最高几何体 跃=0.8);
	# 电梯/摆渡行程全域无实体穿插;界的天路(天花底面)从 Z4 连续铺到归门壁龛。
	#   Z0 出生(浮台:疾二段/跃顶弹) | Z1 八层定值(L3/L5/L6/L7/L8 各一)
	#   | Z2 faces 四型 + 逆双平台置换走廊(天花 faces=bottom)
	#   | Z3 机关物(琴键/摆渡/坑内滚出坡/电梯/甲板加速门/曲面/气闸门)
	#   | Z4 双子磁界室 + 限时桥(掉坑测召回) | Z5 归门(伍niche:双体同区到站)
	LEVELS.append(_make("机制试炼场", 0,
		"分层试炼场 v4:八层定值 × who 集合 × faces 四型 × 全机关物。\n界的天路贯穿双子室至归门壁龛;磁界唯逆可穿。",
		Vector2(13350, 2200), [0, 1, 2, 3, 4],
		[
			# —— Z0 出生区(地面 y1800;浮台离地 2.6 格,下方通行无阻)——
			Rect2(0, 1800, 1400, 400),
			{"rect": Rect2(1000, 1440, 300, 100), "id": 405},
			# —— Z1 八层定值展区(主路径经坡道翻越,无阻断)——
			Rect2(1400, 1800, 3000, 400),
			{"rect": Rect2(1700, 1100, 160, 700), "layer": 3, "id": 301},   # L3 背景建筑:可穿行
			{"rect": Rect2(2200, 1450, 360, 420), "layer": 8, "id": 801},   # L8 前景遮挡:躲入剪影
			{"rect": Rect2(2700, 1500, 120, 350), "layer": 5, "who": [0], "id": 501},   # L5 疾域:唯疾被挡(底缘嵌入地面0.5格防共面穿模)
			{"rect": Rect2(2500, 1560, 300, 60), "layer": 7, "who": [1, 3], "id": 701}, # L7 跃圆共用板:who 集合示范
			# L6 圆域:33° 坡(≤37° 纪律)登顶;他人视角虚化,穿台坠落回主路
			{"rect": Rect2(3780, 1400, 300, 100), "layer": 6, "who": [3], "id": 601},   # L6 圆域实台:与圆丘顶(3780,1400)齐平,唯圆可登
			# —— Z2 faces 四型 + 逆双平台置换走廊 ——
			Rect2(4400, 1800, 2200, 400),
			{"rect": Rect2(4400, 1300, 2200, 120), "faces": "bottom", "id": 411},       # 天花:仅底面实心 = 逆的天路
			{"rect": Rect2(4900, 1500, 80, 350), "layer": 5, "who": [2], "id": 503},    # 逆域墙:逼出置换(底缘嵌地防穿模)
			{"rect": Rect2(5300, 1620, 260, 80), "faces": "none", "id": 802},           # 虚化装饰:穿行
			{"rect": Rect2(5750, 1500, 80, 350), "layer": 5, "who": [2], "id": 504},    # 第二道:双置换练习
			{"rect": Rect2(6100, 1640, 300, 60), "faces": "top", "id": 410},            # 单向板:顶面可站/下方可穿
			# —— Z3 机关物区(坑:摆渡跨越 / 圆走坑内滚出坡;电梯上方净空全开)——
			Rect2(6600, 1800, 1100, 400),
			Rect2(7700, 2100, 1200, 100),        # 坑底安全网
			Rect2(8900, 1800, 1300, 400),
			{"rect": Rect2(9210, 1060, 500, 80), "id": 406},   # 甲板(电梯送上来)
			# —— Z4 双子磁界室 + 限时桥(界生天花;掉坑测召回)——
			Rect2(10200, 1800, 800, 400),
			Rect2(11000, 2100, 500, 100),        # 桥下安全坑
			Rect2(11500, 1800, 700, 400),
			{"rect": Rect2(10200, 1200, 2000, 120), "id": 412}, # Z4 天花:界的天路
			# 爬墙塔立在天花顶面(甲板曲面飞越抵达):疾贴塔缓降+按跳攀爬 8 格
			Rect2(11400, 400, 100, 800),
			Rect2(11500, 400, 250, 80),          # 塔顶台
			# —— Z5 归门(天花延续到壁龛,界一路走天花底面)——
			Rect2(12200, 1800, 1150, 400),
			{"rect": Rect2(12200, 1200, 1100, 120), "id": 413},
			# 伍归门壁龛:界沿天花踏步逐级下跳(100/80),边走台阶(100/100),
			# 两半同入门区(±50);其他几何体的门在其左侧,无需入龛
			{"rect": Rect2(13060, 1320, 110, 100), "id": 414},
			{"rect": Rect2(13170, 1320, 130, 180), "id": 415},
			Rect2(13060, 1700, 110, 100),
			Rect2(13170, 1600, 140, 200),
		],
		[   # ramps:圆丘双向坡(≤37°,两侧皆可登顶)+ 坑内贯通坡(直通右岸,
			# 消除带下困死区;圆滚速 1.5 无需飞跃)+ 甲板曲面(切线飞越上天花顶)
			{"pts": [Vector2(3200, 1800), Vector2(3780, 1400), Vector2(4360, 1800)], "base": 1800.0},
			{"pts": [Vector2(7700, 2100), Vector2(8890, 1795)], "base": 2100.0},
			{"pts": [Vector2(9710, 1060), Vector2(10140, 940)], "base": 1060.0},
		],
		[[Vector2(9550, 980), Vector2(140, 160)]],   # gates:甲板加速门
		[
			[0, Vector2(12400, 1754)],
			[1, Vector2(12550, 1754)],
			[2, Vector2(12700, 1754)],
			[3, Vector2(12850, 1754)],
			[4, Vector2(13235, 1550)],   # 伍双体门:niche 内界/边同区到站
		],
		[
			Vector2(300, 1745),
			Vector2(400, 1745),
			Vector2(500, 1745),
			Vector2(600, 1745),
			{"a": Vector2(10400, 1335), "b": Vector2(10490, 1785)},   # 界挂天花 / 边行地面
		],
		[   # movers:摆渡过坑(行程终点与右岸齐平不进实体)+ 电梯(上方净空全开)
			{"rect": Rect2(7700, 1700, 260, 60), "offset": Vector2(940, 0), "period": 4.0, "phase": 0.0},
			{"rect": Rect2(8950, 1740, 260, 60), "offset": Vector2(0, -700), "period": 4.5, "phase": 0.0},
		],
		[   # hints
			{"pos": Vector2(500, 1600), "text": "分层试炼场 v4:八层定值 × who 集合 × faces 四型"},
			{"pos": Vector2(1100, 1300), "text": "浮台:疾二段跳 / 跃踩同伴头顶 ×2"},
			{"pos": Vector2(1800, 1000), "text": "L3 背景建筑(301):纯视觉,可直接穿过"},
			{"pos": Vector2(2380, 1350), "text": "L8 前景遮挡(801):躲入其后呈剪影"},
			{"pos": Vector2(2780, 1420), "text": "L5 疾域(501):唯疾被挡,他人视角虚化"},
			{"pos": Vector2(2580, 1700), "text": "L7 跃圆共用板(701):who 集合 {跃,圆}"},
			{"pos": Vector2(3700, 1250), "text": "L6 圆域(601):圆丘双向可越,唯圆登顶有实台"},
			{"pos": Vector2(4950, 1400), "text": "L5 逆域(503):置换上天花跨越,天路尽头前回落"},
			{"pos": Vector2(6750, 1500), "text": "琴键砖:踩踏发声,圆滚过即琶音"},
			{"pos": Vector2(7800, 1550), "text": "摆渡过坑;掉下去走坡道滚出(圆也行)"},
			{"pos": Vector2(9050, 1300), "text": "电梯上方净空全开;甲板:加速门 + 曲面板"},
			{"pos": Vector2(9900, 1300), "text": "气闸门:踩住对侧开关接力(切换合作)"},
			{"pos": Vector2(10800, 1100), "text": "双子磁界:线随两半伸缩,唯逆可穿"},
			{"pos": Vector2(11250, 1600), "text": "限时桥周期通断;掉坑按召回(R)回出生点"},
			{"pos": Vector2(11050, 950), "text": "疾:贴塔缓降,按跳攀爬 8 格"},
		],
		[   # zones:命名分区坐标系(levels.md §8.2,整格吸附,列带全高)
			{"rect": Rect2(0, 0, 1400, 2200), "name": "Z0 出生"},
			{"rect": Rect2(1400, 0, 3000, 2200), "name": "Z1 八层展区"},
			{"rect": Rect2(4400, 0, 2200, 2200), "name": "Z2 置换走廊"},
			{"rect": Rect2(6600, 0, 3600, 2200), "name": "Z3 机关物"},
			{"rect": Rect2(10200, 0, 2000, 2200), "name": "Z4 双子磁界"},
			{"rect": Rect2(12200, 0, 1150, 2200), "name": "Z5 归门"},
		],
	))
	LEVELS[0].piano_tiles = [
		{"rect": Rect2(6650, 1800, 100, 400), "note": "C4", "id": 407},
		{"rect": Rect2(6750, 1800, 100, 400), "note": "E4"},
		{"rect": Rect2(6850, 1800, 100, 400), "note": "G4"},
		{"rect": Rect2(6950, 1800, 100, 400), "note": "C5"},
	]
	LEVELS[0].lever_gates = [
		{"levers": [Rect2(9700, 1720, 150, 80), Rect2(10050, 1720, 150, 80)],
			"door": {"rect": Rect2(9850, 1400, 120, 450), "id": 402}},
	]
	LEVELS[0].timed_bridges = [
		{"rect": Rect2(11000, 1740, 500, 60), "on_time": 2.0, "off_time": 2.0, "phase": 0.0, "id": 403},
	]
	LEVELS[0].kill_y = 2400.0


## JSON 同构装载(关卡编辑器数据契约前置,editor-plan.md §2 / levels.md §0):
## 字段名与 LevelDef 一致;Vector2 = {x,y}、Rect2 = {x,y,w,h};
## 组件 = 语义字典(rect 必填,id/layer/faces/who/tags 可选);spawns 缺项 = Vector2.ZERO。
static func from_json_text(text: String) -> LevelDef:
	var parsed = JSON.parse_string(text)
	assert(parsed is Dictionary, "level json: root must be object")
	var d: Dictionary = parsed
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
	for g in d.get("gates", []):
		def.gates.append([_json_vec2(g[0]), _json_vec2(g[1])])
	for e in d.get("exits", []):
		def.exits.append([int(e[0]), _json_vec2(e[1])])
	var spawns: Array = []
	for i in maxi(d.get("spawns", []).size(), def.roster.size()):
		var sp = d.get("spawns", [])[i] if i < d.get("spawns", []).size() else null
		spawns.append(_json_vec2(sp) if sp != null else Vector2.ZERO)
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
