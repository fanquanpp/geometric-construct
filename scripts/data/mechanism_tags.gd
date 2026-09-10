class_name MechanismTags
## 机制标签常量表(统合重构终案 Sprint 2):Comp.tags 通路的命名登记处。
## 纪律(structures.md §7):**StringName 一旦写入即稳定契约,改名 = 破坏性
## 变更** —— 只加不改不删;新增标签须与 structures.md §7 表同步。
## 命名:flat snake_case,与 Comp.norm 的 tags 通路同构;不采用
## dot-separated 层级(2026-09-10 甄别结论:项目规模下零收益)。

# —— 在用语义(与既有机关一一对应)——
const TIMED := &"timed"              # 周期切换(限时桥)
const TRIGGER := &"trigger"          # 触发型(开关门)
const SPEED_GATE := &"speed_gate"    # 加速门
const SPEED_RAMP := &"speed_ramp"    # 曲面加速

# —— 预留登记位(§5 规划件落地时启用,先占名防漂移)——
const PUSHABLE := &"pushable"            # 可被推挤
const SLIPPERY := &"slippery"            # 低摩擦(滑雪 / 冰面)
const PORTAL_SOURCE := &"portal_source"  # 传送对入口
const PORTAL_TARGET := &"portal_target"  # 传送对出口
const BOUNCY := &"bouncy"                # 高弹性
const CONVEYOR := &"conveyor"            # 持续水平推力

const KNOWN: Array[StringName] = [TIMED, TRIGGER, SPEED_GATE, SPEED_RAMP,
	PUSHABLE, SLIPPERY, PORTAL_SOURCE, PORTAL_TARGET, BOUNCY, CONVEYOR]


static func is_known(tag: StringName) -> bool:
	return KNOWN.has(tag)
