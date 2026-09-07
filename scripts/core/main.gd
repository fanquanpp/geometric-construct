class_name Main
extends Node2D
## 游戏总控:菜单 ↔ 关卡流转、几何体切换、进度存档、几何档案 / 剧情入口、自动测试钩子。

static var I  # Main 单例

enum State { MENU, PLAYING, PAUSED, TRANSITION, WIN }

var _state: State = State.MENU

var _level_root: Node2D
var _hud: Hud
var _menu: MenuLayer
var _pause: PauseMenu
var geometry_panel: GeometryPanel
var settings_panel: SettingsPanel
var touch_controls: TouchControls
var _save: SaveManager
var _current := -1
var _unlocked := 0
var _active_slot := 0
var _auto_shot := false
var debug_move := Vector2.ZERO
var debug_jump := false
var frame_no := 0

var players: Array = []
var camera_rig = null            # LevelBuilder.CameraRig,切换时触发过渡动画
var _doors := {}                 # geo_index -> ExitDoor
var _complete_seq := 0           # 通关链序列号:重开/换关时作废待执行的自动流转

# ———— 自动化测试 ————
## 测试模式:屏蔽真实键盘的切换/重开/暂停输入,避免外部按键干扰自动验证。
var debug_solo := false

var _held_keys := {}

# ———— 自动截图(开发调试) ————
var _shot_level := 0
var _shot_dir := ""
var _door_shot := false
var _panel_shot := false
var _set_shot := false
var _act_shot := false
var _act_shot_idx := 0
var _boot_shot := false
var _intro_shot := false
var _story_shot := false
var _tour_shot := false
var _auto_test := false


func _ready() -> void:
	I = self
	Ui.init_font()
	add_child(Backdrop.new())
	Sfx.init(self)
	var amb := Ambience.new()
	amb.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(amb)

	# 设置先于全部 UI 加载并应用(轮盘模式 / 音量在面板创建前就位)
	SettingsManager.load_settings()
	SettingsManager.apply_all()

	# TouchControls 先于 HUD 创建:HUD 就能感知触屏模式(提示条 / 坐标位置)
	touch_controls = TouchControls.new()
	add_child(touch_controls)
	_hud = Hud.new()
	add_child(_hud)
	_menu = MenuLayer.new()
	_menu.m = self
	add_child(_menu)
	geometry_panel = GeometryPanel.new()
	add_child(geometry_panel)
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	_pause = PauseMenu.new()
	_pause.m = self
	add_child(_pause)

	_save = SaveManager.new()
	_save.load_save()
	_save.clamp_unlocked(LevelData.LEVELS.size() - 1)
	_unlocked = _save.unlocked
	_menu.set_unlocked(_unlocked)
	_menu.visible = true
	_hud.visible = false

	# 开屏动画:游戏名揭示(点按可跳过),盖在标题菜单入场之上
	add_child(BootIntro.new())

	_parse_auto_shot()


func _exit_tree() -> void:
	if I == self:
		I = null


# ———————————————— 场景与流程 ————————————————

func _show_menu() -> void:
	_state = State.MENU
	_clear_level()
	_hud.visible = false
	touch_controls.set_in_game(false)
	geometry_panel.close()
	settings_panel.close()
	_menu.visible = true
	_menu.set_unlocked(_unlocked)


func _clear_level() -> void:
	players.clear()
	camera_rig = null
	_doors.clear()
	if _level_root != null:
		_level_root.queue_free()
		_level_root = null


func start_level(index: int, intro := true) -> void:
	if debug_solo:
		print("TRACE start_level(", index, ") state_was=", State.keys()[_state])
	_complete_seq += 1    # 作废任何待执行的通关自动流转(重开/换关不被拽走)
	get_tree().paused = false
	if _pause != null:
		_pause.close()
	_current = clampi(index, 0, LevelData.LEVELS.size() - 1)
	_clear_level()
	_doors.clear()
	_level_root = LevelBuilder.build(LevelData.LEVELS[_current])
	add_child(_level_root)
	_collect_players()
	_state = State.PLAYING
	Sfx.play("start")

	_menu.visible = false
	_menu.close_act_panel()
	geometry_panel.close()
	settings_panel.close()
	_hud.visible = true
	touch_controls.set_in_game(true)
	# 单人阵容没有"切换"可言:隐藏左侧切换钮,避免无效按键
	touch_controls.set_switch_available(LevelData.LEVELS[_current].roster.size() > 1)
	_hud.show_win(false)
	_hud.set_level_info(_current, LevelData.LEVELS[_current])
	_refresh_roster()
	_hud.fade_from_black()
	if intro:
		_hud.show_intro(_current, LevelData.LEVELS[_current])
		var focus: GeometryDef = Geometries.get_def(LevelData.LEVELS[_current].focus)
		_hud.narration(focus.quote, focus.color, 3.8)
	_switch_to(0, true)


func _collect_players() -> void:
	players.clear()
	_doors.clear()
	for n in _level_root.get_children():
		if n is Player:
			players.append(n as Player)
		elif n is ExitDoor:
			_doors[(n as ExitDoor).geo_index] = n
	players.sort_custom(func(a, b) -> bool: return a.index < b.index)
	_active_slot = 0


# ———————————————— 几何体切换 ————————————————

## 切换操控:已到达终点门待命的几何体仍然可以被选中(终点激活前不收取);
## 只跳过正在进门 / 死亡中的几何体。
func _switch_to(slot: int, quiet := false) -> void:
	if _state != State.PLAYING or players.is_empty():
		return
	var n := players.size()
	# 第一遍:找健康几何体(含已到达待命者);第二遍:接受正在重生中的几何体
	for pass_i in 2:
		for k in n:
			var p: Player = players[(slot + k) % n]
			var ok: bool = (not p.in_exit and not p.dying) \
				if pass_i == 0 else (not p.in_exit)
			if not ok:
				continue
			_active_slot = players.find(p)
			for j in n:
				players[j].is_active = j == _active_slot
			_refresh_roster()
			if not quiet:
				Sfx.play("switch")
				_hud.narration(p.def.quote, p.def.color)
				if camera_rig != null:
					camera_rig.on_switch()
			return


func _cycle_slot(dir: int) -> void:
	if players.is_empty():
		return
	_switch_to(((_active_slot + dir) % players.size() + players.size()) % players.size())


func _refresh_roster() -> void:
	var mask := 0
	for p in players:
		if p.in_exit or p.arrived:
			mask |= 1 << p.index
	var active: int = players[_active_slot].index \
		if (_active_slot >= 0 and _active_slot < players.size()) else -1
	_hud.refresh_roster(LevelData.LEVELS[_current].roster, active, mask)


# ———————————————— 输入 ————————————————

## 按键边沿检测:仅在按下瞬间返回 true,避免按住重复触发。
func _key_pressed(k: Key) -> bool:
	var now := Input.is_physical_key_pressed(k)
	if now:
		if not _held_keys.has(k):
			_held_keys[k] = true
			return true
	else:
		_held_keys.erase(k)
	return false


func _physics_process(_delta: float) -> void:
	frame_no += 1
	if geometry_panel.is_open or settings_panel.is_open:
		return
	if _state == State.PLAYING:
		_check_deaths()
		if debug_solo:
			return
		# 切换几何体(含已到达待命者):Tab / Q / E / 1-4,Shift+Tab 反向
		if Input.is_action_just_pressed("switch_next"):
			_cycle_slot(-1 if Input.is_physical_key_pressed(KEY_SHIFT) else 1)
		if Input.is_action_just_pressed("switch_prev"):
			_cycle_slot(-1)

		for i in mini(players.size(), 4):
			if _key_pressed(KEY_1 + i) and i < LevelData.LEVELS[_current].roster.size():
				_switch_to(i)

		if Input.is_action_just_pressed("restart"):
			_restart_level()
		if Input.is_action_just_pressed("pause"):
			_open_pause()
	elif _state == State.MENU:
		if debug_solo:
			return
		# 数字键:二级菜单开着时直达该_choose剧目内的场次;否则快速选剧目
		# (1=序章开演 → 进二级菜单,2-4 未上演幕同样给出 toast 反馈);
		# C 打开几何档案;S 打开设置;Esc 关二级菜单 / 退出游戏
		if _menu.is_act_panel_open():
			for i in 4:
				if _key_pressed(KEY_1 + i):
					_menu.act_level_digit(i + 1)
			if Input.is_action_just_pressed("ui_cancel"):
				_menu.close_act_panel()
			return
		for i in LevelData.ACTS.size():
			if _key_pressed(KEY_1 + i):
				_menu.try_open_act(i)
		if _key_pressed(KEY_C):
			open_geometry_panel()
		if _key_pressed(KEY_S):
			open_settings()
		if Input.is_action_just_pressed("ui_cancel"):
			get_tree().quit()
	elif _state == State.WIN:
		if debug_solo:
			return
		if Input.is_action_just_pressed("restart"):
			start_level(0)
		if Input.is_action_just_pressed("pause"):
			_show_menu()


func _check_deaths() -> void:
	var def: LevelDef = LevelData.LEVELS[_current]
	for p in players:
		if p.dying or p.in_exit or p.arrived:
			continue
		# 死亡判定按各几何体"当前"重力方向(置换会翻转)
		if p.gravity_dir > 0 and p.position.y > def.kill_y:
			p.die()
		elif p.gravity_dir < 0 and p.position.y < def.top_kill_y:
			p.die()


func _restart_level() -> void:
	if _state != State.PLAYING:
		return
	Sfx.play("restart")
	_hud.fade_to_black(0.25, func() -> void: start_level(_current))
	_state = State.TRANSITION


# ———————————————— 暂停与菜单回调 ————————————————

func _open_pause() -> void:
	if _state != State.PLAYING:
		return
	_state = State.PAUSED
	get_tree().paused = true
	_pause.open()


## 菜单/暂停面板回调:开始下一章旅程。
func start_game() -> void:
	if _state != State.MENU:
		return
	start_level(_unlocked)


func start_chapter(index: int) -> void:
	if _state != State.MENU:
		return
	start_level(index)


func open_geometry_panel() -> void:
	geometry_panel.open(_unlocked)


## 打开设置面板(标题菜单 / 暂停菜单共用)。
func open_settings() -> void:
	settings_panel.open()


func resume_game() -> void:
	Sfx.play("resume")
	get_tree().paused = false
	_pause.close()
	if _state == State.PAUSED:
		_state = State.PLAYING


func restart_from_pause() -> void:
	get_tree().paused = false
	_pause.close()
	if _state == State.PAUSED:
		_state = State.PLAYING
		_restart_level()


func quit_to_menu() -> void:
	Sfx.play("ui_close")
	get_tree().paused = false
	_pause.close()
	_show_menu()


# ———————————————— 剧情文字(konado) ————————————————

## 播放剧情:暂停世界,叠放 Konado 对话层;结束后恢复。
## kind:"prologue" 序幕(标题菜单)/ "epilogue" 尾声(通关画面)。
func show_story(kind: String) -> void:
	var story := StoryLayer.new()
	story.m = self
	add_child(story)
	story.play("res://story/%s.ks" % kind)


func open_prologue() -> void:
	if _state != State.MENU:
		return
	get_tree().paused = true
	show_story("prologue")


func on_story_finished() -> void:
	get_tree().paused = false


# ———————————————— 事件回调 ————————————————

func on_player_died(p: Player) -> void:
	if _auto_test:
		print("TEST: ", p.def.name, " died/respawned")
	if _state == State.PLAYING:
		_cycle_slot(1)
	_refresh_roster()


## 到达专属终点门:原地待命(仍可被切换控制),全员到齐后终点激活。
func on_player_arrived(p: Player) -> void:
	if _auto_test:
		print("TEST: ", p.def.name, " arrived at exit")
	if _state != State.PLAYING:
		return
	# 当前操控者到站且还有未到站的同伴 → 自动切给下一位;全员到齐则保持视角
	var all_arrived := true
	for q in players:
		if not q.arrived:
			all_arrived = false
			break
	if not all_arrived and _active_slot >= 0 and _active_slot < players.size() \
			and players[_active_slot] == p:
		_cycle_slot(1)
	_refresh_roster()
	_check_all_arrived()


## 已到站几何体离开门区:取消到站(终点未激活时随时可以再回来)。
func on_player_departed(p: Player) -> void:
	if _auto_test:
		print("TEST: ", p.def.name, " left the exit")
	_refresh_roster()


func on_player_exited(p: Player) -> void:
	if _auto_test:
		print("TEST: ", p.def.name, " entered exit")
	_refresh_roster()


## 全员到站 → 终点激活:封印各门 → 依次吸入各自的终点门 → 结算。
func _check_all_arrived() -> void:
	if _state != State.PLAYING:
		return
	for p in players:
		if not p.arrived:
			return
	# 终点激活:封印门区,到达状态不再可撤销
	for idx in _doors:
		var d: ExitDoor = _doors[idx]
		if is_instance_valid(d):
			d.sealed = true
	for i in players.size():
		var p: Player = players[i]
		var door: ExitDoor = _doors.get(p.index)
		if door == null:
			continue
		var delay := 0.08 + 0.18 * i
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(p) and is_instance_valid(door):
				p.enter_exit(door))
	get_tree().create_timer(0.08 + 0.18 * players.size() + 0.55).timeout.connect(
		func() -> void:
			if _state == State.PLAYING:
				_check_complete())


## 重生结束时,若没有任何几何体处于操控中,则自动补一次切换。
func on_respawn_done() -> void:
	if _state != State.PLAYING:
		return
	for p in players:
		if p.is_active:
			return
	_cycle_slot(1)


## 加速门首次强化时的旁白提示。
func notify_buff(mult: float, gd: GeometryDef) -> void:
	if _hud != null:
		_hud.narration("加速门 · 速度上限提升至 %.1f×" % mult, gd.color, 2.4)


## 曲面强化首次生效时的旁白提示(只提示效果,不逐帧打扰)。
func notify_ramp(gd: GeometryDef) -> void:
	if _hud != null:
		_hud.narration("曲面 · 速度 ×1.5,重量减半(离开后 1.5 秒)", gd.color, 1.8)


func _check_complete() -> void:
	for p in players:
		if not p.in_exit:
			return

	_state = State.TRANSITION
	Sfx.play("complete")
	if _auto_test:
		print("TEST: LEVEL COMPLETE ", _current)
	_hud.show_complete("归位。" if _current == LevelData.LEVELS.size() - 1 else "通过。")
	if _current + 1 > _unlocked:
		_unlocked = mini(_current + 1, LevelData.LEVELS.size() - 1)
		_save.unlocked = _unlocked
		_save.write_save()
	# 延迟流转:期间重开/换关会递增序列号,令本次流转作废
	_complete_seq += 1
	var seq := _complete_seq
	get_tree().create_timer(2.1).timeout.connect(func() -> void:
		if seq == _complete_seq:
			_after_complete())


func _after_complete() -> void:
	if _current >= LevelData.LEVELS.size() - 1:
		_state = State.WIN
		Sfx.play("fanfare")
		_hud.show_win(true)
		# 通关尾声剧情(仅一次,Esc/对话结束返回)
		if not get_tree().paused:
			get_tree().paused = true
			show_story("epilogue")
	else:
		_hud.fade_to_black(0.5, func() -> void: start_level(_current + 1))


# ———————————————— 自动截图(开发调试) ————————————————

func _parse_auto_shot() -> void:
	var args := OS.get_cmdline_user_args()
	for raw in args:
		if raw.begins_with("--autoshot="):
			_auto_shot = true
			_shot_level = raw.substr(11).to_int()
		elif raw.begins_with("--shotdir="):
			_shot_dir = raw.substr(10)
		elif raw.begins_with("--autotest="):
			_auto_test = true
			_shot_level = raw.substr(11).to_int()
		elif raw == "--menushot":
			_auto_shot = true
		elif raw == "--doorshot":
			_door_shot = true
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
		elif raw == "--storyshot":
			_story_shot = true
		elif raw == "--tourshot":
			_tour_shot = true
		elif raw.begins_with("--level="):
			_shot_level = raw.substr(8).to_int()
	if _auto_shot and _shot_dir.is_empty():
		_shot_dir = "C:/Atian/Project/shots_bm"
	if _auto_shot and args.has("--menushot"):
		_run_menu_shot()
	# --introshot / --storyshot 自带开局流程,跳过通用 autoshot 以免抢关卡
	if _auto_shot and not args.has("--menushot") \
			and not _intro_shot and not _story_shot:
		_run_auto_shot()
	if _door_shot:
		_run_door_shot()
	if _panel_shot:
		_run_panel_shot()
	if _set_shot:
		_run_set_shot()
	if _act_shot:
		_run_actshot()
	if _boot_shot:
		_run_boot_shot()
	if _intro_shot:
		_run_intro_shot()
	if _story_shot:
		_run_story_shot()
	if _tour_shot:
		_run_tour_shot()
	if _auto_test:
		_run_auto_test()


## 截取设置面板。
func _run_set_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "C:/Atian/Project/shots_bm"
	await get_tree().create_timer(0.6).timeout
	settings_panel.open()
	await get_tree().create_timer(0.5).timeout
	await _shot("settings")
	get_tree().quit()


## 截取剧目二级菜单(关卡列)。
func _run_actshot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "C:/Atian/Project/shots_bm"
	await get_tree().create_timer(0.6).timeout
	_menu.try_open_act(_act_shot_idx)
	await get_tree().create_timer(0.6).timeout
	await _shot("act_panel")
	get_tree().quit()


## 截取开屏动画(标题落定瞬间)。
func _run_boot_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "C:/Atian/Project/shots_bm"
	await get_tree().create_timer(1.35).timeout
	await _shot("boot")
	await get_tree().create_timer(1.8).timeout
	await _shot("boot_end")
	get_tree().quit()


## 截取章节开场卡。
func _run_intro_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "C:/Atian/Project/shots_bm"
	start_level(_shot_level, true)
	await get_tree().create_timer(1.2).timeout
	await _shot("intro")
	get_tree().quit()


## 截取剧情对话框(序幕)。
## 刻意先开局把相机带到关卡深处再开对话:验证变暗遮罩不再跟随相机
## (follow_viewport 关闭后,遮罩恒定铺满屏幕,左右两侧都不会漏光)。
func _run_story_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "C:/Atian/Project/shots_bm"
	await get_tree().create_timer(0.6).timeout
	start_level(0, false)
	await get_tree().create_timer(0.3).timeout
	if not players.is_empty():
		players[0].position = Vector2(2000, 850)
		players[0].velocity = Vector2.ZERO
	await get_tree().create_timer(0.4).timeout
	get_tree().paused = true
	show_story("prologue")
	await get_tree().create_timer(1.6).timeout
	await _shot("story")
	get_tree().quit()


## 巡航截图:沿大型关卡的关键节拍传送受控几何体,逐点截图验收。
## 节拍表按当前关卡下标内建;新巨构关卡在此追加自己的节拍行。
func _run_tour_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "C:/Atian/Project/shots_bm"
	_unlocked = LevelData.LEVELS.size() - 1
	start_level(_shot_level, false)
	await get_tree().create_timer(0.4).timeout
	var tours := {
		4: [["spawn", Vector2(300, 2700)],
			["terraces", Vector2(2400, 2000)],
			["pillar", Vector2(4300, 1400)],
			["beam", Vector2(5600, 330)],
			["bridge", Vector2(5900, 900)],
			["gap", Vector2(6900, 800)],
			["tower", Vector2(8300, 900)]],
	}
	var waypoints: Array = tours.get(_shot_level, [["spawn", Vector2(300, 850)]])
	for wp in waypoints:
		if players.is_empty():
			break
		var p: Player = players[_active_slot]
		p.position = wp[1]
		p.velocity = Vector2.ZERO
		await get_tree().create_timer(0.55).timeout
		await _shot("tour_" + str(wp[0]))
	get_tree().quit()


## 截取几何档案页(全部页)。
func _run_panel_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "C:/Atian/Project/shots_bm"
	await get_tree().create_timer(0.6).timeout
	geometry_panel.open(0)
	await get_tree().create_timer(0.5).timeout
	await _shot("panel_char0")
	for page in range(1, Geometries.ALL.size()):
		geometry_panel._switch(1)
		await get_tree().create_timer(0.4).timeout
		await _shot("panel_char%d" % page)
	get_tree().quit()


## 传送到出口门前,验证门的渲染与过关文字。
func _run_door_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "C:/Atian/Project/shots_bm"
	start_level(0, false)
	await get_tree().create_timer(0.3).timeout
	players[0].position = Vector2(1430, 968)
	players[0].velocity = Vector2.ZERO
	await get_tree().create_timer(0.25).timeout
	await _shot("door")
	await get_tree().create_timer(1.1).timeout
	await _shot("complete")
	get_tree().quit()


## 截取标题菜单画面。
func _run_menu_shot() -> void:
	await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var img := get_viewport().get_texture().get_image()
	var path := _shot_dir.path_join("menu.png")
	img.save_png(path)
	print("SHOT_SAVED: ", ProjectSettings.globalize_path(path))
	get_tree().quit()


## 自动通关测试:一直向右走 + 周期性跳跃,打印关键事件直到超时。
func _run_auto_test() -> void:
	_unlocked = LevelData.LEVELS.size() - 1
	print("TEST: begin level ", _shot_level)
	start_level(_shot_level, false)
	debug_move = Vector2(1, 0)
	var deadline := Time.get_ticks_msec() + 60000
	var tick := 0
	while Time.get_ticks_msec() < deadline and _state != State.WIN:
		debug_jump = true
		await get_tree().create_timer(0.25).timeout
		debug_jump = false
		await get_tree().create_timer(0.55).timeout
		tick += 1
		if tick % 3 == 0 and players.size() > 0:
			print("TEST: pos=", players[_active_slot].position,
				" onFloor=", players[_active_slot].is_on_floor())
	print("TEST: end state=", State.keys()[_state])
	get_tree().quit()


func _run_auto_shot() -> void:
	_unlocked = LevelData.LEVELS.size() - 1
	start_level(_shot_level, false)
	await get_tree().create_timer(1.0).timeout
	await _shot("a")

	# 走一段 + 冲刺 + 跳一次(再补一跳二段),验证物理与出口渲染
	debug_move = Vector2(1, 0)
	await get_tree().create_timer(5.0).timeout
	debug_move = Vector2.ZERO
	debug_jump = true
	await get_tree().create_timer(0.16).timeout
	debug_jump = false
	await get_tree().create_timer(0.3).timeout
	debug_jump = true
	await get_tree().create_timer(0.16).timeout
	debug_jump = false
	await get_tree().create_timer(1.1).timeout
	await _shot("b")
	get_tree().quit()


func _shot(tag: String) -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var img := get_viewport().get_texture().get_image()
	var path := _shot_dir.path_join("L%d_%s.png" % [_shot_level, tag])
	img.save_png(path)
	print("SHOT_SAVED: ", ProjectSettings.globalize_path(path))
