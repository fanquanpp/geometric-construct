class_name TimedBridge
extends StaticBody2D

## 限时桥(structures.md §5):周期性实心 ↔ 虚化的桥板 ——
## 虚化期无碰撞(运行时 set_collision_layer_value 切位)、降透明度,
## 保留 8% 亮度线框 + 轨道线,切换状态可预读(可预读纪律)。
## on/off 各 ≥1s 保证可读;sync_beat = 与 BGM 节拍时钟对齐(audio.md §5)。

var slab_rect := Rect2()
var on_time := 2.0
var off_time := 2.0
var phase := 0.0
var sync_beat := false
var layer_bit := 1
var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7.10)
var _t := 0.0
var _solid := true
var _beat_phase := 0.0   # 启动时对齐到的节拍相位
var _occ: LightOccluder2D   # 遮挡体随实/虚切换(虚化 = 不投影)

func _ready() -> void:
	collision_layer = 1 << (layer_bit - 1)
	collision_mask = 0
	var cs := CollisionShape2D.new()
	cs.position = slab_rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = slab_rect.size
	cs.shape = shape
	add_child(cs)
	position = Vector2.ZERO
	_occ = LevelBuilder._rect_occluder(slab_rect)
	add_child(_occ)
	if sync_beat and Sfx.beat_period() > 0.0:
		_beat_phase = Sfx.beat_time()
		_t = _beat_phase

func _physics_process(delta: float) -> void:
	# 联机同 Mover:共享关卡时钟(单机本地累计不变)
	if NetSession.I != null and NetSession.I.is_net():
		_t = NetSession.I._clock
	else:
		_t += delta
	var cycle := maxf(on_time + off_time, 2.0)
	var t := fposmod(_t + phase, cycle)
	var solid := t < on_time
	if solid != _solid:
		_solid = solid
		# 运行时碰撞位切换(levels.md §7.6):虚化 = 全体不可踩
		set_collision_layer_value(layer_bit, solid)
		_occ.visible = solid   # 虚化态不投影(与线框虚化语言一致)
		queue_redraw()
		if not solid:
			Sfx.play("ui_page", -8.0)
		else:
			Sfx.play("ui_click", -8.0)

func _draw() -> void:
	var r := Rect2(slab_rect.position, slab_rect.size)
	# 轨道线:桥的行程始终可见(可预读的一部分)
	draw_rect(Rect2(Vector2(r.position.x - 10, r.get_center().y - 1),
		Vector2(4, 2)), Color(Ui.RED, 0.55))
	draw_rect(Rect2(Vector2(r.end.x + 6, r.get_center().y - 1),
		Vector2(4, 2)), Color(Ui.RED, 0.55))
	if _solid:
		draw_rect(r, Color("2B3140"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color("3A4254"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Ui.PAPER, 0.42))
		# 实心态刻度:左缘红块(与移动板同语言)
		draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(8, 3)), Color(Ui.RED, 0.8))
	else:
		# 虚化态:8% 亮度线框 + 虚线段(可预读纪律)
		draw_rect(r, Color(Ui.PAPER, 0.08))
		var seg := 14.0
		var x := r.position.x
		while x < r.end.x:
			draw_rect(Rect2(Vector2(x, r.position.y), Vector2(minf(seg, r.end.x - x), 2)),
				Color(Ui.PAPER, 0.30))
			x += seg * 2.0
		draw_rect(r, Color(Ui.PAPER, 0.16), false, 1.0)
	# 专属高亮描边(呼吸脉冲,§7.10)
	LevelBuilder.draw_focus(self, r, hl_color)
