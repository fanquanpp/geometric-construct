class_name StatBonus
## 加成数值条(glossary.md §4 v3,v0.36.0):能力修正的统一语言。
##
## 每项能力两个量:**基础值**(几何体自己的 .tres 物理值,永不改写)与
## **加成档位**(整数条,默认 0)。数值条显示的是加成档位,不是基础读数:
##   0        无加成(任何几何体的条都从 0 起);
##   +1..+4   按档位比例放大基础:有效值 = 基础 × (1 + STEP × 档位);
##   -1       锁定:能力被主动禁用(仅对基础值 > 0 的能力有意义);
##   状态-1   基础就不具备该项能力(非锁定)——条上显示"状态-1"占位,
##            加成对其无意义(resolve 对 base ≤ 0 恒返回 0,加成不能
##            无中生有)。数据上与"硬编码禁用"区分:判定只看基础值。
##
## 物理(运动/碰撞公式)永远吃有效物理值;档位只经 resolve() 换算,
## 不直接参与物理。肉鸽硬顶口径:满档 ×2,基础 2.0 时有效 4.0
## (读数 5.0,与既有"正常模式硬顶 5.0"一致)。

## 加成档位作用的能力键(物理消费点全部经 RunState.modified 钩子)。
## climb_units(攀墙)暂不入列:player.gd 爬墙预算直读 MovementTuning,
## 钩子未接,先不卖假档位(接钩子时一并入列,见 REFACTOR §八 M-5)。
const BAR_KEYS := ["base_speed", "bounce", "jump_units", "weight", "carry",
	"buff_sprint_speed"]

const MIN_LEVEL := -1   # 锁定档
const MAX_LEVEL := 4    # 满档(基础 2.0 → 有效 4.0 = 读数 5.0 硬顶)
const STEP := 0.25      # 每档比例:+4 = ×2.0

## 有效值换算:base ≤ 0 → 0(状态-1:能力不存在);档位 ≤ -1 → 0(锁定);
## 否则 base × (1 + STEP × 档位),钳制 [0, 4.0]。
## 注意:重量锁定 = 0 质量会使加速度公式退化,词条内容禁止撰写
## "锁定重量"(内容纪律,roguelike.md §2)。
static func resolve(base: float, level: int) -> float:
	if base <= 0.0:
		return 0.0
	if level <= MIN_LEVEL:
		return 0.0
	return clampf(base * (1.0 + STEP * float(level)), 0.0, 4.0)


## 该能力的"基础不具备"判定(数值条 状态-1 的唯一数据来源)。
static func is_absent(base: float) -> bool:
	return base <= 0.0


## 有效物理值 → 展示读数。跳高例外:读数 = 格数本身(2.0 格 = 基准 2.0,
## glossary.md §4);其余 = 物理 + 1.0。
static func to_reading(key: String, physical: float) -> float:
	return physical if key == "jump_units" \
		else GeometryDef.scale_reading(physical)
