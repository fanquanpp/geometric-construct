@icon("res://assets/editor/spawn_marker.svg")
@tool
class_name SpawnMarker
extends Marker2D

## 出生点组件(v0.65.0 万物节点化):geo_index 绑定归属几何体,
## 编辑器实时绘制归属色字形(所见即所得);运行时由 NativeLevel 收集。

@export_range(0, 2) var geo_index := 0:
	set(v):
		geo_index = v
		queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or Palette.I == null:
		return
	var cols: Array[Color] = [Palette.I.red, Palette.I.yellow, Palette.I.blue]
	var c: Color = cols[clampi(geo_index, 0, 2)]
	draw_rect(Rect2(-26, -26, 52, 52), Color(c, 0.22), false, 3.0)
	draw_rect(Rect2(-14, -14, 28, 28), Color(c, 0.85))
	draw_rect(Rect2(-14, -14, 28, 5), Color(1, 1, 1, 0.55))
	DrawKit.chevron(self, Vector2(0, 34), Vector2(0, -1), 14.0, Color(c, 0.7), 3.0)
