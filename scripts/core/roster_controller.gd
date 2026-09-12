class_name RosterController
extends Node
## 名册域控制器(统合重构终案 Sprint 3):切换 / 召回 / 到站 / 记录点的
## 状态与逻辑唯一归属地。Main 保留同名一行委托与数据 getter 作为对外
## 契约(hud / net / tests 的调用点零改动);body_key 双体身份契约
## (characters.md §5)一字不动 —— 本文件只迁职责,不改语义。
##
## 状态:
##   players      当前关卡的几何体实例(双子同 index 两具,pair_half 排序)
##   active_slot  受控槽位(= Main._active_slot 的真身)
##   doors        geo_index -> ExitDoor
##   checkpoints  体身份键(Player.body_key)-> Vector2 最近记录点
##
## InputRouter 审计结论(2026-09-11,随 Sprint 3 归档):名册指令
## (切换 / 直达 / 召回)的入口已收敛于此 —— 键盘(_physics_process)、
## 触屏 chips(chip_tapped)、召回按钮 / R 键、测试钩子全部经 Main 委托
## 进同一实现;设备级输入分流已由 InputSource(net.md §2 N0)承担,
## 不再需要第二个路由层。

var main: Main
var players: Array = []
var active_slot := 0
var doors := {}          # geo_index -> ExitDoor
var checkpoints := {}    # 体身份键 -> Vector2(双体两半各占一键)
var death_hinted := false   # 序章首摔安抚旁白已播(每次启动一次;自 Main 迁入)


func collect_players(level_root: Node2D) -> void:
	players.clear()
	doors.clear()
	for n in level_root.get_children():
		if n is Player:
			players.append(n as Player)
		elif n is ExitDoor:
			doors[(n as ExitDoor).geo_index] = n
	# 双子(伍)两具同 index:按 pair_half 稳定排序,界恒先于边
	players.sort_custom(func(a: Player, b: Player) -> bool:
		if a.index != b.index:
			return a.index < b.index
		return a.pair_half < b.pair_half)
	active_slot = 0


## 当前取景槽位(net.md §3 视口插槽预埋):HUD / 相机 / 分镜统一经此取
## "看谁"。单机 = 受控槽透传(行为不变);同屏双人(N1)将按视口返回
## 各自绑定槽。
func view_slot() -> int:
	return active_slot


## 取景目标集(net.md §3 相机插槽预埋):相机 / HUD 超距指示统一经此取。
## 单机 = 受控几何体单元素(含越界钳制);同屏双人(N1)将返回两具
## 绑定体,相机经 targets.size()>1 自动分流双人缩放。
func camera_targets() -> Array:
	if main.dual_mode and players.size() >= 2:
		return [players[0], players[1]]   # 双人:双取景(镜头动态缩放)
	if players.is_empty():
		return []
	var p: Player = players[clampi(active_slot, 0, players.size() - 1)]
	return [] if p == null else [p]


## 切换操控:已到达终点门待命的几何体仍然可以被选中(终点激活前不收取);
## 只跳过正在进门 / 死亡中的几何体。
## 伍(界/边)是双子:两具身体在切换循环中各占一位、独立操控
## (characters.md §5);磁力边界始终张在两顶之间,不随操控改变。
## 联机绑定集过滤(N2,net.md §8 首版对半分):返回本机可操控的
## players 下标集合;非联机返回空数组 = 不过滤。判定的唯一入口,
## switch_to / check_deaths 共用。
func net_allowed_slots() -> Array:
	if NetSession.I == null or not NetSession.I.in_game():
		return []
	return NetSession.I.own_slots_arr() if NetSession.I.is_host() \
		else NetSession.I.own_slots_arr()


## 联机中本机是否主机权威编排方(到站编排 / 死亡判定只在主机跑)。
static func net_host_authority() -> bool:
	return NetSession.I == null or not NetSession.I.is_net() or NetSession.I.is_host()


func switch_to(slot: int, quiet := false) -> void:
	if main.dual_mode:
		return   # 同屏双人:切换除役(双活模型)
	if main._state != Main.State.PLAYING or players.is_empty():
		return
	var allowed := net_allowed_slots()
	var n := players.size()
	# 第一遍:找健康几何体(含已到达待命者);第二遍:接受正在重生中的几何体
	for pass_i in 2:
		for k in n:
			var i := (slot + k) % n
			if not allowed.is_empty() and not allowed.has(i):
				continue   # 联机:绑定集之外的几何体不可选中
			var p: Player = players[i]
			var ok: bool = (not p.in_exit and not p.dying) \
				if pass_i == 0 else (not p.in_exit)
			if not ok:
				continue
			active_slot = i
			for j in n:
				players[j].is_active = j == active_slot
			refresh_roster()
			if not quiet:
				Sfx.play("switch")
				main._hud.narration(p.quote_text(), p.def.color)
				if main.camera_rig != null:
					main.camera_rig.on_switch()
			return


## 数字键 / 点按 chips 切换(v0.17.2):按几何体下标直达;
## 双子(伍)同下标两具 —— 已选中其一时再点即换另一位。
## 无全局防抖:chips 侧已有 120ms 防抖 + accept_event 吞模拟鼠标双发,
## 这里的旧 150ms 防抖会把"快速再点同芯片切另一体"吞掉(切换失灵)。
func switch_to_geo(index: int) -> void:
	if main._state != Main.State.PLAYING or players.is_empty():
		return
	var candidates: Array = []
	for i in players.size():
		var p: Player = players[i]
		if p.index == index and not p.in_exit and not p.dying:
			candidates.append(i)
	if candidates.is_empty():
		return
	var target: int = candidates[0]
	if candidates.size() > 1 and candidates.has(active_slot):
		target = candidates[1] if active_slot == candidates[0] else candidates[0]
	switch_to(target)


func cycle_slot(dir: int) -> void:
	if players.is_empty():
		return
	switch_to(((active_slot + dir) % players.size() + players.size()) % players.size())


## 双活绑定槽(net.md §2「roster chips 双人高亮」数据源)。HUD binds 契约:
## [{slot: 0/1, geo: 几何体下标}];N2 联机的绑定集合(NetSession.split_roster
## → 槽位)按同一形状对齐,房间 UI / 相机插槽复用此形状取"谁被谁控"。
func dual_binds() -> Array:
	if players.size() < 2:
		return []
	return [{"slot": 0, "geo": players[0].index},
		{"slot": 1, "geo": players[1].index}]


func refresh_roster() -> void:
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
	var active: int = players[active_slot].index \
		if (active_slot >= 0 and active_slot < players.size()) else -1
	# 同屏双人:无单一"受控"槽,active 高亮让位给 binds 双人描边
	# (P1 纸白 / P2 橙,hud.refresh_roster)。联机(N2)同样双方描边:
	# own = slot 0(纸白)/ other = slot 1(橙),数据源 = NetSession
	# 开局绑定集(v0.36.0 选角认领,net.md §8)——不画出来,玩家无从
	# 知道哪些几何体归自己。
	var binds: Array = []
	if main.dual_mode:
		binds = dual_binds()
	elif NetSession.I != null and NetSession.I.in_game() \
			and main._level_def != null:
		var own: Array = NetSession.I.own_geo_arr()
		var other: Array = NetSession.I.other_geo_arr()
		for g in main._level_def.roster:
			binds.append({"slot": 0 if own.has(int(g)) else 1, "geo": int(g)})
	main._hud.refresh_roster(main._level_def.roster, active, mask, binds)


func check_deaths(def: LevelDef) -> void:
	for p in players:
		if p.dying or p.in_exit or p.arrived:
			continue
		# 联机:死亡判定主机权威(net.md §6),客机侧几何体由快照搬运,
		# 本地判定不可信 —— 跳过,由主机经 EV_DIED 复现。
		if not net_host_authority():
			return
		# 死亡判定按各几何体"当前"重力方向(置换会翻转)
		if p.gravity_dir > 0 and p.position.y > def.kill_y:
			p.die()
		elif p.gravity_dir < 0 and p.position.y < def.top_kill_y:
			p.die()


func on_player_died(p: Player) -> void:
	if main._auto_test:
		print("TEST: ", p.def.name, " died/respawned")
	if main._state == Main.State.PLAYING:
		# v0.17.3:死亡不再自动切换几何体(操控权保持,由玩家手动切换)
		# 序章首摔安抚(每次启动至多一次):把序幕"重拼"规则说成玩法语言,
		# 新手第一次摔碎时不至于以为出了错
		if not death_hinted and not main._rogue \
				and LevelData.act_index_of(main._current) <= 0:
			death_hinted = true
			main._hud.narration("摔碎不是终结 · 空白处会把你在起点重新拼好",
				Palette.I.red, 3.4)
	refresh_roster()
	# 肉鸽:重拼消耗一段红色刻度,耗尽则本局落幕
	if main._rogue:
		main.rogue_dir.on_player_died()


## 到达专属终点门:原地待命(仍可被切换控制),全员到齐后终点激活。
func on_player_arrived(p: Player) -> void:
	if main._auto_test:
		print("TEST: ", p.def.name, " arrived at exit")
	if main._state != Main.State.PLAYING:
		return
	# v0.17.3:到站不再自动切换几何体(玩家手动点 chips / 数字键切换)
	refresh_roster()
	check_all_arrived()


## 已到站几何体离开门区:取消到站(终点未激活时随时可以再回来)。
func on_player_departed(p: Player) -> void:
	if main._auto_test:
		print("TEST: ", p.def.name, " left the exit")
	refresh_roster()


func on_player_exited(p: Player) -> void:
	if main._auto_test:
		print("TEST: ", p.def.name, " entered exit")
	refresh_roster()


## 全员到站 → 终点激活:封印各门 → 依次吸入各自的终点门 → 结算。
## 联机:主机权威编排(net.md §6),客机由 EV_SEAL / EV_EXITED / EV_COMPLETE
## 事件复现,本函数在客机侧直返。
func check_all_arrived() -> void:
	if main._state != Main.State.PLAYING:
		return
	if not net_host_authority():
		return
	for p in players:
		if not p.arrived:
			return
	# 终点激活:封印门区,到达状态不再可撤销
	for idx in doors:
		var d: ExitDoor = doors[idx]
		if is_instance_valid(d):
			d.sealed = true
	for i in players.size():
		var p: Player = players[i]
		var door: ExitDoor = doors.get(p.index)
		if door == null:
			continue
		var delay := 0.08 + 0.18 * i
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(p) and is_instance_valid(door):
				p.enter_exit(door))
	get_tree().create_timer(0.08 + 0.18 * players.size() + 0.55).timeout.connect(
		func() -> void:
			if main._state == Main.State.PLAYING:
				main._check_complete())


## 重生完成:v0.17.3 起不再自动切换——死亡几何体保持操控权,原地复活续玩。
func on_respawn_done() -> void:
	if main._state != Main.State.PLAYING:
		return


## 召回(v0.17.3):右上按钮 / R 键 —— 当前受控几何体传送回最近记录点;
## 尚无关卡内记录点信标,默认回到其出生点。到站 / 进门 / 死亡中不可召回。
## 双体(伍)两半各回各的出生点 / 各自的记录点(body_key 隔离)。
func recall_active() -> void:
	if main._state != Main.State.PLAYING or players.is_empty():
		return
	if active_slot < 0 or active_slot >= players.size():
		return
	var p: Player = players[active_slot]
	if p == null or p.in_exit or p.dying or p.arrived:
		return
	p.recall_to(checkpoints.get(p.body_key(), p.spawn_pos))
	Sfx.play("switch")


## 记录点登记(关卡内记录点信标实体未来接入):
## key = Player.body_key() —— 双体两半各占一键,不得用几何体下标。
func set_checkpoint(body_key: int, pos: Vector2) -> void:
	checkpoints[body_key] = pos
