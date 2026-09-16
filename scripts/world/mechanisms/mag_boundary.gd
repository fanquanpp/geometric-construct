class_name MagBoundary
extends Node2D

## 磁力边界(伍·界/边,characters.md §5):两半顶部之间的阻隔线,
## 随两半移动逐帧伸缩;除逆(can_pass_boundary)与双子自身外人人受阻。
##
## v2 修法②(characters.md §5 候选②,根治扫掠推挤):不再挂
## StaticBody2D —— 逐帧重设端点后,物理引擎的去穿透扫掠会把贴线
## 几何体沿最短向量推出去;渐进扫掠(每帧 < 120px)不触发旧收线守卫,
## 推挤逐帧累积(~1/3 flaky 的根因)。改为【自定义速度投影】:
## 受阻几何体在自身物理步进之前(process_physics_priority = -10)
## 对本线做穿越判定,试图穿越者把速度沿线方向投影(削去法向分量),
## 沿线滑行 —— 线只阻挡不推移,端点任何速度都不再"搬运"贴线体。
## 收线语义保留:任一半死亡 / 进门期间两端并拢,不阻隔任何人。

var a: Player
var b: Player

## 编辑器占位跨度(所见即所指):磁界两端运行时锚定双子,编辑器内
## 无法预知——用占位线标出"这里会有一道磁界",方向与长度可摆。
@export var hint_span := Vector2(320, 0)

var _seg_a := Vector2.ZERO   # 端点(全局坐标;本节点恒在原点)
var _seg_b := Vector2.ZERO
var _active := false         # 线是否张成(收线时 false,只画不拦)


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	z_index = 4
	process_physics_priority = -10   # 先于各玩家的 _physics_process 执行


## 阻挡判定 + 速度投影:几何体本帧的运动轨迹若穿越磁界线(按自身
## 半宽 r 膨胀,端点按圆帽处理),削去法向分速度,只保留沿线分量。
func _project_bodies(dt: float) -> void:
	var players: Array = Main.I.players if Main.I != null else []
	if players.is_empty():
		return
	var d := _seg_b - _seg_a
	var length := d.length()
	if length < 8.0:
		return   # 两半几乎并拢:不构成阻隔
	var dn := d / length
	for node in players:
		var p := node as Player
		if p == null or p == a or p == b:
			continue
		# 与 player.gd _ready 的 BOUNDARY_BIT 判据一致:逆可穿、双子豁免
		if p.pair_half >= 0 or p.def.can_pass_boundary:
			continue
		# 联机:客机侧几何体由快照搬运,不参与本地投影(主机权威)
		if p.remote_driven:
			continue
		var r := minf(p.def.size.x, p.def.size.y) * 0.5
		var now := p.global_position - _seg_a
		var side_now := dn.cross(now)            # 带符号垂距(法向)
		var side_nxt := dn.cross(now + p.velocity * dt)
		# 已在线半径之内(线从身上扫过):不推,放行 —— 线只阻挡不推移
		if side_now > -r and side_now < r:
			continue
		# 本帧轨迹穿越 r 壳层才拦(两侧同号 = 未穿越)
		if (side_now > 0.0) == (side_nxt > 0.0):
			continue
		if absf(side_now) < r:
			continue
		# 穿越点须落在段范围 + 圆帽半径内
		var t_c := side_now / (side_now - side_nxt)
		var u := now.lerp(now + p.velocity * dt, t_c).dot(dn)
		if u < -r or u > length + r:
			continue
		# 速度投影:削去法向分量,保留沿线分量(线只阻挡不推移)
		p.velocity = p.velocity.project(dn)


func _draw() -> void:
	if Engine.is_editor_hint():
		# 编辑器占位:伍色虚折线 + 端点方块(构成主义硬边,#8455A6)
		var hcol := Color(0.518, 0.333, 0.651, 0.85)
		var hpb := hint_span
		draw_line(Vector2.ZERO, hpb, hcol, 2.5)
		var hn := Vector2(-hpb.y, hpb.x).normalized() * 7.0
		for i in 5:
			var hm := hpb * ((i + 0.5) / 5.0)
			draw_line(hm - hn, hm + hn, hcol, 2.0)
		draw_rect(Rect2(Vector2(-4, -4), Vector2(8, 8)), hcol)
		draw_rect(Rect2(hpb - Vector2(4, 4), Vector2(8, 8)), hcol)
		return
	if a == null or b == null or not _active:
		return
	var col: Color = a.def.color
	var pa := _seg_a
	var pb := _seg_b
	var d := pb - pa
	if d.length() < 8.0:
		return
	var mid := (pa + pb) * 0.5
	var n := Vector2(-d.y, d.x).normalized()
	var bow := n * clampf(d.length() * 0.08, 4.0, 14.0)
	# 磁力折线:三段硬折(构成主义,不弯曲)
	var pts := PackedVector2Array([pa, pa + d * 0.3 + bow,
		pa + d * 0.7 + bow, pb])
	for i in 3:
		draw_line(pts[i], pts[i + 1], Color(col, 0.85), 2.5)
	# 端点方块 + 折点中块(磁力感)
	draw_rect(Rect2(pa - Vector2(4, 4), Vector2(8, 8)), Color(col, 0.95))
	draw_rect(Rect2(pb - Vector2(4, 4), Vector2(8, 8)), Color(col, 0.95))
	draw_rect(Rect2(mid + bow - Vector2(3, 3), Vector2(6, 6)), Color(Palette.I.paper, 0.9))
