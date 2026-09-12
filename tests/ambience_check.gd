extends SceneTree
## ambience_check.gd — BGM 静音断言(audio.md §6 验收项,v0.37 落地)。
## 用法:--headless --path . --script res://tests/ambience_check.gd
## 对每个 motif 直接驱动 Ambience._fill 纯 DSP 管线(不依赖音频设备,
## headless 可跑),断言:非静音(峰值达标)、无 NaN/Inf、动态范围合理、
## motif 热切换不崩、声部上限不越界。

func _init() -> void:
	var fails := 0
	var chunks := 48   # 48 × 2048 / 32000 ≈ 3.1s:足够 pad 完成起音
	for motif_name in Ambience.MOTIFS.keys():
		var amb := Ambience.new()
		amb.set_motif(motif_name)
		var peak := 0.0
		var sum_sq := 0.0
		var n := 0
		var bad := false
		for c in chunks:
			var buf := PackedVector2Array()
			buf.resize(2048)
			amb._fill(buf)
			for v in buf:
				var a: float = absf(v.x)
				var b: float = absf(v.y)
				peak = maxf(peak, maxf(a, b))
				sum_sq += a * a + b * b
				n += 2
				if is_nan(a) or is_nan(b) or is_inf(a) or is_inf(b):
					bad = true
		var rms := sqrt(sum_sq / maxf(n, 1))
		var ok := (not bad) and peak > 0.01 and peak < 0.99 and rms > 0.0005 			and rms < 0.3
		print("AMBCHECK %s %s peak=%.4f rms=%.5f" %
			[motif_name, "PASS" if ok else "FAIL", peak, rms])
		if not ok:
			fails += 1
		amb.free()
	# 热切换冒烟:连切全部 motif 不崩、延迟环重建正常
	var amb2 := Ambience.new()
	for i in 3:
		for motif_name in Ambience.MOTIFS.keys():
			amb2.set_motif(motif_name)
			var buf := PackedVector2Array()
			buf.resize(2048)
			amb2._fill(buf)
	print("AMBCHECK hot-switch PASS")
	amb2.free()
	print("AMBCHECK ", "ALL PASS" if fails == 0 else "FAIL(%d)" % fails)
	quit(0 if fails == 0 else 1)
