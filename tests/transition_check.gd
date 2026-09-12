extends SceneTree
## transition_check.gd — 构成主义转场层断言(v0.37,motion.md §2.3 实装)。
## 用法:--headless --path . --script res://tests/transition_check.gd
## 断言:四式转场 on_covered 恰好触发一次且收尾归零;同屏单飞(在飞拒绝);
## 减动效 = 硬切(立即回调、零演出);两枚白名单 shader 可加载可实例化。

const TransitionLayer := preload("res://scripts/fx/transition_fx.gd")

var _fails := 0


func _init() -> void:
	_run()


func _run() -> void:
	var fx: CanvasLayer = TransitionLayer.new()
	root.add_child(fx)
	await process_frame

	# ① 四式:covered 恰好一次,结束后隐藏且不忙
	for style in [TransitionFX.Style.FADE, TransitionFX.Style.SWEEP,
			TransitionFX.Style.BLOCKS_RED, TransitionFX.Style.CORNERS]:
		var hits := [0]
		var ok: bool = fx.transition(style, 0.05, func() -> void:
			hits[0] += 1)
		if not ok:
			_fail("%d transition 被拒(初始即忙?)" % style)
			continue
		# 轮询至收尾(上限 5s)
		var guard := 0
		while fx.is_busy() and guard < 600:
			await process_frame
			guard += 1
		if hits[0] != 1:
			_fail("式 %d covered 次数 = %d(期望 1)" % [style, hits[0]])
		elif fx.visible:
			_fail("式 %d 收尾后仍可见" % style)
		else:
			print("TRANSITION style %d PASS" % style)

	# ② 同屏单飞:在飞期间第二次 transition 必须被拒
	var calls := [0]
	fx.transition(TransitionFX.Style.FADE, 0.3, func() -> void: calls[0] += 1)
	var rejected: bool = not fx.transition(TransitionFX.Style.SWEEP, 0.1,
		func() -> void: pass)
	if not rejected:
		_fail("同屏单飞:在飞期间第二转场未被拒")
		await _drain(fx)
	else:
		print("TRANSITION single-flight PASS")
		await _drain(fx)

	# ③ 减动效:硬切——立即回调,零演出(帧间即收尾)
	SettingsManager.reduced_motion = true
	var cut := [0]
	var t0 := Time.get_ticks_msec()
	fx.transition(TransitionFX.Style.SWEEP, 0.5, func() -> void: cut[0] += 1)
	var instant: bool = not fx.is_busy() and cut[0] == 1 \
		and Time.get_ticks_msec() - t0 < 50
	SettingsManager.reduced_motion = false
	if instant:
		print("TRANSITION reduced-motion PASS")
	else:
		_fail("减动效未退化为硬切")
	await _drain(fx)

	# ④ 白名单 shader 可加载(Material 实例化 + 参数写入)
	for path in ["res://assets/fx/sweep_diagonal.gdshader",
			"res://assets/fx/block_dissolve.gdshader"]:
		var sh: Shader = load(path)
		if sh == null or sh.get_rid().is_valid() == false:
			_fail("shader 加载失败:%s" % path)
		else:
			var mat := ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("progress", 0.5)
			print("SHADER %s PASS" % path.get_file())

	print("TRANSITIONCHECK ", "ALL PASS" if _fails == 0 else "FAIL(%d)" % _fails)
	quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("TRANSITION FAIL: ", msg)


func _drain(fx: CanvasLayer) -> void:
	var guard := 0
	while fx.is_busy() and guard < 600:
		await process_frame
		guard += 1
