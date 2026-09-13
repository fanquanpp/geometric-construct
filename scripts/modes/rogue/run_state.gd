class_name RunState
extends RefCounted
## 肉鸽一局的运行时状态(docs/design/roguelike.md)。
## 词条 = 属性钩子覆盖层:Player 对属性的全部读取改走
## `RunState.modified(def, key)`——标准闯关(无局)时逐字段直通,零影响。
##
## 能力修正两族(v0.36.0,glossary.md §4 v3):
##   加成档位(op = "bonus",整数)——加成数值条语言:净档位 = 各词条
##     val 之和,钳 [-1, 4];有效值 = StatBonus.resolve(基础, 档位)
##     (+4 = ×2,-1 = 锁定,基础 ≤ 0 的能力不受加成 = 状态-1)。
##   微调(op = "add"/"mul")——物理小步,用于非加成钩子(coyote /
##     friction / swap_cooldown 等)与加成键上的轻量微调(失重镀层),
##     先加后乘,落在加成换算之后;加成键最后统一钳 [0, 4]
##     (读数 5.0 硬顶,roguelike.md §2)。
##
## 红色刻度(序幕 §4 的叙事落地):每次重拼(死亡重生)消耗一段;
## 刻度耗尽,这一局落幕,进入结算。

## 当前进行中的一局(标准闯关 / 菜单时为 null)。
static var active: RunState

## 非加成钩子的默认值(无词条 / 无局时的直通读数)。
const DEFAULTS := {
	"friction": 1.0,          # 摩擦倍率(乘在等效摩擦系数上)
	"coyote": 0.09,           # 土狼时间(秒)
	"swap_cooldown": 0.25,    # 置换冷却(秒)
	"air_jumps": 1.0,         # 空中跳次数(二段跳的第 2 跳)
	"gate_mult": 1.0,         # 加速门效果倍率
	"gravity_fall_mult": 1.24,  # 三段重力:下落加重(跳-落曲线不对称,更利落)
	"gravity_apex_mult": 0.86,  # 三段重力:抛物线顶点轻微悬停(目标感)
	"climb_units": 1.0,       # 爬墙预算倍率(×MovementTuning.climb_units;M-5)
}

const MAX_TICKS := 5         # 一局携带的红色刻度(重拼次数)


var focus := 0               # 主体几何体(入口选择;词条加权 + 叙事身份)
var mods: Array = []         # 已拿词条(RunModifiers.ALL 的元素)
var ticks := MAX_TICKS       # 剩余红色刻度
var chapter := 1             # 当前章节(1–3)
var arrivals := 0            # 到站数(结算货币的一部分)
var elites_done := 0         # 已通过的精英考数
var fragments_done := 0      # 已完成片段数
var deaths := 0              # 死亡(重拼)次数
var rng := RandomNumberGenerator.new()


static func _static_init() -> void:
	rng_randomize()


## 无局环境下也要能安全 randomize(引擎启动早期调用一次)。
static func rng_randomize() -> void:
	if active != null:
		active.rng.randomize()


## 能力基础值(absent 感知):加成键按几何体自身数据取,
## 不具备的能力(不可跳等)基础 = 0 → 数值条显示"状态-1"。
static func base_of(def: GeometryDef, key: String) -> float:
	match key:
		"jump_units":
			return def.jump_units if def.can_jump else 0.0
		"climb_units":
			return 1.0 if def.can_climb else 0.0
		_:
			if DEFAULTS.has(key):
				return float(DEFAULTS[key])
			var v: Variant = def.get(key)
			return float(v) if v != null else 0.0


## 加成键净档位(当前局词条堆叠;无局 = 0)。
static func bonus_level(key: String) -> int:
	var run := active
	if run == null or not StatBonus.BAR_KEYS.has(key):
		return 0
	var lvl := 0
	for m in run.mods:
		for e in m["effects"]:
			if e["key"] == key and e["op"] == "bonus":
				lvl += int(e["val"])
	return clampi(lvl, StatBonus.MIN_LEVEL, StatBonus.MAX_LEVEL)


## 属性钩子读取总入口:def 的字段直通,局内被词条覆盖。
static func modified(def: GeometryDef, key: String) -> float:
	var base := base_of(def, key)
	var run := active
	if run == null or run.mods.is_empty():
		return base
	return run._apply_effects(base, key)


## 布尔标记(glass 之类):有任一词条声明即真。
static func has_flag(def: GeometryDef, key: String) -> bool:
	var run := active
	if run == null:
		return false
	for m in run.mods:
		for e in m["effects"]:
			if e["key"] == key and e["op"] == "flag":
				return true
	return false


## 起跳速度:按(可能被词条加高 / 锁定的)跳高档位反推 h = v₀²/2g。
## 锁定档(−1)有效值 0 → 起跳速度 0(禁跳);不可跳几何体恒 0。
static func jump_v(def: GeometryDef) -> float:
	if not def.can_jump:
		return 0.0
	return GeometryDef.jump_v_for(modified(def, "jump_units"))


## 词条池:通用词条 + 本局主角专属(未锁 + 已解锁;单人制,设计档 §2)。
static func available_pool(focus: int) -> Array:
	var pool: Array = []
	for m in RunModifiers.ALL:
		if m["geo"] == RunModifiers.GEO_ANY or m["geo"] == focus:
			if not m["locked"]:
				pool.append(m)
	for id in SaveManager.I.rogue_unlocked:
		var m: Dictionary = RunModifiers.get_mod(id)
		if not m.is_empty() and (m["geo"] == RunModifiers.GEO_ANY or m["geo"] == focus):
			pool.append(m)
	return pool


# —————————————————————————— 实例侧 ——————————————————————————

func _init(focus_geo := 0) -> void:
	focus = focus_geo
	rng.randomize()


func add_mod(mod: Dictionary) -> void:
	mods.append(mod)


func mod_keys() -> Array:
	var keys: Array = []
	for m in mods:
		for e in m["effects"]:
			if not keys.has(e["key"]):
				keys.append(e["key"])
	return keys


func mod_ids() -> Array:
	var ids: Array = []
	for m in mods:
		ids.append(m["id"])
	return ids


## 死亡(重拼):消耗一段红色刻度;返回是否仍有一局(false = 应落幕)。
func consume_tick() -> bool:
	deaths += 1
	ticks -= 1
	return ticks >= 0


## 结算货币:刻度残段 = 最远章节×3 + 到站数 + 精英×3 + (全通加成 6)。
func shards_earned(cleared: bool) -> int:
	var shards := mini(chapter, 3) * 3 + arrivals + elites_done * 3
	if cleared:
		shards += 6
	return shards


func _apply_effects(base: float, key: String) -> float:
	var value := base
	# 第一层:加成档位换算(仅加成键;锁定/缺席在 StatBonus.resolve 内裁决)
	if StatBonus.BAR_KEYS.has(key):
		value = StatBonus.resolve(base, bonus_level(key))
	# 第二层:微调 add → mul(非加成钩子的主通道;加成键上的轻量微调)
	for m in mods:
		for e in m["effects"]:
			if e["key"] != key:
				continue
			match e["op"]:
				"add":
					value += e["val"]
				"mul":
					value *= e["val"]
	# 纪律:加成键统一钳 [0, 4](读数 5.0 硬顶);非加成钩子不钳(保持既有)
	if StatBonus.BAR_KEYS.has(key):
		value = clampf(value, 0.0, 4.0)
	return value
