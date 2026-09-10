class_name SpeedGate
extends Area2D
## 加速门(光电门):穿过时立即把速度抬到门后上限,并永久提升速度上限
## (对"圆"为 2.5×、"逆"为 2.0×,直至死亡重生)。
## 视觉:门柱 + 顶梁 + 循环滚动的雪佛龙箭头,有人强化时箭头变红加速。

var center: Vector2
var zone_size := Vector2(96, 190)

var _t := 0.0
var _bodies := {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 3
	position = center

	var cs := CollisionShape2D.new()
	cs.position = Vector2.ZERO
	var shape := RectangleShape2D.new()
	shape.size = zone_size
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	# 联机:强化只在主机判定,客机经事件复现(net.md §6)
	if NetSession.I != null and NetSession.I.is_net() and not NetSession.I.is_host():
		return
	if body is Player:
		_bodies[body] = true
		(body as Player).apply_speed_gate()
		if NetSession.I != null and NetSession.I.is_host() and Main.I != null:
			NetSession.I.emit_event(NetSession.EV_BUFFED, Main.I.players.find(body))


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_bodies.erase(body)


func _exit_tree() -> void:
	_bodies.clear()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := zone_size.x
	var h := zone_size.y
	var post_w := 8.0
	var live := not _bodies.is_empty()   # 有人正在门内:进入强化态配色
	var frame_col := Color(1, 1, 1, 0.75) if live else Color(1, 1, 1, 0.55)
	var accent := Color("E0492F")

	# 两侧门柱 + 顶梁(留出底部通行)
	draw_rect(Rect2(-w / 2.0 - post_w, -h / 2.0, post_w, h), frame_col)
	draw_rect(Rect2(w / 2.0, -h / 2.0, post_w, h), frame_col)
	draw_rect(Rect2(-w / 2.0 - post_w, -h / 2.0, w + post_w * 2.0, post_w), accent)

	# 内部区域底色(极淡,提示是可穿过的场)
	draw_rect(Rect2(-w / 2.0, -h / 2.0 + post_w, w, h - post_w),
		Color("E0492F", 0.10) if live else Color(1, 1, 1, 0.04))

	# 循环滚动的雪佛龙箭头(向右,指示加速方向;粗折线,避免自相交多边形)
	var spacing := 26.0
	var speed := 92.0 if live else 46.0
	var offset := fmod(_t * speed, spacing)
	var x := -w / 2.0 + 6.0 - spacing + offset
	var chev_col := Color("E0492F", 0.8) if live else Color(1, 1, 1, 0.5)
	while x < w / 2.0 - 4.0:
		if x > -w / 2.0 + 2.0:
			var s := 7.0
			draw_line(Vector2(x, -s), Vector2(x + s, 0), chev_col, 4.0)
			draw_line(Vector2(x + s, 0), Vector2(x, s), chev_col, 4.0)
		x += spacing
