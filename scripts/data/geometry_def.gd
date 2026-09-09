class_name GeometryDef
extends RefCounted
## 一个可操控几何体的完整定义。
##
## 属性规范(glossary.md §4 标尺 v2):
##   内部存储 = 物理倍率(0.0 – 2.0):1.0 = 标准物理基准,0.0 = 无该能力,
##   2.0 = 物理上限;物理公式(px/s、格、反弹率)与本文件数值绑定。
##   面板/文档展示 = 标尺 v2 读数:读数 = 物理倍率 + 1.0(物理 0.0 → 读数
##   -1.0"关闭");跳高例外:读数 = 格数(标准跳 2.0 格 = 基准 2.0)。
##   常规域读数 -1.0 – 3.0,正常模式硬顶 5.0,肉鸽不设限。
##
## 标尺换算:1.0 属性单位 = 100 px(1 格)。
##   跳高(格) = jump_units(独立属性,二段跳几何体统一 2.0 格/跳);
##   关卡可跳台阶高度必须比 jump_units 低 0.1。
##   弹性全员固定:0.5;跃为 2.0 固定(只决定落地反弹,不再决定跳高)。

enum Shape { SQUARE, RECT, BALL }

## 主动跳跃次数上限(二段跳:地面跳 1 次 + 空中跳 1 次)。
const MAX_JUMPS := 2

## 背负超载(头顶来者总重 > 负重力)时的跳跃高度倍率:减半,而不是禁止跳跃。
const OVERLOAD_JUMP_RATIO := 0.5

## 地面摩擦系数 μ(库伦摩擦 a = μ·g;标准 ≈ 1.27)与圆球滚动阻力系数。
## 物理权威在此(数据层),Player 引用——摩擦读数(characters.md §1)同源。
const MU_FRICTION := 1.2667
const BALL_MU_ROLL := 0.43

## 爬墙(can_climb):单次离地期间可向上攀爬的总高度(格),落地重置。
const CLIMB_UNITS := 2.0

# ———— 身份 ————
var index: int = 0
var name: String = ""          # 单字代号,用于大字排版
var full_name: String = ""     # 完整名(形态 + 色),档案页标题
var slug: String = ""          # 对应 assets/svg/characters 素材名
var shape: Shape = Shape.SQUARE
var color: Color = Color.WHITE
var role: String = ""          # 定位标签:速度型 / 弹性型 / 置换型 / 滚动型
var quote: String = ""         # 切换时的台词
var traits: Array = []         # 特性要点(Array[String]),档案页展示

# ———— 形体 ————
var size: Vector2 = Vector2.ZERO
var gravity_dir: int = 1       # 初始重力:1 = 常规(向下),-1 = 反重力(向上)
var can_jump: bool = true
var jump_v: float = 0.0
var can_swap: bool = false     # 置换:跳跃键改为在上下平台间翻转
var can_climb: bool = false    # 爬墙:贴墙按住方向缓降滑壁,按住跳跃键向上爬
var jump_units: float = 0.0    # 跳高(格/跳):二段跳统一 2.0 格;与弹性解耦


## 跳跃起跳速度:由跳高格数换算(跳高 = jump_units × 100 px)。
static func jump_v_for(units: float) -> float:
	return sqrt(2.0 * Geometries.GRAVITY * units * Geometries.UNIT_PX)


# ———— 属性(0.0 – 2.0) ————
var base_speed: float = 1.0    # 基础速度倍率(1.0 = 标准)
var sprint_speed: float = 1.0  # 冲刺上限倍率;不可冲刺的几何体 = base_speed
var buff_sprint_speed: float = 1.0  # 加速门后的速度上限倍率(永久)
var can_sprint: bool = true
var bounce: float = 1.0        # 弹性:决定跳跃高度与落地反弹;全员 0.5,跃 2.0 固定
var weight: float = 1.0        # 重量:影响加速度、惯性、承载判定
var carry: float = 1.0         # 负重力:头顶可承载的总重量

# ———— v0.16 新特性旗标(characters.md §1/§5;默认关,名册逐个开) ————
## 顶弹翻倍(贰·跃):同伴站在本几何体顶部起跳时,该次跳跃高度 ×2。
var can_top_boost := false
## 可推动(肆·圆):其他几何体水平推挤时,本几何体受力滚动。
var can_be_pushed := false
## 磁界穿透(叁·逆):可任意穿过伍(界/边)的磁力边界。
var can_pass_boundary := false


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
	var mu := BALL_MU_ROLL if shape == Shape.BALL else MU_FRICTION
	return snappedf(mu / MU_FRICTION * 2.0, 0.1)


## 档案页属性行:{label, value, hint} 或 {label, text}。value 为标尺 v2 读数
## (-1.0 关闭 – 3.0 常规上限;glossary.md §4)。
## 派生量一律按真实物理式换算:
##   速度 → v = (读数−1.0) × RUN_SPEED(3.0 格/秒 = 300 px/s);
##   跳高 → h = v₀² / 2g(起跳速度按能量守恒反推);
##   弹性 → 反弹率 e = bounce × 0.5(牛顿碰撞定律 v′ = e·v);
##   摩擦 → 减速度 a = μ·g(库伦摩擦,重量项视作材质差异)。
func stat_rows() -> Array:
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

	var climb_hint := "贴墙按住方向缓降 · 按住跳跃键爬升(单次 %.1f 格)" % CLIMB_UNITS \
		if can_climb else "不可攀墙"

	var bounce_hint := "反弹率约 %.0f%%(v′ = e·v)" % roundf(bounce * 50.0)

	var weight_hint := _band_hint(weight, "极轻 · 起步快、滑行远", "标准",
		"沉重 · 起步慢、惯性大")
	weight_hint += " · 摩擦 a = μ·g"

	return [
		{"label": "速度", "value": scale_reading(base_speed), "hint": speed_hint},
		{"label": "弹性", "value": scale_reading(bounce), "hint": bounce_hint},
		{"label": "跳跃", "value": jump_units if can_jump else -1.0,
			"hint": jump_hint},
		{"label": "攀墙", "value": CLIMB_UNITS if can_climb else -1.0,
			"hint": climb_hint},
		{"label": "重量", "value": scale_reading(weight), "hint": weight_hint},
		{"label": "负载", "value": scale_reading(carry), "hint":
			"头顶超载:跳跃高度减半" if carry <= 0.05
			else _band_hint(carry, "仅轻量", "标准", "强力承载")},
		{"label": "惯性", "value": inertia_reading(), "hint":
			"动量保持程度(与重量同源耦合,解耦预留)"},
		{"label": "摩擦系数", "value": friction_reading(), "hint":
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
