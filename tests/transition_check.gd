extends SceneTree


const TransitionLayer := preload("res://scripts/fx/transition_fx.gd")

var _fails := 0


func _init() -> void:
	_run()


func _run() -> void:
	var fx: CanvasLayer = TransitionLayer.new()
	root.add_child(fx)
	await process_frame

	for style in [TransitionFX.Style.FADE, TransitionFX.Style.SWEEP,
			TransitionFX.Style.BLOCKS_RED, TransitionFX.Style.CORNERS,
			TransitionFX.Style.CURTAIN]:
		var hits := [0]
		var ok: bool = fx.transition(style, 0.05, func() -> void:
			hits[0] += 1)
		if not ok:
			_fail("%d transition 被拒(初始即忙?)" % style)
			continue

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

	# v0.55.0 白屏根治:转场不再依赖自定义 shader(安卓 Vulkan 上 shader
	# 首用编译卡顿/失败会让白底 ColorRect 裸奔成全屏白)。断言旧 shader
	# 已清退、veil 为纯色引擎绘制(无材质),SWEEP 相位真实推进满覆。
	for path in ["res://assets/fx/sweep_diagonal.gdshader",
			"res://assets/fx/block_dissolve.gdshader"]:
		if ResourceLoader.exists(path):
			_fail("转场 shader 未清退:%s" % path)
		else:
			print("TRANSITION shader-cleared %s PASS" % path.get_file())
	if fx._veil.material != null:
		_fail("veil 仍挂 ShaderMaterial(应为纯色引擎绘制)")
	else:
		print("TRANSITION veil-material-free PASS")

	var peak := [0.0]
	var layer_seen := [false]
	fx.transition(TransitionFX.Style.SWEEP, 0.15, func() -> void: pass)
	var guard2 := 0
	while fx.is_busy() and guard2 < 600:
		peak[0] = maxf(peak[0], fx._sweep.phase)
		if fx.visible:
			layer_seen[0] = true
		await process_frame
		guard2 += 1
	# v0.55.2:层体 visible 必须在飞(此前重写丢 visible=true,扫掠全盲)
	if not layer_seen[0]:
		_fail("SWEEP 飞行期间层体不可见(白屏/硬切根因回归)")
	else:
		print("TRANSITION sweep-layer-visible PASS")
	if peak[0] >= 1.0 and not fx.visible:
		print("TRANSITION sweep-phase PASS (max=%.2f)" % peak[0])
	else:
		_fail("SWEEP 相位未满覆(%.2f)或收尾未隐藏" % peak[0])

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
