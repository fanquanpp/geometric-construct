class_name GameFlow
extends Node


var main: Main
var current := -1
var level_info: Dictionary = {}
var complete_seq := 0
var run_ms := 0
var run_deaths := 0
# 教程局标记(start_tutorial 置位,check_complete 据此截断战役进度面;
# 任一非教程 start_level 复位)。
var tutorial_mode := false


func _physics_process(delta: float) -> void:
	if main != null and main._state == Main.State.PLAYING:
		run_ms += int(delta * 1000.0)


func note_death() -> void:
	run_deaths += 1


func start_level(index: int, intro := true, scene_override := "") -> void:
	if main.debug_solo:
		print("TRACE start_level(", index, ") state_was=", Main.State.keys()[main._state])
	if scene_override.is_empty():
		tutorial_mode = false
	complete_seq += 1
	main.dual_mode = false
	main.get_tree().paused = false
	if main._pause != null:
		main._pause.close()
	current = clampi(index, 0, LevelData.count() - 1) \
		if scene_override.is_empty() else index
	run_ms = 0
	run_deaths = 0
	clear_level()
	main._doors.clear()
	main._checkpoints.clear()
	var scene: PackedScene = load(LevelData.scene_path(current) \
		if scene_override.is_empty() else scene_override)
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
	if main.backdrop != null:
		main.backdrop.apply_act(act_i)

	main._menu.visible = false
	main._menu.close_act_panel()
	main.archive_panel.close()
	main.controls_panel.close()
	main.settings_panel.close()
	main._hud.visible = true
	main.touch_controls.set_in_game(true)

	main.touch_controls.set_switch_available(
		level_info.roster.size() > 1)
	main._hud.show_win(false)
	main._hud.set_level_info(current, level_info["name"])
	main._refresh_roster()
	main._hud.reveal_corners()
	if intro:
		var act_name := str(LevelData.ACTS[act_i]["name"]) if act_i >= 0 \
			else "正戏"
		main._hud.show_intro("%s · 第 %d 场 · %s" % [act_name, LevelData.scene_no_of(current),
			Geometries.get_def(level_info["focus"]).full_name], level_info)
	main._switch_to(0, true)
	main.race.reset()
	main.ghost.on_level_started(current)

	if NetSession.I != null and NetSession.I.is_net():
		main.net_room_layer.visible = false
		NetSession.I.on_level_built()


const TUTORIAL_SCENE := "res://levels_native/tutorial/tutorial.tscn"


## 教程入口契约(tutorial 波消费;menu_layer 新手教程钮按零参调用钉死,
## scene 路径可省缺走规范 tutorial.tscn,也可显式覆盖供多段教程)。
## 复用 start_level 全链路(建体/收集/气氛/触控一套不差);current=-1:
## act 查找走既有 -1 容忍路径(:48-49 气氛钳制、:68-69 幕名「正戏」)。
## 战役进度面(unlocked/mark_level_result/medal)经 tutorial_mode 在
## check_complete 截断,教程进度由 tutorial 波经 SaveManager 新字段自理。
func start_tutorial(scene_path := TUTORIAL_SCENE) -> void:
	if not FileAccess.file_exists(scene_path):
		push_warning("start_tutorial: 教程场景缺失 %s" % scene_path)
		return
	tutorial_mode = true
	start_level(-1, true, scene_path)


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
	if main._hud == null:
		return
	# 回菜单统一 CURTAIN(风格矩阵:回菜单与进房同语汇)。经 transition_fx
	# 直驱 cover_then:包装器忙(单飞在飞)时下一帧重试直至接管,不再
	# 出现「忙→裸直切」的闪变兜底;cover 回调才 show_menu,回调必达。
	main._hud._fx.cover_then(TransitionFX.Style.CURTAIN,
		Ui.MOTION_SCENE_MS / 1000.0, func() -> void: show_menu())


func show_menu() -> void:
	main._state = Main.State.MENU
	main.dual_mode = false
	main._ambience_motif("prologue")
	if main.backdrop != null:
		main.backdrop.apply_act(-1)
	clear_level()
	main._hud.visible = false
	main.touch_controls.set_in_game(false)
	main.archive_panel.close()
	main.controls_panel.close()
	main.settings_panel.close()
	main._menu.visible = true
	# 归还焦点集(联机房间路径会让菜单钮留在 FOCUS_NONE),
	# set_unlocked 内的 grab 在钮不可聚焦时静默失效。
	main._menu.set_menu_focusable(true)
	main._menu.set_unlocked(main._unlocked)


func restart_level() -> void:
	if main._state != Main.State.PLAYING:
		return
	Sfx.play("restart")
	# 重开走 intro=false:开场卡只在会话首次进关显示,重试不重播
	# 3s 开场卡;首次进入路径行为不变。FADE=重开(风格矩阵),
	# 时长取页面进出档(ui.gd 动效档位收敛)。
	main._hud.fade_to_black(Ui.MOTION_PAGE_MS / 1000.0,
		func() -> void: start_level(current, false))
	main._state = Main.State.TRANSITION


func check_complete() -> void:
	for p in main.players:
		if not p.in_exit:
			return

	main._state = Main.State.TRANSITION
	Sfx.play("complete")
	main.ghost.on_complete()
	if main._auto_test:
		print("TEST: LEVEL COMPLETE ", current)
	var done_text := "通过。"
	if run_deaths == 0:
		done_text = "完美归位。"
	elif current == LevelData.campaign_last():
		done_text = "归位。"
	main._hud.show_complete(done_text)

	if tutorial_mode:
		# 教程关截断:不写战役进度(unlocked/mark_level_result/medal 不触)、
		# 不自动换关、不接联机链路。收尾走标准遮挡回菜单(过渡纪律不豁免);
		# 专属结算演出由 tutorial 波自理(SaveManager 教程字段属之)。
		complete_seq += 1
		var seq_t := complete_seq
		main.get_tree().create_timer(2.1).timeout.connect(func() -> void:
			if seq_t == complete_seq:
				return_to_menu())
		return
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
		# WIN 入场遮挡契约(供 tutorial 波复用):SLABS 斜切色块遮屏后
		# 才亮结算页,cover 回调才切 WIN 状态(转场期 TRANSITION 锁输入,
		# 时序同 return_to_menu 型);忙时经 transition_fx 帧重试兜底,
		# reduced_motion 走 transition 自带硬切降级。
		main._hud._fx.cover_then(TransitionFX.Style.SLABS,
			Ui.MOTION_SCENE_MS / 1000.0, func() -> void: _win_enter())
	else:
		main._hud.transition_sweep(0.55, func() -> void: start_level(current + 1))


func _win_enter() -> void:
	main._state = Main.State.WIN
	Sfx.play("fanfare")
	main._hud.show_win(true, win_summary())


func win_summary() -> String:
	var s := main._save
	return "落幕场最佳 %s · 旅程用时 %s · 摔碎 %d 次 · 完美 %d / %d 场" % [
		s.time_text(s.best_time_of(LevelData.campaign_last())),
		s.long_time_text(s.total_play_ms), s.total_deaths,
		s.perf_count(), LevelData.campaign_last() + 1]


func open_net_room() -> void:
	if main._state != Main.State.MENU:
		return
	# 菜单→房间入口入遮挡面(CURTAIN,回菜单/进房同语汇):转场期先落
	# TRANSITION 锁输入(菜单数字键/面板键不再穿透,连点被吞),cover
	# 回调才切 ROOM(时序同 return_to_menu 型);忙时兜底直开(有界收敛)。
	main._state = Main.State.TRANSITION
	if main._hud != null and main._hud.transition_curtain(
			Ui.MOTION_SCENE_MS / 1000.0, func() -> void: _room_enter()):
		return
	_room_enter()


func _room_enter() -> void:
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
	p.recall_to(main.roster.checkpoints.get(p.index, p.spawn_pos))
	Sfx.play("switch")


func net_show_complete() -> void:
	main._state = Main.State.TRANSITION
	Sfx.play("complete")
	main._hud.show_complete("通过。")


func net_back_to_room() -> void:
	_net_back_to_room(Callable())


## 回房统一入口(过关返回 EV_BACK / 掉线兜底共用):在局/暂停/换关期
## 先 CURTAIN 遮屏(残局/结算画面直切房间=闪变),cover 回调才真还原
## 房间,期间 TRANSITION 锁输入;忙时兜底直还原(v0.66 有界收敛口径)。
## after:房间重开后补发动作(如掉线 toast,须在房间可见后到达)。
func _net_back_to_room(after: Callable) -> void:
	var in_game := main._state == Main.State.PLAYING \
		or main._state == Main.State.PAUSED \
		or main._state == Main.State.TRANSITION
	if in_game:
		main._state = Main.State.TRANSITION
		if main._hud != null and main._hud.transition_curtain(
				Ui.MOTION_SCENE_MS / 1000.0,
				func() -> void: _room_restore(after)):
			return
	_room_restore(after)


func _room_restore(after: Callable) -> void:
	main._pause.close()
	main.get_tree().paused = false
	clear_level()
	main._state = Main.State.ROOM
	main._hud.visible = false
	main.touch_controls.set_in_game(false)
	main._hud.set_net_badge("")
	NetSession.I.back_to_lobby()
	main.net_room_layer.reopen_after_game()
	if after.is_valid():
		after.call()


func net_peer_lost() -> void:
	if main._state == Main.State.PLAYING or main._state == Main.State.PAUSED \
			or main._state == Main.State.TRANSITION:
		main.get_tree().paused = false
		main._pause.close()
		# 掉线瞬间 RPC 已停、残局画面无主:入遮挡再回房,toast 在房间
		# 重开后补发(toast_line 对不可见层静默,直发会被遮挡期吞掉)。
		_net_back_to_room(func() -> void:
			main.net_room_layer.toast_line("对手掉线,已返回房间"))
	else:
		main.net_room_layer.toast_line("对手掉线")


func net_host_lost(was_in_game: bool) -> void:
	var msg := "主机已离开房间" if was_in_game else "与主机的连接已断开"
	main.get_tree().paused = false
	main._pause.close()
	# 在局/换关期掉主机:CURTAIN 遮屏后再回菜单(cover 回调切状态);
	# 房间页掉主机时 room_closed 已先行直落菜单,直还原即可。
	var in_game := main._state == Main.State.PLAYING \
		or main._state == Main.State.PAUSED \
		or main._state == Main.State.TRANSITION
	if in_game:
		main._state = Main.State.TRANSITION
		if main._hud != null and main._hud.transition_curtain(
				Ui.MOTION_SCENE_MS / 1000.0,
				func() -> void: _host_lost_restore(msg)):
			return
	_host_lost_restore(msg)


func _host_lost_restore(msg: String) -> void:
	main._hud.set_net_badge("")
	show_menu()
	main._menu.toast(msg)
