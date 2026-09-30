extends Node2D

# 轨道星系(v0.60.0 风格化重置,源自 fandex decor-orbit):三重同心**方框**
# 38/26/48s 匀速巡行(其一反向),框上各一枚方点沿边匀速直线行进、直角折角。
# 框静态绘制、点走 position(零重绘)。
# 数量与强调色由 BackdropPreset 下发;动画关 = 停转保姿态。

const SPEEDS := [TAU / 38.0, -TAU / 26.0, TAU / 48.0]
# v0.60.0 风格化重置:圆环+圆周绕行(曲线运动)→ 方框轨道+沿边匀速
# 直线行进、直角折角(构成主义:运动走直线折角);框静态绘制、点走
# 节点 position(零重绘纪律不变)。
const RADII := [190.0, 150.0, 118.0]

var accent := Color(0.306, 0.525, 0.847, 0.4)
var _rings: Array = []


func set_count(n: int) -> void:
	var want := clampi(n, 0, SPEEDS.size())
	while _rings.size() > want:
		var r: Node2D = _rings.pop_back()
		r.queue_free()
	while _rings.size() < want:
		var i := _rings.size()
		var ring := Ring.new()
		ring.radius = RADII[i]
		ring.speed = SPEEDS[i]
		ring.accent = accent
		add_child(ring)
		_rings.append(ring)


func set_accent(c: Color) -> void:
	accent = c
	for r in _rings:
		(r as Ring).accent = c
		(r as Ring).queue_redraw()


func set_animated(on: bool) -> void:
	for r in _rings:
		r.set_process(on)


class Ring:
	extends Node2D

	var radius := 150.0
	var speed := TAU / 38.0
	var accent := Color(1, 1, 1, 0.4)
	var _t := 0.0
	var _dot: Node2D

	func _ready() -> void:
		pass

	func _process(delta: float) -> void:
		_t += delta * (1.0 if speed >= 0.0 else -1.0)
		queue_redraw()

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
		var pts := PackedVector2Array([
			Vector2(-s, -s), Vector2(s, -s), Vector2(s, s),
			Vector2(-s, s), Vector2(-s, -s)])
		draw_polyline(pts, Color(accent.r, accent.g, accent.b, accent.a * 0.5), 1.0, true)
		draw_rect(Rect2(_dot_pos() - Vector2(3, 3), Vector2(6, 6)), accent)
