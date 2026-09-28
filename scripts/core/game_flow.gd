class_name GameFlow
extends Node


var main: Main
var current := -1
var level_info: Dictionary = {}
var complete_seq := 0
var run_ms := 0
var run_deaths := 0


func _physics_process(delta: float) -> void:
	if main != null and main._state == Main.State.PLAYING:
		run_ms += int(delta * 1000.0)


func note_death() -> void:
	run_deaths += 1


func start_level(index: int, intro := true) -> void:
	if main.debug_solo:
		print("TRACE start_level(", index, ") state_was=", Main.State.keys()[main._state])
	complete_seq += 1
	main.dual_mode = false
	main.get_tree().paused = false
	if main._pause != null:
		main._pause.close()
	current = clampi(index, 0, LevelData.count() - 1)
	run_ms = 0
	run_deaths = 0
	clear_level()
	main._doors.clear()
	main._checkpoints.clear()
	var scene: PackedScene = load(LevelData.scene_path(current))
	var root: NativeLevel = scene.instantiate()
	main._level_root = root
	main.add_child(root)

	level_info = {"name": root.level_name, "intro": root.intro_text,
		"focus": root.focus, "roster": root.roster,
		"kill_y": root.kill_y, "top_kill_y": root.top_kill_y}
	collect_players()
	main._state = Main.State.PLAYING
	Sfx.play("start")

	var act_i := LevelData.act_index_of(current)
	main._ambience_motif("act%d" % clampi(act_i + 1, 1, LevelData.ACTS.size()))

	main._menu.visible = false
	main._menu.close_act_panel()
	main.archive_panel.close()
	main.settings_panel.close()
	main._hud.visible = true
	main.touch_controls.set_in_game(true)

	main.touch_controls.set_switch_available(
		Geometries.roster_body_total(level_info.roster) > 1)
	main._hud.show_win(false)
	main._hud.set_level_info(current, level_info["name"])
	main._refresh_roster()
	main._hud.reveal_corners()
	if intro:
		var act_name := str(LevelData.ACTS[act_i]["name"]) if act_i >= 0 \
			else "正戏"
		main._hud.show_intro("%s · 第 %d 场 · %s" % [act_name, LevelData.scene_no_of(current),
			Geometries.get_def(level_info["focus"]).full_name], level_info)
		var focus: GeometryDef = Geometries.get_def(level_info["focus"])
		main._hud.narration(focus.quote, focus.color, 3.8)
	main._switch_to(0, true)

	if NetSession.I != null and NetSession.I.is_net():
		main.net_room_layer.visible = false
		NetSession.I.on_level_built()

	if act_i >= 0 and current == LevelData.first_level_of_act(act_i) \
			and intro:
		var kind := "act%d" % (act_i + 1)
		if not main._save.story_seen(kind):
			main._save.note_story(kind)
			main.get_tree().paused = true
			main.show_story(kind)


func collect_players() -> void:
	main.roster.collect_players(main._level_root)


func clear_level() -> void:
	main.players.clear()
	main.camera_rig = null
	main._doors.clear()
	if main._level_root != null:
		# 必须 free() 而非 queue_free:延迟释放窗口里旧根仍挂着
		# character_created,新关建体会被同帧抢挂,下一关无法诞生。
		main._level_root.free()
		main._level_root = null


func return_to_menu() -> void:
	if main._hud == null or main._hud.transition_curtain(0.4, func() -> void: show_menu()):
		return
	show_menu()


func show_menu() -> void:
	main._state = Main.State.MENU
	main.dual_mode = false
	main._ambience_motif("prologue")
	clear_level()
	main._hud.visible = false
	main.touch_controls.set_in_game(false)
	main.archive_panel.close()
	main.settings_panel.close()
	main._menu.visible = true
	main._menu.set_unlocked(main._unlocked)


func restart_level() -> void:
	if main._state != Main.State.PLAYING:
		return
	Sfx.play("restart")
	main._hud.fade_to_black(0.25, func() -> void: start_level(current))
	main._state = Main.State.TRANSITION


func check_complete() -> void:
	for p in main.players:
		if not p.in_exit:
			return

	main._state = Main.State.TRANSITION
	Sfx.play("complete")
	if main._auto_test:
		print("TEST: LEVEL COMPLETE ", current)
	var done_text := "通过。"
	if run_deaths == 0:
		done_text = "完美归位。"
	elif current == LevelData.campaign_last():
		done_text = "归位。"
	main._hud.show_complete(done_text)

	if NetSession.I != null and NetSession.I.is_net():
		if NetSession.I.is_host():
			NetSession.I.emit_event(NetSession.EV_COMPLETE)
		complete_seq += 1
		var seq_n := complete_seq
		main.get_tree().create_timer(2.1).timeout.connect(func() -> void:
			if seq_n == complete_seq:
				main.net_back_to_room())
		return
	if not main._auto_test and not main.debug_solo and not main.dev_run:
		if current + 1 > main._unlocked:
			main._unlocked = mini(current + 1, LevelData.campaign_last())
			main._save.unlocked = main._unlocked
		main._save.add_play_ms(run_ms)
		var record := main._save.mark_level_result(current, run_ms, run_deaths)
		main._menu.set_unlocked(main._unlocked)
		var medal := LevelData.medal_of(current, run_ms)
		if record and run_ms > 0:
			main._hud.narration("新纪录 · %s" % main._save.time_text(run_ms),
				Palette.I.paper, 2.6)
		elif medal == 1:
			main._hud.narration("金牌用时 · %s" % main._save.time_text(run_ms),
				Palette.I.yellow, 2.6)

	complete_seq += 1
	var seq := complete_seq
	main.get_tree().create_timer(2.1).timeout.connect(func() -> void:
		if seq == complete_seq:
			after_complete())


func after_complete() -> void:
	if current >= LevelData.campaign_last():
		main._state = Main.State.WIN
		Sfx.play("fanfare")
		main._hud.show_win(true, win_summary())

		if not main.get_tree().paused:
			main.get_tree().paused = true
			main.show_story("epilogue")
	else:
		main._hud.transition_sweep(0.55, func() -> void: start_level(current + 1))


func win_summary() -> String:
	var s := main._save
	return "落幕场最佳 %s · 旅程用时 %s · 摔碎 %d 次 · 完美 %d / %d 场" % [
		s.time_text(s.best_time_of(LevelData.campaign_last())),
		s.long_time_text(s.total_play_ms), s.total_deaths,
		s.perf_count(), LevelData.campaign_last() + 1]


func open_net_room() -> void:
	if main._state != Main.State.MENU:
		return
	main._state = Main.State.ROOM
	main._menu.visible = false
	main.net_room_layer.open()


func net_post_setup() -> void:
	main.touch_controls.set_switch_available(true)
	if NetSession.I.is_host():
		var own: Array = NetSession.I.own_slots_arr()
		if not own.is_empty():
			main.roster.switch_to(own[0], true)
	else:
		main.roster.active_slot = NetSession.I.active_slot()
		for i in main.players.size():
			main.players[i].is_active = i == main.roster.active_slot
	main._refresh_roster()


func net_recall(slot: int) -> void:
	if slot < 0 or slot >= main.players.size():
		return
	var p: Player = main.players[slot]
	if p == null or p.in_exit or p.dying or p.arrived:
		return
	p.recall_to(main.roster.checkpoints.get(p.body_key(), p.spawn_pos))
	Sfx.play("switch")


func net_show_complete() -> void:
	main._state = Main.State.TRANSITION
	Sfx.play("complete")
	main._hud.show_complete("通过。")


func net_back_to_room() -> void:
	main.get_tree().paused = false
	clear_level()
	main._state = Main.State.ROOM
	main._hud.visible = false
	main.touch_controls.set_in_game(false)
	main._hud.set_net_badge("")
	NetSession.I.back_to_lobby()
	main.net_room_layer.reopen_after_game()


func net_peer_lost() -> void:
	if main._state == Main.State.PLAYING or main._state == Main.State.PAUSED \
			or main._state == Main.State.TRANSITION:
		main.get_tree().paused = false
		main._pause.close()
		net_back_to_room()
		main.net_room_layer.toast_line("对手掉线,已返回房间")
	else:
		main.net_room_layer.toast_line("对手掉线")


func net_host_lost(was_in_game: bool) -> void:
	main.get_tree().paused = false
	main._pause.close()
	main._ambience_motif("prologue")
	clear_level()
	main._hud.visible = false
	main.touch_controls.set_in_game(false)
	main._hud.set_net_badge("")
	main._state = Main.State.MENU
	main._menu.visible = true
	main._menu.set_unlocked(main._unlocked)
	main._menu.toast("主机已离开房间" if was_in_game else "与主机的连接已断开")
