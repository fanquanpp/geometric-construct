class_name FrameDraw
extends Control


var style := "panel"


func _init(p_style := "panel") -> void:
	style = p_style
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if Palette.I == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	if style == "poster":
		DrawKit.poster_frame(self, r, Palette.I.red)
		return
	draw_rect(r, Color(Palette.I.ink_2, 0.97))
	DrawKit.frame_rect(self, r.grow(-2.0), Color(Palette.I.paper, 0.5), 2.0)
	draw_rect(r.grow(-9.0), Color(Palette.I.paper, 0.16), false, 1.0)
