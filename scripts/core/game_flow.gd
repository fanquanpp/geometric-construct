class_name GameFlow
extends Node
## 流转域控制器(REFACTOR.md Phase 4-4 前半,v0.38.2):关卡装载 / 幕流转 /
## 通关判定的唯一归属地。Main 保留同名一行委托与 _current 属性转发
## (hud / net / 名册 / 钢琴块 / 分镜钩子的调用点零改动)。
##
## 状态:
##   current      当前标准关下标(-1 = 无关)
##   level_info    当前装载的关卡清单(NativeLevel 字段摘录,见 start_level)
##   complete_seq 通关链序列号:重开/换关时作废待执行的自动流转

var main: Main
var current := -1
var level_info: Dictionary = {}
var complete_seq := 0


# ———————————————— 关卡装载 ————————————————

func start_level(index: int, intro := true) -> void:
	if main.debug_solo:
		print("TRACE start_level(", index, ") state_was=", Main.State.keys()[main._state])
	complete_seq += 1    # 作废任何待执行的通关自动流转(重开/换关不被拽走)
	main.dual_mode = false   # 普通开局恒单人(双人走 start_level_dual 开局后再翻)
	main.get_tree().paused = false
	if main._pause != null:
		main._pause.close()
	current = clampi(index, 0, LevelData.count() - 1)
	clear_level()
	main._doors.clear()
	main._checkpoints.clear()   # 换关作废记录点:陈旧坐标会把召回/重生送进异世界
	var scene: PackedScene = load(LevelData.scene_path(current))
	var root: NativeLevel = scene.instantiate()
	main._level_root = root
	main.add_child(root)
	# 关卡清单(表现层消费面):名称 / 教学主角 / 名册 / 死亡线 ——
	# 原生作关后关卡数据在场景里,这里只摘 HUD / 名册 / 判定要用的字段。
	level_info = {"name": root.level_name, "intro": root.intro_text,
		"focus": root.focus, "roster": root.roster,
		"kill_y": root.kill_y, "top_kill_y": root.top_kill_y}
	collect_players()
	main._state = Main.State.PLAYING
	Sfx.play("start")
	# 幕归属由 LevelData.ACTS 推导(v0.15 序章扩容后不再按下标硬编码)
	var act_i := LevelData.act_index_of(current)
	main._ambience_motif("act1")

	main._menu.visible = false
	main._menu.close_act_panel()
	main.archive_panel.close()
	main.settings_panel.close()
	main._hud.visible = true
	main.touch_controls.set_in_game(true)
	# 体数 > 1 才有"切换"可言(双子一位两具):按 roster 长度判断会把
	# 纯双子阵容误判成"单人无切换"(v0.21.0 修正)
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
	# 联机(N2):两端装配完成后算定绑定 / 标注 remote_driven / 注入输入源
	# (net.md §6 生成免 Spawner 的收尾;on_level_built 两端各自调用);
	# 客机经 rpc_start_level 直达此处,房间页须在这里收起(主机路径自关)
	if NetSession.I != null and NetSession.I.is_net():
		main.net_room_layer.visible = false
		NetSession.I.on_level_built()
	# 幕开演剧(v0.44.0 泛化):首次进入某幕首场,播该幕开演剧(kind = act1..act5)
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
		# 必须 free() 立即释放(v0.31 教训,v0.44.0 回归修):queue_free 的
		# 延迟释放窗口里,旧根 _init 连接的 character_created 仍挂在
		# CharacterManager 上,新关 build 建体时会被同帧抢挂——玩家随旧根
		# 一并被释放,下一关"无法诞生"(players 空 / 位置错)。
		main._level_root.free()
		main._level_root = null


# ———————————————— 幕流转 ————————————————

## 幕落回菜单(motion.md §2.3 三类大流转之三:折线幕帘)——
## 覆盖后换内容,幕继续坠出;在飞/减动效由 TransitionFX 兜底。
func return_to_menu() -> void:
	if main._hud == null or main._hud.transition_curtain(0.4, func() -> void: show_menu()):
		return
	show_menu()


func show_menu() -> void:
	main._state = Main.State.MENU
	main.dual_mode = false   # 退出即散伙:回菜单后普通开局不受残留双活态影响
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


# ———————————————— 通关流转 ————————————————

func check_complete() -> void:
	for p in main.players:
		if not p.in_exit:
			return

	main._state = Main.State.TRANSITION
	Sfx.play("complete")
	if main._auto_test:
		print("TEST: LEVEL COMPLETE ", current)
	main._hud.show_complete("归位。" if current == LevelData.campaign_last() else "通过。")
	# 联机(N2):客机由 EV_COMPLETE 复现结算画面;两端都不自动进下一关,
	# 停留片刻后回房间等待主机再开演(net.md §7 主机选关)。
	if NetSession.I != null and NetSession.I.is_net():
		if NetSession.I.is_host():
			NetSession.I.emit_event(NetSession.EV_COMPLETE)
		complete_seq += 1
		var seq_n := complete_seq
		main.get_tree().create_timer(2.1).timeout.connect(func() -> void:
			if seq_n == complete_seq:
				main.net_back_to_room())
		return
	if current + 1 > main._unlocked:
		main._unlocked = mini(current + 1, LevelData.campaign_last())
		main._save.unlocked = main._unlocked
		main._save.write_save()
	# 延迟流转:期间重开/换关会递增序列号,令本次流转作废
	complete_seq += 1
	var seq := complete_seq
	main.get_tree().create_timer(2.1).timeout.connect(func() -> void:
		if seq == complete_seq:
			after_complete())


func after_complete() -> void:
	if current >= LevelData.campaign_last():
		main._state = Main.State.WIN
		Sfx.play("fanfare")
		main._hud.show_win(true)
		# 通关尾声剧情(仅一次,Esc/对话结束返回)
		if not main.get_tree().paused:
			main.get_tree().paused = true
			main.show_story("epilogue")
	else:
		main._hud.transition_sweep(0.55, func() -> void: start_level(current + 1))


# ———————————————— 联机流转(N2 同网直连,net.md §4/§7;v0.39.2 自 Main 收编) ————————

## 菜单「双人试炼 → 跨设备双人」入口:进入房间流程页(创建 / 加入)。
func open_net_room() -> void:
	if main._state != Main.State.MENU:
		return
	main._state = Main.State.ROOM
	main._menu.visible = false
	main.net_room_layer.open()


## 两端 start_level 装配完成后的联机收尾(NetSession.on_level_built 调用):
## 主机点亮自己绑定集的首具操控体;客机镜像上传槽为取景 / 名牌语义槽。
func net_post_setup() -> void:
	main.touch_controls.set_switch_available(true)   # 绑定集 > 1 体,集合内可切
	if NetSession.I.is_host():
		var own: Array = NetSession.I.own_slots_arr()
		if not own.is_empty():
			main.roster.switch_to(own[0], true)
	else:
		main.roster.active_slot = NetSession.I.active_slot()
		for i in main.players.size():
			main.players[i].is_active = i == main.roster.active_slot
	main._refresh_roster()


## 客机召回执行(主机侧,NetSession._do_recall 调用):传送 + 快照回传。
func net_recall(slot: int) -> void:
	if slot < 0 or slot >= main.players.size():
		return
	var p: Player = main.players[slot]
	if p == null or p.in_exit or p.dying or p.arrived:
		return
	p.recall_to(main.roster.checkpoints.get(p.body_key(), p.spawn_pos))
	Sfx.play("switch")


## 客机结算画面复现(主机经 EV_COMPLETE 触发;流转由主机驱动)。
func net_show_complete() -> void:
	main._state = Main.State.TRANSITION
	Sfx.play("complete")
	main._hud.show_complete("通过。")


## 两端回房间(联机通关流转终点:不开下一关,主机可再开演)。
func net_back_to_room() -> void:
	main.get_tree().paused = false
	clear_level()
	main._state = Main.State.ROOM
	main._hud.visible = false
	main.touch_controls.set_in_game(false)
	main._hud.set_net_badge("")
	NetSession.I.back_to_lobby()
	main.net_room_layer.reopen_after_game()


## 主机侧:客机掉线(§11 待议项的临时拍板 = 整队弹回房间,可再开演)。
func net_peer_lost() -> void:
	if main._state == Main.State.PLAYING or main._state == Main.State.PAUSED \
			or main._state == Main.State.TRANSITION:
		main.get_tree().paused = false
		main._pause.close()
		net_back_to_room()
		main.net_room_layer.toast_line("对手掉线,已返回房间")
	else:
		main.net_room_layer.toast_line("对手掉线")


## 客机侧:主机掉线 —— 弹回标题菜单 + 明确提示(net.md §5)。
func net_host_lost(was_in_game: bool) -> void:
	main.get_tree().paused = false
	main._pause.close()
	clear_level()
	main._hud.visible = false
	main.touch_controls.set_in_game(false)
	main._hud.set_net_badge("")
	main._state = Main.State.MENU
	main._menu.visible = true
	main._menu.set_unlocked(main._unlocked)
	main._menu.toast("主机已离开房间" if was_in_game else "与主机的连接已断开")
