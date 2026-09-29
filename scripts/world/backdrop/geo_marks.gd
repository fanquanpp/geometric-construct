extends Node2D

# 刻度星散布由种子程序生成,数量形态运行时确定(procedural-art)。

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20250905
	for i in 90:
		var p := Vector2(rng.randf_range(0.0, 2400.0), rng.randf_range(-600.0, 1800.0))
		var s := rng.randf_range(1.6, 3.4)
		var a := rng.randf_range(0.10, 0.42)
		var c := Color(Palette.I.red, a * 0.9) if rng.randf() < 0.10 \
			else Color(Palette.I.paper, a)
		if rng.randf() < 0.16:
			draw_line(p + Vector2(-s * 2, 0), p + Vector2(s * 2, 0), c, 1.0)
			draw_line(p + Vector2(0, -s * 2), p + Vector2(0, s * 2), c, 1.0)
		else:
			draw_rect(Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), c)
