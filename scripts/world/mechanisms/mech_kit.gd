class_name MechKit
extends RefCounted


## 机关脚手架(架构组件化):mover / timed_bridge / piano_tile / ski_patch /
## speed_gate 五个机制脚本的同构样板收敛处——碰撞形状取建、贴地偏移。
## 行为逐字保持(改前五份原实现已逐行对账):新机制照此取用,
## 不再各复制一遍「CollisionShape2D 取或建」与「贴地 _calc_flush」。
## DrawKit 同层纪律:纯静态工具,无状态,不进场景树。


## 矩形碰撞形状取/建/赋:「CollisionShape2D 取或建 + 缺形补矩形 + 赋尺寸」
## 收敛形(mover/timed_bridge/piano_tile/ski_patch/speed_gate _ready 原样)。
## 返回形状节点(piano 需续写 position;其余调用方可弃)。
static func ensure_rect_shape(body: CollisionObject2D,
		size: Vector2) -> CollisionShape2D:
	var cs := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		body.add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = size
	return cs


## 贴地偏移(piano/ski 两份 _calc_flush 的公共形):节点原点为几何中心时,
## 把形状/外观推贴到脚下地面(优先)或头顶天花板,消除作关摆放的高度毛刺。
## 返回形状相对原点的 y 偏移:脚下命中 = [0, 2*half_h];天花板命中 =
## [-2*half_h, 0];两侧都未命中 = 0(原 _flush_off 缺省值)。
## with_ceiling=false = ski 原形(只贴地、无天花板分支),保持逐字等价。
static func flush_offset(parent: Node, gp: Vector2, half_h: float,
		with_ceiling := true) -> float:
	var gtop := TerrainKit.floor_top_at(parent, gp.x,
		gp.y - half_h + 2.0, 60.0)
	if gtop != TerrainKit.SURFACE_MISS:
		return clampf(gtop - (gp.y - half_h), 0.0, half_h * 2.0)
	if not with_ceiling:
		return 0.0
	var cbot := TerrainKit.ceil_bottom_at(parent, gp.x, gp.y + half_h, 60.0)
	if cbot != -TerrainKit.SURFACE_MISS:
		return clampf(cbot - (gp.y + half_h), -half_h * 2.0, 0.0)
	return 0.0
