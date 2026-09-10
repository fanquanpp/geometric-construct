class_name MechanismRegistry
## 机制注册表(统合重构终案 Sprint 2):kind → 脚本的唯一映射 +
## 机制生命周期契约的落档处(契约全文见 structures.md §7)。
## 新机制三步:新建 scripts/world/mechanisms/ 下脚本 → 在此登记一行
## → structures.md 补条目与标签。
##
## 生命周期契约(鸭子类型,机制脚本可选实现;联机就绪不变式):
##   setup(comp: Dictionary)        装配期注入归一化组件字典
##   tick(delta: float)             帧逻辑(联机时主机权威)
##   net_apply(...)                 客机复现主机事件(范本:LeverGate.net_apply_open)
##   teardown()                     关卡卸载前清理
## 纪律:机制状态变更必须可被 net_apply 复现;做不到同步的状态不许进机制。

const KINDS: Array[StringName] = [&"ramp", &"mover", &"mover_slab",
	&"mover_track", &"timed_bridge", &"lever_gate", &"piano_tile",
	&"mag_boundary"]


static func script_for(kind: StringName) -> GDScript:
	match kind:
		&"ramp":
			return Ramp
		&"mover":
			return Mover
		&"mover_slab":
			return MoverSlab
		&"mover_track":
			return MoverTrack
		&"timed_bridge":
			return TimedBridge
		&"lever_gate":
			return LeverGate
		&"piano_tile":
			return PianoTile
		&"mag_boundary":
			return MagBoundary
		_:
			push_warning("MechanismRegistry: 未登记的机制 kind '%s'" % kind)
			return null


static func create(kind: StringName) -> Node:
	var s := script_for(kind)
	return null if s == null else s.new()
