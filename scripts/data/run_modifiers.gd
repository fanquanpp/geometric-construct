class_name RunModifiers
## 肉鸽词条数据表(docs/design/roguelike.md §2)。
## 词条 = 属性钩子覆盖层:每条词条声明一组 {key, op, val} 效果,
## 由 RunState 堆叠后经 RunState.modified(def, key) 生效——不改 Player 逻辑。
##
## 单人制口径:词条池 = 通用(geo = -1)+ 本局主角专属(geo = 主角下标)。
## 专属词条只强化该主角的核心机制——疾 = 冲刺 / 跳 / 爬;跃 = 弹性 /
## 二段跳;逆 = 置换;圆 = 滚动 / 加速门。
##
## 数值纪律(设计档 §2;v0.36.0 加成数值条口径,glossary.md §4):
##   加成档位(op = "bonus",整数)——加成数值条语言:净档位钳 [-1, 4],
##     +1 档 = 基础 × 1.25,+4 档 = ×2(满档读数 5.0 硬顶),-1 = 锁定
##     该能力;基础 ≤ 0 的能力不受加成(状态-1,加成词条对其无意义)。
##     禁止撰写"锁定重量"词条:重量 0 会使加速度公式退化(内容纪律)。
##   微调(op = "add"/"mul")——非加成钩子(coyote / friction /
##     swap_cooldown / air_jumps / gate_mult / glass)与加成键上的轻量
##     物理小步(失重镀层等),单条幅度 ±0.5 以内,先加后乘,落在
##     加成换算之后;加成键最终由 RunState 统一钳 [0, 4]。
##
## 局外解锁(设计档 §3):locked = true 的词条需用「刻度残段」兑换入池;
## 解锁只扩充词条池,不解锁数值强度。

enum Rarity { COMMON, RARE, DANGER }

## 稀有度 → 展示色与名(设计档 §5:红=危险,黄=稀有,白=常规)。
const RARITY_COLOR := {
	Rarity.COMMON: Color("EDEAE0"),
	Rarity.RARE: Color("E8B33A"),
	Rarity.DANGER: Color("E0492F"),
}
const RARITY_NAME := {
	Rarity.COMMON: "常规",
	Rarity.RARE: "稀有",
	Rarity.DANGER: "危险",
}

## 兑换价格(刻度残段):常规 10 / 稀有 15 / 危险 12。
const UNLOCK_COST := {
	Rarity.COMMON: 10,
	Rarity.RARE: 15,
	Rarity.DANGER: 12,
}

## 通用词条的归属标记:不属于任何主角,人人可出。
const GEO_ANY := -1

static var ALL: Array[Dictionary] = []


static func _static_init() -> void:
	# ———— 通用词条(geo = GEO_ANY,所有主角共用) ————
	ALL.append(_make("short_beat", "短拍节奏", GEO_ANY, Rarity.COMMON,
		"土狼时间 +0.04s——离地一瞬间仍可起跳。",
		false,
		[{"key": "coyote", "op": "add", "val": 0.04}]))
	ALL.append(_make("weightless", "失重镀层", GEO_ANY, Rarity.COMMON,
		"重量 −0.3——起步更快,惯性变弱。",
		false,
		[{"key": "weight", "op": "add", "val": -0.3}]))
	ALL.append(_make("glass_dash", "玻璃疾走", GEO_ANY, Rarity.DANGER,
		"速度 +2 档,但重落地即碎——高风险高移速。",
		false,
		[{"key": "base_speed", "op": "bonus", "val": 2},
			{"key": "glass", "op": "flag", "val": true}]))
	ALL.append(_make("tailwind", "顺风格", GEO_ANY, Rarity.COMMON,
		"速度 +1 档——温和的常驻提速。",
		true,
		[{"key": "base_speed", "op": "bonus", "val": 1}]))
	ALL.append(_make("steady_base", "沉稳底盘", GEO_ANY, Rarity.COMMON,
		"弹性 −0.2——落地更稳,反弹更克制。",
		true,
		[{"key": "bounce", "op": "add", "val": -0.2}]))
	ALL.append(_make("deaden_coat", "钝化涂层", GEO_ANY, Rarity.DANGER,
		"弹性锁定(−1),跳跃 +1 档——落地绝不反弹,但跳得更高。",
		false,
		[{"key": "bounce", "op": "bonus", "val": -1},
			{"key": "jump_units", "op": "bonus", "val": 1}]))

	# ———— 疾 · 专属(速度 / 跳 / 爬) ————
	ALL.append(_make("high_freq", "高频踏点", 0, Rarity.RARE,
		"跳高 +1 档——每一次起跳都更高一线。",
		false,
		[{"key": "jump_units", "op": "bonus", "val": 1}]))

	# ———— 跃 · 专属(弹性 / 二段跳) ————
	ALL.append(_make("cloud_ladder", "云梯踏", 1, Rarity.RARE,
		"空中跳 +1——二段跳成为三段跳。",
		false,
		[{"key": "air_jumps", "op": "add", "val": 1.0}]))
	ALL.append(_make("glass_spring", "琉璃跳", 1, Rarity.DANGER,
		"跳高 +2 档,但重落地即碎——跃的高风险一跳。",
		true,
		[{"key": "jump_units", "op": "bonus", "val": 2},
			{"key": "glass", "op": "flag", "val": true}]))

	# ———— 逆 · 专属(置换) ————
	ALL.append(_make("pendulum", "逆行钟摆", 2, Rarity.RARE,
		"置换冷却 ×0.6——逆的连翻转。",
		false,
		[{"key": "swap_cooldown", "op": "mul", "val": 0.6}]))
	ALL.append(_make("no_anchor", "无锚", 2, Rarity.DANGER,
		"置换冷却 ×0.5,土狼 −0.04s——翻转更自由,落地窗口更小。",
		true,
		[{"key": "swap_cooldown", "op": "mul", "val": 0.5},
			{"key": "coyote", "op": "add", "val": -0.04}]))

	# ———— 圆 · 专属(滚动 / 加速门) ————
	ALL.append(_make("lubricate", "润滑刻度", 3, Rarity.COMMON,
		"摩擦 ×0.85——滑得更远,也更难停下。",
		false,
		[{"key": "friction", "op": "mul", "val": 0.85}]))
	ALL.append(_make("double_gate", "双倍门", 3, Rarity.RARE,
		"加速门效果翻倍(钳 3.75×)——门越密越强。",
		false,
		[{"key": "gate_mult", "op": "mul", "val": 2.0}]))
	ALL.append(_make("inertia_core", "惯性核心", 3, Rarity.DANGER,
		"摩擦 ×0.7——极端的滑行,极端的失控。",
		true,
		[{"key": "friction", "op": "mul", "val": 0.7}]))


static func get_mod(id: String) -> Dictionary:
	for m in ALL:
		if m["id"] == id:
			return m
	return {}


## 组一个「三选一」:1 常规 + 1 稀有 + 1 危险,全部来自主角池
## (通用 + 该主角专属;设计档 §4.2)。四个主角的池在两个稀有度上
## 都至少各有一条(数据自查),roll 永不落空。
static func roll_three(focus: int, pool: Array, rng: RandomNumberGenerator) -> Array:
	var picked: Array = []
	var used := {}
	for rarity in [Rarity.COMMON, Rarity.RARE, Rarity.DANGER]:
		var bucket: Array = []
		for m in pool:
			if m["rarity"] == rarity and not used.has(m["id"]):
				bucket.append(m)
		if bucket.is_empty():
			continue
		var pick: Dictionary = bucket[rng.randi_range(0, bucket.size() - 1)]
		picked.append(pick)
		used[pick["id"]] = true
	return picked


static func _make(id: String, mod_name: String, geo: int, rarity: int,
		quote: String, locked: bool, effects: Array) -> Dictionary:
	return {
		"id": id,
		"name": mod_name,
		"geo": geo,
		"rarity": rarity,
		"quote": quote,
		"locked": locked,
		"cost": UNLOCK_COST[rarity],
		"effects": effects,
	}
