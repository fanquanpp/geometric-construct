class_name MoverSlab
extends Node2D

## 移动石板外观:与静态平台同语言(亮面板 + 顶缘亮线),
## 侧缘红色刻度块标出"正在移动"的身份;投影由引擎光影实算。

var size := Vector2.ZERO
var _base: StyleBoxFlat
var _slab: StyleBoxFlat

func _ready() -> void:
	_base = StyleBoxFlat.new()
	_base.bg_color = Color("2B3140")
	_slab = StyleBoxFlat.new()
	_slab.bg_color = Color("3A4254")

func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	draw_style_box(_base, r)
	var slab := minf(size.y * 0.4, 22.0)
	if slab > 2.0:
		draw_style_box(_slab, Rect2(r.position, Vector2(size.x, slab)))
	draw_rect(Rect2(r.position, Vector2(size.x, 2)), Color(Ui.PAPER, 0.42))
	# 左右缘红色移动刻度(与静态平台的左侧刻度区分)
	draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(8, 3)), Color(Ui.RED, 0.8))
	draw_rect(Rect2(Vector2(r.end.x - 8, r.position.y + 3), Vector2(8, 3)),
		Color(Ui.RED, 0.8))
	# 专属高亮描边(读宿主 Mover 的 hl_color,呼吸脉冲,§7.10)
	var mv := get_parent() as Mover
	if mv != null:
		LevelBuilder.draw_focus(self, r, mv.hl_color)
