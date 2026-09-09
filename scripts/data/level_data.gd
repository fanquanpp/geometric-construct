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

	# 机制试炼场 v2(双平台重规划,2026-09-10):
	#   Z0 出生 | Z1 分层语义 | Z2 双平台置换走廊(逆:地⇄天两面行进)
	#   | Z3 机关物区 | Z4 双子双平台室(伍:界上边下,磁界封门)+ 特性塔
	#   | Z5 五门归位
	LEVELS.append(_make("机制试炼场", 0,
		"双平台测试:逆在地与天两面之间置换行进。\n双子界/边一上一下分踞两层,磁界即门——只有逆能穿。",
		Vector2(15200, 2200), [0, 1, 2, 3, 4],
		[
			# —— Z0 出生区(地面 y1800)——
			Rect2(0, 1800, 1500, 400),
			Rect2(1000, 1610, 80, 190),          # 1.9 格墙:二段跳
			# —— Z1 分层语义区 ——
			Rect2(1500, 1800, 2900, 400),
			{"rect": Rect2(2400, 1100, 160, 700), "lane": "back"},   # 背景巨构:可穿行
			{"rect": Rect2(3000, 1350, 320, 280), "lane": "front"},  # 前景遮挡:躲入呈剪影
			{"rect": Rect2(3600, 1500, 120, 300), "who": [0]},       # 疾专属墙:唯疾不可穿
			{"rect": Rect2(2000, 1000, 300, 120), "who": [3]},       # 圆的高台:他人视角自动 far
			# —— Z2 双平台置换走廊(逆):地面被墙断,置换上天花板行进 ——
			Rect2(4400, 1800, 2400, 400),
			# —— 全覆盖天花板(连续整板):逆的天路贯通全关,界生于其下 ——
			Rect2(300, 1300, 14900, 120),
			{"rect": Rect2(5100, 1550, 80, 250), "who": [2]},        # 逆的置换墙(唯逆被挡:逼出置换)
			{"rect": Rect2(5700, 1550, 80, 250), "who": [2]},
			{"rect": Rect2(4700, 1450, 300, 120), "faces": "top"},   # 单向顶面:疾/跃的上层路
			# —— Z3 机关物区 ——
			Rect2(6800, 1800, 2000, 400),
			Rect2(8800, 2100, 1000, 100),        # 坑底安全网
			Rect2(9800, 1800, 2000, 400),
			Rect2(10250, 940, 700, 80),          # 上层甲板(电梯 + 加速门 + 曲面)
			# —— Z4 双子双平台室 + 特性塔 ——
			Rect2(11800, 1800, 2400, 400),
			Rect2(12000, 1000, 100, 800),        # 爬墙塔(8 格,疾)
			Rect2(12100, 1000, 420, 80),         # 塔顶台
			Rect2(12900, 1340, 320, 460),        # 4.6 格高台(跃顶翻倍才可越)
			{"rect": Rect2(13300, 1300, 500, 120), "faces": "none"}, # 虚化演示段(无碰撞)
			# —— Z5 归门台 ——
			Rect2(14200, 1800, 1000, 400),
		],
		[   # ramps:坑内缓坡(滚出)+ 上层曲面(切线飞越)
			{"pts": [Vector2(8800, 2100), Vector2(9500, 1800)], "base": 2100},
			{"pts": [Vector2(11350, 940), Vector2(11600, 830), Vector2(11850, 720)], "base": 940},
		],
		[[Vector2(11100, 860), Vector2(120, 160)]],   # gates:上层加速门
		[
			[0, Vector2(14450, 1754)],
			[1, Vector2(14600, 1754)],
			[2, Vector2(14750, 1754)],
			[3, Vector2(14900, 1754)],
			[4, Vector2(15050, 1754)],
		],
		[
			Vector2(300, 1745),
			Vector2(400, 1745),
			Vector2(500, 1745),
			Vector2(600, 1745),
			{"a": Vector2(700, 1435), "b": Vector2(790, 1785)},
		],
		[   # movers:水平摆渡过坑 + 垂直电梯上甲板
			{"rect": Rect2(8900, 1740, 260, 60), "offset": Vector2(700, 0), "period": 4.0, "phase": 0.0},
			{"rect": Rect2(9900, 1740, 260, 60), "offset": Vector2(0, -800), "period": 4.5, "phase": 0.0},
		],
		[   # hints
			{"pos": Vector2(430, 1330), "text": "试炼场 v3:全覆盖天花板 + 双子天地出生,逐区自检"},
			{"pos": Vector2(2450, 950), "text": "背景层(back):纯视觉,可直接穿过"},
			{"pos": Vector2(3050, 1150), "text": "前景层(front):躲入其后呈剪影"},
			{"pos": Vector2(3650, 1300), "text": "who 专属:此墙只对疾是实体"},
			{"pos": Vector2(4950, 1150), "text": "逆的置换走廊:地面被墙断,置换上天花板行进"},
			{"pos": Vector2(5550, 1150), "text": "天花琴键 E5:逆踩出高音对答"},
			{"pos": Vector2(7750, 1500), "text": "机关物区:琴键 / 摆渡 / 电梯 / 加速门 / 曲面"},
			{"pos": Vector2(12050, 800), "text": "爬墙:贴墙缓降,按跳攀爬(疾)"},
			{"pos": Vector2(12950, 1050), "text": "站上跃的头顶起跳:顶弹翻倍 4 格"},
			{"pos": Vector2(13400, 1050), "text": "双子双平台:界生于天花板,边行于地面"},
			{"pos": Vector2(13900, 1150), "text": "双子对齐则磁界封门,只有逆能穿;错开即放行"},
		],
	))
	LEVELS[0].piano_tiles = [
		{"rect": Rect2(6800, 1800, 100, 400), "note": "C4"},
		{"rect": Rect2(6900, 1800, 100, 400), "note": "E4"},
		{"rect": Rect2(7000, 1800, 100, 400), "note": "G4"},
		{"rect": Rect2(7100, 1800, 100, 400), "note": "C5"},
	]
	LEVELS[0].lever_gates = [
		{"levers": [Rect2(11500, 1720, 150, 80), Rect2(11890, 1720, 150, 80)],
			"door": {"rect": Rect2(11700, 1400, 120, 500)}},
	]
	LEVELS[0].timed_bridges = [
		{"rect": Rect2(11300, 1750, 500, 60), "on_time": 2.0, "off_time": 2.0, "phase": 0.0},
	]
	LEVELS[0].kill_y = 2400.0


## JSON 同构装载(关卡编辑器数据契约前置,editor-plan.md §2 / levels.md §0):
## 字段名与 LevelDef 一致;Vector2 = {x,y}、Rect2 = {x,y,w,h};
## 组件 = 语义字典(rect 必填,lane/faces/who/tags 可选);spawns 缺项 = Vector2.ZERO。
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
		spawns: Array, movers: Array = [], hints: Array = []) -> LevelDef:
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
	return def
