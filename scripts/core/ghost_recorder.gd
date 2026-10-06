class_name GhostRecorder
extends Node


const SAMPLE_MS := 100

var main: Main
var _samples := {}
var _best_by_level := {}
var _marks := {}
var _draw: GhostDraw
var _last_ms := -1000
var _recent := {}
var _replays: Array = []


func on_level_started(level_index: int) -> void:
	_samples = {}
	_last_ms = -SAMPLE_MS
	if not _marks.has(level_index):
		_marks[level_index] = []
	_recent = {}
	_replays = []
	if _draw != null and is_instance_valid(_draw):
		_draw.queue_free()
		_draw = null
	if (NetSession.I != null and NetSession.I.is_net()) or main.dual_mode:
		# 联机整段禁用幽灵:不载回、不落盘、不绘制(差值签同步隐藏)。
		# dual 同 gate(audit ⑤):双人竞速整段禁读/禁采/禁存——双体样本
		# 与含倒计时的用时不再覆盖单人计时赛最佳幽灵,单人纯净恢复。
		_best_by_level.erase(level_index)
		return
	# 跨会话最佳幽灵载回:曾改写纪录的路线立即作为本局实时参照。
	_backfill_best(level_index)
	if main._level_root == null:
		return
	_draw = GhostDraw.new()
	_draw.recorder = self
	_draw.level_index = level_index
	main._level_root.add_child(_draw)


func on_death(p: Player) -> void:
	if (NetSession.I != null and NetSession.I.is_net()) or main.dual_mode:
		return
	var li: int = main.game_flow.current
	if not _marks.has(li):
		_marks[li] = []
	_marks[li].append(p.position)
	var key: int = p.index
	var ring: Array = _recent.get(key, []).duplicate()
	ring.append({"t": -1, "pos": p.position, "index": p.index})
	if _replays.size() < 30:
		_replays.append(ring)
	if _draw != null:
		_draw.queue_redraw()


func _physics_process(_delta: float) -> void:
	if main == null or main._state != Main.State.PLAYING:
		return
	if (NetSession.I != null and NetSession.I.is_net()) or main.dual_mode:
		return
	var gf: GameFlow = main.game_flow
	if gf == null:
		return
	var ms := gf.run_ms
	if ms - _last_ms < SAMPLE_MS:
		return
	_last_ms = ms
	for p in main.players:
		if p == null or not is_instance_valid(p) or p.in_exit or p.dying:
			continue
		var key: int = p.index
		if not _samples.has(key):
			_samples[key] = []
		var rec := {"t": ms, "pos": p.position, "index": p.index}
		(_samples[key] as Array).append(rec)
		if not _recent.has(key):
			_recent[key] = []
		var ring: Array = _recent[key]
		ring.append(rec)
		if ring.size() > 10:
			ring.pop_front()


func on_complete() -> void:
	if (NetSession.I != null and NetSession.I.is_net()) or main.dual_mode:
		# dual 竞速结束(main._on_race_finished 即调)整段不落:无死亡
		# 回放、无最佳覆写、无存档写盘(键级门禁:lv%d_ghost 零变化)。
		return
	if not _replays.is_empty() and not SettingsManager.reduced_motion \
			and main._level_root != null:
		var theater := DeathTheater.new()
		theater.recorder = self
		main._level_root.add_child(theater)
	var li: int = main.game_flow.current
	var best: Dictionary = _best_by_level.get(li, {})
	var best_ms: int = best.get("ms", -1)
	if best_ms < 0 or main.game_flow.run_ms < best_ms:
		_best_by_level[li] = {"ms": main.game_flow.run_ms,
			"samples": _samples.duplicate(true)}
		# 新纪录落盘(auto/dev 会话不写,与 game_flow.check_complete
		# 的存档门一致;联机已在上方禁用)。
		if not main._auto_test and not main.debug_solo and not main.dev_run:
			main._save.store_best_ghost(li, main.game_flow.run_ms,
				_best_by_level[li]["samples"])
			main._save.write_save()


## 从存档平铺幽灵重建 _best_by_level 条目(结构与在线记录一致)。
func _backfill_best(li: int) -> void:
	_best_by_level.erase(li)
	var flat: PackedFloat32Array = main._save.best_ghost_of(li)
	if flat.size() < 2:
		return
	var samples := {}
	var i := 2
	for _b in int(flat[1]):
		if i + 2 > flat.size():
			return
		var key := int(flat[i])
		var count := int(flat[i + 1])
		i += 2
		var arr: Array = []
		for _s in count:
			if i + 3 > flat.size():
				return
			arr.append({"t": int(flat[i]),
				"pos": Vector2(flat[i + 1], flat[i + 2]), "index": key})
			i += 3
		samples[key] = arr
	if not samples.is_empty():
		_best_by_level[li] = {"ms": int(flat[0]), "samples": samples}


func best_of(level_index: int) -> Dictionary:
	return _best_by_level.get(level_index, {})


func marks_of(level_index: int) -> Array:
	return _marks.get(level_index, [])


class DeathTheater extends Node2D:
	const DUR := 1.1
	const HOLD := 0.7
	var recorder: GhostRecorder
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t > DUR + HOLD:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if Palette.I == null:
			return
		var k := clampf(_t / DUR, 0.0, 1.0)
		var fade := 1.0 if _t <= DUR else maxf(1.0 - (_t - DUR) / HOLD, 0.0)
		for ring: Array in recorder._replays:
			if ring.size() < 2:
				continue
			var pts := PackedVector2Array()
			for s in ring:
				pts.append(s["pos"])
			var head_idx := int(floor(k * float(pts.size() - 1)))
			var col: Color = _color_of(ring[0])
			draw_polyline(pts, Color(col.r, col.g, col.b, 0.30 * fade), 2.0, true)
			var head: Vector2 = pts[head_idx]
			var sz := 8.0
			draw_rect(Rect2(head - Vector2(sz, sz) / 2.0,
				Vector2(sz, sz)), Color(col.r, col.g, col.b, 0.85 * fade))
			draw_rect(Rect2(head - Vector2(sz, sz) / 2.0,
				Vector2(sz, sz)), Color(Palette.I.paper, 0.6 * fade), false, 1.5)

	func _color_of(s: Dictionary) -> Color:
		var idx: int = s.get("index", 0)
		if idx < 0 or idx >= Geometries.ALL.size():
			return Palette.I.paper
		return Geometries.ALL[idx].color


class GhostDraw extends Node2D:
	var recorder: GhostRecorder
	var level_index := 0

	func _draw() -> void:
		if Palette.I == null:
			return
		for m: Vector2 in recorder.marks_of(level_index):
			draw_line(m + Vector2(-7, -7), m + Vector2(7, 7),
				Color(Palette.I.red, 0.45), 3.0)
			draw_line(m + Vector2(7, -7), m + Vector2(-7, 7),
				Color(Palette.I.red, 0.45), 3.0)
		var best: Dictionary = recorder.best_of(level_index)
		if best.is_empty():
			return
		var ms: int = recorder.main.game_flow.run_ms
		var samples: Dictionary = best["samples"]
		for key: int in samples:
			var arr: Array = samples[key]
			if arr.is_empty():
				continue
			var s := _sample_at(arr, ms)
			if s.is_empty():
				continue
			var idx: int = s["index"]
			if idx < 0 or idx >= Geometries.ALL.size():
				continue
			var def: GeometryDef = Geometries.ALL[idx]
			var pos: Vector2 = s["pos"]
			var col := Color(def.color, 0.30)
			draw_rect(Rect2(pos - def.size / 2.0, def.size), col)

	func _sample_at(arr: Array, ms: int) -> Dictionary:
		var last: Dictionary = arr[0]
		for s in arr:
			if int(s["t"]) > ms:
				if last.is_empty() or int(s["t"]) == ms:
					return s
				var t0: int = int(last["t"])
				var t1: int = int(s["t"])
				if t1 <= t0:
					return last
				var k := float(ms - t0) / float(t1 - t0)
				return {"t": ms, "pos": (last["pos"] as Vector2).lerp(s["pos"], k),
					"index": s["index"]}
			last = s
		return {}
