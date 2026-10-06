extends Node2D

# 方框轨道群(五带之「中景」0.32):嵌套方框 + 沿边直角折行方点
# (继承 orbit_rings 语言:框静态绘制、点走 position,零逐帧重绘);
# Ambience SPECIAL 拍整群 modulate 微沉回浮(单 Tween,同属性 kill 旧再建);
# 方点恒速巡行,拍缺席自由节奏回退。组数(1-2)与 accent 由 Backdrop 下发;
# 瓦片 2600 横向重复,组内最大框 280px,两组横向净距 >1280,
# 同屏至多显形一群(防「中尺寸元素铺满」壁纸化)。

const RADII := [140.0, 104.0, 74.0]
const SPEEDS := [TAU / 34.0, -TAU / 22.0, TAU / 46.0]
const POSITIONS := [Vector2(1880.0, 430.0), Vector2(560.0, 620.0)]
const DOT_A := 0.55
const BOX_A := 0.16

var accent := Color(0.306, 0.525, 0.847, 1.0):
	set(v):
		if accent != v:
			accent = v
			for ring in _rings:
				(ring as TrackRing).set_ring_accent(accent)

var _rings: Array = []
var _cycle_tween: Tween
var _anim := true


func _ready() -> void:
	for g in POSITIONS.size():
		for i in RADII.size():
			var ring := TrackRing.new()
			ring.position = POSITIONS[g]
			ring.radius = RADII[i]
			ring.speed = SPEEDS[i]
			ring.accent = accent
			ring.set_ring_animated(_anim)
			add_child(ring)
			_rings.append(ring)


func set_count(n: int) -> void:
	var want := clampi(n, 1, POSITIONS.size())
	for g in POSITIONS.size():
		var on := g < want
		for i in RADII.size():
			(_rings[g * RADII.size() + i] as TrackRing).visible = on


func set_accent(c: Color) -> void:
	accent = c


func set_animated(on: bool) -> void:
	_anim = on
	for ring in _rings:
		(ring as TrackRing).set_ring_animated(on)
	if not on and _cycle_tween != null:
		_cycle_tween.kill()
		_cycle_tween = null
		modulate.a = 1.0


## Beat 转发入口:远带只绑 SPECIAL 拍(整群微沉回浮,零重绘)。
func on_beat(kind: int, _index: int) -> void:
	if not _anim or kind != Ambience.BeatKind.SPECIAL:
		return
	if _cycle_tween != null:
		_cycle_tween.kill()
	modulate.a = 0.76
	_cycle_tween = create_tween()
	_cycle_tween.tween_property(self, "modulate:a", 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


class TrackRing:
	extends Node2D

	var radius := 140.0
	var speed := TAU / 34.0
	var accent := Color(1, 1, 1, 0.16)
	var _t := 0.0
	var _dot: Node2D

	func _ready() -> void:
		_dot = TrackDot.new()
		_dot.col = Color(accent.r, accent.g, accent.b, DOT_A)
		add_child(_dot)

	## 动画门控:停巡保姿态(方点停在当前边位,静态轮廓保留)。
	func set_ring_animated(on: bool) -> void:
		set_process(on)

	func set_ring_accent(c: Color) -> void:
		accent = c
		queue_redraw()
		if _dot != null:
			_dot.col = Color(c.r, c.g, c.b, DOT_A)

	func _process(delta: float) -> void:
		_t += delta * (1.0 if speed >= 0.0 else -1.0)
		if _dot != null:
			_dot.position = _dot_pos()

	func _dot_pos() -> Vector2:
		var s := radius
		var per := absf(speed) / TAU
		if per <= 0.0001:
			return Vector2(s, -s)
		var p := fposmod(_t * per, 1.0) * 4.0
		var edge := int(p)
		var f := p - float(edge)
		match edge:
			0: return Vector2(-s + f * 2.0 * s, -s)
			1: return Vector2(s, -s + f * 2.0 * s)
			2: return Vector2(s - f * 2.0 * s, s)
			_:
				return Vector2(-s, s - f * 2.0 * s)

	func _draw() -> void:
		var s := radius
		var stroke := Color(accent.r, accent.g, accent.b, BOX_A)
		var pts := PackedVector2Array([
			Vector2(-s, -s), Vector2(s, -s), Vector2(s, s),
			Vector2(-s, s), Vector2(-s, -s)])
		draw_polyline(pts, stroke, 1.0, true)
		# 外框四角纸色角括弧(构成主义取景记号)。
		var tick := Color(Palette.I.paper, 0.3)
		for corner: Vector2 in [Vector2(-s, -s), Vector2(s, -s),
				Vector2(s, s), Vector2(-s, s)]:
			var dx := signf(corner.x) * -10.0
			var dy := signf(corner.y) * -10.0
			draw_line(corner, corner + Vector2(dx, 0), tick, 1.0)
			draw_line(corner, corner + Vector2(0, dy), tick, 1.0)


## 方点子节点:只随 position 移动,换色才重绘。
class TrackDot:
	extends Node2D

	var col := Color(1, 1, 1, DOT_A):
		set(v):
			if col != v:
				col = v
				queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2(-3, -3), Vector2(6, 6)), col)
