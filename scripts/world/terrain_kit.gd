class_name TerrainKit
## 地形绘制工具箱(Phase 2 解环):原 LevelBuilder 的共享静态件——
## 机制(world/mechanisms)与装配器(level_builder)/渲染(world/render)
## 都要用的地形级工具,独立成工具箱后,机制不再反向依赖装配器。
## 纯静态,无状态;不动碰撞语义。

const BOUNDARY_BIT := 1 << 30
## 磁力边界碰撞位(伍·界/边专用;组件签名位只占 3..29,bit30 起为特权位)。


## 专属高亮描边(高亮三档,levels.md §7.10):几何体专属色 2px 外框 +
## 呼吸脉冲;col.a = 0 时不画(LaneRenderer 与机关物 _draw 共用)。
static func draw_focus(c: CanvasItem, r: Rect2, col: Color) -> void:
	if col.a <= 0.0:
		return
	var pl := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	c.draw_rect(r.grow(3.0), Color(col.r, col.g, col.b, col.a * pl), false, 2.0)


## 矩形遮挡体(引擎光影 v0.19,art-style.md §8):世界坐标矩形 →
## 顺时针绕行的闭合遮挡多边形;cull_mode 挡掉自身受影(平台顶面
## 不被自己的遮挡体压出暗带)。
static func rect_occluder(r: Rect2) -> LightOccluder2D:
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y),
		r.end, Vector2(r.position.x, r.end.y)])
	poly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
	occ.occluder = poly
	return occ


## 曲面跳跃板的包围框(FocusDriver 波次排序用)。
static func ramp_bounds(pts: PackedVector2Array, base_y: float) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo + Vector2(0, base_y - lo.y))
