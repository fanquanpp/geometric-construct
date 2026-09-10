class_name Ramp
extends StaticBody2D

## 曲面跳跃板:折线曲面(碰撞 = 逐段实心凸四边形),几何体沿面滑行,末端沿切线飞出。

var pts := PackedVector2Array()
var base_y := 1000.0
var layer_value := 1    # 语义签名碰撞位(景观层 = 0:纯视觉)
var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7.10)

func _ready() -> void:
	collision_layer = layer_value
	collision_mask = 0
	add_to_group("ramp")   # 玩家据此识别"站在曲面上"(加速 + 减重 buff)
	# 逐段实心四边形:顶边为曲面,向下加厚;避免薄线段的双面碰撞把球弹开
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var cs := CollisionShape2D.new()
		var shape := ConvexPolygonShape2D.new()
		shape.points = PackedVector2Array([
			a, b, b + Vector2(0, THICKNESS), a + Vector2(0, THICKNESS),
		])
		cs.shape = shape
		add_child(cs)
	# 遮挡体(引擎光影 v0.19):与绘制主体同形的实体多边形
	if pts.size() >= 2:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
		var body := PackedVector2Array(pts)
		body.append(Vector2(pts[pts.size() - 1].x, base_y))
		body.append(Vector2(pts[0].x, base_y))
		poly.polygon = body
		occ.occluder = poly
		add_child(occ)

func _draw() -> void:
	if pts.size() < 2:
		return
	# 主体填充(曲面到基线)
	var poly := PackedVector2Array(pts)
	poly.append(Vector2(pts[pts.size() - 1].x, base_y))
	poly.append(Vector2(pts[0].x, base_y))
	draw_colored_polygon(poly, Color("262B34"))
	# 表层亮面板(沿曲面下移的带状)
	var band := PackedVector2Array(pts)
	for i in range(pts.size() - 1, -1, -1):
		band.append(pts[i] + Vector2(0, 14))
	draw_colored_polygon(band, Color("313845"))
	# 顶缘亮线
	draw_polyline(pts, Color(Ui.PAPER, 0.35), 2.0)
	# 红色刻度块(每段中点)
	for i in pts.size() - 1:
		var mid := (pts[i] + pts[i + 1]) * 0.5
		draw_rect(Rect2(mid - Vector2(7, 8), Vector2(14, 3)), Color(Ui.RED, 0.55))
	# 专属高亮描边(呼吸脉冲,§7.10)
	LevelBuilder.draw_focus(self, LevelBuilder._ramp_bounds(pts, base_y), hl_color)

const THICKNESS := 48.0
