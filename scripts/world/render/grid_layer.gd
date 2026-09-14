class_name GridLayer
extends Node2D

## 定位网格:1 格 = 100 px 的世界坐标网格,次格细线、5 格主线、
## 左缘红色刻度块与 HUD 坐标读数(单位:格)一一对齐。
## 三级 LOD(levels.md §8):按视口内"每格像素数"自适应 ——
## 近景 = 1 格细线 + 5 格主线;中景 = 仅 5 格主线;远景 = 10 格点阵 + 缘坐标数字。

var level_size := Vector2.ZERO
var zones: Array = []   # 命名分区 [{rect, name}](levels.md §8.2)
var _tier := 0    # 0 近景 / 1 中景 / 2 远景

func _ready() -> void:
	z_index = 0

func _process(_delta: float) -> void:
	var tier := _current_tier()
	if tier != _tier:
		_tier = tier
		queue_redraw()

func _current_tier() -> int:
	var cam := get_viewport().get_camera_2d()
	var zoom := cam.zoom.x if cam != null else 1.0
	var m = Main.I
	if m != null and m.debug_zoom > 0.0:
		zoom = m.debug_zoom
	var px_per_cell := Geometries.UNIT_PX * zoom
	if px_per_cell >= 56.0:
		return 0
	if px_per_cell >= 26.0:
		return 1
	return 2

func _draw() -> void:
	if level_size == Vector2.ZERO:
		return
	var unit := Geometries.UNIT_PX
	var w := int(level_size.x / unit)
	var h := int(level_size.y / unit)
	if _tier == 2:
		# 远景:10 格点阵(交点微点比线阵远看不糊)
		var dot := 3.0
		for gx in range(0, w + 1, 10):
			for gy in range(0, h + 1, 10):
				draw_rect(Rect2(gx * unit - dot * 0.5, gy * unit - dot * 0.5,
					dot, dot), Color(Palette.I.paper, 0.16))
		_draw_edge_numbers(w, h, 10)
		return
	# 近景 / 中景:主线 5 格;近景再叠 1 格细线
	var minor_a := 0.045 if _tier == 0 else 0.0
	for gx in w + 1:
		var a := 0.085 if gx % 5 == 0 else minor_a
		if a <= 0.0:
			continue
		draw_line(Vector2(gx * unit, 0), Vector2(gx * unit, level_size.y),
			Color(Palette.I.paper, a), 1.0)
	for gy in h + 1:
		var a := 0.085 if gy % 5 == 0 else minor_a
		if a <= 0.0:
			continue
		draw_line(Vector2(0, gy * unit), Vector2(level_size.x, gy * unit),
			Color(Palette.I.paper, a), 1.0)
	# 左缘红色格点刻度(每 1 格,构成主义强调点)
	for gy in h + 1:
		draw_rect(Rect2(-6, gy * unit - 1.5, 12, 3), Color(Palette.I.red, 0.5))
	# 原点十字
	draw_line(Vector2(0, 0), Vector2(26, 0), Color(Palette.I.red, 0.55), 2.0)
	draw_line(Vector2(0, 0), Vector2(0, 26), Color(Palette.I.red, 0.55), 2.0)
	# —— 分区坐标系(§8.2):边界竖线 + 分区名(近景 LOD 显示)——
	if _tier == 0:
		for z in zones:
			var zr: Rect2 = z["rect"]
			draw_line(Vector2(zr.position.x, 0),
				Vector2(zr.position.x, level_size.y), Color(Palette.I.paper, 0.13), 1.0)
			if Ui.HEAD != null:
				draw_string(Ui.HEAD, zr.position + Vector2(10, 30),
					str(z["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
					Color(Palette.I.paper, 0.30))

## 上 / 左双缘坐标数字(levels.md §8.2;游戏内仅远景边缘显示)。
func _draw_edge_numbers(w: int, h: int, step: int) -> void:
	if Ui.HEAD == null:
		return
	var unit := Geometries.UNIT_PX
	for gx in range(0, w + 1, step):
		var s := str(gx)
		draw_string(Ui.HEAD, Vector2(gx * unit + 4, 14), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Palette.I.red, 0.7))
	for gy in range(step, h + 1, step):
		draw_string(Ui.HEAD, Vector2(4, gy * unit - 4), str(gy),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Palette.I.red, 0.7))
