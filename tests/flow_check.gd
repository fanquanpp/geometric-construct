extends Node2D
## 开发门禁:通关第 N 关 → 自动流转第 N+1 关 → 受控几何体必须出生在
## 新关 spawns[focus](v0.44.0 回归防护:clear_level 若用 queue_free 延迟
## 释放,旧 LevelRoot 的 character_created 连接会同帧抢挂,出生错位)。
## 运行:godot --path . res://tests/flow_check.tscn(退出码 0 = 过)

const PROBE_IDX := 2   # 第一幕第 2 场(疾速课)→ 第 3 场,非末关走 start_level+1 分支


func _ready() -> void:
	var main := Main.new()
	add_child(main)
	await get_tree().process_frame
	main.start_level(PROBE_IDX, false)
	await get_tree().create_timer(1.0).timeout

	var doors: Array = []
	for n in main._level_root.get_children():
		if n is ExitDoor:
			doors.append(n)
	for p in main.players:
		for d in doors:
			if d.geo_index == p.index:
				p.position = d.center + Vector2(0, 4)
				break
	# 通关结算 2.1s 后 after_complete → transition_sweep → start_level(+1)
	await get_tree().create_timer(6.0).timeout

	var ok := true
	var flow: GameFlow = main.game_flow
	if flow.current != PROBE_IDX + 1:
		ok = false
		print("FLOW FAIL: current=", flow.current, " expect ", PROBE_IDX + 1)
	var def: LevelDef = flow.level_def
	var p0: Player = main.players[main.view_slot()] \
		if not main.players.is_empty() else null
	if p0 == null:
		print("FLOW FAIL: 下一关无已诞生玩家(players=%d)" % main.players.size())
		get_tree().quit(1)
		return
	# 期望位置 = 受控几何体自己的出生点(spawns 按几何体下标索引)
	var raw = def.spawns[p0.index] \
		if p0.index < def.spawns.size() else Vector2.ZERO
	var want: Vector2 = raw.get("b") if raw is Dictionary else raw
	var got: Vector2 = p0.position
	if got.distance_to(want) > 40.0:
		ok = false
		print("FLOW FAIL: spawn got=", got, " want=", want,
			" level=", def.name, " geo=", p0.index)
	if ok:
		print("FLOW CHECK PASS (L%d→L%d · %s · geo%d @ %s)"
			% [PROBE_IDX, PROBE_IDX + 1, def.name, p0.index, got])
	get_tree().quit(0 if ok else 1)
