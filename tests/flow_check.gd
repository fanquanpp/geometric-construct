extends Node2D


const PROBE_IDX := 2


func _ready() -> void:
	var main := Main.create()
	add_child(main)
	main.debug_solo = true
	await get_tree().process_frame
	main.start_level(PROBE_IDX, false)
	await get_tree().create_timer(1.0).timeout

	for n in main._level_root.get_children():
		if n is ExitDoor and n.geo_index == main.players[0].index:
			main.players[0].position = n.position + Vector2(0, 4)
			break
	await get_tree().create_timer(1.5).timeout
	print("FLOWDBG in_exit=", main.players[0].in_exit, " arrived=",
		main.players[0].arrived, " state=", Main.State.keys()[main._state],
		" doors=", main._doors.size(), " root_children=",
		main._level_root.get_children().map(func(c: Node) -> String: return c.name))

	await get_tree().create_timer(6.0).timeout

	var ok := true
	var flow: GameFlow = main.game_flow
	if flow.current != PROBE_IDX + 1:
		ok = false
		print("FLOW FAIL: current=", flow.current, " expect ", PROBE_IDX + 1)
	var p0: Player = main.players[main.view_slot()] \
		if not main.players.is_empty() else null
	if p0 == null:
		print("FLOW FAIL: 下一关无已诞生玩家(players=%d)" % main.players.size())
		get_tree().quit(1)
		return

	var marker := main._level_root.get_node_or_null(
		NodePath("Spawn%d" % p0.index)) as Marker2D
	var want: Vector2 = marker.global_position \
		if marker != null else Vector2.ZERO
	var got: Vector2 = p0.position
	if got.distance_to(want) > 40.0:
		ok = false
		print("FLOW FAIL: spawn got=", got, " want=", want,
			" level=", flow.level_info.get("name", "?"), " geo=", p0.index)
	if ok:
		print("FLOW CHECK PASS (L%d→L%d · %s · geo%d @ %s)"
			% [PROBE_IDX, PROBE_IDX + 1, flow.level_info.get("name", "?"),
			p0.index, got])
	get_tree().quit(0 if ok else 1)
