extends RefCounted
## 开发验证钩子执行器(统合重构终案 Sprint 4 自 main.gd 迁出):
## --*shot / --autotest / --recalltest / --laneshot / --tourshot 等
## 命令行分镜与自测的唯一实现。经 Main._dev_harness() 软引用装载,
## 导出包剥离 scripts/dev/* 后 load 失败 → 钩子整体关闭;
## 旗标解析留守 Main(_parse_auto_shot),本文件只管执行。
## run_perf_log:Android debug 真机自动 PERF 日志(每秒一行监视数据,
## adb logcat 抓取;ROADMAP §5)。原留守 Main,v0.31.1 随死代码清扫迁入。

var m: Main


## 性能基线日志(原 Main._run_perf_log,零改动迁入):每秒向 stdout 打
## 一行 Performance 监视数据。
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
		0: [["spawn", Vector2(300, 855)],
			["ski", Vector2(950, 820)],
			["pushbox", Vector2(1750, 820)],
			["speedgate", Vector2(2200, 820)],
			["launchpad", Vector2(2450, 820)],
			["portal", Vector2(3300, 760)],
			["piano", Vector2(3800, 830)],
			["dodge", Vector2(4280, 700)],
			["airgate", Vector2(5000, 820)],
			["ramp_top", Vector2(5300, 620)],
			["exits", Vector2(5950, 826)],
			["wuwu_niche", Vector2(6220, 560)],
			["ceiling_road", Vector2(6150, 225)]],
	}
	var waypoints: Array = tours.get(m._shot_level, [["spawn", Vector2(300, 850)]])
	for wp in waypoints:
		if m.players.is_empty():
			break
		var p: Player = m.players[m.view_slot()]
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
	m.archive_panel._sel["bld"] = 6   # 梁(v0.36 Kit 构件补绘首批)
	m.archive_panel._refresh_codex("bld")
	await m.get_tree().create_timer(0.4).timeout
	await _shot("panel_bld_beam")
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
	var p: Player = m.players[m.view_slot()]
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
	var jie: Player = m.players[m.view_slot()]
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
	var bian: Player = m.players[m.view_slot()]
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
	# ④ 记录点信标(v0.36 实装):触碰登记(体身份键入账)→ 召回回信标落点
	m.switch_to_geo(0)
	await m.get_tree().physics_frame
	var cpr: Player = m.players[m.view_slot()]
	var bpos: Vector2 = LevelData.LEVELS[0].checkpoints[0]["pos"]
	cpr.position = bpos
	await m.get_tree().physics_frame
	await m.get_tree().physics_frame
	await m.get_tree().physics_frame
	var ok_cp: bool = m.roster.checkpoints.has(cpr.body_key())
	await _recall_keypress()
	ok_cp = ok_cp and cpr.position.distance_to(bpos) < 2.0 and not cpr.dying
	print("RECALLTEST 信标 ", "PASS" if ok_cp else "FAIL",
		" pos=", cpr.position, " beacon=", bpos)
	if not ok_cp:
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


## N1 同屏双人冒烟自测(--dualtest,headless):双活绑定 / 分区输入 /
## 双活禁切 / 死亡保操控 / 双体到站登记,五链路一次走完。
func run_dual_test() -> void:
	m.start_level_dual()
	await m.get_tree().create_timer(0.5).timeout
	var fails := 0
	var p1: Player = m.players[0]   # 疾 → P1 槽
	var p2: Player = m.players[1]   # 跃 → P2 槽
	# ① 双活绑定:双开 is_active + 各自输入槽
	var ok_bind: bool = m.dual_mode and p1.is_active and p2.is_active \
		and p1.input_source.slot == 0 and p2.input_source.slot == 1
	print("DUALTEST bind ", "PASS" if ok_bind else "FAIL",
		" dual=", m.dual_mode, " p1=", p1.is_active, " p2=", p2.is_active)
	if not ok_bind:
		fails += 1
	# ② 分区输入:P1 右行 / P2 左行,两具互不牵连
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
	# ③ 双活禁切:chips 直达在双活下应无效(双开不受扰动)
	m.switch_to_geo(2)
	await m.get_tree().physics_frame
	var ok_noswitch: bool = not m.players[2].is_active \
		and p1.is_active and p2.is_active
	print("DUALTEST noswitch ", "PASS" if ok_noswitch else "FAIL")
	if not ok_noswitch:
		fails += 1
	# ④ 死亡保操控:P2 的跃坠杀 → 重生回出生点,is_active 不丢
	p2.position = Vector2(p2.position.x, 1500.0)   # kill_y = 1400
	await m.get_tree().create_timer(1.2).timeout
	var ok_death: bool = not p2.dying and p2.is_active \
		and p2.position.distance_to(p2.spawn_pos) < 32.0   # 32px:含落地安放的物理沉降
	print("DUALTEST death ", "PASS" if ok_death else "FAIL",
		" pos=", p2.position, " spawn=", p2.spawn_pos)
	if not ok_death:
		fails += 1
	# ⑤ 双体到站登记:各自进各自门;全员未齐不误通关
	var d0: ExitDoor = m._doors.get(p1.index)
	var d1: ExitDoor = m._doors.get(p2.index)
	p1.position = d0.center
	p2.position = d1.center
	await m.get_tree().create_timer(0.4).timeout
	var ok_arrive: bool = p1.arrived and p2.arrived \
		and m._state == Main.State.PLAYING
	print("DUALTEST arrive ", "PASS" if ok_arrive else "FAIL",
		" p1=", p1.arrived, " p2=", p2.arrived)
	if not ok_arrive:
		fails += 1
	print("DUALTEST ALL ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	m.get_tree().quit(0 if fails == 0 else 1)


## 同屏双人视觉分镜(--dualshot):双活开局后连拍——chips 双人描边
## 高亮(P1 纸白 / P2 橙)、双人双取景构图、双体芯片「界 / 边」并示。
func run_dual_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
	m.start_level_dual()
	await m.get_tree().create_timer(1.2).timeout
	await _shot("dual_spawn")
	# P1 右行 / P2 左行各走一段:双取景拉开 + 分区输入的可见证据
	Input.action_press("p1_move_right")
	Input.action_press("p2_move_left")
	await m.get_tree().create_timer(0.8).timeout
	Input.action_release("p1_move_right")
	Input.action_release("p2_move_left")
	await m.get_tree().create_timer(0.4).timeout
	await _shot("dual_spread")
	m.get_tree().quit()


## N2 客机自动化(--netjoin,headless 可用):广播发现附近房间 →
## 自动加入第一个版本兼容的房间 → 等待主机开演(net.md §4.1:PC 客机
## 发广播,手机当主机)。
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


## N2 房间流程页分镜(--roomshot):双人联接选择面板 → 房间四页
## (选择 / 创建等待 / 加入搜索),配 UI 图册与 ui-flow 页面规范对照。
func run_room_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
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
	# 选图 / 选角两页(v0.36.0,net.md §8):主机定档 → 双方认领态分镜
	# (headless 单机 = 仅主机侧"我方"认领,未认领位照常渲染)
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


## N2 主机自动化(--netauto,headless 可用):自动建房,对手加入即自动
## 开演(首版固定试炼场)——供真机联测时 PC 端无人值守当主机。
func run_net_auto() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._state = Main.State.ROOM
	m._menu.visible = false
	m.net_room_layer.open()
	m.net_room_layer.autostart_host()
	# 等对手加入 → 自动开演(最多 120s)
	for i in 240:
		await m.get_tree().create_timer(0.5).timeout
		if NetSession.I != null and NetSession.I.in_game():
			print("NETAUTO: in game, done")
			return
		if NetSession.I != null and NetSession.I.is_host() \
				and NetSession.I.member_count() >= NetConfig.MAX_PLAYERS \
				and m.net_room_layer.visible:
			m.net_room_layer.visible = false   # 同「开演」钮:先收房间页
			NetSession.I.host_start_level(0)
	print("NETAUTO: timeout waiting for peer")
	m.get_tree().quit(1)


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


## 点按粒子反馈分镜(--tapshot):在屏内三点程序化触发 TouchControls
## 的触点反馈(菱形回包 + 方块迸散),验证爆发与消散全程(开发验收用)。
func run_tap_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = "res://.shots"
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


## JSON 试水关出生点连拍:验证双体渲染 / 磁力边界 / 双门(开发用)。
func run_trial_shot() -> void:
	if m._shot_dir.is_empty():
		m._shot_dir = ".shots_v16"
	m.start_level(0, false)
	await m.get_tree().create_timer(0.4).timeout
	await _shot("trial_spawn")
	await m.get_tree().create_timer(0.8).timeout
	await _shot("trial_rest")
	# 信标分镜(v0.36):传送至记录点信标,验证实体渲染与触碰亮灯
	var bpos: Vector2 = LevelData.LEVELS[0].checkpoints[0]["pos"]
	var p: Player = m.players[m.view_slot()]
	p.position = bpos
	await m.get_tree().create_timer(0.6).timeout
	await _shot("trial_checkpoint")
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
			print("TEST: pos=", m.players[m.view_slot()].position,
				" onFloor=", m.players[m.view_slot()].is_on_floor())
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
