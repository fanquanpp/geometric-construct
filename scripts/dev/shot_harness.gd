extends RefCounted
## 开发验证钩子执行器(统合重构终案 Sprint 4 自 main.gd 迁出):
## --*shot / --autotest / --recalltest / --laneshot / --tourshot 等
## 命令行分镜与自测的唯一实现。经 Main._dev_harness() 软引用装载,
## 导出包剥离 scripts/dev/* 后 load 失败 → 钩子整体关闭;
## 旗标解析留守 Main(_parse_auto_shot),本文件只管执行。
## _run_perf_log 留守 Main:服务 Android debug 真机自动 PERF 日志。

var m: Main


## 截取设置面板。
func run_set_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	await m.get_tree().create_timer(0.6).timeout
	m.settings_panel.open()
	await m.get_tree().create_timer(0.5).timeout
	await _shot("settings")
	m.get_tree().quit()


## 截取剧目二级菜单(关卡列)。
func run_actshot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	await m.get_tree().create_timer(0.6).timeout
	m._menu.try_open_act(m._act_shot_idx)
	await m.get_tree().create_timer(0.6).timeout
	await _shot("act_panel")
	m.get_tree().quit()


## 截取开屏动画(标题落定瞬间)。
func run_boot_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	await m.get_tree().create_timer(1.35).timeout
	await _shot("boot")
	await m.get_tree().create_timer(1.8).timeout
	await _shot("boot_end")
	m.get_tree().quit()


## 截取章节开场卡。
func run_intro_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	m.start_level(m._shot_level, true)
	await m.get_tree().create_timer(1.2).timeout
	await _shot("intro")
	m.get_tree().quit()


## 截取肉鸽模式 UI(选体 / 选路 / 词条三选一 / 结算,逐屏截图验收)。
func run_rogue_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	m._state = Main.State.PLAYING
	await m.get_tree().create_timer(0.6).timeout
	var done := func(_a = null) -> void: pass
	m.rogue_layer.show_geo_pick(done, 34, 2)
	await m.get_tree().create_timer(0.5).timeout
	await _shot("rogue_pick")
	m.rogue_layer._close_overlay()
	var mock_routes := [
		{"title": "演示甲", "note": "快 · 三级梯田直上,缺口只有两格"},
		{"title": "演示乙", "note": "稳 · 全程地面安全网,谷底滚不碎"},
	]
	m.rogue_layer.show_route(1, mock_routes, done)
	await m.get_tree().create_timer(0.5).timeout
	await _shot("rogue_route")
	m.rogue_layer._close_overlay()
	m.rogue_layer.show_reward([
		RunModifiers.ALL[0], RunModifiers.ALL[4], RunModifiers.ALL[5]], done)
	await m.get_tree().create_timer(0.5).timeout
	await _shot("rogue_reward")
	m.rogue_layer._close_overlay()
	m.rogue_layer.show_settle({
		"cleared": false, "chapter": 2, "arrivals": 12, "elites": 1, "deaths": 3,
		"shards": 17, "balance": 34, "mods": [RunModifiers.ALL[1], RunModifiers.ALL[4]],
	}, done)
	await m.get_tree().create_timer(0.5).timeout
	await _shot("rogue_settle")
	m.rogue_layer._close_overlay()
	# 局内状态条:mock 一局(2 段进度 / 3 格刻度 / 2 词条)后装载真片段
	m.rogue_dir.run = RunState.new(0)
	m.rogue_dir.run.chapter = 2
	m.rogue_dir.run.fragments_done = 1
	m.rogue_dir.run.ticks = 3
	m.rogue_dir.run.add_mod(RunModifiers.ALL[1])
	m.rogue_dir.run.add_mod(RunModifiers.ALL[4])
	m.get_tree().paused = false
	# v0.17 片段库已清空:状态条 mock 照常截图,真片段装载跳过
	var _routes: Array = RogueFragments.chapter_routes(0, 1)
	if _routes.is_empty():
		print("ROGUESHOT: 片段库已清空,跳过片段装载")
		m.get_tree().quit()
		return
	m.start_rogue_fragment(_routes[0]["def"])
	m.rogue_layer.refresh_status(m.rogue_dir.run)
	await m.get_tree().create_timer(0.6).timeout
	await _shot("rogue_status")
	m.rogue_dir.run = null
	m.get_tree().quit()


## 肉鸽全流程自动测试:auto 模式下自动选路 / 选奖励 / 强制完成片段,
## 跑完一整局(三章 + 三精英考 + 结算)直到回菜单。
func run_rogue_auto_test() -> void:
	print("TEST: rogue auto run begin")
	m._menu.visible = false
	m._hud.visible = true
	m._state = Main.State.PLAYING
	m.rogue_dir.auto = true
	print("TEST: rogue focus=", Geometries.get_def(m._rogue_focus).name)
	m.rogue_dir.begin(m._rogue_focus)
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline \
			and m.rogue_dir.phase != RogueDirector.Phase.IDLE:
		await m.get_tree().create_timer(0.5).timeout
	print("TEST: rogue run end phase=", m.rogue_dir.phase,
		" mods=", m.rogue_dir.run.mod_ids() if m.rogue_dir.run != null else [],
		" shards=", m._save.rogue_shards, " runs=", m._save.rogue_runs)
	m.get_tree().quit()


## 截取剧情对话框(序幕)。
## 刻意先开局把相机带到关卡深处再开对话:验证变暗遮罩不再跟随相机
## (follow_viewport 关闭后,遮罩恒定铺满屏幕,左右两侧都不会漏光)。
func run_story_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	await m.get_tree().create_timer(0.6).timeout
	m.start_level(0, false)
	await m.get_tree().create_timer(0.3).timeout
	if not m.players.is_empty():
		m.players[0].position = Vector2(2000, 850)
		m.players[0].velocity = Vector2.ZERO
	await m.get_tree().create_timer(0.4).timeout
	m.get_tree().paused = true
	m.show_story(m._story_kind)
	await m.get_tree().create_timer(1.6).timeout
	await _shot("story_" + m._story_kind)
	m.get_tree().quit()


## 巡航截图:沿大型关卡的关键节拍传送受控几何体,逐点截图验收。
## 节拍表按当前关卡下标内建;新巨构关卡在此追加自己的节拍行。
func run_tour_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	m._unlocked = LevelData.LEVELS.size() - 1
	m.start_level(m._shot_level, false)
	await m.get_tree().create_timer(0.4).timeout
	var tours := {
		0: [["spawn", Vector2(430, 1745)],
			["float_top", Vector2(1150, 1415)],
			["L3_pass", Vector2(1800, 1745)],
			["L8_silhouette", Vector2(2380, 1745)],
			["dash_wall", Vector2(2820, 1745)],
			["L6_roll_top", Vector2(3930, 1374)],
			["swap_corridor", Vector2(5200, 1745)],
			["faces_top", Vector2(6250, 1600)],
			["piano_row", Vector2(6800, 1745)],
			["ferry", Vector2(8200, 1670)],
			["pit_ramp", Vector2(8300, 1850)],
			["lift_top", Vector2(9080, 1000)],
			["deck_gate", Vector2(9550, 1020)],
			["ceiling_top", Vector2(10800, 1150)],
			["climb_tower", Vector2(11600, 360)],
			["bridge", Vector2(11250, 1700)],
			["twins_hall", Vector2(11800, 1745)],
			["niche_door4", Vector2(13235, 1650)],
			["doors", Vector2(12700, 1745)]],
	}
	var waypoints: Array = tours.get(m._shot_level, [["spawn", Vector2(300, 850)]])
	for wp in waypoints:
		if m.players.is_empty():
			break
		var p: Player = m.players[m._active_slot]
		p.position = wp[1]
		p.velocity = Vector2.ZERO
		await m.get_tree().create_timer(0.55).timeout
		await _shot("tour_" + str(wp[0]))
	m.get_tree().quit()


## 分层语义 v3 截图验收(levels.md §7.10):装载机制试炼场,分镜截取
## L3 背景可穿行 / L6 专属高亮(圆站上台面)/ L5 专属域(疾墙对疾高亮、
## 逆墙对逆)/ L8 前景躲入降透明 / 动态机关两态;配合 --zoom=N 验网格 LOD。
func run_lane_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	m._shot_level = 99
	m._level_def = LevelData.LEVELS[0]   # 分层演示即机制试炼场(v0.17 起)
	m._rogue = false
	m._current = -1
	m._clear_level()
	m._level_root = LevelBuilder.build(m._level_def)
	m.add_child(m._level_root)
	m._collect_players()
	m._state = Main.State.PLAYING
	m._menu.visible = false
	m._hud.visible = true
	m.touch_controls.set_in_game(true)
	m.touch_controls.set_switch_available(true)
	m._hud.show_win(false)
	m._hud.set_level_info(m._level_def)
	m._refresh_roster()
	m._hud.fade_from_black()
	m._switch_to(0, true)
	await m.get_tree().create_timer(0.8).timeout

	# ① 疾 @ Z1:L3 背景建筑(1700)与 L8 前景遮挡(2200)同框,右侧 L5 疾域墙
	m.players[0].position = Vector2(2350, 1740)
	m.players[0].velocity = Vector2.ZERO
	await m.get_tree().create_timer(0.8).timeout
	await _shot("lane_L3_L8_dash")
	# ② 圆 @ L6 圆域实台:专属高亮描边(呼吸脉冲)
	if m.players.size() > 3:
		m._switch_to(3, true)
		m.players[3].position = Vector2(3930, 1370)
		m.players[3].velocity = Vector2.ZERO
		await m.get_tree().create_timer(0.9).timeout
		await _shot("lane_L6_focus_roll")
	# ③ 疾 @ L5 疾域墙:对疾实体 + 高亮描边
	m._switch_to(0, true)
	m.players[0].position = Vector2(2560, 1740)
	m.players[0].velocity = Vector2.ZERO
	await m.get_tree().create_timer(0.8).timeout
	await _shot("lane_L5_focus_dash")
	# ④ 疾躲入 L8 前景:组件降透明呈剪影
	m.players[0].position = Vector2(2380, 1740)
	m.players[0].velocity = Vector2.ZERO
	await m.get_tree().create_timer(0.7).timeout
	await _shot("lane_L8_dim")
	# ⑤ 逆 @ Z2 置换走廊:L5 逆域墙高亮;上方 faces=bottom 天路
	m._switch_to(2, true)
	m.players[2].position = Vector2(4700, 1740)
	m.players[2].velocity = Vector2.ZERO
	await m.get_tree().create_timer(0.8).timeout
	await _shot("lane_L5_focus_fall")
	# ⑥ 气闸开关门(共享件常亮,无描边)
	m._switch_to(0, true)
	m.players[0].position = Vector2(9900, 1740)
	m.players[0].velocity = Vector2.ZERO
	await m.get_tree().create_timer(0.6).timeout
	await _shot("lane_dyn_gate")
	# ⑦ 限时桥 + 双子磁界室远景
	m.players[0].position = Vector2(10800, 1740)
	m.players[0].velocity = Vector2.ZERO
	await m.get_tree().create_timer(0.8).timeout
	await _shot("lane_dyn_bridge")
	m.get_tree().quit()


## 截取档案几何(全部页签,含动态精灵)。
func run_panel_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	await m.get_tree().create_timer(0.6).timeout
	m.archive_panel.open(0)
	await m.get_tree().create_timer(0.5).timeout
	await _shot("panel_geo0")
	for page in range(1, Geometries.ALL.size()):
		m.archive_panel._switch(1)
		await m.get_tree().create_timer(0.4).timeout
		await _shot("panel_geo%d" % page)
	# 页签真实点击回归:走 GUI 输入管线点「键位」页签中心(v0.19.1 教训:
	# 整页容器默认 STOP 吞点击,open() 直调的分镜测不出,必须过一遍真实
	# 输入命中测试)。v0.21.2 教训:① 坐标不能硬编码 —— 真机 = (设计+160)×2、
	# 桌面窗口 = 设计×1.25,两套映射只对一端成立,改取按钮全局矩形中心;
	# ② 桌面窗口里 parse_input_event(ScreenTouch) 不产生 GUI 点击(旧分镜
	# 从未点中过)—— 桌面必须注入鼠标事件并做画布→窗口变换,真机触屏
	# 回归仍由 adb 点按另行走查。
	var keys_tab: Button = m.archive_panel._tab_btns["keys"]
	var tab_center: Vector2 = keys_tab.get_global_rect().get_center()
	var to_window: Transform2D = m.get_viewport().get_final_transform()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = to_window * tab_center
	Input.parse_input_event(press)
	await m.get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to_window * tab_center
	Input.parse_input_event(release)
	await m.get_tree().create_timer(0.4).timeout
	# 一镜两用:既证明真实输入点按成功落在「键位」页签上(点击回归),
	# 也是键位指南页的常规分镜(文档名沿用 panel_keys 惯例)。
	await _shot("panel_keys")
	# 建筑图鉴 + 机关图鉴(两态静帧 + 动态精灵各拍一帧)
	m.archive_panel.open(0, "bld")
	await m.get_tree().create_timer(0.5).timeout
	await _shot("panel_bld0")
	m.archive_panel.open(0, "mech")
	await m.get_tree().create_timer(0.5).timeout
	await _shot("panel_mech0")
	var refs: Dictionary = m.archive_panel._pages["mech"].get_meta("refs")
	(refs["toggle"] as Button).button_pressed = true
	m.archive_panel._refresh_codex("mech")
	await m.get_tree().create_timer(0.4).timeout
	await _shot("panel_mech_f2")
	m.archive_panel._sel["mech"] = ArchiveData.MECHS.size() - 1  # 传送对(规划中·动态)
	m.archive_panel._refresh_codex("mech")
	await m.get_tree().create_timer(1.2).timeout
	await _shot("panel_mech_portal")
	# 剧情目录 + 全文本阅读器(序幕)
	m.archive_panel.open(0, "gallery")
	await m.get_tree().create_timer(0.5).timeout
	await _shot("panel_gallery")
	m.archive_panel._open_story(ArchiveData.STORIES[0])
	await m.get_tree().create_timer(0.5).timeout
	await _shot("panel_story")
	m.get_tree().quit()


## 传送到出口门前,验证门的渲染与过关文字。
## 召回链路自测(headless):动作注册 → 按下 → 召回至出生点;
## v0.21.0 扩展双体链路:chips 同位再点即切另一半,界/边各回各的
## 出生点(body_key 隔离),重力方向随各半基准复位。
func run_recall_test() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = ".shots_v17"
	m.start_level(0, false)
	await m.get_tree().create_timer(0.5).timeout
	var fails := 0
	# ① 单体(疾):召回出生点
	var p: Player = m.players[m._active_slot]
	p.position = p.spawn_pos + Vector2(600, -300)
	await _recall_keypress()
	var ok: bool = p.position.distance_to(p.spawn_pos) < 2.0 and not p.dying
	print("RECALLTEST 疾 ", "PASS" if ok else "FAIL",
		" pos=", p.position, " spawn=", p.spawn_pos)
	if not ok:
		fails += 1
	# ② 双子:点伍芯片(= m.switch_to_geo(4))→ 默认选中界;召回回天花出生点 a
	m.switch_to_geo(4)
	await m.get_tree().physics_frame
	var jie: Player = m.players[m._active_slot]
	var ok_jie: bool = jie.pair_half == 0
	jie.position = jie.spawn_pos + Vector2(600, 0)
	await _recall_keypress()
	ok_jie = ok_jie and jie.position.distance_to(jie.spawn_pos) < 2.0 \
		and jie.gravity_dir == -1 and not jie.dying
	print("RECALLTEST 界 ", "PASS" if ok_jie else "FAIL",
		" pos=", jie.position, " spawn=", jie.spawn_pos,
		" g=", jie.gravity_dir)
	if not ok_jie:
		fails += 1
	# ③ 同键再点(切换另一半语义)→ 边;召回回地面出生点 b
	m.switch_to_geo(4)
	await m.get_tree().physics_frame
	var bian: Player = m.players[m._active_slot]
	var ok_bian: bool = bian.pair_half == 1
	bian.position = bian.spawn_pos + Vector2(-300, 0)
	await _recall_keypress()
	ok_bian = ok_bian and bian.position.distance_to(bian.spawn_pos) < 2.0 \
		and bian.gravity_dir == 1 and not bian.dying
	print("RECALLTEST 边 ", "PASS" if ok_bian else "FAIL",
		" pos=", bian.position, " spawn=", bian.spawn_pos,
		" g=", bian.gravity_dir)
	if not ok_bian:
		fails += 1
	m.get_tree().quit(0 if fails == 0 else 1)


## 真实输入管线按一次 R(动作 recall):idle 协程直调 action_press 会错过
## just_pressed 的物理帧比对,必须 parse_input_event + 物理帧等待;按后抬起。
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


func run_door_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	m.start_level(0, false)
	await m.get_tree().create_timer(0.3).timeout
	m.players[0].position = Vector2(14450, 1700)
	m.players[0].velocity = Vector2.ZERO
	await m.get_tree().create_timer(0.25).timeout
	await _shot("door")
	await m.get_tree().create_timer(1.1).timeout
	await _shot("complete")
	m.get_tree().quit()


## JSON 试水关出生点连拍:验证双体渲染 / 磁力边界 / 双门(开发用)。
func run_trial_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = ".shots_v16"
	m.start_level(0, false)
	await m.get_tree().create_timer(0.4).timeout
	await _shot("trial_spawn")
	await m.get_tree().create_timer(0.8).timeout
	await _shot("trial_rest")
	m.get_tree().quit()


## 截取标题菜单画面。
func run_menu_shot() -> void:
	await m.get_tree().create_timer(1.0).timeout
	await m.get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(m._shot_dir)
	var img := m.get_viewport().get_texture().get_image()
	var path := m._shot_dir.path_join("menu.png")
	img.save_png(path)
	print("SHOT_SAVED: ", ProjectSettings.globalize_path(path))
	m.get_tree().quit()


## 自动通关测试:一直向右走 + 周期性跳跃,打印关键事件直到超时。
func run_auto_test() -> void:
	m._unlocked = LevelData.LEVELS.size() - 1
	print("TEST: begin level ", m._shot_level)
	m.start_level(m._shot_level, false)
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
			print("TEST: pos=", m.players[m._active_slot].position,
				" onFloor=", m.players[m._active_slot].is_on_floor())
	print("TEST: end state=", Main.State.keys()[m._state])
	m.get_tree().quit()


func run_auto_shot() -> void:
	m._unlocked = LevelData.LEVELS.size() - 1
	m.start_level(m._shot_level, false)
	await m.get_tree().create_timer(1.0).timeout
	await _shot("a")

	# 走一段 + 冲刺 + 跳一次(再补一跳二段),验证物理与出口渲染
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
	DirAccess.make_dir_recursive_absolute(m._shot_dir)
	var img := m.get_viewport().get_texture().get_image()
	var path := m._shot_dir.path_join("L%d_%s.png" % [m._shot_level, tag])
	img.save_png(path)
	print("SHOT_SAVED: ", ProjectSettings.globalize_path(path))
