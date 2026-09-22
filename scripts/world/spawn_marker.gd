@tool
class_name SpawnMarker
extends Marker2D


@export var geo_index := 0

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() or Palette.I == null:
		return
	var colors := [Palette.I.red, Palette.I.yellow, Palette.I.blue,
		Palette.I.orange, Color(0.518, 0.333, 0.651)]
	var col: Color = colors[clampi(geo_index, 0, colors.size() - 1)]

	draw_line(Vector2(0, 0), Vector2(0, -44), Color(Palette.I.paper, 0.55), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -44), Vector2(22, -37), Vector2(0, -30)]),
		Color(col, 0.9))
	draw_rect(Rect2(-7, -3, 14, 6), Color(Palette.I.red, 0.8))
	draw_rect(Rect2(-12, 4, 24, 3), Color(Palette.I.paper, 0.25))
