extends Node2D

# 构成巨面由种子程序生成,数量形态运行时确定(procedural-art)。

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 5:
		var x := 200.0 + i * 520.0 + rng.randf_range(-90.0, 90.0)
		var top := rng.randf_range(240.0, 620.0)
		var w1 := rng.randf_range(260.0, 520.0)
		var w2 := w1 * rng.randf_range(0.3, 0.7)
		var col := Color(Palette.I.paper, rng.randf_range(0.018, 0.032))
		if i % 2 == 0:
			var tri := PackedVector2Array([
				Vector2(x, top), Vector2(x + w1, top + rng.randf_range(-60, 60)),
				Vector2(x + w2, top + 900.0),
			])
			draw_colored_polygon(tri, col)
		else:
			var quad := PackedVector2Array([
				Vector2(x, top), Vector2(x + w1, top),
				Vector2(x + w1 * 0.8, top + 900.0), Vector2(x + w1 * 0.2, top + 900.0),
			])
			draw_colored_polygon(quad, col)
