class_name Main
extends Node2D


enum State { MENU, ROOM, PLAYING, PAUSED, TRANSITION, WIN }


# v0.61.0 节点化:16 子系统常驻场景全部改在 Main.tscn 编辑器组装
# (R1:场景组合优于脚本拼树);本脚本只做接线与运行期分派。
# 装配时序契约:设置/字体/Main.I 前置 _enter_tree(先于全部子节点
# _ready);子节点间 _ready 顺序 = 场景子节点顺序,勿重排。

static var I


## 唯一正规构造入口:Main 的子系统全部是 Main.tscn 里的场景子节点,
## 裸 Main.new() 没有子树(旧代码装配时代的产物),一律走本工厂。
static func create() -> Main:
	var ps: PackedScene = load("res://scenes/Main.tscn")
	return ps.instantiate() as Main


var _state: State = State.MENU

var _level_root: Node2D
@onready var _hud: Hud = $Hud
@onready var _menu: MenuLayer = $MenuLayer
@onready var _pause: PauseMenu = $PauseMenu
@onready var archive_panel: ArchivePanel = $ArchivePanel
@onready var controls_panel: ControlsPanel = $ControlsPanel
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var touch_controls: TouchControls = $TouchControls
@onready var _save: SaveManager = SaveManager.new()
@onready var _ambience: Ambience = $Ambience


var _current := -1:
	get:
		return game_flow.current if game_flow != null else -1
	set(value):
		if game_flow != null:
			game_flow.current = value
var _unlocked := 0
var _auto_shot := false
var debug_move := Vector2.ZERO
var debug_jump := false

var debug_zoom := 0.0
var frame_no := 0

@onready var roster: RosterController = $RosterController
@onready var game_flow: GameFlow = $GameFlow
@onready var race: RaceController = $RaceController
@onready var ghost: GhostRecorder = $GhostRecorder
@onready var backdrop: Backdrop = $Backdrop
@onready var net_session: NetSession = $NetSession
@onready var net_room_layer: NetRoomLayer = $NetRoomLayer
var players: Array:
	get:
		return roster.players
var camera_rig = null
var _doors: Dictionary:
	get:
		return roster.doors


var _level_info: Dictionary:
	get:
		return game_flow.level_info if game_flow != null else null
	set(value):
		if game_flow != null:
			game_flow.level_info = value


var debug_solo := false

var _held_keys := {}
var _panel_opener := ""


var _auto_test := false
var dev_run := false


func _enter_tree() -> void:
	# 前置于全部子节点 _ready:子场景(设置面板/触屏轮盘/天幕门控/
	# net_session._m 等)就绪期即读到已载入的设置与 Main.I。
	I = self
	Ui.init_font()
	SettingsManager.load_settings()
	SettingsManager.apply_all_at_boot()


func _ready() -> void:
	# 场景结构在 Main.tscn(16 子系统按装配顺序入场景);此处只做
	# 接线。子节点 _ready 已全部先行,回引与信号在此挂接。
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	Sfx.init(self)
	backdrop.refresh_gate()
	_setup_dual_input()

	roster.main = self
	game_flow.main = self
	race.main = self
	ghost.main = self
	_menu.m = self
	_pause.m = self
	net_room_layer.m = self

	_hud.chip_tapped.connect(switch_to_geo)
	_hud.race_rematch_requested.connect(func() -> void:
		if race != null and race.phase == RaceController.Phase.FINISHED:
			race.rematch())
	# 竞速 3-2-1 阶梯音(3→2→1 对应 C5→D5→E5 上行)+ GO 用 C6 高音。
	race.countdown.connect(func(n: int) -> void:
		Sfx.play_note(["C5", "D5", "E5"][clampi(3 - n, 0, 2)]))
	race.countdown.connect(_hud.race_countdown)
	race.race_go.connect(func() -> void: Sfx.play_note("C6", true))
	race.race_go.connect(_hud.race_go)
	race.race_finished.connect(_on_race_finished)

	# 面板关闭 → 焦点归还打开方(菜单记忆位 / 暂停「继续」)
	archive_panel.closed.connect(_on_top_panel_closed)
	controls_panel.closed.connect(_on_top_panel_closed)
	settings_panel.closed.connect(_on_top_panel_closed)

	_save.load_save()
	_save.clamp_unlocked(LevelData.campaign_last())
	_unlocked = _save.unlocked
	# unlock_all 构建特性(测试发布包):全解锁只覆写「选关显示档」,
	# 不写回存档;继续键仍按真实存档进度起跳,不直跳终场。
	if OS.has_feature("unlock_all"):
		_unlocked = LevelData.campaign_last()
	_menu.set_unlocked(_unlocked)
	_menu.visible = true
	_hud.visible = false

	_parse_auto_shot()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_android_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _state == State.PLAYING and not _auto_test and _is_local_session():
			_open_pause()


func _is_local_session() -> bool:
	return NetSession.I == null or not NetSession.I.in_game()


func _android_back() -> void:
	if settings_panel.is_open:
		settings_panel.close()
	elif controls_panel.is_open:
		controls_panel.go_back()
	elif archive_panel.is_open:
		archive_panel.go_back()
	elif _state == State.PLAYING:
		_open_pause()
	elif _state == State.PAUSED:
		resume_game()
	elif _state == State.ROOM:
		net_room_layer.back_out()
	elif _state == State.MENU:
		if _menu.is_dual_pick_open():
			_menu.close_dual_pick()
		elif _menu.is_act_panel_open():
			_menu.close_act_panel()
		else:
			get_tree().quit()
	elif _state == State.WIN:
		_return_to_menu()


func _exit_tree() -> void:
	if I == self:
		I = null


func _show_menu() -> void:
	game_flow.show_menu()


func _clear_level() -> void:
	game_flow.clear_level()


func start_level(index: int, intro := true) -> void:
	game_flow.start_level(index, intro)


func _collect_players() -> void:
	game_flow.collect_players()


func view_slot() -> int:
	return roster.view_slot()


func camera_targets() -> Array:
	return roster.camera_targets()


func slot_actions() -> bool:
	return dual_mode


func _setup_dual_input() -> void:
	for action in ["p1_move_left", "p1_move_right", "p1_jump", "p1_sprint",
			"p2_move_left", "p2_move_right", "p2_jump", "p2_sprint"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.4)
	_pkey("p1_move_left", KEY_A)
	_pkey("p1_move_right", KEY_D)
	_pkey("p1_jump", KEY_W)
	_pkey("p1_sprint", KEY_SHIFT)
	_pkey("p2_move_left", KEY_LEFT)
	_pkey("p2_move_right", KEY_RIGHT)
	_pkey("p2_jump", KEY_UP)
	_pkey("p2_sprint", KEY_CTRL)
	_pjoy()


func _pkey(action: String, key: Key) -> void:
	if InputMap.action_get_events(action).is_empty():
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _pjoy() -> void:
	for slot in 2:
		var move_l := InputEventJoypadMotion.new()
		move_l.device = slot
		move_l.axis = JOY_AXIS_LEFT_X
		move_l.axis_value = -1.0
		var move_r := InputEventJoypadMotion.new()
		move_r.device = slot
		move_r.axis = JOY_AXIS_LEFT_X
		move_r.axis_value = 1.0
		var jump := InputEventJoypadButton.new()
		jump.device = slot
		jump.button_index = JOY_BUTTON_A
		var sprint := InputEventJoypadMotion.new()
		sprint.device = slot
		sprint.axis = JOY_AXIS_TRIGGER_LEFT
		sprint.axis_value = 1.0
		var prefix := "p1_" if slot == 0 else "p2_"
		_joybind("%smove_left" % prefix, move_l)
		_joybind("%smove_right" % prefix, move_r)
		_joybind("%sjump" % prefix, jump)
		_joybind("%ssprint" % prefix, sprint)


func _joybind(action: String, ev: InputEvent) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion or e is InputEventJoypadButton:
			return
	InputMap.action_add_event(action, ev)


func start_level_dual(index := 0, intro := true) -> void:
	if NetSession.I != null and NetSession.I.is_net():
		return
	# 入口防御(audit ①):目标关没有 ≥2 体(如菜单旧入口固定进 0 号
	# 单体关)直接拒启并 toast 明确提示——P2 无体可分,静默单飞比拒绝
	# 更糟。目标关名册在建体前只能读 LevelData.scene_roster 真值。
	var idx := clampi(index, 0, LevelData.count() - 1)
	if (LevelData.scene_roster(idx) as Array).size() < 2:
		_menu.toast("该场只有一个起点,双人竞速请选双体关卡")
		return
	# 触屏拒启(audit ⑪):触屏模式(--touch 强制或真机)下双人分键
	# 无实体输入面,P2 只能静立无声——同样拒启并提示,不允许无声开局。
	if Adaptive.is_touch_mode():
		_menu.toast("触屏模式暂不支持双人分键,请接键鼠或手柄")
		return
	game_flow.start_level(idx, intro, "", true)
	dual_mode = true

	if roster.players.size() >= 2:
		roster.players[0].input_source = InputSource.local(0)
		roster.players[0].is_active = true
		roster.players[1].input_source = InputSource.local(1)
		roster.players[1].is_active = true
	_refresh_roster()
	race.begin()


func open_net_room() -> void:
	game_flow.open_net_room()


func net_post_setup() -> void:
	game_flow.net_post_setup()


func net_recall(slot: int) -> void:
	game_flow.net_recall(slot)


func net_show_complete() -> void:
	game_flow.net_show_complete()


func net_back_to_room() -> void:
	game_flow.net_back_to_room()


func net_peer_lost() -> void:
	game_flow.net_peer_lost()


func net_host_lost(was_in_game: bool) -> void:
	game_flow.net_host_lost(was_in_game)


func _cycle_slot(dir: int) -> void:
	if dual_mode:
		return

	if NetSession.I != null and NetSession.I.in_game():
		NetSession.I.cycle_own_slot(dir)
		return
	roster.cycle_slot(dir)


func _switch_to(slot: int, quiet := false) -> void:
	roster.switch_to(slot, quiet)


func switch_to_geo(index: int) -> void:
	if NetSession.I != null and NetSession.I.in_game():
		NetSession.I.switch_to_geo(index)
		return
	roster.switch_to_geo(index)


func _refresh_roster() -> void:
	roster.refresh_roster()


func _key_pressed(k: Key) -> bool:
	var now := Input.is_physical_key_pressed(k)
	if now:
		if not _held_keys.has(k):
			_held_keys[k] = true
			return true
	else:
		_held_keys.erase(k)
	return false


func race_input_locked() -> bool:
	return dual_mode and race != null and race.input_locked()


func _on_race_finished(winner: int, t_win_ms: int, t_other_ms: int) -> void:
	var fmt := func(ms: int) -> String:
		return _save.time_text(ms) if ms >= 0 else "—"
	_hud.show_race_result(winner, fmt.call(t_win_ms), fmt.call(t_other_ms),
		[int(race.wins.get(0, 0)), int(race.wins.get(1, 0))])
	ghost.on_complete()
	Sfx.play("fanfare", -4.0)


func _physics_process(_delta: float) -> void:
	frame_no += 1
	if archive_panel.is_open or controls_panel.is_open or settings_panel.is_open:
		return
	if _state == State.PLAYING:

		if _level_info == null:
			return
		if dual_mode and race != null \
				and race.phase == RaceController.Phase.FINISHED:
			if Input.is_action_just_pressed("recall"):
				race.rematch()
			elif Input.is_action_just_pressed("pause") \
					or Input.is_action_just_pressed("ui_cancel"):
				quit_to_menu()
			return
		if dual_mode and race != null \
				and race.phase == RaceController.Phase.COUNTDOWN:
			_check_deaths()
			# 倒计时死窗出口(audit ⑦):与 FINISHED 分支同语——pause/
			# ui_cancel 退出竞速局,3 秒锁输入期不再只能干等 GO。
			# 先 reset 竞速再退,防回菜单后倒计时走完补发一声 GO 音。
			if Input.is_action_just_pressed("pause") \
					or Input.is_action_just_pressed("ui_cancel"):
				race.reset()
				quit_to_menu()
			return
		_check_deaths()
		if debug_solo:
			return

		if Input.is_action_just_pressed("switch_next"):
			_cycle_slot(-1 if Input.is_physical_key_pressed(KEY_SHIFT) else 1)
		if Input.is_action_just_pressed("switch_prev"):
			_cycle_slot(-1)

		for i in mini(_level_info.roster.size(), 5):
			if _key_pressed(KEY_1 + i):
				switch_to_geo(int(_level_info.roster[i]))

		if Input.is_action_just_pressed("recall"):
			recall_active()
		if Input.is_action_just_pressed("pause"):
			_open_pause()
	elif _state == State.ROOM:
		if debug_solo:
			return

		if Input.is_action_just_pressed("ui_cancel"):
			net_room_layer.back_out()
	elif _state == State.MENU:
		if debug_solo:
			return

		if _menu.is_dual_pick_open():
			if Input.is_action_just_pressed("ui_cancel"):
				_menu.close_dual_pick()
			return
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
		if _key_pressed(KEY_K):
			open_controls()
		if _key_pressed(KEY_C):
			open_archive()
		if _key_pressed(KEY_S):
			open_settings()
		# 主菜单退出只认 Esc:手柄 B 已绑 ui_cancel 作全局返回,
		# 在顶层菜单按 B 只应无动作,不得误退游戏(手柄返回语义)。
		if _key_pressed(KEY_ESCAPE):
			get_tree().quit()
	elif _state == State.WIN:
		if debug_solo:
			return
		if Input.is_action_just_pressed("recall"):
			start_level(0)
		if Input.is_action_just_pressed("pause"):
			_return_to_menu()


func _check_deaths() -> void:
	roster.check_deaths(_level_info)


func _restart_level() -> void:
	game_flow.restart_level()


func _open_pause() -> void:
	if _state != State.PLAYING:
		return
	# 联机拒暂停(audit ② main 层硬兜底):暂停树只在本机生效,联机期
	# 主机暂停会把客机状态流悬空——联机一律不暂停,退路只有 quit_to_menu。
	# pause_menu 按钮语义归 ui 包,此层先行硬拦。
	if NetSession.I != null and NetSession.I.is_net():
		return
	_state = State.PAUSED
	get_tree().paused = true
	_pause.open()


func start_game() -> void:
	if _state != State.MENU:
		return
	# 继续/开始按真实存档进度起跳(unlock_all 只放开选关,不改继续语义)
	start_level(_save.unlocked)


func start_chapter(index: int) -> void:
	if _state != State.MENU:
		return
	start_level(index)


func open_archive() -> void:
	_panel_opener = "pause" if _state == State.PAUSED else "menu"
	_menu.set_menu_focusable(false)
	# 几何体页固定从红开(0):_unlocked 是关卡索引,误当几何体索引
	# 传会在通关数增长后落到随机的几何体页。
	archive_panel.open(0)


func open_controls() -> void:
	_panel_opener = "menu"
	_menu.set_menu_focusable(false)
	controls_panel.open()


func open_settings() -> void:
	_panel_opener = "pause" if _state == State.PAUSED else "menu"
	_menu.set_menu_focusable(false)
	settings_panel.open()


func _on_top_panel_closed() -> void:
	if _panel_opener == "pause" and _state == State.PAUSED:
		_pause.grab_resume()
	elif _state == State.MENU:
		_menu.set_menu_focusable(true)
	_panel_opener = ""


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
		# 双人竞速正规重开=rematch(局分保留):game_flow.restart_level 对
		# dual 硬拒(v0.70 双护栏),此处若仍走 _restart_level 即静默死按钮。
		if dual_mode:
			race.rematch()
		else:
			_restart_level()


func quit_to_menu() -> void:
	Sfx.play("ui_close")
	get_tree().paused = false
	_pause.close()

	if NetSession.I != null and NetSession.I.is_net():
		NetSession.I.leave("")
		_hud.set_net_badge("")
	_return_to_menu()


func _return_to_menu() -> void:
	game_flow.return_to_menu()


func _ambience_motif(motif_name: String) -> void:
	if _ambience != null:
		_ambience.set_motif(motif_name)


func on_player_died(p: Player) -> void:

	game_flow.note_death()
	ghost.on_death(p)
	if NetSession.I != null and NetSession.I.is_host() and NetSession.I.in_game():
		NetSession.I.emit_event(NetSession.EV_DIED, players.find(p))
	roster.on_player_died(p)


func on_player_arrived(p: Player) -> void:
	if NetSession.I != null and NetSession.I.is_host() and NetSession.I.in_game():
		NetSession.I.emit_event(NetSession.EV_ARRIVED, players.find(p))
	roster.on_player_arrived(p)


func on_player_departed(p: Player) -> void:
	if NetSession.I != null and NetSession.I.is_host() and NetSession.I.in_game():
		NetSession.I.emit_event(NetSession.EV_DEPARTED, players.find(p))
	roster.on_player_departed(p)


func on_player_exited(p: Player) -> void:
	if NetSession.I != null and NetSession.I.is_host() and NetSession.I.in_game():
		NetSession.I.emit_event(NetSession.EV_EXITED, players.find(p))
	roster.on_player_exited(p)


func _check_all_arrived() -> void:
	roster.check_all_arrived()


func on_respawn_done() -> void:
	roster.on_respawn_done()


var _checkpoints: Dictionary:
	get:
		return roster.checkpoints


func recall_active() -> void:

	if NetSession.I != null and NetSession.I.in_game():
		NetSession.I.request_recall(roster.active_slot)
		return
	# 双人召回(audit ④):dual 下按 InputSource 分键各归各体不可行
	# (recall 是全局共享键),取审计首选方案——作用于双体,各归各自
	# 检查点(分派在 roster.recall_active);单人/联机语义不变。
	roster.recall_active()


func set_checkpoint(key: int, pos: Vector2) -> void:
	roster.set_checkpoint(key, pos)


func hud_swap_flash() -> void:
	if _hud != null:
		_hud.swap_anchor_flash()


func notify_buff(mult: float, gd: GeometryDef) -> void:
	if _hud != null:
		_hud.narration("加速门 · 速度上限提升至 %.1f×" % mult, gd.color, 2.4)



func _check_complete() -> void:
	game_flow.check_complete()


func _parse_auto_shot() -> void:

	for raw in OS.get_cmdline_user_args():
		if raw.begins_with("--zoom="):
			debug_zoom = raw.substr(7).to_float()

	var h := _dev_harness()
	if h != null:
		h.boot(OS.get_cmdline_user_args())


var dual_mode := false
var _dev_h: RefCounted = null
var _dev_h_tried := false


func _dev_harness() -> RefCounted:
	if not _dev_h_tried:
		_dev_h_tried = true
		var s: Variant = load("res://scripts/dev/shot_harness.gd")
		_dev_h = s.new() if s != null else null
		if _dev_h != null:
			_dev_h.m = self
	return _dev_h
