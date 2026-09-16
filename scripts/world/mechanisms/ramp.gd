@tool
class_name Ramp
extends StaticBody2D

## 曲面跳跃板:折线曲面(碰撞 = 逐段实心凸四边形),几何体沿面滑行,末端沿切线飞出。
## @tool:正典帧贴包围盒下衬在编辑器内随 pts 实时预览;顶缘亮线与红色
## 刻度(_draw)在编辑器内同样生效,摆曲线即所见。

@export var pts := PackedVector2Array()
@export var base_y := 1000.0
var sig_value := 1    # 碰撞层值(共享层 = 1;专属在编辑器 Inspector 改)
var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7)

const T_FRAME := preload("res://assets/archive/mech_ramp.png")

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	collision_layer = sig_value
	collision_mask = 0
	add_to_group("ramp")   # 玩家据此识别"站在曲面上"(加速 + 减重 buff)
	# 正典帧贴包围盒下衬(曲面形由碰撞与亮线表达;帧为斜坡插画质感)
	if pts.size() >= 2:
		var spr := Sprite2D.new()
		spr.show_behind_parent = true
		TerrainKit.mech_layout(spr, T_FRAME, _frame_zone())
		add_child(spr)
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

## 正典帧目标区:折线包围盒向下延伸到 base_y。
func _frame_zone() -> Rect2:
	var flo: Vector2 = pts[0]
	var fhi: Vector2 = pts[0]
	for p in pts:
		flo = flo.min(p)
		fhi = fhi.max(p)
	flo.y = minf(flo.y, base_y)
	fhi.y = maxf(fhi.y, base_y)
	return Rect2(flo, fhi - flo)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)

var _sig := ""

## 编辑器预览同步:pts/base_y 变化才重建临时预览(不写入场景文件)。
func _editor_sync(force: bool) -> void:
	var s := str(pts) + "|" + str(base_y)
	if not force and s == _sig:
		return
	_sig = s
	var prev := get_node_or_null("EditorPreview")
	if prev != null:
		prev.queue_free()
	if pts.size() < 2:
		return
	var box := Node2D.new()
	box.name = "EditorPreview"
	var spr := Sprite2D.new()
	spr.show_behind_parent = true
	TerrainKit.mech_layout(spr, T_FRAME, _frame_zone())
	box.add_child(spr)
	add_child(box)
	queue_redraw()

func _draw() -> void:
	if Palette.I == null:
		return   # 编辑器极早期:静态资源未就绪,下帧重试
	if pts.size() < 2:
		if Engine.is_editor_hint():
			# 未配置占位:虚线斜面提示"这里将是一段曲面"(pts 逐点编辑)
			var hcol := Color(Palette.I.dim, 0.7)
			for i in 6:
				var t0 := i / 6.0
				draw_line(Vector2(t0 * 200.0, -t0 * 100.0),
					Vector2((t0 + 0.08) * 200.0, -(t0 + 0.08) * 100.0), hcol, 2.0)
			draw_line(Vector2(-10, 0), Vector2(210, 0),
				Color(Palette.I.paper, 0.25), 2.0)
		return
	# 顶缘亮线(正典帧贴包围盒下衬之上,保持曲线可读)
	draw_polyline(pts, Color(Palette.I.paper, 0.35), 2.0)
	# 红色刻度块(每段中点,沿坡向斜画 —— 与曲面平行,v0.27 用户定稿)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := (b - a).normalized()
		var mid := (a + b) * 0.5
		draw_line(mid - d * 7.0, mid + d * 7.0, Color(Palette.I.red, 0.55), 3.0)
	# 专属高亮描边(呼吸脉冲,§7)
	TerrainKit.draw_focus(self, TerrainKit.ramp_bounds(pts, base_y), hl_color)

const THICKNESS := 48.0

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if pts.size() < 2:
		w.append("pts 至少需要 2 个折线点(Inspector 逐点编辑)。")
	return w
