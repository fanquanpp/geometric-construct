extends Node2D

# 构成棱环太阳为程序绘制装饰(procedural-art)。绘制绕节点原点,
# 摆位由场景 position 决定;活化:自转(spin deg/s)+ 呼吸(15s,fandex 光晕参数),
# 全走节点 transform,零重绘;动画关 = 停转保姿态。
# burst() 为到站光涌的瞬时脉冲(一次性 Tween,由 Backdrop 调用)。

const FACETS := 12

var spin := 1.2
var pulse := 0.03
var _t := 0.0
var _burst_tween: Tween
var _animated := true


func set_animated(on: bool) -> void:
	_animated = on
	set_process(on)


func _process(delta: float) -> void:
	rotation += deg_to_rad(spin) * delta
	_t += delta
	scale = Vector2.ONE * (1.0 + pulse * sin(_t * TAU / 15.0))


func burst(amp := 1.06) -> void:
	if not _animated:
		return
	if _burst_tween != null:
		_burst_tween.kill()
	_burst_tween = create_tween()
	_burst_tween.tween_property(self, "scale", Vector2.ONE * amp, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_burst_tween.tween_property(self, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var center := Vector2.ZERO
	_draw_facet_ring(center, 120.0, Color(Palette.I.paper, 0.14), 2.0)
	_draw_facet_ring(center, 78.0, Color(Palette.I.paper, 0.07), 1.0)
	draw_line(center + Vector2(-170, 0), center + Vector2(170, 0),
		Color(Palette.I.red, 0.30), 3.0)


func _draw_facet_ring(c: Vector2, r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	var off := -PI / 2.0 + PI / FACETS
	for i in FACETS + 1:
		var a := off + TAU * float(i) / float(FACETS)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, col, w, true)
