extends Node2D

# 构成棱环太阳为程序绘制装饰(procedural-art)。

const FACETS := 12

func _draw() -> void:
	var center := Vector2(1560.0, 240.0)
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
