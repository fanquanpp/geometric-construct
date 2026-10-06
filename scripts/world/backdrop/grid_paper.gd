extends Node2D

# 网格纸基座(五带之最远 0.05):瑞士网格秩序——32px 细分线 + 256px 主线,
# 取色 palette.line(白 α0.1)派生两级灰阶,静态单次绘制零逐帧开销。
# 节点位于 Parallax2D 原点,瓦片 1024×1024(32px 整数倍,横向纵向重复无缝),
# 内容左上角对齐 (0,0)(Parallax2D 官方纪律,禁居中)。
# 网格是纸面本体(静态结构),双门控下保留——reduced_motion 停帧语义为
# 「保静态轮廓」,网格即轮廓。

const TILE := 1024.0
const MINOR := 32.0
const MAJOR := 256.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var minor := Color(Palette.I.line, Palette.I.line.a * 0.55)
	var major := Palette.I.line
	# 半开区间 [0, TILE):右/下边缘让位给相邻瓦片的 0 线,避免接缝叠亮。
	var x := 0.0
	while x < TILE - 0.25:
		draw_line(Vector2(x, 0.0), Vector2(x, TILE),
			major if fmod(x, MAJOR) < 0.5 else minor, 1.0)
		x += MINOR
	var y := 0.0
	while y < TILE - 0.25:
		draw_line(Vector2(0.0, y), Vector2(TILE, y),
			major if fmod(y, MAJOR) < 0.5 else minor, 1.0)
		y += MINOR
