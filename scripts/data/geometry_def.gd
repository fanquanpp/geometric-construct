class_name GeometryDef
extends Resource


enum Shape { SQUARE, RECT }


const MAX_JUMPS := 2


@export var index: int = 0
@export var name: String = ""
@export var full_name: String = ""
@export var slug: String = ""
@export var note: String = "C4"
@export var shape: Shape = Shape.SQUARE
@export var color: Color = Color.WHITE
@export var role: String = ""
@export var quote: String = ""
@export var traits: Array = []


@export var size: Vector2 = Vector2.ZERO
@export var gravity_dir: int = 1
@export var can_jump: bool = true
@export var can_swap: bool = false
@export var can_climb: bool = false
@export var jump_units: float = 0.0


@export var base_speed: float = 1.0
@export var sprint_speed: float = 1.0
@export var buff_sprint_speed: float = 1.0
@export var can_sprint: bool = true
@export var bounce: float = 1.0
@export var weight: float = 1.0
@export var carry: float = 1.0


@export var can_top_boost := false

@export var can_be_pushed := false


var jump_v: float:
	get:
		return jump_v_for(jump_units) if can_jump else 0.0


static func jump_v_for(units: float) -> float:
	return sqrt(2.0 * MovementTuning.I.gravity * units * Geometries.UNIT_PX)


func bottom_units() -> float:
	return size.x / Geometries.UNIT_PX


func height_units() -> float:
	return size.y / Geometries.UNIT_PX


static func scale_reading(physical: float) -> float:
	return -1.0 if physical <= 0.0 else physical + 1.0


func inertia_reading() -> float:
	return scale_reading(weight)


func friction_reading() -> float:
	var t := MovementTuning.I
	return snappedf(t.standard_mu / t.standard_mu * 2.0, 0.1)


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
			"地面减速 a = μ·g(标准读数 2.0;滑雪带例外)"},
		{"label": "形体", "text": "%.2f × %.2f 格(%d × %d px)"
			% [bottom_units(), height_units(), int(size.x), int(size.y)]},
	]


func _band_hint(v: float, low: String, mid: String, high: String) -> String:
	if v <= 0.85:
		return low
	if v <= 1.15:
		return mid
	return high
