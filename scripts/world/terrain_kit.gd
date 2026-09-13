class_name TerrainKit
## 地形绘制工具箱(Phase 2 解环):原 LevelBuilder 的共享静态件——
## 机制(world/mechanisms)与装配器(level_builder)/渲染(world/render)
## 都要用的地形级工具,独立成工具箱后,机制不再反向依赖装配器。
## 纯静态,无状态;不动碰撞语义。

const BOUNDARY_BIT := 1 << 30
## 磁力边界碰撞位(伍·界/边专用;组件签名位只占 3..29,bit30 起为特权位)。


## 专属高亮描边(高亮三档,levels.md §7.10):几何体专属色 2px 外框 +
## 呼吸脉冲;col.a = 0 时不画(机关物 _draw 共用;平台石板为静态引擎
## 节点,不含运行时高亮)。
static func draw_focus(c: CanvasItem, r: Rect2, col: Color) -> void:
	if col.a <= 0.0:
		return
	var pl := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	c.draw_rect(r.grow(3.0), Color(col.r, col.g, col.b, col.a * pl), false, 2.0)


## 石板节点(R0 引擎原生,v0.43.0):一件平台组件 → 一个 Node2D,内含
## Polygon2D 面 / 亮肩 / 顶缘亮线 / 底缘蓝线 / 红刻度 / 接触裙角与
## Line2D 装饰框,零 _draw、零运行时控制器(LayerVisual 渲染控制器
## 随八层渲染退役,静态视觉迁入本函数;三档运行时透明度一并退役——
## 现役关卡 who 集合零使用)。layer_items = 同层全部组件(裙角的静态
## 承接判定要跨件比对)。
static func slab_node(it: Dictionary, layer_items: Array) -> Node2D:
	var node := Node2D.new()
	var r: Rect2 = it["rect"]
	var faces: String = it["faces"]
	var paper: Color = Palette.I.paper
	var red: Color = Palette.I.red
	var is_top := faces == Comp.FACES_TOP
	var is_bottom := faces == Comp.FACES_BOTTOM
	if faces == Comp.FACES_NONE:
		# 纯装饰:8% 亮度的填充 + 14% 线框(与动态构件虚化态同语言)
		_rect_poly(node, r, Color(paper, 0.06))
		var frame := Line2D.new()
		frame.closed = true
		frame.width = 1.5
		frame.default_color = Color(paper, 0.14)
		frame.points = _rect_points(r, 0.0)
		node.add_child(frame)
	else:
		var face_col: Color = Color("2B3140") if is_top \
			else ("232833" if is_bottom else "262B34")
		_rect_poly(node, r, face_col)
		# 上层亮肩面板(石板沿口,高 ≤22px)
		var slab := minf(r.size.y * 0.4, 22.0)
		if slab > 2.0:
			_rect_poly(node, Rect2(r.position, Vector2(r.size.x, slab)),
				Color("3A4254") if is_top else Color("313845"))
		# 顶缘亮线(top 单向板更亮,提示"只有这面是实的")
		_rect_poly(node, Rect2(r.position, Vector2(r.size.x, 2)),
			Color(paper, 0.55 if is_top else 0.30))
		# bottom 面:底缘蓝色细线 —— 逆的重力天花板(art-style.md §6)
		if is_bottom:
			_rect_poly(node, Rect2(Vector2(r.position.x, r.end.y - 3.0),
				Vector2(r.size.x, 3)), Color("4E86D8", 0.65))
		# 左缘红色刻度块(构成主义强调点,每 480px 一处)
		var mark_x := 40.0
		while mark_x < r.size.x - 20.0:
			_rect_poly(node, Rect2(r.position + Vector2(mark_x, 0),
				Vector2(14, 3)), Color(red, 0.55))
			mark_x += 480.0
		# 接触裙角:立块底缘两侧 45° 硬折线(主体同色),把立块"种"进
		# 承接面,消除生硬的竖直接缝(构建期按静态承接判定)
		if _rests_on(it, layer_items):
			var f := 16.0
			var by := r.end.y
			_tri_poly(node, [Vector2(r.position.x, by - f),
				Vector2(r.position.x, by), Vector2(r.position.x - f, by)],
				Color("262B34"))
			_tri_poly(node, [Vector2(r.end.x, by - f),
				Vector2(r.end.x, by), Vector2(r.end.x + f, by)],
				Color("262B34"))
	return node


## it 是否坐落在同层另一个组块上(底缘贴着对方顶缘,水平方向有实质
## 搭接)——构建期定静态承接。
static func _rests_on(it: Dictionary, layer_items: Array) -> bool:
	var r: Rect2 = it["rect"]
	for u0: Dictionary in layer_items:
		if u0 == it:
			continue
		var ur: Rect2 = u0["rect"]
		if ur.position.y <= r.position.y:
			continue
		if absf(r.end.y - ur.position.y) > 6.0:
			continue
		var overlap := minf(r.end.x, ur.end.x) - maxf(r.position.x, ur.position.x)
		if overlap >= 6.0:
			return true
	return false


static func _rect_points(r: Rect2, grow: float) -> PackedVector2Array:
	var g := r.grow(grow)
	return PackedVector2Array([g.position, Vector2(g.end.x, g.position.y),
		g.end, Vector2(g.position.x, g.end.y)])


static func _rect_poly(parent: Node, r: Rect2, col: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
		r.end, Vector2(r.position.x, r.end.y)])
	p.color = col
	parent.add_child(p)


static func _tri_poly(parent: Node, pts: Array, col: Color) -> void:
	var p := Polygon2D.new()
	var arr := PackedVector2Array()
	for v: Vector2 in pts:
		arr.append(v)
	p.polygon = arr
	p.color = col
	parent.add_child(p)


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
