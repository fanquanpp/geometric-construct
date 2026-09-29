extends Node2D

# 轨道星系(移植 fandex decor-orbit):三重同心环 38/26/48s 匀速绕行(其一反向),
# 环顶各带一枚绕行圆点。旋转走节点 rotation(零重绘)。
# 数量与强调色由 BackdropPreset 下发;动画关 = 停转保姿态。

const SPEEDS := [TAU / 38.0, -TAU / 26.0, TAU / 48.0]
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

	func _ready() -> void:
		rotation = randf() * TAU

	func _process(delta: float) -> void:
		rotation += speed * delta

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 65:
			var a := TAU * float(i) / 64.0
			pts.append(Vector2(cos(a), sin(a)) * radius)
		draw_polyline(pts, Color(accent.r, accent.g, accent.b, accent.a * 0.5), 1.0, true)
		draw_circle(Vector2(radius, 0), 3.0, accent)
