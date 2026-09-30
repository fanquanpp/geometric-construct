extends Node2D

# 回归门禁:过关切关的演出转场必须每次都真播放(v0.54.1 修复项)。
# 病史:shot_harness.boot 曾在无参启动(正常游玩)也强制 reduced_motion,
# 过关切关退化 1 帧硬切=白屏过渡。本门禁以减动效关闭为前提,连闯三腿:
# A=首关通关自动切下关;B=下关再通关;C=回菜单重进再通关。
# 断言:每次过关后 SWEEP 必须起飞(fx busy 且活动式=SWEEP)并完整收束。

const PROBE_IDX := 2

var main: Main
var _fails := 0


func _ready() -> void:
	main = Main.new()
	add_child(main)
	main.debug_solo = true
	await get_tree().process_frame
	# 本门禁前提:演出转场开启(覆盖 dev harness 可能的强制值)。
	SettingsManager.reduced_motion = false

	await _play_and_pass(PROBE_IDX)
	print("REPLAYTRANSITION leg B: 下一关再通关")
	await _play_and_pass(main.game_flow.current)
	print("REPLAYTRANSITION leg C: 回菜单重进再通关")
	main._return_to_menu()
	_wait_state(Main.State.MENU, 8.0, "curtain 回菜单")
	await get_tree().create_timer(0.8).timeout
	await _play_and_pass(PROBE_IDX)

	print("REPLAYTRANSITION ", "ALL PASS" if _fails == 0 else "FAIL(%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _play_and_pass(index: int) -> void:
	main.start_level(index, false)
	await get_tree().create_timer(1.0).timeout
	# 关卡无关:终点门要全员到齐才封印,把每个玩家都送到自己归属的门
	# (单门关与三门并立这类多门关同链路可通)。
	for p in main.players:
		var door: ExitDoor = null
		for n in main._level_root.get_children():
			if n is ExitDoor and n.geo_index == p.index:
				door = n
				break
		if door == null:
			_fail("L%d 缺 %d 号终点门" % [index, p.index])
			get_tree().quit(1)
			return
		p.position = door.position + Vector2(0, 4)
		p.velocity = Vector2.ZERO
	_wait_state(Main.State.TRANSITION, 8.0, "L%d 通关" % index)

	var swept := false
	var waited := 0.0
	var fx: TransitionFX = main._hud._fx
	while waited < 6.0:
		if fx.is_busy() and fx.active_style() == TransitionFX.Style.SWEEP:
			swept = true
			break
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not swept:
		_fail("L%d 通关后 SWEEP 未起飞(reduced_motion=%s)" % [index,
			SettingsManager.reduced_motion])
	var guard := 0
	while fx.is_busy() and guard < 900:
		await get_tree().process_frame
		guard += 1
	if fx.visible:
		_fail("L%d 转场收束后 fx 仍可见" % index)
	_wait_state(Main.State.PLAYING, 8.0, "L%d→%d 切关" % [index, index + 1])
	if main.game_flow.current == index:
		_fail("过关后关卡号未前进(current=%d)" % main.game_flow.current)
	else:
		print("REPLAYTRANSITION L%d pass: sweep PASS → L%d" % [index,
			main.game_flow.current])


func _wait_state(st: Main.State, timeout: float, what: String) -> void:
	var waited := 0.0
	while main._state != st and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if main._state != st:
		_fail("等待 %s 超时(state=%s current=%d)" % [what,
			Main.State.keys()[main._state], main.game_flow.current])
		get_tree().quit(1)


func _fail(msg: String) -> void:
	_fails += 1
	print("REPLAYTRANSITION FAIL: ", msg)
