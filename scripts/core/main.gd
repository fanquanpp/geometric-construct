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
var _ambience: Ambience
var _current := -1
var _unlocked := 0
var _active_slot := 0
var _auto_shot := false
var debug_move := Vector2.ZERO
var debug_jump := false
## 镜头变焦覆盖(>0 时镜头锁定该 zoom):网格 LOD / 远景档截图验证用。
var debug_zoom := 0.0
var frame_no := 0

var players: Array = []
var camera_rig = null            # LevelBuilder.CameraRig,切换时触发过渡动画
var _doors := {}                 # geo_index -> ExitDoor
var _complete_seq := 0           # 通关链序列号:重开/换关时作废待执行的自动流转
var _death_hinted := false       # 序章首摔安抚旁白已播(每次启动一次)

# ———— 肉鸽模式(RogueDirector 驱动,modes/rogue) ————
var rogue_layer: RogueLayer
var rogue_dir: RogueDirector
var _rogue := false              # 当前片段是肉鸽局内关卡(不走标准解锁/流转)
var _level_def: LevelDef         # 当前装载的关卡数据(标准关 = LEVELS[_current])
var _pending_rogue_pick := false # 剧情播完后弹出"选本局主角"
var _pending_rogue_focus := -1   # 已选主角:个人单章剧播完后开跑

# ———— 自动化测试 ————
## 测试模式:屏蔽真实键盘的切换/重开/暂停输入,避免外部按键干扰自动验证。
var debug_solo := false

var _held_keys := {}

# ———— 自动截图(开发调试) ————
var _shot_level := 0
var _shot_dir := ""
var _door_shot := false
var _recall_shot := false       # --recalltest:召回链路自测(动作注册/按下/传送)
var _panel_shot := false
var _set_shot := false
var _act_shot := false
var _act_shot_idx := 0
var _boot_shot := false
var _intro_shot := false
var _story_shot := false
var _story_kind := "prologue"   # --storyshot=NAME:指定要截图/验证的剧本
var _rogue_shot := false
var _rogue_auto := false
var _rogue_focus := 0           # --rogueautotest=N:指定主角跑通局
var _json_level_path := ""      # --leveljson=<res://...>:JSON 关卡覆盖(editor 契约前置)
var _trial_shot := false        # --trialshot:JSON 关卡出生点连拍(双体/磁界验证)
var _tour_shot := false
var _lane_shot := false
var _perf_log := false
var _auto_test := false


func _ready() -> void:
	I = self
	Ui.init_font()
	# 移动端传感器横屏(重力感应双横屏;桌面无效果)
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	add_child(Backdrop.new())
	Sfx.init(self)
	var amb := Ambience.new()
	amb.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(amb)
	_ambience = amb

	# 设置先于全部 UI 加载并应用(轮盘模式 / 音量在面板创建前就位;
	# 画面分辨率仅在命令行未给 --resolution 时应用,截图钩子优先)
	SettingsManager.load_settings()
	SettingsManager.apply_all_at_boot()

	# TouchControls 先于 HUD 创建:HUD 就能感知触屏模式(提示条 / 坐标位置)
	touch_controls = TouchControls.new()
	touch_controls.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(touch_controls)
	_hud = Hud.new()
	add_child(_hud)
	_hud.chip_tapped.connect(switch_to_geo)
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

	# 肉鸽模式:UI 层 + 流程控制器(modes/rogue)
	rogue_layer = RogueLayer.new()
	add_child(rogue_layer)
	rogue_dir = RogueDirector.new()
	rogue_dir.main = self
	rogue_dir.layer = rogue_layer
	add_child(rogue_dir)

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
	_rogue = false
	_current = clampi(index, 0, LevelData.LEVELS.size() - 1)
	_level_def = LevelData.LEVELS[_current]
	# JSON 关卡覆盖(--leveljson,editor 数据契约走查):不进 ACTS / 进度体系
	if not _json_level_path.is_empty():
		var f := FileAccess.open(_json_level_path, FileAccess.READ)
		if f != null:
			_level_def = LevelData.from_json_text(f.get_as_text())
		else:
			push_warning("start_level: --leveljson 打开失败 %s" % _json_level_path)
	_clear_level()
	_doors.clear()
	_level_root = LevelBuilder.build(_level_def)
	add_child(_level_root)
	_collect_players()
	_state = State.PLAYING
	Sfx.play("start")
	# 幕归属由 LevelData.ACTS 推导(v0.15 序章扩容后不再按下标硬编码)
	var act_i := LevelData.act_index_of(_current)
	_ambience_motif("prologue" if act_i <= 0 else "act1")

	_menu.visible = false
	_menu.close_act_panel()
	geometry_panel.close()
	settings_panel.close()
	_hud.visible = true
	touch_controls.set_in_game(true)
	# 单人阵容没有"切换"可言:隐藏左侧切换钮,避免无效按键
	touch_controls.set_switch_available(_level_def.roster.size() > 1)
	_hud.show_win(false)
	_hud.set_level_info(_level_def)
	_refresh_roster()
	_hud.fade_from_black()
	if intro:
		var act_name := "序章" if act_i <= 0 else str(LevelData.ACTS[act_i]["name"])
		_hud.show_intro("%s · 第 %d 场 · %s" % [act_name, LevelData.scene_no_of(_current),
			Geometries.get_def(_level_def.focus).full_name], _level_def)
		var focus: GeometryDef = Geometries.get_def(_level_def.focus)
		_hud.narration(focus.quote, focus.color, 3.8)
	_switch_to(0, true)
	# 第一幕首次开演:先看开演剧,再上手(序幕钩子的下一拍)
	if _current == LevelData.first_level_of_act(1) and intro and not _save.seen_act1:
		_save.note_story("act1")
		get_tree().paused = true
		show_story("act1")


## 肉鸽局内装载片段(RogueDirector 调用):不走标准解锁与通关流转。
func start_rogue_fragment(def: LevelDef, elite_title := "") -> void:
	_complete_seq += 1
	get_tree().paused = false
	if _pause != null:
		_pause.close()
	_rogue = true
	_level_def = def
	_clear_level()
	_doors.clear()
	_level_root = LevelBuilder.build(def)
	add_child(_level_root)
	_collect_players()
	_state = State.PLAYING
	Sfx.play("start")
	_ambience_motif("rogue_%s" % Geometries.get_def(rogue_dir.run.focus).slug)

	_menu.visible = false
	_menu.close_act_panel()
	geometry_panel.close()
	settings_panel.close()
	_hud.visible = true
	touch_controls.set_in_game(true)
	touch_controls.set_switch_available(true)
	_hud.show_win(false)
	_hud.set_level_info(def, "考" if not elite_title.is_empty() else "重跑")
	_refresh_roster()
	_hud.fade_from_black()
	var kicker := "重跑 · 精英考 · %s" % elite_title \
		if not elite_title.is_empty() else "重跑 · %s章 · 第 %d 段" % [
			["一", "二", "三"][clampi(rogue_dir.run.chapter - 1, 0, 2)],
			rogue_dir.run.fragments_done + 1]
	_hud.show_intro(kicker, def)
	_switch_to(0, true)


func _collect_players() -> void:
	players.clear()
	_doors.clear()
	for n in _level_root.get_children():
		if n is Player:
			players.append(n as Player)
		elif n is ExitDoor:
			_doors[(n as ExitDoor).geo_index] = n
	# 双子(伍)两具同 index:按 pair_half 稳定排序,界恒先于边
	players.sort_custom(func(a: Player, b: Player) -> bool:
		if a.index != b.index:
			return a.index < b.index
		return a.pair_half < b.pair_half)
	_active_slot = 0


# ———————————————— 几何体切换 ————————————————

## 切换操控:已到达终点门待命的几何体仍然可以被选中(终点激活前不收取);
## 只跳过正在进门 / 死亡中的几何体。
## 伍(界/边)是双子:两具身体在切换循环中各占一位、独立操控
## (characters.md §5);磁力边界始终张在两顶之间,不随操控改变。
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
				_hud.narration(p.quote_text(), p.def.color)
				if camera_rig != null:
					camera_rig.on_switch()
			return


## 数字键 / 点按 chips 切换(v0.17.2):按几何体下标直达;
## 双子(伍)同下标两具 —— 已选中其一时再点即换另一位。
var _switch_ms := 0


func switch_to_geo(index: int) -> void:
	if _state != State.PLAYING or players.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _switch_ms < 150:
		return   # 触摸 + 模拟鼠标双发防抖
	_switch_ms = now
	var candidates: Array = []
	for i in players.size():
		var p: Player = players[i]
		if p.index == index and not p.in_exit and not p.dying:
			candidates.append(i)
	if candidates.is_empty():
		return
	var target: int = candidates[0]
	if candidates.size() > 1 and candidates.has(_active_slot):
		target = candidates[1] if _active_slot == candidates[0] else candidates[0]
	_switch_to(target)


func _cycle_slot(dir: int) -> void:
	if players.is_empty():
		return
	_switch_to(((_active_slot + dir) % players.size() + players.size()) % players.size())


func _refresh_roster() -> void:
	var mask := 0
	for p in players:
		if p.in_exit or p.arrived:
			# 双体(伍):同一 index 的两半全部到站才点亮名册勾选
			var all_in := true
			for q in players:
				if q.index == p.index and not (q.in_exit or q.arrived):
					all_in = false
					break
			if all_in:
				mask |= 1 << p.index
	var active: int = players[_active_slot].index \
		if (_active_slot >= 0 and _active_slot < players.size()) else -1
	_hud.refresh_roster(_level_def.roster, active, mask)


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

		for i in mini(players.size(), 5):
			if _key_pressed(KEY_1 + i) and i < _level_def.roster.size():
				_switch_to(i)

		if Input.is_action_just_pressed("recall"):
			recall_active()
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
		if Input.is_action_just_pressed("recall"):
			start_level(0)
		if Input.is_action_just_pressed("pause"):
			_show_menu()


func _check_deaths() -> void:
	var def: LevelDef = _level_def
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
	# 肉鸽局内重来:重开当前片段(不计死亡,不烧刻度)
	if _rogue:
		_hud.fade_to_black(0.25, func() -> void: start_rogue_fragment(_level_def))
	else:
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
	if _rogue:
		_rogue = false
		rogue_dir.exit_run()
	_show_menu()


# ———————————————— 剧情文字(konado) ————————————————

## 播放剧情:暂停世界,叠放 Konado 对话层;结束后恢复。
## kind:"act1" 开演剧(首进第一幕)/ "epilogue" 尾声(通关画面)/
## "rogue_*" 肉鸽序说与单章。回看走档案几何回廊页的全文本阅读器,不经此处。
func show_story(kind: String) -> void:
	var story := StoryLayer.new()
	story.m = self
	add_child(story)
	story.play("res://story/%s.ks" % kind)


func on_story_finished() -> void:
	get_tree().paused = false
	# 个人单章剧播完 → 正式开跑
	if _pending_rogue_focus >= 0:
		_begin_rogue_run()
		return
	# 重跑序说播完 → 弹出"选本局主角"
	if _pending_rogue_pick:
		_pending_rogue_pick = false
		_open_rogue_pick()


## 菜单入口:进入重跑(肉鸽)模式 —— 首局先看"重跑序说",再选本局主角;
## 每位主角首次重跑时播放他的个人单章刻画(story/rogue_<slug>.ks)。
func start_rogue_run() -> void:
	if _state != State.MENU:
		return
	Sfx.play("ui_open")
	get_tree().paused = true
	if not _save.seen_rogue:
		_save.note_story("rogue_intro")
		show_story("rogue_intro")
	else:
		_open_rogue_pick()


func _open_rogue_pick() -> void:
	var shards := _save.rogue_shards
	var runs := _save.rogue_runs
	rogue_layer.show_geo_pick(_on_rogue_picked, shards, runs)


## 选定本局主角:先看他的个人单章(仅首次),再正式开跑。
func _on_rogue_picked(idx: int) -> void:
	_state = State.PLAYING
	_menu.visible = false
	_hud.visible = true
	_pending_rogue_focus = idx
	var kind := "rogue_%s" % Geometries.get_def(idx).slug
	if not _save.story_seen(kind):
		_save.note_story(kind)
		get_tree().paused = true
		show_story(kind)
	else:
		_begin_rogue_run()


func _begin_rogue_run() -> void:
	rogue_dir.begin(_pending_rogue_focus)
	_pending_rogue_focus = -1


## 肉鸽落幕结算完成,回到标题菜单。
func finish_rogue_run() -> void:
	get_tree().paused = false
	_rogue = false
	rogue_dir.exit_run()
	_show_menu()


# ———————————————— BGM motif ————————————————

## BGM motif 随章节 / 肉鸽主角切换(audio.md §3:motif 即章节与角色的音乐画像)。
func _ambience_motif(motif_name: String) -> void:
	if _ambience != null:
		_ambience.set_motif(motif_name)


# ———————————————— 事件回调 ————————————————

func on_player_died(p: Player) -> void:
	if _auto_test:
		print("TEST: ", p.def.name, " died/respawned")
	if _state == State.PLAYING:
		# v0.17.3:死亡不再自动切换几何体(操控权保持,由玩家手动切换)
		# 序章首摔安抚(每次启动至多一次):把序幕"重拼"规则说成玩法语言,
		# 新手第一次摔碎时不至于以为出了错
		if not _death_hinted and not _rogue and LevelData.act_index_of(_current) <= 0:
			_death_hinted = true
			_hud.narration("摔碎不是终结 · 空白处会把你在起点重新拼好", Ui.RED, 3.4)
	_refresh_roster()
	# 肉鸽:重拼消耗一段红色刻度,耗尽则本局落幕
	if _rogue:
		rogue_dir.on_player_died()


## 到达专属终点门:原地待命(仍可被切换控制),全员到齐后终点激活。
func on_player_arrived(p: Player) -> void:
	if _auto_test:
		print("TEST: ", p.def.name, " arrived at exit")
	if _state != State.PLAYING:
		return
	# v0.17.3:到站不再自动切换几何体(玩家手动点 chips / 数字键切换)
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


## 重生完成:v0.17.3 起不再自动切换——死亡几何体保持操控权,原地复活续玩。
func on_respawn_done() -> void:
	if _state != State.PLAYING:
		return


var _checkpoints := {}   # geo index -> Vector2 最近记录点(关卡内记录点实体未来接入)


## 召回(v0.17.3):右上按钮 / R 键 —— 当前受控几何体传送回最近记录点;
## 尚无关卡内记录点系统,默认回到其出生点。到站 / 进门 / 死亡中不可召回。
func recall_active() -> void:
	if _state != State.PLAYING or players.is_empty():
		return
	if _active_slot < 0 or _active_slot >= players.size():
		return
	var p: Player = players[_active_slot]
	if p == null or p.in_exit or p.dying or p.arrived:
		return
	p.recall_to(_checkpoints.get(p.index, p.spawn_pos))
	Sfx.play("switch")


## 记录点登记(关卡内记录点实体未来接入):index = 几何体下标。
func set_checkpoint(index: int, pos: Vector2) -> void:
	_checkpoints[index] = pos


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

	# 肉鸽局:通关流转交给 RogueDirector(选路 / 奖励 / 精英考 / 结算)
	if _rogue:
		_state = State.TRANSITION
		_complete_seq += 1
		var seq := _complete_seq
		var elite := rogue_dir.in_elite
		get_tree().create_timer(0.9).timeout.connect(func() -> void:
			if seq == _complete_seq and rogue_dir != null:
				if elite:
					rogue_dir.on_elite_complete()
				else:
					rogue_dir.on_fragment_complete())
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
		elif raw == "--recalltest":
			_recall_shot = true
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
		elif raw.begins_with("--storyshot"):
			_story_shot = true
			if raw.contains("="):
				_story_kind = raw.substr(12)
		elif raw == "--rogueshot":
			_rogue_shot = true
		elif raw.begins_with("--rogueautotest"):
			_rogue_auto = true
			if raw.contains("="):
				_rogue_focus = raw.substr(15).to_int()
		elif raw == "--tourshot":
			_tour_shot = true
		elif raw == "--laneshot":
			_lane_shot = true
		elif raw == "--perflog":
			_perf_log = true
		elif raw.begins_with("--zoom="):
			debug_zoom = raw.substr(7).to_float()
		elif raw.begins_with("--level="):
			_shot_level = raw.substr(8).to_int()
		elif raw == "--trialshot":
			_trial_shot = true
		elif raw.begins_with("--leveljson="):
			_json_level_path = raw.substr(12)
	if _auto_shot and _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	if _auto_shot and args.has("--menushot"):
		_run_menu_shot()
	# --introshot / --storyshot 自带开局流程,跳过通用 autoshot 以免抢关卡
	if _auto_shot and not args.has("--menushot") \
			and not _intro_shot and not _story_shot:
		_run_auto_shot()
	if _door_shot:
		_run_door_shot()
	if _recall_shot:
		_run_recall_test()
	if _trial_shot:
		_run_trial_shot()
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
	if _rogue_shot:
		_run_rogue_shot()
	if _rogue_auto:
		_run_rogue_auto_test()
	if _tour_shot:
		_run_tour_shot()
	if _lane_shot:
		_run_lane_shot()
	if _perf_log:
		_run_perf_log()
	elif OS.is_debug_build() and OS.has_feature("mobile"):
		# Android debug 包自动开基线日志(真机无法传 user args,
		# adb logcat 直接抓 PERF 行);桌面 debug 不受影响。
		_run_perf_log()
	if _auto_test:
		_run_auto_test()


## 截取设置面板。
func _run_set_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	await get_tree().create_timer(0.6).timeout
	settings_panel.open()
	await get_tree().create_timer(0.5).timeout
	await _shot("settings")
	get_tree().quit()


## 截取剧目二级菜单(关卡列)。
func _run_actshot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	await get_tree().create_timer(0.6).timeout
	_menu.try_open_act(_act_shot_idx)
	await get_tree().create_timer(0.6).timeout
	await _shot("act_panel")
	get_tree().quit()


## 截取开屏动画(标题落定瞬间)。
func _run_boot_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	await get_tree().create_timer(1.35).timeout
	await _shot("boot")
	await get_tree().create_timer(1.8).timeout
	await _shot("boot_end")
	get_tree().quit()


## 截取章节开场卡。
func _run_intro_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	start_level(_shot_level, true)
	await get_tree().create_timer(1.2).timeout
	await _shot("intro")
	get_tree().quit()


## 截取肉鸽模式 UI(选体 / 选路 / 词条三选一 / 结算,逐屏截图验收)。
func _run_rogue_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	_state = State.PLAYING
	await get_tree().create_timer(0.6).timeout
	var done := func(_a = null) -> void: pass
	rogue_layer.show_geo_pick(done, 34, 2)
	await get_tree().create_timer(0.5).timeout
	await _shot("rogue_pick")
	rogue_layer._close_overlay()
	var mock_routes := [
		{"title": "演示甲", "note": "快 · 三级梯田直上,缺口只有两格"},
		{"title": "演示乙", "note": "稳 · 全程地面安全网,谷底滚不碎"},
	]
	rogue_layer.show_route(1, mock_routes, done)
	await get_tree().create_timer(0.5).timeout
	await _shot("rogue_route")
	rogue_layer._close_overlay()
	rogue_layer.show_reward([
		RunModifiers.ALL[0], RunModifiers.ALL[4], RunModifiers.ALL[5]], done)
	await get_tree().create_timer(0.5).timeout
	await _shot("rogue_reward")
	rogue_layer._close_overlay()
	rogue_layer.show_settle({
		"cleared": false, "chapter": 2, "arrivals": 12, "elites": 1, "deaths": 3,
		"shards": 17, "balance": 34, "mods": [RunModifiers.ALL[1], RunModifiers.ALL[4]],
	}, done)
	await get_tree().create_timer(0.5).timeout
	await _shot("rogue_settle")
	rogue_layer._close_overlay()
	# 局内状态条:mock 一局(2 段进度 / 3 格刻度 / 2 词条)后装载真片段
	rogue_dir.run = RunState.new(0)
	rogue_dir.run.chapter = 2
	rogue_dir.run.fragments_done = 1
	rogue_dir.run.ticks = 3
	rogue_dir.run.add_mod(RunModifiers.ALL[1])
	rogue_dir.run.add_mod(RunModifiers.ALL[4])
	get_tree().paused = false
	start_rogue_fragment(RogueFragments.chapter_routes(0, 1)[0]["def"])
	rogue_layer.refresh_status(rogue_dir.run)
	await get_tree().create_timer(0.6).timeout
	await _shot("rogue_status")
	rogue_dir.run = null
	get_tree().quit()


## 肉鸽全流程自动测试:auto 模式下自动选路 / 选奖励 / 强制完成片段,
## 跑完一整局(三章 + 三精英考 + 结算)直到回菜单。
func _run_rogue_auto_test() -> void:
	print("TEST: rogue auto run begin")
	_menu.visible = false
	_hud.visible = true
	_state = State.PLAYING
	rogue_dir.auto = true
	print("TEST: rogue focus=", Geometries.get_def(_rogue_focus).name)
	rogue_dir.begin(_rogue_focus)
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline \
			and rogue_dir.phase != RogueDirector.Phase.IDLE:
		await get_tree().create_timer(0.5).timeout
	print("TEST: rogue run end phase=", rogue_dir.phase,
		" mods=", rogue_dir.run.mod_ids() if rogue_dir.run != null else [],
		" shards=", _save.rogue_shards, " runs=", _save.rogue_runs)
	get_tree().quit()


## 截取剧情对话框(序幕)。
## 刻意先开局把相机带到关卡深处再开对话:验证变暗遮罩不再跟随相机
## (follow_viewport 关闭后,遮罩恒定铺满屏幕,左右两侧都不会漏光)。
func _run_story_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	await get_tree().create_timer(0.6).timeout
	start_level(0, false)
	await get_tree().create_timer(0.3).timeout
	if not players.is_empty():
		players[0].position = Vector2(2000, 850)
		players[0].velocity = Vector2.ZERO
	await get_tree().create_timer(0.4).timeout
	get_tree().paused = true
	show_story(_story_kind)
	await get_tree().create_timer(1.6).timeout
	await _shot("story_" + _story_kind)
	get_tree().quit()


## 巡航截图:沿大型关卡的关键节拍传送受控几何体,逐点截图验收。
## 节拍表按当前关卡下标内建;新巨构关卡在此追加自己的节拍行。
func _run_tour_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	_unlocked = LevelData.LEVELS.size() - 1
	start_level(_shot_level, false)
	await get_tree().create_timer(0.4).timeout
	var tours := {
		0: [["spawn", Vector2(430, 1745)],
			["wall_top", Vector2(1040, 1560)],
			["back_zone", Vector2(2500, 1745)],
			["front_zone", Vector2(3160, 1745)],
			["who_wall", Vector2(3550, 1745)],
			["swap_corridor", Vector2(4950, 1745)],
			["ceiling_cover", Vector2(5000, 1245)],
			["ceiling_deck", Vector2(5100, 1245)],
			["faces_top", Vector2(4850, 1395)],
			["piano_row", Vector2(6950, 1745)],
			["ferry", Vector2(8050, 1690)],
			["lift", Vector2(9950, 1100)],
			["deck_gate", Vector2(10600, 890)],
			["ramp_fly", Vector2(11700, 700)],
			["bridge", Vector2(11550, 1700)],
			["lever", Vector2(11600, 1760)],
			["climb_tower", Vector2(12050, 1500)],
			["boost_tower", Vector2(13060, 1290)],
			["twins_hall", Vector2(13500, 1745)],
			["doors", Vector2(14600, 1754)]],
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


## 性能基线日志(ROADMAP §5 Android 性能 P0):每秒向 stdout 打一行
## Performance 监视数据,`adb logcat` 抓取;与 --autotest / 手工试玩同用。
func _run_perf_log() -> void:
	while is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		print("PERF fps=%d process=%.2fms draw=%d prim=%d obj=%d mem=%.1fMB" % [
			int(Performance.get_monitor(Performance.TIME_FPS)),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		])


## 图层实验室截图(ROADMAP §1 M0 验收):装载 LevelData.layer_lab(),
## 分镜截取 back 层亮度 / who 不适用远景沉降与 far:0 原位淡化对照 /
## front 遮挡淡出 / 逐几何体层级归属(疾跃同机位对照)/ 逆的 bottom 天花板 /
## 开关门与限时桥两态;配合 --zoom=N 可验网格 LOD 远景档。
func _run_lane_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	_shot_level = 99
	_level_def = LevelData.LEVELS[0]   # 分层演示已并入机制试炼场(v0.17)
	_rogue = false
	_current = -1
	_clear_level()
	_level_root = LevelBuilder.build(_level_def)
	add_child(_level_root)
	_collect_players()
	_state = State.PLAYING
	_menu.visible = false
	_hud.visible = true
	touch_controls.set_in_game(true)
	touch_controls.set_switch_available(true)
	_hud.show_win(false)
	_hud.set_level_info(_level_def)
	_refresh_roster()
	_hud.fade_from_black()
	_switch_to(0, true)
	await get_tree().create_timer(0.8).timeout

	# ① back 梁区(疾视角):疾站在背景梁上 —— 梁压亮度仍可站,
	#    下方可见 top 单向板(顶缘亮线加亮)
	players[0].position = Vector2(1500, 760)
	players[0].velocity = Vector2.ZERO
	await get_tree().create_timer(0.8).timeout
	await _shot("lane_back_dash")
	# ② 圆视角同区:疾专属墙对圆降透明(视觉即机制)+ top 单向板
	if players.size() > 3:
		_switch_to(3, true)
		players[3].position = Vector2(1480, 1740)
		players[3].velocity = Vector2.ZERO
		await get_tree().create_timer(0.8).timeout
		await _shot("lane_back_roll")
	# ② 动态构件区:限时桥 + faces=none 装饰(桥实心/虚化两态各一张)
	_switch_to(0, true)
	players[0].position = Vector2(2950, 1700)
	players[0].velocity = Vector2.ZERO
	await get_tree().create_timer(0.55).timeout
	await _shot("lane_bridge_a")
	await get_tree().create_timer(2.0).timeout
	await _shot("lane_bridge_b")
	# ③ 前景遮挡区(疾躲入 front 组件后 → 组件淡出)
	players[0].position = Vector2(4900, 1750)
	players[0].velocity = Vector2.ZERO
	await get_tree().create_timer(0.6).timeout
	await _shot("lane_front")
	# ④ 远景沉降(疾视角):两块圆专属浮板对疾沉入远景 ——
	#    近板自动档 far1,远板 far:2 固定最深档;旁边钢琴砖(全员适用)保持主层作对照
	_switch_to(0, true)
	players[0].position = Vector2(3150, 1745)
	players[0].velocity = Vector2.ZERO
	await get_tree().create_timer(0.9).timeout
	await _shot("lane_sink_far")
	# ④b 切换回升(圆视角):两板回升主层 mid —— 原远景抬起,疾专属墙(far:0)仍原位淡化
	if players.size() > 3:
		_switch_to(3, true)
		players[3].position = Vector2(3150, 1745)
		players[3].velocity = Vector2.ZERO
		await get_tree().create_timer(0.9).timeout
		await _shot("lane_sink_rise")
	# ④c 逐几何体层级(跃/疾同机位对照):疾跃共享板 —— 跃见 back 层(压亮度),疾见 mid 主层
	if players.size() > 1:
		_switch_to(1, true)
		players[1].position = Vector2(1200, 1010)
		players[1].velocity = Vector2.ZERO
		await get_tree().create_timer(0.9).timeout
		await _shot("lane_override_spring")
	_switch_to(0, true)
	players[0].position = Vector2(1200, 1010)
	players[0].velocity = Vector2.ZERO
	await get_tree().create_timer(0.9).timeout
	await _shot("lane_override_dash")
	# ⑤ 逆 + bottom 天花板:翻转重力贴上梁底(faces=bottom 单向面),
	#    同框可见 back 梁压亮度;随后传送到开关门区
	_switch_to(2, true)
	players[2].gravity_dir = -1
	players[2].up_direction = Vector2(0, 1)
	players[2].position = Vector2(2950, 660)
	players[2].velocity = Vector2.ZERO
	await get_tree().create_timer(1.2).timeout
	if camera_rig != null:
		print("LANE SHOT cam=", camera_rig.position, " zoom=", camera_rig.zoom)
	await _shot("lane_bottom_fall")
	players[2].gravity_dir = 1
	players[2].up_direction = Vector2(0, -1)
	players[2].position = Vector2(5400, 1740)
	players[2].velocity = Vector2.ZERO
	await get_tree().create_timer(0.8).timeout
	await _shot("lane_gate")
	get_tree().quit()


## 截取几何档案页(全部页)。
func _run_panel_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	await get_tree().create_timer(0.6).timeout
	geometry_panel.open(0)
	await get_tree().create_timer(0.5).timeout
	await _shot("panel_char0")
	for page in range(1, Geometries.ALL.size()):
		geometry_panel._switch(1)
		await get_tree().create_timer(0.4).timeout
		await _shot("panel_char%d" % page)
	# 回廊页签(档案几何整合页)+ 全文本阅读器(序幕)
	geometry_panel.open(0, "gallery")
	await get_tree().create_timer(0.5).timeout
	await _shot("panel_gallery")
	geometry_panel._open_story(GeometryPanel.STORIES[0])
	await get_tree().create_timer(0.5).timeout
	await _shot("panel_story")
	get_tree().quit()


## 传送到出口门前,验证门的渲染与过关文字。
## 召回链路自测(headless):动作注册 → 按下 → 召回至出生点。
func _run_recall_test() -> void:
	if _shot_dir.is_empty():
		_shot_dir = ".shots_v17"
	start_level(0, false)
	await get_tree().create_timer(0.5).timeout
	var p: Player = players[_active_slot]
	p.position = p.spawn_pos + Vector2(600, -300)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# 走真实输入管线(R 键):action_press 从 idle 协程调用会错过 just_pressed 物理帧比对
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ok: bool = p.position.distance_to(p.spawn_pos) < 2.0 and not p.dying
	print("RECALLTEST ", "PASS" if ok else "FAIL",
		" pos=", p.position, " spawn=", p.spawn_pos)
	get_tree().quit(0 if ok else 1)


func _run_door_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = "res://.shots"
	start_level(0, false)
	await get_tree().create_timer(0.3).timeout
	players[0].position = Vector2(14450, 1700)
	players[0].velocity = Vector2.ZERO
	await get_tree().create_timer(0.25).timeout
	await _shot("door")
	await get_tree().create_timer(1.1).timeout
	await _shot("complete")
	get_tree().quit()


## JSON 试水关出生点连拍:验证双体渲染 / 磁力边界 / 双门(开发用)。
func _run_trial_shot() -> void:
	if _shot_dir.is_empty():
		_shot_dir = ".shots_v16"
	start_level(0, false)
	await get_tree().create_timer(0.4).timeout
	await _shot("trial_spawn")
	await get_tree().create_timer(0.8).timeout
	await _shot("trial_rest")
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
