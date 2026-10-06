extends Node2D

# 数据流网络(五带之「远景」0.16):方点节点 + 直角折线连线(电路图语言),
# 信号方点沿折线路径 A→B 匀速传输(子节点 position 位移,零逐帧重绘);
# sweep 相位单场重绘(事件级:切幕/速度阈值穿越,red_wave phase-setter
# 同款先例);Ambience SPECIAL 拍:整网 modulate 微沉回浮 + 一粒信号归零
# 重发(拍缺席回退自由节奏:恒有信号在途)。accent 由 Backdrop 远景降阶
# 下发;密度倍率 set_density 事件级重绘。瓦片 2600 横向重复,内容左上对齐。

const TILE_W := 2600.0
const NODE_N := 12
const LINK_N := 15
const SWEEP_S := 0.7
const SWEEP_SPAN := 3000.0
const SWEEP_W := 240.0
const PACKET_N := 4
const SEED := 70701
const ROUTES := [1, 5, 9, 13]

var density := 1.0
var accent := Color(0.306, 0.525, 0.847, 1.0):
	set(v):
		if accent != v:
			accent = v
			queue_redraw()
			_paint_packets()

## 单场扫掠相位(<0 静置;推进中仅扫掠期重绘,场毕归 -1 停绘)。
var sweep := -1.0:
	set(v):
		sweep = v
		queue_redraw()

var _pts: Array[Vector2] = []
var _paths: Array[PackedVector2Array] = []
var _packets: Array[Packet] = []
var _beat_i := 0
var _cycle_tween: Tween
var _anim := true


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for row in 3:
		for col in 4:
			_pts.append(Vector2(
				180.0 + col * 560.0 + rng.randf_range(-70.0, 70.0),
				220.0 + row * 260.0 + rng.randf_range(-60.0, 60.0)))
	# 直角折线连线:右邻/下邻为主 + 两处隔位跨接;肘点竖先横后按奇偶交替。
	for row in 3:
		for col in 3:
			var i := row * 4 + col
			_paths.append(_elbow(_pts[i], _pts[i + 1], (i + 1) % 2 == 0))
	for row in 2:
		for col in 2:
			var i := row * 4 + col * 2
			_paths.append(_elbow(_pts[i], _pts[i + 4], (i + 4) % 2 == 0))
	_paths.append(_elbow(_pts[0], _pts[5], true))
	_paths.append(_elbow(_pts[7], _pts[10], false))
	for k in PACKET_N:
		var idx: int = ROUTES[k]
		var pts := _paths[idx]
		if k % 2 == 1:
			pts = pts.duplicate()
			pts.reverse()
		var pk := Packet.new()
		pk.setup(pts, _packet_color(), 96.0 + k * 26.0, 90.0 + k * 260.0)
		add_child(pk)
		pk.position = pk.point_at(pk.t)
		_packets.append(pk)


func _elbow(a: Vector2, b: Vector2, vert_first: bool) -> PackedVector2Array:
	var corner := Vector2(a.x, b.y) if vert_first else Vector2(b.x, a.y)
	return PackedVector2Array([a, corner, b])


func _packet_color() -> Color:
	return Color(accent.r, accent.g, accent.b, 0.55)


func _paint_packets() -> void:
	for pk in _packets:
		pk.col = _packet_color()


func set_density(m: float) -> void:
	density = m
	queue_redraw()


func set_animated(on: bool) -> void:
	_anim = on
	set_process(on)
	if not on:
		if _cycle_tween != null:
			_cycle_tween.kill()
			_cycle_tween = null
		modulate.a = 1.0


## Beat 转发入口(Backdrop 统一订阅后分发;远带只绑 SPECIAL 拍)。
func on_beat(kind: int, _index: int) -> void:
	if not _anim or kind != Ambience.BeatKind.SPECIAL:
		return
	if _cycle_tween != null:
		_cycle_tween.kill()
	modulate.a = 0.78
	_cycle_tween = create_tween()
	_cycle_tween.tween_property(self, "modulate:a", 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 拍点信号:一粒在途信号归零重发(纯 position,零重绘)。
	var pk := _packets[_beat_i % _packets.size()]
	pk.t = 0.0
	pk.position = pk.path[0]
	_beat_i += 1


## 一次性低耗活化:切幕 / 速度阈值穿越时由 Backdrop 调用。
func fire_sweep() -> void:
	if _anim:
		sweep = 0.0


func _process(delta: float) -> void:
	if sweep >= 0.0:
		var v := sweep + delta / SWEEP_S
		sweep = -1.0 if v >= 1.0 else v
	if not _anim:
		return
	for pk in _packets:
		pk.t = fposmod(pk.t + pk.speed * delta, pk.total)
		pk.position = pk.point_at(pk.t)


func _front() -> float:
	return sweep * SWEEP_SPAN - SWEEP_W


func _draw() -> void:
	var paper := Palette.I.paper
	var nl := int(round(LINK_N * density))
	for i in mini(nl, _paths.size()):
		var pl := _paths[i]
		var c := Color(paper, 0.11 if i % 3 == 0 else 0.07)
		if sweep >= 0.0:
			var d := absf(pl[int(pl.size() * 0.5)].x - _front())
			if d < SWEEP_W:
				c = Color(c.r, c.g, c.b,
					minf(c.a + (1.0 - d / SWEEP_W) * 0.28, 0.5))
		draw_polyline(pl, c, 1.0, true)
	var nd := int(round(NODE_N * density))
	for i in mini(nd, _pts.size()):
		var major := i % 4 == 0
		var s := 8.0 if major else 5.0
		var nc := Color(accent.r, accent.g, accent.b, 0.5) if major \
			else Color(paper, 0.3)
		if sweep >= 0.0:
			var d2 := absf(_pts[i].x - _front())
			if d2 < SWEEP_W:
				nc = Color(nc.r, nc.g, nc.b,
					minf(nc.a + (1.0 - d2 / SWEEP_W) * 0.3, 0.85))
		draw_rect(Rect2(_pts[i] - Vector2(s, s) * 0.5, Vector2(s, s)), nc)


## 在途信号方点:宿主推 position(折线路径采样),自身只在换色时重绘。
class Packet:
	extends Node2D

	var path := PackedVector2Array()
	var seg_len := PackedFloat64Array()
	var total := 0.0
	var speed := 120.0
	var t := 0.0
	var col := Color(1, 1, 1, 0.55):
		set(v):
			if col != v:
				col = v
				queue_redraw()

	func setup(p: PackedVector2Array, c: Color, spd: float, phase: float) -> void:
		path = p
		col = c
		speed = spd
		seg_len = PackedFloat64Array()
		seg_len.resize(p.size() - 1)
		var acc := 0.0
		for i in p.size() - 1:
			acc += p[i].distance_to(p[i + 1])
			seg_len[i] = acc
		total = acc
		t = fposmod(phase, total)

	func point_at(pos: float) -> Vector2:
		var d := fposmod(pos, total)
		var prev := 0.0
		for i in seg_len.size():
			if d <= seg_len[i]:
				var seg := seg_len[i] - prev
				var f := 0.0 if seg <= 0.0001 else (d - prev) / seg
				return path[i].lerp(path[i + 1], f)
			prev = seg_len[i]
		return path[path.size() - 1]

	func _draw() -> void:
		draw_rect(Rect2(Vector2(-3, -3), Vector2(6, 6)), col)
