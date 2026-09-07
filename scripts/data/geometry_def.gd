class_name GeometryDef
extends RefCounted
## 一个可操控几何体的完整定义。
##
## 属性规范(docs/DESIGN.md):所有属性取值 0.0 – 2.0;
##   1.0 = 标准基准,0.0 = 不具备该特性,2.0 = 特性上限。
##   未特殊化的属性一律记标准值,面板中标注"标准"。
##
## 标尺换算:1.0 属性单位 = 100 px(1 格)。
##   跳高(格) = jump_units(独立属性,二段跳角色统一 2.0 格/跳);
##   关卡可跳台阶高度必须比 jump_units 低 0.1。
##   弹性全员固定:0.5;跃为 2.0 固定(只决定落地反弹,不再决定跳高)。

enum Shape { SQUARE, RECT, BALL }

## 主动跳跃次数上限(二段跳:地面跳 1 次 + 空中跳 1 次)。
const MAX_JUMPS := 2

## 背负超载(头顶来者总重 > 负重力)时的跳跃高度倍率:减半,而不是禁止跳跃。
const OVERLOAD_JUMP_RATIO := 0.5

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


## 底部长度 / 高度,单位:格。
func bottom_units() -> float:
	return size.x / Geometries.UNIT_PX


func height_units() -> float:
	return size.y / Geometries.UNIT_PX


## 档案页属性行:{label, value, hint} 或 {label, text}。value 为 0.0 – 2.0 标尺读数。
func stat_rows() -> Array:
	var speed_hint := "固定极速"
	if can_sprint and sprint_speed > base_speed:
		speed_hint = "冲刺 %.1f" % sprint_speed
		if buff_sprint_speed > sprint_speed:
			speed_hint += " / 加速门 %.1f" % buff_sprint_speed
	elif not can_sprint:
		speed_hint = "不可加速"
		if buff_sprint_speed > base_speed:
			speed_hint += " · 加速门 %.1f" % buff_sprint_speed

	var jump_hint := ""
	if can_swap:
		jump_hint = "置换:按跳跃键翻转上下平台"
	elif can_jump:
		jump_hint = "二段跳 · 每次跳高 %.1f 格" % jump_units
	else:
		jump_hint = "不可跳跃"

	var climb_hint := "贴墙按住方向缓降 · 按住跳跃键爬升(单次 %.1f 格)" % CLIMB_UNITS \
		if can_climb else "不可攀墙"

	var bounce_hint := "固定 · 落地反弹约 %.0f%%" % roundf(bounce * 50.0)

	return [
		{"label": "速度", "value": base_speed, "hint": speed_hint},
		{"label": "弹性", "value": bounce, "hint": bounce_hint},
		{"label": "跳跃", "value": jump_units if can_jump else 0.0,
			"hint": jump_hint},
		{"label": "攀墙", "value": CLIMB_UNITS if can_climb else 0.0,
			"hint": climb_hint},
		{"label": "重量", "value": weight, "hint": _band_hint(weight, "极轻", "标准", "沉重")},
		{"label": "负重力", "value": carry, "hint":
			"头顶超载:跳跃高度减半" if carry <= 0.05
			else _band_hint(carry, "仅轻量", "标准", "强力承载")},
		{"label": "形体", "text": "%.2f × %.2f 格(%d × %d px)"
			% [bottom_units(), height_units(), int(size.x), int(size.y)]},
	]


func _band_hint(v: float, low: String, mid: String, high: String) -> String:
	if v <= 0.85:
		return low
	if v <= 1.15:
		return mid
	return high
