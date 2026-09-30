extends Node2D

# 死亡红波(v0.60.0 风格化重置,源自 fandex decor-wave):三道折线波自左向右横扫,
# phase 0→1 由 Backdrop 的 Tween 推动 setter 重绘(TransitionFX CurtainDraw 同款),
# alpha 按 sin(phase*PI) 包络,单场约 0.9s,一次性开销。

const PERIOD := 320.0
const AMP := 18.0
const ROWS := [0.34, 0.5, 0.66]

var phase := -1.0:
	set(v):
		phase = v
		queue_redraw()

var _col := Color(0.878, 0.286, 0.184, 1.0)


func fire(c: Color) -> void:
	_col = c
	phase = 0.0


func _draw() -> void:
	if phase < 0.0:
		return
	var vp := get_viewport_rect().size
	var a := sin(phase * PI) * 0.30
	if a <= 0.005:
		return
	var c := Color(_col.r, _col.g, _col.b, a)
	var drift := phase * TAU * 2.0
	for row: float in ROWS:
		var y0 := vp.y * row
		var pts := PackedVector2Array()
		for i in 65:
			var x := vp.x * float(i) / 64.0
			# 折线波(直线段+硬折角)替代正弦曲线。
			var u := x / PERIOD + drift + row * 0.25
			var y := y0 + (absf(fposmod(u, 1.0) - 0.5) * 4.0 - 1.0) * AMP
			pts.append(Vector2(x, y))
		draw_polyline(pts, c, 1.6, true)
