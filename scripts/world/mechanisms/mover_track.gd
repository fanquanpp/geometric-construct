class_name MoverTrack
extends Node2D

## 移动构件轨道:世界坐标里的细线路径 + 两端终点刻度,提前预告行程。

var center := Vector2.ZERO
var travel := Vector2.ZERO

func _ready() -> void:
	z_index = 0

func _draw() -> void:
	if travel == Vector2.ZERO:
		return
	var a := center - travel * 0.5
	var b := center + travel * 0.5
	draw_line(a, b, Color(Ui.PAPER, 0.10), 1.0)
	for p: Vector2 in [a, b]:
		draw_rect(Rect2(p + Vector2(-2.5, -14.0), Vector2(5, 5)), Color(Ui.RED, 0.55))
		draw_rect(Rect2(p + Vector2(-2.5, 9.0), Vector2(5, 5)), Color(Ui.RED, 0.55))
