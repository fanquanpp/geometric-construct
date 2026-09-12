class_name Geometries
## 几何体数据注册表(场景资源强制约束 R2 / REFACTOR §八 M-4):
## 装载 data/characters/*.tres(GeometryDef 资源)。
## 新增几何体:在 data/characters/ 追加一份 .tres(参照 dash.tres),
## 在 _PATHS 尾部登记下标,并提供 assets/svg/characters/<slug>-flat.svg;
## 规范见 docs/UPDATE.md(内容包章节)。下标只能尾部追加(存档按位掩码)。

## 标尺换算:1.0 属性单位 = 100 px(1 格)。结构性单位常量(非调参数值)。
const UNIT_PX := 100.0

## 角色资源清单(下标 = 名册位,只能尾部追加)。
const PATHS: Array[String] = [
	"res://data/characters/dash.tres",
	"res://data/characters/spring.tres",
	"res://data/characters/fall.tres",
	"res://data/characters/roll.tres",
	"res://data/characters/pair.tres",
]

static var ALL: Array[GeometryDef] = []


static func _static_init() -> void:
	for i in PATHS.size():
		var def: GeometryDef = load(PATHS[i])
		def.index = i   # 下标权威在注册表顺序,不信任 .tres 内的存值
		ALL.append(def)


static func get_def(index: int) -> GeometryDef:
	return ALL[clampi(index, 0, ALL.size() - 1)]


## 按重量降序(用于承载/堆叠判定顺序)。
static func by_weight() -> Array:
	var copy := ALL.duplicate()
	copy.sort_custom(func(a: GeometryDef, b: GeometryDef) -> bool:
		return a.weight > b.weight)
	return copy


## 名册展开后的"体"数(双体每位两具,characters.md §5):
## 切换可用性 / 切换提示的判断基准 —— 纯双子阵容 roster 只有 1 位,
## 体数却是 2,按 roster 长度判断会误判为"单人无切换"。
static func roster_body_total(roster: Array) -> int:
	var n := 0
	for i in roster:
		n += get_def(int(i)).bodies()
	return n
