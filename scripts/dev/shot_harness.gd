extends RefCounted


var m: Main


var _auto_shot := false
var _shot_level := 0
var _shot_dir := ""
var _door_shot := false
var _recall_shot := false
var _transition_shot := false
var _dual_test := false
var _dual_shot := false
var _room_shot := false
var _net_test := false
var _net_auto := false
var _net_join := false
var _net_join_ip := ""
var _panel_shot := false
var _set_shot := false
var _act_shot := false
var _act_shot_idx := 0
var _boot_shot := false
var _intro_shot := false
var _tour_shot := false
var _tap_shot := false
var _perf_log := false
var _auto_test := false


func boot(args: Array) -> void:
	if not args.is_empty():
		m.dev_run = true
	for raw: String in args:
		if raw.begins_with("--autoshot="):
			_auto_shot = true
			_shot_level = raw.substr(11).to_int()
		elif raw.begins_with("--shotdir="):
			_shot_dir = raw.substr(10)
		elif raw.begins_with("--autotest="):
			_auto_test = true
			m._auto_test = true
			_shot_level = raw.substr(11).to_int()
		elif raw == "--menushot":
			_auto_shot = true
		elif raw == "--doorshot":
			_door_shot = true
		elif raw == "--recalltest":
			_recall_shot = true
		elif raw == "--transitionshot":
			_transition_shot = true
		elif raw == "--dualtest":
			_dual_test = true
		elif raw == "--dualshot":
			_dual_shot = true
		elif raw == "--roomshot":
			_room_shot = true
		elif raw == "--nettest":
			_net_test = true
		elif raw == "--netauto":
			_net_test = true
			_net_auto = true
		elif raw.begins_with("--netjoin"):
			_net_test = true
			_net_join = true
			_net_join_ip = raw.substr(10) if raw.contains("=") else ""
		elif raw == "--panelshot":
			_panel_shot = true
		elif raw == "--setshot":
			_set_shot = true
		elif raw.begins_with("--actshot"):
			_act_shot = true
			if raw.contains("="):
				_act_shot_idx = raw.substr(9).to_int()
		elif raw == "--bootshot":
			_boot_shot = true
		elif raw == "--introshot":
			_intro_shot = true
		elif raw == "--tourshot":
			_tour_shot = true
		elif raw == "--tapshot":
			_tap_shot = true
		elif raw == "--perflog":
			_perf_log = true
		elif raw.begins_with("--level="):
			_shot_level = raw.substr(8).to_int()
	if _auto_shot and _shot_dir.is_empty():
		_shot_dir = "res://.shots"

	# 承重约束:无参启动=正常游玩,不得改任何设置;钩子(带参)统一减动效
	# 硬切防后台/遮挡窗口 Tween 冻结卡分镜,--transitionshot 例外照常播。
	if not args.is_empty() and not _transition_shot:
		SettingsManager.reduced_motion = true
	if _auto_shot and args.has("--menushot"):
		run_menu_shot()

	if _auto_shot and not args.has("--menushot") \
			and not _intro_shot:
		run_auto_shot()
	if _door_shot:
		run_door_shot()
	if _recall_shot:
		run_recall_test()
	if _transition_shot:
		run_transition_shot()
	if _tap_shot:
		run_tap_shot()
	if _dual_test:
		run_dual_test()
	if _dual_shot:
		run_dual_shot()
	if _room_shot:
		run_room_shot()
	if _net_test:
		if _net_auto:
			run_net_auto()
		elif _net_join:
			run_net_join(_net_join_ip)
		else:
			m.net_session.run_self_test()
	if _panel_shot:
		run_panel_shot()
	if _set_shot:
		run_set_shot()
	if _act_shot:
		run_actshot()
	if _boot_shot:
		run_boot_shot()
	if _intro_shot:
		run_intro_shot()
	if _tour_shot:
		run_tour_shot()
	if _perf_log:
		run_perf_log()
	elif not args.is_empty() and OS.is_debug_build() \
			and OS.has_feature("mobile"):

		run_perf_log()
	if _auto_test:
		run_auto_test()


func run_perf_log() -> void:
	while m != null and m.is_inside_tree():
		await m.get_tree().create_timer(1.0).timeout
		print("PERF fps=%d process=%.2fms draw=%d prim=%d obj=%d mem=%.1fMB" % [
			int(Performance.get_monitor(Performance.TIME_FPS)),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		])


func run_set_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	await m.get_tree().create_timer(0.6).timeout
	m.settings_panel.open()
	await m.get_tree().create_timer(0.5).timeout
	await _shot("settings")
	m.get_tree().quit()


func run_actshot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	await m.get_tree().create_timer(0.6).timeout
	m._menu.try_open_act(_act_shot_idx)
	await m.get_tree().create_timer(0.6).timeout
	await _shot("act_panel")
	m.get_tree().quit()


func run_boot_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	await m.get_tree().create_timer(1.35).timeout
	await _shot("boot")
	await m.get_tree().create_timer(1.8).timeout
	await _shot("boot_end")
	m.get_tree().quit()


func run_intro_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	m.start_level(_shot_level, true)
	await m.get_tree().create_timer(1.2).timeout
	await _shot("intro")
	m.get_tree().quit()


func run_tour_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	m._unlocked = LevelData.count() - 1
	m.start_level(_shot_level, false)
	await m.get_tree().create_timer(0.4).timeout
	var wps: Array = []
	var root: Node = m._level_root
	for idx: int in m.game_flow.level_info["roster"]:
		var mk := root.get_node_or_null(NodePath("Spawn%d" % idx)) as Marker2D
		if mk != null:
			wps.append(["spawn%d" % idx, mk.global_position])
			break
	for n in root.get_children():
		if n is CheckpointBeacon:
			wps.append(["cp%d" % n.beacon_id, n.position])
	for n in root.get_children():
		if n is ExitDoor:
			wps.append(["door%d" % n.geo_index, n.position + Vector2(0, -160)])
	for wp: Array in wps:
		if m.players.is_empty():
			break
		var p: Player = m.players[m.view_slot()]
		p.position = wp[1]
		p.velocity = Vector2.ZERO
		await m.get_tree().create_timer(0.55).timeout
		await _shot("tour_" + str(wp[0]))
	m.get_tree().quit()


func run_panel_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	await m.get_tree().create_timer(0.6).timeout
	m.archive_panel.open(0)
	await m.get_tree().create_timer(0.5).timeout
	await _shot("panel_geo0")
	for page in range(1, Geometries.ALL.size()):
		m.archive_panel._switch(1)
		await m.get_tree().create_timer(0.4).timeout
		await _shot("panel_geo%d" % page)

	# 键位指南已独立为 ControlsPanel(v0.56.1),直开直关
	m.controls_panel.open()
	await m.get_tree().create_timer(0.4).timeout
	await _shot("panel_keys")
	m.controls_panel.close()

	m.archive_panel.open(0, "bld")
	await m.get_tree().create_timer(0.5).timeout
	await _shot("panel_bld0")
	m.archive_panel._sel["bld"] = 6
	m.archive_panel.builders["bld"].refresh()
	await m.get_tree().create_timer(0.4).timeout
	await _shot("panel_bld_beam")
	m.archive_panel.open(0, "mech")
	await m.get_tree().create_timer(0.5).timeout
	await _shot("panel_mech0")
	var refs: Dictionary = m.archive_panel._pages["mech"].get_meta("refs")
	(refs["toggle"] as Button).button_pressed = true
	m.archive_panel.builders["mech"].refresh()
	await m.get_tree().create_timer(0.4).timeout
	await _shot("panel_mech_f2")
	m.archive_panel._sel["mech"] = ArchiveData.MECHS.size() - 1
	m.archive_panel.builders["mech"].refresh()
	await m.get_tree().create_timer(1.2).timeout
	await _shot("panel_mech_portal")

	m.get_tree().quit()


func run_transition_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = ".shots_v37"
	var fxd: TransitionFX = m._hud._fx
	for style_name in ["sweep", "blocks", "corners", "curtain"]:
		var style := TransitionFX.Style.SWEEP
		match style_name:
			"blocks":
				style = TransitionFX.Style.BLOCKS_RED
			"corners":
				style = TransitionFX.Style.CORNERS
			"curtain":
				style = TransitionFX.Style.CURTAIN
		fxd.transition(style, 0.3, func() -> void: pass)
		await m.get_tree().create_timer(0.26).timeout
		await _shot("transition_%s_cover" % style_name)
		await m.get_tree().create_timer(0.12).timeout
		await _shot("transition_%s_reveal" % style_name)
		var guard := 0
		while fxd.is_busy() and guard < 300:
			await m.get_tree().process_frame
			guard += 1
	m.get_tree().quit()


func run_recall_test() -> void:
	if _shot_dir.is_empty():
		_shot_dir = ".shots_v17"
	m.start_level(0, false)
	await m.get_tree().create_timer(0.5).timeout
	var fails := 0

	var p: Player = m.players[m.view_slot()]
	p.position = p.spawn_pos + Vector2(600, -300)
	await _recall_keypress()
	var ok: bool = p.position.distance_to(p.spawn_pos) < 2.0 and not p.dying
	print("RECALLTEST 疾 ", "PASS" if ok else "FAIL",
		" pos=", p.position, " spawn=", p.spawn_pos)
	if not ok:
		fails += 1

	var cpr: Player = m.players[m.view_slot()]
	var beacon: CheckpointBeacon = null
	for n in m._level_root.get_children():
		if n is CheckpointBeacon:
			beacon = n
			break
	if beacon == null:
		print("RECALLTEST 信标 FAIL: s01 缺信标摆位")
		m.get_tree().quit(1)
		return
	var bpos: Vector2 = beacon.position
	cpr.position = bpos
	print("DBG recall: bpos=", bpos, " cpr=", cpr.position)
	await m.get_tree().physics_frame
	await m.get_tree().physics_frame
	await m.get_tree().physics_frame
	var ok_cp: bool = m.roster.checkpoints.has(cpr.index)
	await _recall_keypress()
	ok_cp = ok_cp and cpr.position.distance_to(bpos) < 2.0 and not cpr.dying
	print("RECALLTEST 信标 ", "PASS" if ok_cp else "FAIL",
		" pos=", cpr.position, " beacon=", bpos)
	if not ok_cp:
		fails += 1

	# 记录点召回后再次召回仍回信标(幂等)
	await _recall_keypress()
	var ok_again: bool = cpr.position.distance_to(bpos) < 2.0 and not cpr.dying
	print("RECALLTEST 信标幂等 ", "PASS" if ok_again else "FAIL")
	if not ok_again:
		fails += 1
	m.get_tree().quit(0 if fails == 0 else 1)


func _recall_keypress() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	ev.pressed = true
	Input.parse_input_event(ev)
	await m.get_tree().physics_frame
	await m.get_tree().physics_frame
	var up := InputEventKey.new()
	up.physical_keycode = KEY_R
	up.pressed = false
	Input.parse_input_event(up)
	await m.get_tree().physics_frame


func run_dual_test() -> void:
	m.start_level_dual(18)
	await m.get_tree().create_timer(0.5).timeout
	var ok_cd: bool = m.race.phase == RaceController.Phase.COUNTDOWN
	print("DUALTEST countdown-phase ", "PASS" if ok_cd else "FAIL",
		" phase=", m.race.phase)
	await m.get_tree().create_timer(3.0).timeout
	var fails: int = 0 if ok_cd else 1
	var p1: Player = m.players[0]
	var p2: Player = m.players[1]

	var ok_bind: bool = m.dual_mode and p1.is_active and p2.is_active \
		and p1.input_source.slot == 0 and p2.input_source.slot == 1
	print("DUALTEST bind ", "PASS" if ok_bind else "FAIL",
		" dual=", m.dual_mode, " p1=", p1.is_active, " p2=", p2.is_active)
	if not ok_bind:
		fails += 1

	var x1 := p1.position.x
	var x2 := p2.position.x
	Input.action_press("p1_move_right")
	Input.action_press("p2_move_left")
	await m.get_tree().create_timer(0.6).timeout
	Input.action_release("p1_move_right")
	Input.action_release("p2_move_left")
	var ok_input: bool = p1.position.x > x1 + 8.0 and p2.position.x < x2 - 8.0
	print("DUALTEST input ", "PASS" if ok_input else "FAIL",
		" p1_dx=%.1f p2_dx=%.1f" % [p1.position.x - x1, p2.position.x - x2])
	if not ok_input:
		fails += 1

	m.switch_to_geo(2)
	await m.get_tree().physics_frame
	var ok_noswitch: bool = m.players.size() == 2 \
		and p1.is_active and p2.is_active
	print("DUALTEST noswitch ", "PASS" if ok_noswitch else "FAIL")
	if not ok_noswitch:
		fails += 1

	p2.position = Vector2(p2.position.x, 1550.0)
	await m.get_tree().create_timer(1.2).timeout
	var ok_death: bool = not p2.dying and p2.is_active \
		and p2.position.distance_to(p2.spawn_pos) < 32.0
	print("DUALTEST death ", "PASS" if ok_death else "FAIL",
		" pos=", p2.position, " spawn=", p2.spawn_pos)
	if not ok_death:
		fails += 1

	var d0: ExitDoor = m._doors[p1.index][0]
	var d1: ExitDoor = m._doors[p2.index][0]
	p1.position = d0.position
	p2.position = d1.position
	await m.get_tree().create_timer(0.6).timeout

	var ok_win: bool = m.race.phase == RaceController.Phase.FINISHED
	var wins_ok: bool = int(m.race.wins.get(m.race.winner, 0)) == 1
	var locked: bool = m.race_input_locked()
	var hud_ok: bool = m._hud._race_panel.visible 		and m._hud._race_root.visible
	var ok_arrive: bool = ok_win and wins_ok and locked and hud_ok
	print("DUALTEST race ", "PASS" if ok_arrive else "FAIL",
		" winner=", m.race.winner, " wins=", m.race.wins,
		" locked=", locked, " hud=", hud_ok)
	if not ok_arrive:
		fails += 1

	var wslot: int = m.race.winner
	m.race.rematch()
	await m.get_tree().create_timer(0.5).timeout
	var ok_rematch: bool = m.race.phase == RaceController.Phase.COUNTDOWN 		and m.game_flow.current == 18 		and int(m.race.wins.get(wslot, 0)) == 1
	print("DUALTEST rematch ", "PASS" if ok_rematch else "FAIL",
		" phase=", m.race.phase, " wins=", m.race.wins)
	if not ok_rematch:
		fails += 1

	print("DUALTEST ALL ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	m.get_tree().quit(0 if fails == 0 else 1)


func run_dual_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	m.start_level_dual(18)
	await m.get_tree().create_timer(1.2).timeout
	await _shot("dual_spawn")

	Input.action_press("p1_move_right")
	Input.action_press("p2_move_left")
	await m.get_tree().create_timer(0.8).timeout
	Input.action_release("p1_move_right")
	Input.action_release("p2_move_left")
	await m.get_tree().create_timer(0.4).timeout
	await _shot("dual_spread")
	m.get_tree().quit()


func run_net_join(ip := "") -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._state = Main.State.ROOM
	m._menu.visible = false
	m.net_room_layer.open()
	m.net_room_layer.autostart_join()
	if not ip.is_empty():
		print("NETJOIN: direct connect ", ip)
		NetSession.I.join_room(ip)
	else:
		print("NETJOIN: discovering...")
	for i in 240:
		await m.get_tree().create_timer(0.5).timeout
		if NetSession.I != null and NetSession.I.in_game():
			print("NETJOIN: in game, done")
			return
		if not ip.is_empty() and NetSession.I != null and NetSession.I.mode == NetSession.Mode.LOBBY:
			print("NETJOIN: connected to host, waiting for start")
			ip = ""
	print("NETJOIN: timeout")
	m.get_tree().quit(1)


func run_room_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	await m.get_tree().create_timer(0.6).timeout
	m._menu._open_dual_pick()
	await m.get_tree().create_timer(0.6).timeout
	await _shot("room_pick")
	m._menu.close_dual_pick()
	m._state = Main.State.ROOM
	m._menu.visible = false
	m.net_room_layer.open()
	await m.get_tree().create_timer(0.5).timeout
	await _shot("room_mode")
	m.net_room_layer.autostart_host()
	await m.get_tree().create_timer(0.5).timeout
	await _shot("room_host")

	m.net_room_layer._show_map()
	await m.get_tree().create_timer(0.4).timeout
	await _shot("room_map")
	NetSession.I.host_pick_level(0)
	await m.get_tree().create_timer(0.4).timeout
	NetSession.I.host_toggle_claim(0, true)
	NetSession.I.host_toggle_claim(1, true)
	await m.get_tree().create_timer(0.4).timeout
	await _shot("room_role")
	m.net_room_layer.beacon_stop_only()
	m._state = Main.State.ROOM
	m.net_room_layer.open()
	m.net_room_layer.autostart_join()
	await m.get_tree().create_timer(1.2).timeout
	await _shot("room_join")
	m.net_room_layer.close_to_menu()
	m.get_tree().quit()


func run_net_auto() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._state = Main.State.ROOM
	m._menu.visible = false
	m.net_room_layer.open()
	m.net_room_layer.autostart_host()

	for i in 240:
		await m.get_tree().create_timer(0.5).timeout
		if NetSession.I != null and NetSession.I.in_game():
			print("NETAUTO: in game, done")
			return
		if NetSession.I != null and NetSession.I.is_host() \
				and NetSession.I.member_count() >= NetConfig.MAX_PLAYERS \
				and m.net_room_layer.visible:
			m.net_room_layer.visible = false
			NetSession.I.host_start_level(0)
	print("NETAUTO: timeout waiting for peer")
	m.get_tree().quit(1)


func run_door_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	m.start_level(0, false)
	await m.get_tree().create_timer(0.3).timeout
	m.players[0].position = Vector2(14450, 1700)
	m.players[0].velocity = Vector2.ZERO
	await m.get_tree().create_timer(0.25).timeout
	await _shot("door")
	await m.get_tree().create_timer(1.1).timeout
	await _shot("complete")
	m.get_tree().quit()


func run_tap_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	m.start_level(0, false)
	await m.get_tree().create_timer(0.5).timeout
	var pts := [Vector2(1180, 560), Vector2(1420, 720), Vector2(980, 430)]
	for k in pts.size():
		m.touch_controls.tap_burst_at(pts[k])
		await m.get_tree().create_timer(0.09).timeout
	await _shot("tapfx")
	await m.get_tree().create_timer(0.6).timeout
	m.touch_controls.tap_burst_at(Vector2(1300, 640))
	await m.get_tree().create_timer(0.05).timeout
	await _shot("tapfx_late")
	m.get_tree().quit()


func run_menu_shot() -> void:
	await m.get_tree().create_timer(1.0).timeout
	await m.get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var img := m.get_viewport().get_texture().get_image()
	var path := _shot_dir.path_join("menu.png")
	img.save_png(path)
	print("SHOT_SAVED: ", ProjectSettings.globalize_path(path))
	m.get_tree().quit()


func run_auto_test() -> void:
	m._unlocked = LevelData.count() - 1
	print("TEST: begin level ", _shot_level)
	m.start_level(_shot_level, false)
	m.debug_move = Vector2(1, 0)
	var deadline := Time.get_ticks_msec() + 60000
	var tick := 0
	while Time.get_ticks_msec() < deadline and m._state != Main.State.WIN:
		m.debug_jump = true
		await m.get_tree().create_timer(0.25).timeout
		m.debug_jump = false
		await m.get_tree().create_timer(0.55).timeout
		tick += 1
		if tick % 3 == 0 and m.players.size() > 0:
			print("TEST: pos=", m.players[m.view_slot()].position,
				" onFloor=", m.players[m.view_slot()].is_on_floor())
	print("TEST: end state=", Main.State.keys()[m._state])
	m.get_tree().quit()


func run_auto_shot() -> void:
	m._unlocked = LevelData.count() - 1
	m.start_level(_shot_level, false)
	await m.get_tree().create_timer(1.0).timeout
	await _shot("a")

	m.debug_move = Vector2(1, 0)
	await m.get_tree().create_timer(5.0).timeout
	m.debug_move = Vector2.ZERO
	m.debug_jump = true
	await m.get_tree().create_timer(0.16).timeout
	m.debug_jump = false
	await m.get_tree().create_timer(0.3).timeout
	m.debug_jump = true
	await m.get_tree().create_timer(0.16).timeout
	m.debug_jump = false
	await m.get_tree().create_timer(1.1).timeout
	await _shot("b")
	m.get_tree().quit()


func _shot(tag: String) -> void:
	await m.get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var img := m.get_viewport().get_texture().get_image()
	var path := _shot_dir.path_join("L%d_%s.png" % [_shot_level, tag])
	img.save_png(path)
	print("SHOT_SAVED: ", ProjectSettings.globalize_path(path))
