class_name Geometries
## 全部几何体数据表。新增几何体:追加一条 _make 并提供 assets/svg/characters/<slug>-flat.svg;
## 规范见 docs/UPDATE.md(内容包章节)。

const GRAVITY := 1500.0
## 标准 1.0 速度对应的像素速度。
const RUN_SPEED := 300.0
## 标尺换算:1.0 属性单位 = 100 px(1 格)。跳高(格) = 弹性值。
const UNIT_PX := 100.0

static var ALL: Array[GeometryDef] = []


static func _static_init() -> void:
	# 0 · 疾 — 红色正方形 · 速度型
	ALL.append(_make(0, "疾", "红色正方形", "dash", GeometryDef.Shape.SQUARE,
		"E0492F", Vector2(56, 56), 1, 1.0, 1.5, 1.5,
		0.5, 2.0, 1.0, 1.0, true, true, false, true, "速度型",
		"疾。他相信只要跑得够快,孤独就追不上他。",
		["冲刺:按住 Shift,速度攀升至 1.5×",
			"二段跳:每次跳高 2.0 格,两连跳可达 4.0 格",
			"速度越快跳得越远:跳远距离与速度成正比",
			"爬墙:贴住侧壁按住朝墙方向缓降滑壁,再按住跳跃键向上爬——单次至多 2.0 格"]))

	# 1 · 跃 — 黄色竖长方形 · 弹性型
	ALL.append(_make(1, "跃", "黄色竖长方形", "spring", GeometryDef.Shape.RECT,
		"E8B33A", Vector2(48, 100), 1, 1.0, 1.0, 1.0,
		2.0, 2.0, 1.5, 1.5, false, true, false, false, "弹性型",
		"跃。把坠落折叠成上升,她从不害怕高度。",
		["弹性 2.0 固定:落地反弹全场最强,按住跳跃主动发力弹得更高",
			"二段跳:每次跳高 2.0 格,两连跳可达 4.0 格",
			"高 1.0 格:同伴可踩上头顶,是一级活的台阶"]))

	# 2 · 逆 — 蓝色镜像正方形 · 置换型
	ALL.append(_make(2, "逆", "蓝色镜像正方形", "fall", GeometryDef.Shape.SQUARE,
		"4E86D8", Vector2(36, 40), 1, 0.5, 1.2, 2.0,
		0.5, 0.0, 0.2, 0.5, true, false, true, false, "置换型",
		"逆。对你们是天与地,对他只是两个可以落脚的面。",
		["置换:按跳跃键在天与地之间翻转,空中惯性保留",
			"弹性固定 0.5;自身不可跳跃,置换即是他唯一的翅膀",
			"基础速度仅 0.5,穿过加速门后上限提升至 2.0×"]))

	# 3 · 圆 — 橙色圆球形 · 滚动型
	ALL.append(_make(3, "圆", "橙色圆球形", "roll", GeometryDef.Shape.BALL,
		"E07E2E", Vector2(52, 52), 1, 1.5, 1.5, 2.5,
		0.5, 0.0, 0.5, 0.0, false, false, false, false, "滚动型",
		"圆。他不会跳,所以他从不回头。",
		["固定极速 1.5×:起步即全速,惯性滚动,不可跳跃",
			"穿过加速门立即加速到 2.5×,超越默认上限",
			"弹性固定 0.5:落地反弹克制,动能都留给向前的惯性"]))


static func get_def(index: int) -> GeometryDef:
	return ALL[clampi(index, 0, ALL.size() - 1)]


## 按重量降序(用于承载/堆叠判定顺序)。
static func by_weight() -> Array:
	var copy := ALL.duplicate()
	copy.sort_custom(func(a: GeometryDef, b: GeometryDef) -> bool:
		return a.weight > b.weight)
	return copy


static func _make(index: int, geo_name: String, full_name: String, slug: String,
		shape: GeometryDef.Shape, color_hex: String, size: Vector2, gravity_dir: int,
		base_speed: float, sprint_speed: float, buff_sprint_speed: float,
		bounce: float, jump_units: float, weight: float, carry: float,
		can_sprint: bool, can_jump: bool, can_swap: bool, can_climb: bool,
		role: String, quote: String, traits: Array) -> GeometryDef:
	var gd := GeometryDef.new()
	gd.index = index
	gd.name = geo_name
	gd.full_name = full_name
	gd.slug = slug
	gd.shape = shape
	gd.color = Color(color_hex)
	gd.size = size
	gd.gravity_dir = gravity_dir
	gd.base_speed = base_speed
	gd.sprint_speed = sprint_speed
	gd.buff_sprint_speed = buff_sprint_speed
	gd.bounce = bounce
	gd.jump_units = jump_units
	gd.weight = weight
	gd.carry = carry
	gd.can_sprint = can_sprint
	gd.can_jump = can_jump
	gd.can_swap = can_swap
	gd.can_climb = can_climb
	gd.jump_v = GeometryDef.jump_v_for(jump_units) if can_jump else 0.0
	gd.role = role
	gd.quote = quote
	gd.traits = traits
	return gd
