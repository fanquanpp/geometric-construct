class_name FramePanel
extends PanelContainer


var accent := Color(0, 0, 0, 0)


func _ready() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(Palette.I.ink_2, 0.97)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		bg.set_content_margin(side, 20.0)
	add_theme_stylebox_override("panel", bg)


func _draw() -> void:
	if Palette.I == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	DrawKit.frame_rect(self, r.grow(-2.0), Color(Palette.I.paper, 0.55), 2.0)
	draw_rect(r.grow(-9.0), Color(Palette.I.paper, 0.14), false, 1.0)
	var m := 10.0
	var ac := accent if accent.a > 0.0 else Palette.I.red
	for corner: Array in [[r.position, Vector2(1, 1)],
			[Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[r.end, Vector2(-1, -1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_rect(Rect2(p + Vector2(
			minf(0.0, d.x) * m, minf(0.0, d.y) * m), Vector2(m, m)), ac)
