class_name TerrainKit
## 机关物共享静态件(磁界位 / 高亮描边 / 光影遮挡体)。
## 纯静态,无状态;地形石板已改 TileMapLayer 摆位(native-levels.md)。

## 磁力边界碰撞位(伍·界/边专用;共享层为 bit1,本位为特权位)。
const BOUNDARY_BIT := 1 << 30


## 机关正典帧适配(native-levels.md 素材化):把 200×200 图鉴画布上的
## **非透明占位框**精确映射到机关区域 zone——占位框铺满、机关碰撞区
## = 视觉区(所见即所碰)。构成主义平色块允许非均匀拉伸(可变宽
## 板条 / 覆盖带按实例尺寸拉满,不糊不空)。
static func mech_sprite(tex: Texture2D, zone: Rect2) -> Sprite2D:
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var used: Rect2 = Rect2(img.get_used_rect())
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = zone.size / used.size
	spr.position = zone.position - used.position * spr.scale
	return spr


## 专属高亮描边(高亮三档,levels.md §7):几何体专属色 2px 外框 +
## 呼吸脉冲;col.a = 0 时不画(机关物 _draw 共用;平台石板为静态引擎
## 节点,不含运行时高亮)。
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


## 参数曲面/件的包围框(ramp 等逐段几何件;通用件)。
static func ramp_bounds(pts: PackedVector2Array, base_y: float) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo + Vector2(0, base_y - lo.y))
