extends SceneTree

# 教程波门禁(headless):
#   godot --headless --path . --script res://tests/tutorial_check.gd
# 断言:教学关可加载(摆件/几何契约齐备)、路径契约与 ui 波守卫逐字
# 一致、v10 旧档迁移后教程新字段缺省正确、实机 start_tutorial 全链路
# (建体/导演层挂载/跳过钮命中)、reduced 分支在册(WIN 直显 + 导演层
# 零动效设计)。输出 "TUTORIALCHECK ALL PASS",退出码即结果。

const TUT_PATH := "res://levels_native/tutorial/tutorial.tscn"
const DIRECTOR_PATH := "res://scripts/tutorial/tutorial_director.gd"
const LAYER_PATH := "res://scenes/tutorial/tutorial_layer.tscn"
const HUD_PATH := "res://scripts/ui/hud.gd"
const MENU_PATH := "res://scripts/ui/menu_layer.gd"
const SAVE_PATH := "user://speed-rouge.cfg"

var _fails := 0


func _initialize() -> void:
	_run()


func _expect(cond: bool, msg: String) -> void:
	if cond:
		return
	_fails += 1
	print("TUTORIAL FAIL: ", msg)


func _run() -> void:
	Ui.init_font()
	await process_frame
	_check_scene()
	_check_contract()
	await _check_save_migration()
	await _check_live_boot()
	if _fails == 0:
		print("TUTORIALCHECK ALL PASS")
	else:
		print("TUTORIALCHECK FAILED (%d)" % _fails)
	quit(0 if _fails == 0 else 1)


## 教学关静态体检:可加载、Spawn/门/记录点/机关/提示牌齐备、
## roster 与 Geometries 一致(越界即 FAIL)。
func _check_scene() -> void:
	_expect(FileAccess.file_exists(TUT_PATH), "教学关场景缺失 " + TUT_PATH)
	if not FileAccess.file_exists(TUT_PATH):
		return
	var ps: PackedScene = load(TUT_PATH)
	_expect(ps != null, "教学关场景无法加载")
	if ps == null:
		return
	var root: NativeLevel = ps.instantiate()
	_expect(root != null, "教学关实例化失败")
	if root == null:
		return
	_expect(root.level_name == "新手教程",
		"level_name=%s 应为「新手教程」" % root.level_name)
	var roster: Array = root.roster
	_expect(roster.size() == 1 and int(roster[0]) == 0,
		"roster=%s 应为 [0](红体单课教学)" % str(roster))
	for idx: int in roster:
		_expect(idx >= 0 and idx < Geometries.ALL.size(),
			"roster 成员 %d 越出 Geometries.ALL" % idx)
	var spawns := 0
	var doors := 0
	var beacons := 0
	var hints := 0
	var gates := 0
	for n in root.get_children():
		if n is SpawnMarker:
			spawns += 1
			_expect(roster.has((n as SpawnMarker).geo_index),
				"Spawn geo%d 不在 roster" % (n as SpawnMarker).geo_index)
		elif n is ExitDoor:
			doors += 1
			_expect(roster.has((n as ExitDoor).geo_index),
				"终点门 geo%d 不在 roster" % (n as ExitDoor).geo_index)
		elif n is CheckpointBeacon:
			beacons += 1
		elif n is HintMarker:
			hints += 1
		elif n is SpeedGate:
			gates += 1
	_expect(spawns == roster.size(), "Spawn 数 %d ≠ roster %d" % [spawns, roster.size()])
	_expect(doors >= 1, "缺终点门 ExitDoor")
	_expect(beacons >= 1, "缺记录点 CheckpointBeacon")
	_expect(hints >= 4, "世界提示牌 %d < 4(四拍世界侧兜底文案缺失)" % hints)
	_expect(gates >= 1, "缺加速门 SpeedGate(首个机关)")
	root.free()


## 路径契约:GameFlow.TUTORIAL_SCENE / ui 波菜单钮守卫路径 / 磁盘文件
## 三者逐字一致;导演层三件套在册;reduced 分支在册。
func _check_contract() -> void:
	_expect(GameFlow.TUTORIAL_SCENE == TUT_PATH,
		"GameFlow.TUTORIAL_SCENE=%s 与守卫路径不一致" % GameFlow.TUTORIAL_SCENE)
	var menu_txt := FileAccess.get_file_as_string(MENU_PATH)
	_expect(menu_txt.contains('"%s"' % TUT_PATH),
		"menu_layer.gd 守卫路径与教学关路径不一致")
	var dir_txt := FileAccess.get_file_as_string(DIRECTOR_PATH)
	_expect(dir_txt.contains("Adaptive.adapt_copy"), "导演层文案未经 adapt_copy")
	_expect(dir_txt.contains("copy_touch"), "导演层缺触屏语言变体")
	_expect(dir_txt.contains("tutorial_done"), "导演层缺通关落档")
	_expect(dir_txt.contains("tutorial_seen"), "导演层缺已见落档")
	_expect(not dir_txt.contains("create_tween()"),
		"导演层动效应为零(reduced 零位移设计,动态请走状态直换)")
	_expect(FileAccess.file_exists(LAYER_PATH), "导演层场景缺失 " + LAYER_PATH)
	var hud_txt := FileAccess.get_file_as_string(HUD_PATH)
	_expect(hud_txt.contains("_sync_tutorial_layer"), "hud 缺教程层挂载收口")
	_expect(hud_txt.contains("SettingsManager.reduced_motion"),
		"hud WIN 入场缺 reduced 直显分支")


## 存档迁移实证(可执行路径):v10 旧档注入 user:// → SaveManager 读回
## 战役进度保留、教程新字段缺省 false → 写回即 v11。原档先备份后还原。
func _check_save_migration() -> void:
	var original := ""
	if FileAccess.file_exists(SAVE_PATH):
		original = FileAccess.get_file_as_string(SAVE_PATH)
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 10)
	cfg.set_value("meta", "game_version", "0.68.0")
	cfg.set_value("progress", "unlocked", 3)
	cfg.set_value("stats", "lv1_cleared", true)
	cfg.set_value("stats", "lv1_best_ms", 15234)
	cfg.set_value("stats", "total_deaths", 7)
	cfg.set_value("tutorial", "done", false)
	if cfg.save(SAVE_PATH) != OK:
		_fails += 1
		print("TUTORIAL FAIL: v10 假档写入失败")
		return
	var sm := SaveManager.new()
	sm.load_save()
	_expect(sm.unlocked == 3, "旧档 unlocked=%d 应原样保留(纯追加迁移)" % sm.unlocked)
	_expect(sm.is_cleared(1), "旧档 cleared 丢失")
	_expect(sm.best_time_of(1) == 15234, "旧档 best_ms 丢失")
	_expect(not sm.tutorial_done, "旧档 tutorial_done 缺省应为 false")
	_expect(not sm.tutorial_seen, "旧档 tutorial_seen 缺省应为 false")
	_expect(SaveManager.SAVE_VERSION == 11, "SAVE_VERSION 应为 11")
	sm.tutorial_seen = true
	sm.write_save()
	var after := ConfigFile.new()
	var read_err := after.load(SAVE_PATH)
	_expect(read_err == OK and int(after.get_value("meta", "save_version", 0)) == 11
		and bool(after.get_value("tutorial", "seen", true)),
		"写回后 save_version=11 / tutorial.seen 落盘失败")
	# 再读一次:v11 档 + seen=true → 字段回读正确(用户值不回退)。
	var sm2 := SaveManager.new()
	sm2.load_save()
	_expect(sm2.tutorial_seen and not sm2.tutorial_done,
		"v11 档回读 seen/done 不正确")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if not original.is_empty():
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_string(original)
		f.close()


## 实机全链路:Main.create → start_tutorial → 建体/落地/导演层挂载/
## 开场卡教程抬头/编号面板收起。
func _check_live_boot() -> void:
	var main := Main.create()
	root.add_child(main)
	await process_frame
	await process_frame
	main.debug_solo = true
	main.game_flow.start_tutorial()
	await create_timer(2.0).timeout
	_expect(main._state == Main.State.PLAYING, "start_tutorial 后未进 PLAYING")
	_expect(main.game_flow.tutorial_mode, "tutorial_mode 未置位")
	_expect(main.players.size() == 1,
		"建体数 %d ≠ 1" % main.players.size())
	if not main.players.is_empty():
		var p: Player = main.players[0]
		_expect(p.is_on_floor() or p.velocity.length() < 20.0,
			"教程出生未落地 @ %s" % str(p.position))
	var hud: Hud = main._hud
	_expect(hud._tut != null, "教程导演层未挂载到 HUD")
	if hud._tut != null:
		_expect(hud._tut.get_parent() == hud, "教程导演层父级应为 HUD")
		var skip: Button = hud._tut.get_node("%Skip")
		_expect(skip.custom_minimum_size.y >= 44.0,
			"跳过钮命中高 %.0f < 44" % skip.custom_minimum_size.y)
		var copy: Label = hud._tut.get_node("%Copy")
		_expect(not copy.text.is_empty(), "导演层首拍文案为空")
	# 幽灵签承载契约:签入定宽锚槽(常驻 TitleRow),显隐不再重排行。
	_expect(hud._ghost_slot != null and hud._ghost_chip != null \
		and hud._ghost_chip.get_parent() == hud._ghost_slot \
		and hud._ghost_slot.custom_minimum_size.x >= 60.0,
		"幽灵签未入固定锚槽(TitleRow 回摆未根除)")
	_expect(not hud.get_node("%NumPanel").visible, "教程局编号面板应收起")
	var intro_num: Label = hud.get_node("%IntroNum")
	_expect(not intro_num.text.begins_with("正戏"),
		"教程开场卡抬头=%s(不应是「正戏」抬头)" % intro_num.text)
	# 关卡结束/返回菜单清理路径:直回菜单后导演层应收口。
	hud._sync_tutorial_layer()
	main.game_flow.show_menu()
	await process_frame
	await process_frame
	_expect(hud._tut == null, "返回菜单后教程导演层残留")
