class_name GeometryDef
extends Resource
## 一个可操控几何体的完整定义(场景资源强制约束 R2 / REFACTOR §八 M-4):
## 每位几何体一个 .tres(data/characters/<slug>.tres),数值在编辑器
## Inspector 直调;resource 只作静态数据,运行时禁止写入(共享引用,
## 一处写处处变)。
##
## 属性规范(glossary.md §4,v0.36.0):
##   内部存储 = 物理倍率(0.0 – 2.0):1.0 = 标准物理基准,0.0 = 无该能力,
##   2.0 = 物理上限;物理公式(px/s、格、反弹率)与本文件数值绑定。
##   **基础值只属于几何体自己**;基础 ≤ 0 的能力 = "状态-1"
##   (非禁用,是天生没有)。
##   基础读数(存档/文档兼容记法)= 物理倍率 + 1.0(物理 0.0 → -1.0);
##   跳高例外:读数 = 格数(标准跳 2.0 格 = 基准 2.0)。常规域读数
##   -1.0 – 3.0。
##
## 标尺换算:1.0 属性单位 = 100 px(1 格)。
##   跳高(格) = jump_units(独立属性,二段跳几何体统一 2.0 格/跳);
##   关卡可跳台阶高度必须比 jump_units 低 0.1。
##   弹性全员固定:0.5;跃为 2.0 固定(只决定落地反弹,不再决定跳高)。

enum Shape { SQUARE, RECT, BALL, TRIANGLE }

## 主动跳跃次数上限(二段跳:地面跳 1 次 + 空中跳 1 次)——结构性规则常量。
const MAX_JUMPS := 2

# ———— 身份 ————
@export var index: int = 0
@export var name: String = ""      # 单字代号,用于大字排版(Resource 无 name 属性,可安全占用)
@export var full_name: String = ""  # 完整名(形态 + 色),档案页标题
@export var slug: String = ""       # 对应 assets/svg/characters 素材名
@export var note: String = "C4"     # 主题音符(C 大调音名):跳跃/落地音效变调基准
@export var shape: Shape = Shape.SQUARE
@export var color: Color = Color.WHITE
@export var role: String = ""       # 定位标签:速度型 / 弹性型 / 置换型 / 滚动型
@export var quote: String = ""      # 切换时的台词
@export var traits: Array = []      # 特性要点(Array[String]),档案页展示

# ———— 形体 ————
@export var size: Vector2 = Vector2.ZERO
@export var gravity_dir: int = 1    # 初始重力:1 = 常规(向下),-1 = 反重力(向上)
@export var can_jump: bool = true
@export var can_swap: bool = false  # 置换:跳跃键改为在上下平台间翻转
@export var can_climb: bool = false # 爬墙:贴墙按住方向缓降滑壁,按住跳跃键向上爬
@export var jump_units: float = 0.0 # 跳高(格/跳):二段跳统一 2.0 格;与弹性解耦

# ———— 属性(0.0 – 2.0) ————
@export var base_speed: float = 1.0     # 基础速度倍率(1.0 = 标准)
@export var sprint_speed: float = 1.0   # 冲刺上限倍率;不可冲刺的几何体 = base_speed
@export var buff_sprint_speed: float = 1.0 # 加速门后的速度上限倍率(永久)
@export var can_sprint: bool = true
@export var bounce: float = 1.0         # 弹性:决定落地反弹;全员 0.5,跃 2.0 固定
@export var weight: float = 1.0         # 重量:影响加速度、惯性、承载判定
@export var carry: float = 1.0          # 负重力:头顶可承载的总重量

# ———— v0.16 新特性旗标(characters.md §1/§5;默认关,名册逐个开) ————
## 顶弹翻倍(贰·跃):同伴站在本几何体顶部起跳时,该次跳跃高度 ×2。
@export var can_top_boost := false
## 可推动(肆·圆):其他几何体水平推挤时,本几何体受力滚动。
@export var can_be_pushed := false
## 磁界穿透(叁·逆):可任意穿过伍(界/边)的磁力边界。
@export var can_pass_boundary := false
## 双子(伍·界/边):true 时该名册位出生两个个体(characters.md §5)。
@export var paired := false
## 双体第二半的代号与台词("边");空 = 非双体或第一半。
@export var name_half := ""
@export var quote_half := ""


## 起跳速度(派生量,不落盘):由跳高格数换算(跳高 = jump_units × 100 px)。
var jump_v: float:
	get:
		return jump_v_for(jump_units) if can_jump else 0.0


## 跳跃起跳速度换算:v₀ = √(2·g·h)。g 取全局手感资源。
static func jump_v_for(units: float) -> float:
	return sqrt(2.0 * MovementTuning.I.gravity * units * Geometries.UNIT_PX)


## 该几何体一位出生几具身体(双体系统契约,characters.md §5):
## 切换可用性 / 到站满员 / 名册体数统计的唯一权威;未来特殊几何体
## (多体/共生)只需覆写派生规则,调用点不得再手写 2 或 paired 判断。
func bodies() -> int:
	return 2 if paired else 1


## 底部长度 / 高度,单位:格。
func bottom_units() -> float:
	return size.x / Geometries.UNIT_PX


func height_units() -> float:
	return size.y / Geometries.UNIT_PX


## 标尺 v2 读数换算:物理倍率 → 展示读数(物理 0.0 → -1.0 关闭)。
static func scale_reading(physical: float) -> float:
	return -1.0 if physical <= 0.0 else physical + 1.0


## 惯性读数(v0.16 显式化):与重量同源耦合,解耦轴预留(characters.md §1)。
func inertia_reading() -> float:
	return scale_reading(weight)


## 摩擦读数 = μ / μ标准 × 2.0:标准材质 2.0,圆滚动 μ0.43 → 0.7(物理不变)。
func friction_reading() -> float:
	var t := MovementTuning.I
	var mu := t.ball_mu_roll if shape == Shape.BALL else t.standard_mu
	return snappedf(mu / t.standard_mu * 2.0, 0.1)


## 档案页属性行(纯基础数据):
##   {label, bar: true,  key, absent, base_read, hint} —— 数值条行
##   (absent = 基础不具备 → 面板显示"状态-1");
##   {label, bar: false, absent, value, hint} —— 派生/材质读数行;
##   {label, text} —— 形体行。
## 基础读数 = 标尺记法(物理 + 1.0,物理 0 → -1.0;glossary.md §4)。
## 派生量一律按真实物理式换算:
##   速度 → v = (读数−1.0) × RUN_SPEED(3.0 格/秒 = 300 px/s);
##   跳高 → h = v₀² / 2g(起跳速度按能量守恒反推);
##   弹性 → 反弹率 e = bounce × 0.5(牛顿碰撞定律 v′ = e·v);
##   摩擦 → 减速度 a = μ·g(库伦摩擦,重量项视作材质差异)。
## modifier(可选,依赖注入):属性解算函数 `func(def, key) -> float`
## (data 层叶节点不反向依赖 UI;由消费方注入,缺省 = 直通原始值)。
func stat_rows(modifier: Callable = Callable()) -> Array:
	var hook := func(key: String, base: float) -> float:
		if modifier.is_valid():
			return float(modifier.call(self, key)) * base
		return base
	var speed_hint := "固定极速"
	if can_sprint and sprint_speed > base_speed:
		speed_hint = "冲刺 %.1f" % scale_reading(sprint_speed)
		if buff_sprint_speed > sprint_speed:
			speed_hint += " / 加速门 %.1f" % scale_reading(buff_sprint_speed)
	elif not can_sprint:
		speed_hint = "不可加速"
		if buff_sprint_speed > base_speed:
			speed_hint += " · 加速门 %.1f" % scale_reading(buff_sprint_speed)
	speed_hint += " · ≈%.0f 格/秒" % roundf(base_speed * 3.0)

	var jump_hint := ""
	if can_swap:
		jump_hint = "置换:按跳跃键翻转上下平台,水平惯性完整保留"
	elif can_jump:
		jump_hint = "二段跳 · 每次跳高 %.1f 格(h = v₀²/2g)" % jump_units
	else:
		jump_hint = "不可跳跃"

	var climb_hint := "贴墙按住方向缓降 · 按住跳跃键爬升(单次 %.1f 格)" % MovementTuning.I.climb_units \
		if can_climb else "不可攀墙"
	# 攀墙值走词条钩子(注入式,见本函数头注);不可爬 = -1(状态-1 行)
	var climb_eff: float = hook.call("climb_units", MovementTuning.I.climb_units) \
		if can_climb else -1.0

	var bounce_hint := "反弹率约 %.0f%%(v′ = e·v)" % roundf(bounce * 50.0)

	var weight_hint := _band_hint(weight, "极轻 · 起步快、滑行远", "标准",
		"沉重 · 起步慢、惯性大")
	weight_hint += " · 摩擦 a = μ·g"

	return [
		{"label": "速度", "bar": true, "key": "base_speed",
			"absent": base_speed <= 0.0, "base_read": scale_reading(base_speed),
			"hint": speed_hint},
		{"label": "弹性", "bar": true, "key": "bounce",
			"absent": bounce <= 0.0, "base_read": scale_reading(bounce),
			"hint": bounce_hint},
		{"label": "跳跃", "bar": true, "key": "jump_units",
			"absent": not can_jump or jump_units <= 0.0,
			"base_read": jump_units if can_jump else -1.0,
			"hint": jump_hint},
		{"label": "攀墙", "bar": false, "absent": not can_climb,
			"value": climb_eff,
			"hint": climb_hint},
		{"label": "重量", "bar": true, "key": "weight",
			"absent": weight <= 0.0, "base_read": scale_reading(weight),
			"hint": weight_hint},
		{"label": "负载", "bar": true, "key": "carry",
			"absent": carry <= 0.0, "base_read": scale_reading(carry),
			"hint": "头顶超载:跳跃高度减半" if carry <= 0.05
				else _band_hint(carry, "仅轻量", "标准", "强力承载")},
		{"label": "惯性", "bar": false, "absent": false,
			"value": inertia_reading(), "hint":
			"动量保持程度(与重量同源耦合,解耦预留)"},
		{"label": "摩擦系数", "bar": false, "absent": false,
			"value": hook.call("friction", friction_reading()), "hint":
			"地面减速 a = μ·g(标准读数 2.0;滚动材质更低)"},
		{"label": "形体", "text": "%.2f × %.2f 格(%d × %d px)"
			% [bottom_units(), height_units(), int(size.x), int(size.y)]},
	]


func _band_hint(v: float, low: String, mid: String, high: String) -> String:
	if v <= 0.85:
		return low
	if v <= 1.15:
		return mid
	return high
