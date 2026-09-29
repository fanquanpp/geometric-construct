extends Node2D

# 刻度星散布由种子程序生成,数量形态运行时确定(procedural-art)。
# 密度倍率与强调色由 BackdropPreset 下发(第五幕「密刻」即 marks=1.8 + red accent);
# 参数变化才 queue_redraw(重绘纪律)。

var density := 1.0
var accent := Color(0.878, 0.286, 0.184, 1.0)
var _dirty := false


func set_density(m: float) -> void:
	density = m
	_dirty = true


func set_accent(c: Color) -> void:
	accent = c
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20250905
	var n := int(round(90.0 * density))
	for i in n:
		var p := Vector2(rng.randf_range(0.0, 2400.0), rng.randf_range(-600.0, 1800.0))
		var s := rng.randf_range(1.6, 3.4)
		var a := rng.randf_range(0.10, 0.42)
		var c := Color(accent.r, accent.g, accent.b, a * 0.9) if rng.randf() < 0.10 \
			else Color(Palette.I.paper, a)
		if rng.randf() < 0.16:
			draw_line(p + Vector2(-s * 2, 0), p + Vector2(s * 2, 0), c, 1.0)
			draw_line(p + Vector2(0, -s * 2), p + Vector2(0, s * 2), c, 1.0)
		else:
			draw_rect(Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), c)
