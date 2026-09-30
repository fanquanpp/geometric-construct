class_name Main
extends Node2D


static var I

enum State { MENU, ROOM, PLAYING, PAUSED, TRANSITION, WIN }


const CHARACTER_MANAGER_SCENE := preload("res://scenes/core/character_manager.tscn")
const ROSTER_SCENE := preload("res://scenes/core/roster_controller.tscn")
const GAME_FLOW_SCENE := preload("res://scenes/core/game_flow.tscn")
const RACE_SCENE := preload("res://scenes/core/race_controller.tscn")
const GHOST_SCENE := preload("res://scenes/core/ghost_recorder.tscn")
const BACKDROP_SCENE := preload("res://scenes/world/backdrop.tscn")
const AMBIENCE_SCENE := preload("res://scenes/fx/ambience.tscn")
const TOUCH_SCENE := preload("res://scenes/ui/touch_controls.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const MENU_SCENE := preload("res://scenes/ui/menu_layer.tscn")
const ARCHIVE_SCENE := preload("res://scenes/ui/archive_panel.tscn")
const CONTROLS_SCENE := preload("res://scenes/ui/controls_panel.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const NET_SESSION_SCENE := preload("res://scenes/net/net_session.tscn")
const NET_ROOM_SCENE := preload("res://scenes/ui/net_room_layer.tscn")

var _state: State = State.MENU

var _level_root: Node2D
var _hud: Hud
var _menu: MenuLayer
var _pause: PauseMenu
var archive_panel: ArchivePanel
var controls_panel: ControlsPanel
var settings_panel: SettingsPanel
var touch_controls: TouchControls
var _save: SaveManager
var _ambience: Ambience


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

var roster: RosterController
var game_flow: GameFlow
var race: RaceController
var ghost: GhostRecorder
var backdrop: Backdrop
var players: Array:
	get:
		return roster.players
var camera_rig = null
var _doors: Dictionary:
	get:
		return roster.doors


var net_session: NetSession
var net_room_layer: NetRoomLayer


var _level_info: Dictionary:
	get:
		return game_flow.level_info if game_flow != null else null
	set(value):
		if game_flow != null:
			game_flow.level_info = value


var debug_solo := false

var _held_keys := {}


var _auto_test := false
var dev_run := false


func _ready() -> void:
	# 场景装配顺序即行为:设置先于 UI、触屏先于 HUD,勿重排。
	I = self
	Ui.init_font()
	var cm: CharacterManager = CHARACTER_MANAGER_SCENE.instantiate()
	add_child(cm)

	roster = ROSTER_SCENE.instantiate() as RosterController
	roster.main = self
	add_child(roster)

	game_flow = GAME_FLOW_SCENE.instantiate() as GameFlow
	game_flow.main = self
	add_child(game_flow)
	race = RACE_SCENE.instantiate() as RaceController
	race.main = self
	add_child(race)
	ghost = GHOST_SCENE.instantiate() as GhostRecorder
	ghost.main = self
	add_child(ghost)
	_setup_dual_input()

	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	backdrop = BACKDROP_SCENE.instantiate() as Backdrop
	add_child(backdrop)
	Sfx.init(self)
	var amb: Ambience = AMBIENCE_SCENE.instantiate()
	amb.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(amb)
	_ambience = amb

	SettingsManager.load_settings()
	SettingsManager.apply_all_at_boot()
	backdrop.refresh_gate()

	touch_controls = TOUCH_SCENE.instantiate() as TouchControls
	touch_controls.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(touch_controls)
	_hud = HUD_SCENE.instantiate() as Hud
	add_child(_hud)
	_hud.chip_tapped.connect(switch_to_geo)
	_hud.race_rematch_requested.connect(func() -> void:
		if race != null and race.phase == RaceController.Phase.FINISHED:
			race.rematch())
	race.countdown.connect(_hud.race_countdown)
	race.race_go.connect(_hud.race_go)
	race.race_finished.connect(_on_race_finished)
	_menu = MENU_SCENE.instantiate() as MenuLayer
	_menu.m = self
	add_child(_menu)
	archive_panel = ARCHIVE_SCENE.instantiate() as ArchivePanel
	add_child(archive_panel)
	controls_panel = CONTROLS_SCENE.instantiate() as ControlsPanel
	add_child(controls_panel)
	settings_panel = SETTINGS_SCENE.instantiate() as SettingsPanel
	add_child(settings_panel)
	_pause = PAUSE_SCENE.instantiate() as PauseMenu
	_pause.m = self
	add_child(_pause)

	net_session = NET_SESSION_SCENE.instantiate() as NetSession
	add_child(net_session)
	net_room_layer = NET_ROOM_SCENE.instantiate() as NetRoomLayer
	net_room_layer.m = self
	add_child(net_room_layer)

	_save = SaveManager.new()
	_save.load_save()
	_save.clamp_unlocked(LevelData.campaign_last())
	_unlocked = _save.unlocked
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


func start_level_dual(index := 0) -> void:
	if NetSession.I != null and NetSession.I.is_net():
		return
	start_level(index)
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
		if Input.is_action_just_pressed("ui_cancel"):
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
	_state = State.PAUSED
	get_tree().paused = true
	_pause.open()


func start_game() -> void:
	if _state != State.MENU:
		return
	start_level(_unlocked)


func start_chapter(index: int) -> void:
	if _state != State.MENU:
		return
	start_level(index)


func open_archive() -> void:
	archive_panel.open(_unlocked)


func open_controls() -> void:
	controls_panel.open()


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
	roster.recall_active()


func set_checkpoint(body_key: int, pos: Vector2) -> void:
	roster.set_checkpoint(body_key, pos)


func hud_swap_flash() -> void:
	if _hud != null:
		_hud.swap_anchor_flash()


func notify_buff(mult: float, gd: GeometryDef) -> void:
	if _hud != null:
		_hud.narration("加速门 · 速度上限提升至 %.1f×" % mult, gd.color, 2.4)


func notify_ramp(gd: GeometryDef) -> void:
	if _hud != null:
		_hud.narration("曲面 · 速度 ×1.5,重量减半(离开后 1.5 秒)", gd.color, 1.8)


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
