@tool
class_name SpawnMarker
extends Marker2D
## 出生点标记(所见即所指):世界内的出生旗 —— 旗杆 + 纸白旗面 +
## 基座红刻度,编辑器内可辨、运行时不画(出生点本身无声无息,
## 摆位契约 = NativeLevel 读 Marker2D 名 Spawn<N>)。
## 纯编辑器辅助绘制(_draw 动态豁免:数量/形态运行时无关,但
## 标记物为编辑器视觉,不入游戏画面)。

@export var geo_index := 0   # 对应几何体(旗面取其角色色,0-4)

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
	# 旗杆 + 三角旗(硬边)+ 基座刻度
	draw_line(Vector2(0, 0), Vector2(0, -44), Color(Palette.I.paper, 0.55), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -44), Vector2(22, -37), Vector2(0, -30)]),
		Color(col, 0.9))
	draw_rect(Rect2(-7, -3, 14, 6), Color(Palette.I.red, 0.8))
	draw_rect(Rect2(-12, 4, 24, 3), Color(Palette.I.paper, 0.25))
