extends SceneTree


func _init() -> void:
	var fails := 0
	var chunks := 48
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
