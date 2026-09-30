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
	if NetSession.I != null and NetSession.I.is_net():
		return
	if main._level_root == null:
		return
	_draw = GhostDraw.new()
	_draw.recorder = self
	_draw.level_index = level_index
	main._level_root.add_child(_draw)


func on_death(p: Player) -> void:
	if NetSession.I != null and NetSession.I.is_net():
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
	if NetSession.I != null and NetSession.I.is_net():
		return
	var gf: GameFlow = main.game_flow
	if gf == null or main.dual_mode and main.race != null \
			and main.race.input_locked():
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
	if NetSession.I != null and NetSession.I.is_net():
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

	func _process(_delta: float) -> void:
		if recorder.main._state == Main.State.PLAYING:
			queue_redraw()

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
