class_name Main
extends Node2D
## 游戏总控:菜单 ↔ 关卡流转、几何体切换、进度存档、档案几何 / 剧情入口、自动测试钩子。

static var I  # Main 单例

enum State { MENU, ROOM, PLAYING, PAUSED, TRANSITION, WIN }

# —— 子系统场景(场景资源强制约束 R1:常驻节点结构一律 .tscn 组合,
# 这里只按既定装配顺序实例化;顺序本身是行为(设置先于 UI、触屏先于
# HUD),故组合根以脚本按序装配,层内结构在各场景文件内编辑器组装) ——
const CHARACTER_MANAGER_SCENE := preload("res://scenes/core/character_manager.tscn")
const ROSTER_SCENE := preload("res://scenes/core/roster_controller.tscn")
const BACKDROP_SCENE := preload("res://scenes/world/backdrop.tscn")
const AMBIENCE_SCENE := preload("res://scenes/fx/ambience.tscn")
const TOUCH_SCENE := preload("res://scenes/ui/touch_controls.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const MENU_SCENE := preload("res://scenes/ui/menu_layer.tscn")
const ARCHIVE_SCENE := preload("res://scenes/ui/archive_panel.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const ROGUE_LAYER_SCENE := preload("res://scenes/ui/rogue_layer.tscn")
const ROGUE_DIR_SCENE := preload("res://scenes/modes/rogue/rogue_director.tscn")
const NET_SESSION_SCENE := preload("res://scenes/net/net_session.tscn")
const NET_ROOM_SCENE := preload("res://scenes/ui/net_room_layer.tscn")
const BOOT_SCENE := preload("res://scenes/ui/boot_intro.tscn")
const STORY_SCENE := preload("res://scenes/ui/story_layer.tscn")

var _state: State = State.MENU

var _level_root: Node2D
var _hud: Hud
var _menu: MenuLayer
var _pause: PauseMenu
var archive_panel: ArchivePanel
var settings_panel: SettingsPanel
var touch_controls: TouchControls
var _save: SaveManager
var _ambience: Ambience
var _current := -1
var _unlocked := 0
var _auto_shot := false
var debug_move := Vector2.ZERO
var debug_jump := false
## 镜头变焦覆盖(>0 时镜头锁定该 zoom):网格 LOD / 远景档截图验证用。
var debug_zoom := 0.0
var debug_grid := false   # --debug-grid:组件 id·层 标注叠加层(levels.md §8.3)
var frame_no := 0

var roster: RosterController  # 名册域控制器(Sprint 3):切换/召回/到站/记录点真身
var players: Array:
	get:
		return roster.players
var camera_rig = null            # CameraRig,切换时触发过渡动画
var _doors: Dictionary:
	get:
		return roster.doors
var _complete_seq := 0           # 通关链序列号:重开/换关时作废待执行的自动流转

# ———— 肉鸽模式(RogueDirector 驱动,modes/rogue) ————
var rogue_layer: RogueLayer
var rogue_dir: RogueDirector
var _rogue := false              # 当前片段是肉鸽局内关卡(不走标准解锁/流转)
var _level_def: LevelDef         # 当前装载的关卡数据(标准关 = LEVELS[_current])
var _pending_rogue_pick := false # 剧情播完后弹出"选本局主角"
var _pending_rogue_focus := -1   # 已选主角:个人单章剧播完后开跑

# ———— 联机(net.md,N2 同网直连) ————
var net_session: NetSession      # 会话中枢(Main 创建,两端路径一致才能 RPC 寻址)
var net_room_layer: NetRoomLayer # 房间流程页(流程带 30,与 RogueLayer 同带互斥)

# ———— 自动化测试 ————
## 测试模式:屏蔽真实键盘的切换/重开/暂停输入,避免外部按键干扰自动验证。
var debug_solo := false

var _held_keys := {}

# ———— 自动截图(开发调试) ————
var _shot_level := 0
var _shot_dir := ""
var _door_shot := false
var _recall_shot := false       # --recalltest:召回链路自测(动作注册/按下/传送)
var _transition_shot := false   # --transitionshot:三式转场覆盖/揭开分镜
var _dual_test := false         # --dualtest:同屏双人自测(绑定/分区/禁切/死亡/到站)
var _dual_shot := false
var _room_shot := false   # --roomshot:房间流程页分镜(UI 图册)         # --dualshot:同屏双人视觉分镜(chips 双高亮/双取景)
var _net_test := false          # --nettest:LAN 发现 / ENet 传输回环自测(net.md §4.3-2)
var _net_auto := false
var _net_join := false
var _net_join_ip := ""          # --netauto:主机自动化(自动建房 + 满员自动开演,联测用)
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
var _tap_shot := false          # --tapshot:点按粒子反馈分镜(TouchControls 触点反馈)
var _perf_log := false
var _auto_test := false


func _ready() -> void:
	I = self
	Ui.init_font()
	# 角色管理器最先装配(R3 数据驱动画面):关卡建体经它入池发信号
	var cm: CharacterManager = CHARACTER_MANAGER_SCENE.instantiate()
	add_child(cm)
	# 名册域控制器(Sprint 3):切换 / 召回 / 到站 / 记录点真身
	roster = ROSTER_SCENE.instantiate() as RosterController
	roster.main = self
	add_child(roster)
	_setup_dual_input()   # N1 分区动作注册(WASD / 方向键)
	# 移动端传感器横屏(重力感应双横屏;桌面显示服务器不支持,守卫后不再告警)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	add_child(BACKDROP_SCENE.instantiate())
	Sfx.init(self)
	var amb: Ambience = AMBIENCE_SCENE.instantiate()
	amb.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(amb)
	_ambience = amb

	# 设置先于全部 UI 加载并应用(轮盘模式 / 音量在面板创建前就位;
	# 画面分辨率仅在命令行未给 --resolution 时应用,截图钩子优先)
	SettingsManager.load_settings()
	SettingsManager.apply_all_at_boot()

	# TouchControls 先于 HUD 创建:HUD 就能感知触屏模式(提示条 / 坐标位置)
	touch_controls = TOUCH_SCENE.instantiate() as TouchControls
	touch_controls.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(touch_controls)
	_hud = HUD_SCENE.instantiate() as Hud
	add_child(_hud)
	_hud.chip_tapped.connect(switch_to_geo)
	_menu = MENU_SCENE.instantiate() as MenuLayer
	_menu.m = self
	add_child(_menu)
	archive_panel = ARCHIVE_SCENE.instantiate() as ArchivePanel
	add_child(archive_panel)
	settings_panel = SETTINGS_SCENE.instantiate() as SettingsPanel
	add_child(settings_panel)
	_pause = PAUSE_SCENE.instantiate() as PauseMenu
	_pause.m = self
	add_child(_pause)

	# 肉鸽模式:UI 层 + 流程控制器(modes/rogue)
	rogue_layer = ROGUE_LAYER_SCENE.instantiate() as RogueLayer
	add_child(rogue_layer)
	rogue_dir = ROGUE_DIR_SCENE.instantiate() as RogueDirector
	rogue_dir.main = self
	rogue_dir.layer = rogue_layer
	add_child(rogue_dir)

	# 联机:会话中枢 + 房间流程页(net.md;path 一致,RPC 才能寻址)
	net_session = NET_SESSION_SCENE.instantiate() as NetSession
	add_child(net_session)
	net_room_layer = NET_ROOM_SCENE.instantiate() as NetRoomLayer
	net_room_layer.m = self
	add_child(net_room_layer)

	_save = SaveManager.new()
	_save.load_save()
	_save.clamp_unlocked(LevelData.LEVELS.size() - 1)
	_unlocked = _save.unlocked
	_menu.set_unlocked(_unlocked)
	_menu.visible = true
	_hud.visible = false

	# 开屏动画:游戏名揭示(点按可跳过),盖在标题菜单入场之上
	add_child(BOOT_SCENE.instantiate())

	_parse_auto_shot()


func _exit_tree() -> void:
	if I == self:
		I = null


# ———————————————— 场景与流程 ————————————————

func _show_menu() -> void:
	_state = State.MENU
	dual_mode = false   # 退出即散伙:回菜单后普通开局不受残留双活态影响
	_clear_level()
	_hud.visible = false
	touch_controls.set_in_game(false)
	archive_panel.close()
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
	dual_mode = false   # 普通开局恒单人(双人走 start_level_dual 开局后再翻)
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
	_checkpoints.clear()   # 换关作废记录点:陈旧坐标会把召回/重生送进异世界
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
	archive_panel.close()
	settings_panel.close()
	_hud.visible = true
	touch_controls.set_in_game(true)
	# 体数 > 1 才有"切换"可言(双子一位两具):按 roster 长度判断会把
	# 纯双子阵容误判成"单人无切换"(v0.21.0 修正)
	touch_controls.set_switch_available(
		Geometries.roster_body_total(_level_def.roster) > 1)
	_hud.show_win(false)
	_hud.set_level_info(_level_def)
	_refresh_roster()
	_hud.reveal_corners()
	if intro:
		var act_name := "序章" if act_i <= 0 else str(LevelData.ACTS[act_i]["name"])
		_hud.show_intro("%s · 第 %d 场 · %s" % [act_name, LevelData.scene_no_of(_current),
			Geometries.get_def(_level_def.focus).full_name], _level_def)
		var focus: GeometryDef = Geometries.get_def(_level_def.focus)
		_hud.narration(focus.quote, focus.color, 3.8)
	_switch_to(0, true)
	# 联机(N2):两端装配完成后算定绑定 / 标注 remote_driven / 注入输入源
	# (net.md §6 生成免 Spawner 的收尾;on_level_built 两端各自调用);
	# 客机经 rpc_start_level 直达此处,房间页须在这里收起(主机路径自关)
	if NetSession.I != null and NetSession.I.is_net():
		net_room_layer.visible = false
		NetSession.I.on_level_built()
	# 第一幕首次开演:先看开演剧,再上手(序幕钩子的下一拍)
	if _current == LevelData.first_level_of_act(1) and intro and not _save.seen_act1:
		_save.note_story("act1")
		get_tree().paused = true
		show_story("act1")


## 肉鸽局内装载片段(RogueDirector 调用):不走标准解锁与通关流转。
func start_rogue_fragment(def: LevelDef, elite_title := "") -> void:
	_complete_seq += 1
	dual_mode = false   # 肉鸽片段恒单人
	get_tree().paused = false
	if _pause != null:
		_pause.close()
	_rogue = true
	_level_def = def
	_clear_level()
	_doors.clear()
	_checkpoints.clear()   # 肉鸽片段换载:记录点同样作废
	_level_root = LevelBuilder.build(def)
	add_child(_level_root)
	_collect_players()
	_state = State.PLAYING
	Sfx.play("start")
	_ambience_motif("rogue_%s" % Geometries.get_def(rogue_dir.run.focus).slug)

	_menu.visible = false
	_menu.close_act_panel()
	archive_panel.close()
	settings_panel.close()
	_hud.visible = true
	touch_controls.set_in_game(true)
	_hud.show_win(false)
	_hud.set_level_info(def, "考" if not elite_title.is_empty() else "重跑")
	touch_controls.set_switch_available(Geometries.roster_body_total(def.roster) > 1)
	_refresh_roster()
	_hud.fade_from_black()
	var kicker := "重跑 · 精英考 · %s" % elite_title \
		if not elite_title.is_empty() else "重跑 · %s章 · 第 %d 段" % [
			["一", "二", "三"][clampi(rogue_dir.run.chapter - 1, 0, 2)],
			rogue_dir.run.fragments_done + 1]
	_hud.show_intro(kicker, def)
	_switch_to(0, true)


func _collect_players() -> void:
	roster.collect_players(_level_root)


# ———————————————— 几何体切换 ————————————————

## 当前取景槽位(net.md §3 视口插槽预埋):HUD / 相机 / 分镜统一经此取
## "看谁"。单机 = 受控槽 _active_slot 透传(行为不变);同屏双人(N1)
## 将按视口返回各自绑定槽。
func view_slot() -> int:
	return roster.view_slot()


## 取景目标集(net.md §3 相机插槽预埋):相机 / HUD 超距指示统一经此取。
## 单机 = 受控几何体单元素(与旧 _active_slot 直读逐位同行为,含越界钳制);
## 同屏双人(N1)将返回两具绑定体,相机经 targets.size()>1 自动分流双人缩放。
func camera_targets() -> Array:
	return roster.camera_targets()


## 槽位输入模式网关(net.md §2):true 时输入槽 0 改读 p1_* 分区动作
## (键盘分区让位 P2;触屏设备槽 0 例外恒读全局动作,见 InputSource)。
## 同屏双人开局后为 true;联机(N2)接入时在此追加 NetSession 在局条件。
func slot_actions() -> bool:
	return dual_mode


## N1 同屏双人:注册 p1_*/p2_* 分区动作(InputMap,仅首次)。
## 键盘分区:P1 = WASD + 左Shift,P2 = 方向键 + Ctrl;
## 手柄独占:P1 = 0 号柄(左摇杆 / A / 左扳机),P2 = 1 号柄(net.md §3)。
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


## 手柄分区绑定:device 0 = P1,device 1 = P2;左摇杆横轴 / A 键 / 左扳机。
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
			return   # 手柄事件已登记(重启输入区不重复叠加)
	InputMap.action_add_event(action, ev)


## 启动同屏双人(net.md §3):管道测试道 Z0 双分位,
## P1 = roster 偶数下标链,P2 = 奇数下标链。
func start_level_dual() -> void:
	if NetSession.I != null and NetSession.I.is_net():
		return   # 同屏双人与联机会话互斥(槽位归属 NetSession,不混管)
	start_level(0)   # 先正常启动(内部 _switch_to(0) 设 is_active;此刻 dual_mode=false,守卫未生效)
	dual_mode = true  # 后翻开关:此后切换守卫生效,绑定须手动
	# 双活绑定:前两 Player 各绑独立输入槽;is_active 双开(dual_mode 下
	# switch_to 已除役,P2 的高亮只能在这里点亮)。
	if roster.players.size() >= 2:
		roster.players[0].input_source = InputSource.local(0)
		roster.players[0].is_active = true
		roster.players[1].input_source = InputSource.local(1)
		roster.players[1].is_active = true
	_refresh_roster()   # 补一次名册刷新:chips 走 binds 双人高亮(单机高亮已被 start_level 刷过)


# ———————————————— 联机(N2 同网直连,net.md §4/§7) ————————————

## 菜单「双人试炼 → 跨设备双人」入口:进入房间流程页(创建 / 加入)。
func open_net_room() -> void:
	if _state != State.MENU:
		return
	_state = State.ROOM
	_menu.visible = false
	net_room_layer.open()


## 两端 start_level 装配完成后的联机收尾(NetSession.on_level_built 调用):
## 主机点亮自己绑定集的首具操控体;客机镜像上传槽为取景 / 名牌语义槽。
func net_post_setup() -> void:
	touch_controls.set_switch_available(true)   # 绑定集 > 1 体,集合内可切
	if NetSession.I.is_host():
		var own: Array = NetSession.I.own_slots_arr()
		if not own.is_empty():
			roster.switch_to(own[0], true)
	else:
		roster.active_slot = NetSession.I.active_slot()
		for i in players.size():
			players[i].is_active = i == roster.active_slot
	_refresh_roster()


## 客机召回执行(主机侧,NetSession._do_recall 调用):传送 + 快照回传。
func net_recall(slot: int) -> void:
	if slot < 0 or slot >= players.size():
		return
	var p: Player = players[slot]
	if p == null or p.in_exit or p.dying or p.arrived:
		return
	p.recall_to(roster.checkpoints.get(p.body_key(), p.spawn_pos))
	Sfx.play("switch")


## 客机结算画面复现(主机经 EV_COMPLETE 触发;流转由主机驱动)。
func net_show_complete() -> void:
	_state = State.TRANSITION
	Sfx.play("complete")
	_hud.show_complete("通过。")


## 两端回房间(联机通关流转终点:不开下一关,主机可再开演)。
func net_back_to_room() -> void:
	get_tree().paused = false
	_clear_level()
	_state = State.ROOM
	_hud.visible = false
	touch_controls.set_in_game(false)
	_hud.set_net_badge("")
	NetSession.I.back_to_lobby()
	net_room_layer.reopen_after_game()


## 主机侧:客机掉线(§11 待议项的临时拍板 = 整队弹回房间,可再开演)。
func net_peer_lost() -> void:
	if _state == State.PLAYING or _state == State.PAUSED or _state == State.TRANSITION:
		get_tree().paused = false
		_pause.close()
		net_back_to_room()
		net_room_layer.toast_line("对手掉线,已返回房间")
	else:
		net_room_layer.toast_line("对手掉线")


## 客机侧:主机掉线 —— 弹回标题菜单 + 明确提示(net.md §5)。
func net_host_lost(was_in_game: bool) -> void:
	get_tree().paused = false
	_pause.close()
	_clear_level()
	_hud.visible = false
	touch_controls.set_in_game(false)
	_hud.set_net_badge("")
	_state = State.MENU
	_menu.visible = true
	_menu.set_unlocked(_unlocked)
	_menu.toast("主机已离开房间" if was_in_game else "与主机的连接已断开")


## N1 退出双人不切换——切靠除役(双活模型,无"另一个受控")。
func _cycle_slot(dir: int) -> void:
	if dual_mode:
		return
	# 联机(N2):绑定集合内切换(主机切本地操控,客机切上传槽)
	if NetSession.I != null and NetSession.I.in_game():
		NetSession.I.cycle_own_slot(dir)
		return
	roster.cycle_slot(dir)


## 切换操控:已到达终点门待命的几何体仍然可以被选中(终点激活前不收取);
## 只跳过正在进门 / 死亡中的几何体。
## 伍(界/边)是双子:两具身体在切换循环中各占一位、独立操控
## (characters.md §5);磁力边界始终张在两顶之间,不随操控改变。
func _switch_to(slot: int, quiet := false) -> void:
	roster.switch_to(slot, quiet)


## 数字键 / 点按 chips 切换(v0.17.2):按几何体下标直达;
## 双子(伍)同下标两具 —— 已选中其一时再点即换另一位。
## 无全局防抖:chips 侧已有 120ms 防抖 + accept_event 吞模拟鼠标双发,
## 这里的旧 150ms 防抖会把"快速再点同芯片切另一体"吞掉(切换失灵)。
func switch_to_geo(index: int) -> void:
	if NetSession.I != null and NetSession.I.in_game():
		NetSession.I.switch_to_geo(index)
		return
	roster.switch_to_geo(index)


func _refresh_roster() -> void:
	roster.refresh_roster()


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
	if archive_panel.is_open or settings_panel.is_open:
		return
	if _state == State.PLAYING:
		# 状态空窗守卫(v0.35.1):肉鸽选体 / 单章剧窗口期 _state 已是
		# PLAYING 而 _level_def 尚未装配(start_rogue_fragment 才落值),
		# 本帧无可玩数据——整帧跳过,防 Nil 逐帧报错(rogueshot 曾 157 帧)
		if _level_def == null:
			return
		_check_deaths()
		if debug_solo:
			return
		# 切换几何体(含已到达待命者):Tab / Q / E / 1-4,Shift+Tab 反向
		if Input.is_action_just_pressed("switch_next"):
			_cycle_slot(-1 if Input.is_physical_key_pressed(KEY_SHIFT) else 1)
		if Input.is_action_just_pressed("switch_prev"):
			_cycle_slot(-1)

		# 数字键按名册位直达(v0.21.0):KEY_1..5 = roster[0..4] 的几何体;
		# 双子(伍)同位两具 —— 再按同键即换另一半。旧实现映射槽位,
		# 双体展开后第 6 具(边)永远够不到。
		for i in mini(_level_def.roster.size(), 5):
			if _key_pressed(KEY_1 + i):
				switch_to_geo(int(_level_def.roster[i]))

		if Input.is_action_just_pressed("recall"):
			recall_active()
		if Input.is_action_just_pressed("pause"):
			_open_pause()
	elif _state == State.ROOM:
		if debug_solo:
			return
		# 房间流程页:Esc = 返回上一步(选页 → 关房/停搜 → 标题菜单)
		if Input.is_action_just_pressed("ui_cancel"):
			net_room_layer.back_out()
	elif _state == State.MENU:
		if debug_solo:
			return
		# 数字键:二级菜单开着时直达该_choose剧目内的场次;否则快速选剧目
		# (1=序章开演 → 进二级菜单,2-4 未上演幕同样给出 toast 反馈);
		# C 打开档案几何;S 打开设置;Esc 关二级菜单 / 退出游戏
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
			_show_menu()


func _check_deaths() -> void:
	roster.check_deaths(_level_def)


func _restart_level() -> void:
	if _state != State.PLAYING:
		return
	Sfx.play("restart")
	# 肉鸽局内重来:重开当前片段(不计死亡,不烧刻度)
	if _rogue:
		_hud.transition_blocks(0.3, func() -> void: start_rogue_fragment(_level_def))
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


func open_archive() -> void:
	archive_panel.open(_unlocked)


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
	# 联机:离开即散房(关 peer / 停信标);主机散房 → 客机收 server_disconnected
	if NetSession.I != null and NetSession.I.is_net():
		NetSession.I.leave("")
		_hud.set_net_badge("")
	_show_menu()


# ———————————————— 剧情文字(konado) ————————————————

## 播放剧情:暂停世界,叠放 Konado 对话层;结束后恢复。
## kind:"act1" 开演剧(首进第一幕)/ "epilogue" 尾声(通关画面)/
## "rogue_*" 肉鸽序说与单章。回看走档案几何剧情页的全文本阅读器,不经此处。
func show_story(kind: String) -> void:
	var story: StoryLayer = STORY_SCENE.instantiate()
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
	# 联机事件漏斗(net.md §6):主机权威事件经可靠 RPC 在客机复现;
	# 客机侧 arrive_at 等回灌本函数时 is_host() 为假,emit 自然no-op。
	if NetSession.I != null and NetSession.I.is_host() and NetSession.I.in_game():
		NetSession.I.emit_event(NetSession.EV_DIED, players.find(p))
	roster.on_player_died(p)


## 到达专属终点门:原地待命(仍可被切换控制),全员到齐后终点激活。
func on_player_arrived(p: Player) -> void:
	if NetSession.I != null and NetSession.I.is_host() and NetSession.I.in_game():
		NetSession.I.emit_event(NetSession.EV_ARRIVED, players.find(p))
	roster.on_player_arrived(p)


## 已到站几何体离开门区:取消到站(终点未激活时随时可以再回来)。
func on_player_departed(p: Player) -> void:
	if NetSession.I != null and NetSession.I.is_host() and NetSession.I.in_game():
		NetSession.I.emit_event(NetSession.EV_DEPARTED, players.find(p))
	roster.on_player_departed(p)


func on_player_exited(p: Player) -> void:
	if NetSession.I != null and NetSession.I.is_host() and NetSession.I.in_game():
		NetSession.I.emit_event(NetSession.EV_EXITED, players.find(p))
	roster.on_player_exited(p)


## 全员到站 → 终点激活:封印各门 → 依次吸入各自的终点门 → 结算。
func _check_all_arrived() -> void:
	roster.check_all_arrived()


## 重生完成:v0.17.3 起不再自动切换——死亡几何体保持操控权,原地复活续玩。
func on_respawn_done() -> void:
	roster.on_respawn_done()


var _checkpoints: Dictionary:
	get:
		return roster.checkpoints


## 召回(v0.17.3):右上按钮 / R 键 —— 当前受控几何体传送回最近记录点;
## 尚无关卡内记录点信标,默认回到其出生点。到站 / 进门 / 死亡中不可召回。
## 双体(伍)两半各回各的出生点 / 各自的记录点(body_key 隔离)。
func recall_active() -> void:
	# 联机(N2):客机召回 = 上传请求,主机执行 teleport 后快照回传落位
	if NetSession.I != null and NetSession.I.in_game():
		NetSession.I.request_recall(roster.active_slot)
		return
	roster.recall_active()


## 记录点登记(关卡内记录点信标实体未来接入):
## key = Player.body_key() —— 双体两半各占一键,不得用几何体下标。
func set_checkpoint(body_key: int, pos: Vector2) -> void:
	roster.set_checkpoint(body_key, pos)


## 置换锚闪(fx-light 卷一 P0:世界翻了,刻度是锚——上下刻度带色序互换一闪)。
func hud_swap_flash() -> void:
	if _hud != null:
		_hud.swap_anchor_flash()


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
		var seq_r := _complete_seq
		var elite := rogue_dir.in_elite
		get_tree().create_timer(0.9).timeout.connect(func() -> void:
			if seq_r == _complete_seq and rogue_dir != null:
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
	# 联机(N2):客机由 EV_COMPLETE 复现结算画面;两端都不自动进下一关,
	# 停留片刻后回房间等待主机再开演(net.md §7 主机选关)。
	if NetSession.I != null and NetSession.I.is_net():
		if NetSession.I.is_host():
			NetSession.I.emit_event(NetSession.EV_COMPLETE)
		_complete_seq += 1
		var seq_n := _complete_seq
		get_tree().create_timer(2.1).timeout.connect(func() -> void:
			if seq_n == _complete_seq:
				net_back_to_room())
		return
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
		_hud.transition_sweep(0.55, func() -> void: start_level(_current + 1))


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
		elif raw == "--tapshot":
			_tap_shot = true
		elif raw == "--debug-grid":
			debug_grid = true
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
	# 分派给开发钩子执行器(scripts/dev/,导出剥离;缺失 = 钩子关闭)
	var h := _dev_harness()
	if h != null:
		if _auto_shot and args.has("--menushot"):
			h.run_menu_shot()
		# --introshot / --storyshot 自带开局流程,跳过通用 autoshot 以免抢关卡
		if _auto_shot and not args.has("--menushot") \
				and not _intro_shot and not _story_shot:
			h.run_auto_shot()
		if _door_shot:
			h.run_door_shot()
		if _recall_shot:
			h.run_recall_test()
		if _transition_shot:
			h.run_transition_shot()
		if _tap_shot:
			h.run_tap_shot()
		if _dual_test:
			h.run_dual_test()
		if _dual_shot:
			h.run_dual_shot()
		if _room_shot:
			h.run_room_shot()
		if _net_test:
			if _net_auto:
				h.run_net_auto()
			elif _net_join:
				h.run_net_join(_net_join_ip)
			else:
				net_session.run_self_test()
		if _trial_shot:
			h.run_trial_shot()
		if _panel_shot:
			h.run_panel_shot()
		if _set_shot:
			h.run_set_shot()
		if _act_shot:
			h.run_actshot()
		if _boot_shot:
			h.run_boot_shot()
		if _intro_shot:
			h.run_intro_shot()
		if _story_shot:
			h.run_story_shot()
		if _rogue_shot:
			h.run_rogue_shot()
		if _rogue_auto:
			h.run_rogue_auto_test()
		if _tour_shot:
			h.run_tour_shot()
		if _lane_shot:
			h.run_lane_shot()
		if _perf_log:
			h.run_perf_log()
		elif OS.is_debug_build() and OS.has_feature("mobile"):
			# Android debug 包自动开基线日志(真机无法传 user args,
			# adb logcat 直接抓 PERF 行);桌面 debug 不受影响。
			h.run_perf_log()
		if _auto_test:
			h.run_auto_test()


## 性能基线日志已迁 scripts/dev/shot_harness.gd run_perf_log()
## (v0.31.1 死代码清扫:原 _run_perf_log 无调用点,harness 侧补上真身)。


var dual_mode := false   # N1 同屏双人:双活绑定(各控各的,不切换)
var _dev_h: RefCounted = null
var _dev_h_tried := false


## 开发钩子执行器软引用(scripts/dev/ 出导出剥离;缺失 = null,钩子关闭)。
func _dev_harness() -> RefCounted:
	if not _dev_h_tried:
		_dev_h_tried = true
		var s: Variant = load("res://scripts/dev/shot_harness.gd")
		_dev_h = s.new() if s != null else null
		if _dev_h != null:
			_dev_h.m = self
	return _dev_h
