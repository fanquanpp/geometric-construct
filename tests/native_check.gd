extends Node2D
## 原生作关门禁(native-levels.md §4):逐关装载关卡目录场景,断言——
## ①玩家诞生数 = 名册体数(双子两具);②全员落地站稳;
## ③每个名册成员都有专属终点门;④Spawn 摆位标记齐全。
## 运行:godot --path . res://tests/native_check.tscn(退出码 0 = 过)


func _ready() -> void:
	var main := Main.new()
	add_child(main)
	await get_tree().process_frame
	var fails := 0
	for li in LevelData.count():
		main.start_level(li, false)
		await get_tree().create_timer(3.0).timeout
		var root: NativeLevel = main._level_root
		if root == null:
			fails += 1
			print("NATIVE FAIL L%d: 场景未装载" % li)
			continue
		var roster: Array = root.roster
		var bodies := 0
		for idx in roster:
			bodies += 2 if Geometries.get_def(idx).paired else 1
		var label := "%s · %s" % [LevelData.scene_name(li), root.level_name]
		if bodies == 0:
			fails += 1
			print("NATIVE FAIL L%d %s: 场景 roster 为空(登记/摆位缺失)" % [li, label])
			continue
		if main.players.size() != bodies:
			fails += 1
			print("NATIVE FAIL L%d %s: players=%d expect=%d"
				% [li, label, main.players.size(), bodies])
		for p in main.players:
			if not (p.is_on_floor() or p.velocity.length() < 20.0):
				fails += 1
				print("NATIVE FAIL L%d %s: %s 未落地 @ %s vel=%s g=%d ph=%d mask=%d"
					% [li, label, p.def.name, p.position, p.velocity,
					p.gravity_dir, p.pair_half, p.collision_mask])
		for idx: int in roster:
			var door_ok := false
			for n in root.get_children():
				if n is ExitDoor and n.geo_index == idx:
					door_ok = true
					break
			if not door_ok:
				fails += 1
				print("NATIVE FAIL L%d %s: 缺 geo%d 终点门" % [li, label, idx])
		for idx: int in roster:
			var names: Array = ["Spawn%d" % idx]
			if Geometries.get_def(idx).paired:
				names = ["Spawn%d_a" % idx, "Spawn%d_b" % idx]
			for nn: String in names:
				if root.get_node_or_null(NodePath(nn)) == null:
					fails += 1
					print("NATIVE FAIL L%d %s: 缺 %s" % [li, label, nn])
		print("NATIVE L%d %s · bodies=%d" % [li, label, main.players.size()])
	if fails == 0:
		print("NATIVE CHECK ALL PASS (%d levels)" % LevelData.count())
	else:
		print("NATIVE CHECK FAILED (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
