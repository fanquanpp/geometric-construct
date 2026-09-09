class_name LevelData
## 关卡数据:序章六场(四场单演 + 机关合拍 + 合演终场)+ 第一幕六场巨构。
## 数值标准(docs/DESIGN.md):1 格 = 100 px;
##   跳高(格) = 弹性值;可跳跃障碍高度必须比对应角色的弹性低 0.1。

static var LEVELS: Array[LevelDef] = []

## 幕目录:主页剧目行按此渲染。levels 为空 = 尚未上演的占位幕
## (入口保留、点击有反馈,但不可开演)。幕归属 / 场次号一律由本表推导
## (act_index_of / scene_no_of),不按关卡下标硬编码。
static var ACTS: Array[Dictionary] = []


## 关卡所属幕的下标(不在任何幕 = -1,如图层实验室)。
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
		"name": "序章剧目",
		"title": "六场连演",
		"hint": "疾 · 跃 · 逆 · 圆 四场单演 → 机关合拍 → 四人合演,六场连演",
		"icon": "buttons/play-flat.svg",
		"levels": [0, 1, 2, 3, 4, 5],
	})
	ACTS.append({
		"name": "第一幕",
		"title": "引力排练",
		"hint": "六场巨构连演 — 承载 · 置换 · 竞速 · 动能 · 幕终齐奏",
		"icon": "buttons/play-flat.svg",
		"levels": [6, 7, 8, 9, 10, 11],
		"total": 6,
	})
	ACTS.append({
		"name": "第二幕",
		"title": "碎裂舞台",
		"hint": "未开演 — 碎裂与重拼的舞台,敬请期待",
		"icon": "icons/lock-flat.svg",
		"levels": [],
	})
	ACTS.append({
		"name": "第三幕",
		"title": "终局构成",
		"hint": "未开演 — 终局构成,敬请期待",
		"icon": "icons/lock-flat.svg",
		"levels": [],
	})

## v0.17「机制完善期」:全部演出关卡已清空,仅保留一个功能测试关——
## 分层语义 / 全机关物 / 全几何体特性逐区自检;机制全部达到完美与正常后,
## 才开始游戏关卡与剧情设计(用户决策 2026-09-10)。

	ACTS = []
	ACTS.append({
		"name": "机制试炼场",
		"title": "功能测试",
		"hint": "分层语义 · 全机关物 · 全几何体特性,逐区自检",
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

	# 机制试炼场(唯一测试关):Z0 出生 / Z1 分层语义 / Z2 faces / Z3 机关物 / Z4 特性 / Z5 归门
	LEVELS.append(_make("机制试炼场", 0,
		"分层语义:back 可穿行、front 躬身剪影、who 专属、mid 才是实体。
机关物与几何体特性逐区自检——全部正常,才建真正的关卡。",
		Vector2(15200, 2200), [0, 1, 2, 3, 4],
		[
			# —— Z0 出生区 ——
			Rect2(0, 1800, 1500, 400),
			Rect2(1000, 1610, 80, 190),          # 1.9 格墙:二段跳
			# —— Z1 分层语义区 ——
			Rect2(1500, 1800, 2900, 400),
			{"rect": Rect2(2400, 1100, 160, 700), "lane": "back"},   # 背景巨构:可穿行
			{"rect": Rect2(3000, 1350, 320, 280), "lane": "front"},  # 前景遮挡:躲入呈剪影
			{"rect": Rect2(3600, 1500, 120, 300), "who": [0]},       # 疾专属墙:唯疾不可穿
			{"rect": Rect2(2000, 1000, 300, 120), "who": [3]},       # 圆的高台:他人视角自动 far 沉降
			# —— Z2 faces 区 ——
			Rect2(4400, 1800, 2200, 400),
			{"rect": Rect2(4700, 1450, 300, 120), "faces": "top"},   # 单向顶面:下方跳穿
			{"rect": Rect2(5300, 1280, 500, 120), "faces": "bottom"},# 天花板:逆的路
			{"rect": Rect2(5950, 1600, 240, 200), "faces": "none"},  # 虚化板:纯视觉
			# —— Z3 机关物区 ——
			Rect2(6600, 1800, 1000, 400),
			Rect2(7600, 2100, 1000, 100),        # 坑底安全网
			Rect2(8600, 1800, 2500, 400),
			Rect2(11100, 1800, 700, 400),
			Rect2(11100, 2000, 500, 200),        # 限时桥下凹口
			Rect2(9050, 940, 700, 80),           # 上层甲板(电梯 + 加速门 + 曲面)
			# —— Z4 特性区 ——
			Rect2(11800, 1800, 3400, 400),
			Rect2(12000, 1000, 100, 800),        # 爬墙塔(8 格,疾)
			Rect2(12100, 1000, 420, 80),         # 塔顶台
			Rect2(12900, 1340, 320, 460),        # 4.6 格高台(跃顶翻倍才可越)
			{"rect": Rect2(13700, 1500, 100, 300), "who": [4]},      # 双子墩(界/边站定张磁界)
			{"rect": Rect2(14100, 1500, 100, 300), "who": [4]},
			# —— Z5 归门台 ——
			Rect2(14200, 1800, 1000, 400),
		],
		[   # ramps:坑内缓坡(滚出)+ 上层曲面(切线飞越)
			{"pts": [Vector2(7600, 2100), Vector2(8300, 1800)], "base": 2100},
			{"pts": [Vector2(10150, 940), Vector2(10400, 830), Vector2(10650, 720)], "base": 940},
		],
		[[Vector2(9900, 860), Vector2(120, 160)]],   # gates:上层加速门
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
			Vector2(700, 1745),
		],
		[   # movers:水平摆渡过坑 + 垂直电梯上甲板
			{"rect": Rect2(7700, 1740, 260, 60), "offset": Vector2(700, 0), "period": 4.0, "phase": 0.0},
			{"rect": Rect2(8700, 1740, 260, 60), "offset": Vector2(0, -800), "period": 4.5, "phase": 0.0},
		],
		[   # hints
			{"pos": Vector2(430, 1330), "text": "机制试炼场:逐区自检,全部正常才建关卡"},
			{"pos": Vector2(2450, 950), "text": "背景层(back):纯视觉,可直接穿过"},
			{"pos": Vector2(3050, 1150), "text": "前景层(front):躲入其后呈剪影"},
			{"pos": Vector2(3650, 1300), "text": "who 专属:此墙只对疾是实体"},
			{"pos": Vector2(4750, 1200), "text": "faces top:下方可跳穿,顶面可站"},
			{"pos": Vector2(5350, 1050), "text": "faces bottom:逆的天花板路"},
			{"pos": Vector2(7750, 1500), "text": "电梯摆渡与琴键:机关物全检查"},
			{"pos": Vector2(12050, 800), "text": "爬墙:贴墙缓降,按跳攀爬(疾)"},
			{"pos": Vector2(12950, 1050), "text": "站上跃的头顶起跳:顶弹翻倍 4 格"},
			{"pos": Vector2(13750, 1150), "text": "双子分墩站定张磁界:只有逆能穿"},
		],
	))
	LEVELS[0].piano_tiles = [
		{"rect": Rect2(6700, 1800, 100, 400), "note": "C4"},
		{"rect": Rect2(6800, 1800, 100, 400), "note": "E4"},
		{"rect": Rect2(6900, 1800, 100, 400), "note": "G4"},
		{"rect": Rect2(7000, 1800, 100, 400), "note": "C5"},
	]
	LEVELS[0].lever_gates = [
		{"levers": [Rect2(11500, 1720, 150, 80), Rect2(11890, 1720, 150, 80)],
			"door": {"rect": Rect2(11700, 1400, 120, 500)}},
	]
	LEVELS[0].timed_bridges = [
		{"rect": Rect2(11100, 1750, 500, 60), "on_time": 2.0, "off_time": 2.0, "phase": 0.0},
	]
	LEVELS[0].kill_y = 2400.0


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
