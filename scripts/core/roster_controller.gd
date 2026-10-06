class_name RosterController
extends Node


var main: Main
var players: Array = []
var active_slot := 0
var doors := {}  # geo_index -> Array[ExitDoor](v0.55.1 支持同几何体双门)
var checkpoints := {}
var death_hinted := false


func collect_players(level_root: Node2D) -> void:
	players.clear()
	doors.clear()
	for n in level_root.get_children():
		if n is Player:
			players.append(n as Player)
		elif n is ExitDoor:
			var k: int = (n as ExitDoor).geo_index
			if not doors.has(k):
				doors[k] = []
			doors[k].append(n)

	players.sort_custom(func(a: Player, b: Player) -> bool:
		return a.index < b.index)
	active_slot = 0


func view_slot() -> int:
	return active_slot


func camera_targets() -> Array:
	if main.dual_mode and players.size() >= 2:
		return [players[0], players[1]]
	if players.is_empty():
		return []
	var p: Player = players[clampi(active_slot, 0, players.size() - 1)]
	return [] if p == null else [p]


func net_allowed_slots() -> Array:
	if NetSession.I == null or not NetSession.I.in_game():
		return []
	return NetSession.I.own_slots_arr()


static func net_host_authority() -> bool:
	return NetSession.I == null or not NetSession.I.is_net() or NetSession.I.is_host()


func switch_to(slot: int, quiet := false) -> void:
	if main.dual_mode:
		return
	if main._state != Main.State.PLAYING or players.is_empty():
		return
	var allowed := net_allowed_slots()
	var n := players.size()

	for pass_i in 2:
		for k in n:
			var i := (slot + k) % n
			if not allowed.is_empty() and not allowed.has(i):
				continue
			var p: Player = players[i]
			var ok: bool = (not p.in_exit and not p.dying) \
				if pass_i == 0 else (not p.in_exit)
			if not ok:
				continue
			# 切带动量:换体前捕获旧活跃体,水平动量按比例传给新体(仅水平
			# 分量;超额部分由超速带自然衰减,不建第二衰减窗)。
			if active_slot >= 0 and active_slot < n:
				var old: Player = players[active_slot]
				if old != null and old != p and is_instance_valid(old) \
						and not old.dying and not old.in_exit:
					p.velocity.x = old.velocity.x \
						* MovementTuning.I.switch_momentum_ratio
			active_slot = i
			for j in n:
				players[j].is_active = j == active_slot
			refresh_roster()
			if not quiet:
				Sfx.play("switch")
				if main.camera_rig != null:
					main.camera_rig.on_switch()
				if main.backdrop != null:
					main.backdrop.pulse_switch(p.def.color)
			var fs := get_tree().get_first_node_in_group("focus_system")
			if fs != null:
				(fs as FocusSystem).on_switch()
			return


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


func refresh_roster() -> void:
	var mask := 0
	for p in players:
		if p.in_exit or p.arrived:

			var all_in := true
			for q in players:
				if q.index == p.index and not (q.in_exit or q.arrived):
					all_in = false
					break
			if all_in:
				mask |= 1 << p.index
	var active: int = players[active_slot].index \
		if (active_slot >= 0 and active_slot < players.size()) else -1

	# 芯片静默(audit ⑨):dual 不再下发可点双活芯片——dual_binds 展示
	# 出的 P1/P2 描边芯片点上去 switch_to 直接 return,零反馈,展示与
	# 行为歧义以「不下发」消解;hud 消费面零改动,芯片回落普通名签
	# (几何体色块+名不变,退出勾选/活跃高亮语义不受影响)。
	var binds: Array = []
	if not main.dual_mode and NetSession.I != null and NetSession.I.in_game() \
			and main._level_info != null:
		var own: Array = NetSession.I.own_geo_arr()
		var other: Array = NetSession.I.other_geo_arr()
		for g in main._level_info.roster:
			binds.append({"slot": 0 if own.has(int(g)) else 1, "geo": int(g)})
	main._hud.refresh_roster(main._level_info.roster, active, mask, binds)


func check_deaths(def: Dictionary) -> void:
	for p in players:
		if p.dying or p.in_exit or p.arrived:
			continue

		if not net_host_authority():
			return

		if p.gravity_dir > 0 and p.position.y > def.kill_y:
			p.die()
		elif p.gravity_dir < 0 and p.position.y < def.top_kill_y:
			p.die()


func on_player_died(p: Player) -> void:
	if main._auto_test:
		print("TEST: ", p.def.name, " died/respawned")
	if main._state == Main.State.PLAYING:

		if not death_hinted \
				and LevelData.act_index_of(main._current) <= 0:
			death_hinted = true
			main._hud.narration("摔碎不是终结 · 空白处会把你在起点重新拼好",
				Palette.I.red, 3.4)
	refresh_roster()


func on_player_arrived(p: Player) -> void:
	if main._auto_test:
		print("TEST: ", p.def.name, " arrived at exit")
	if main._state != Main.State.PLAYING:
		return

	if main.dual_mode and main.race != null:
		refresh_roster()
		main.race.on_arrival(p)
		return
	refresh_roster()
	check_all_arrived()


func on_player_departed(p: Player) -> void:
	if main._auto_test:
		print("TEST: ", p.def.name, " left the exit")
	refresh_roster()


func on_player_exited(p: Player) -> void:
	if main._auto_test:
		print("TEST: ", p.def.name, " entered exit")
	refresh_roster()


func check_all_arrived() -> void:
	if main._state != Main.State.PLAYING:
		return
	if not net_host_authority():
		return
	for p in players:
		if not p.arrived:
			return

	for idx in doors:
		for d: ExitDoor in doors[idx]:
			if is_instance_valid(d):
				d.sealed = true
	for i in players.size():
		var p: Player = players[i]
		var door: ExitDoor = p.arrived_door
		if door == null and doors.has(p.index):
			var arr: Array = doors[p.index]
			door = arr[0] if not arr.is_empty() else null
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


func on_respawn_done() -> void:
	if main._state != Main.State.PLAYING:
		return


func recall_active() -> void:
	if main._state != Main.State.PLAYING or players.is_empty():
		return
	# 双人召回(audit ④):dual 下作用于双体,各归各自检查点——此前只
	# 召回 players[active_slot] 而 active_slot 恒 0,P2 永远唤不回自己。
	# 单人路径仍只召回活跃体;联机走 game_flow.net_recall 语义不变。
	if main.dual_mode:
		var recalled := false
		for p in players:
			if p == null or not is_instance_valid(p) \
					or p.in_exit or p.dying or p.arrived:
				continue
			p.recall_to(checkpoints.get(p.index, p.spawn_pos))
			recalled = true
		if recalled:
			Sfx.play("switch")
		return
	if active_slot < 0 or active_slot >= players.size():
		return
	var p: Player = players[active_slot]
	if p == null or p.in_exit or p.dying or p.arrived:
		return
	p.recall_to(checkpoints.get(p.index, p.spawn_pos))
	Sfx.play("switch")


func set_checkpoint(key: int, pos: Vector2) -> void:
	checkpoints[key] = pos
