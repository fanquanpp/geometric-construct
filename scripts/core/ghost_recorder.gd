class_name GhostRecorder
extends Node


const SAMPLE_MS := 100

var main: Main
var _samples := {}
var _best_by_level := {}
var _marks := {}
var _draw: GhostDraw
var _last_ms := -1000


func on_level_started(level_index: int) -> void:
	_samples = {}
	_last_ms = -SAMPLE_MS
	if not _marks.has(level_index):
		_marks[level_index] = []
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
		var key: int = p.body_key()
		if not _samples.has(key):
			_samples[key] = []
		(_samples[key] as Array).append({
			"t": ms, "pos": p.position, "index": p.index,
			"pair_half": p.pair_half})


func on_complete() -> void:
	if NetSession.I != null and NetSession.I.is_net():
		return
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
			if def.shape == GeometryDef.Shape.BALL:
				draw_circle(pos, def.size.x * 0.5, col)
			elif def.shape == GeometryDef.Shape.TRIANGLE:
				var w := def.size.x * 0.5
				var h := def.size.y * 0.5
				var half: int = s["pair_half"]
				var flat_top := half != 1
				var pts := [
					[pos + Vector2(-w, h), pos + Vector2(w, h), pos + Vector2(0, -h)],
					[pos + Vector2(-w, -h), pos + Vector2(w, -h), pos + Vector2(0, h)]]
				draw_colored_polygon(
					PackedVector2Array(pts[0] if flat_top else pts[1]), col)
			else:
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
					"index": s["index"], "pair_half": s["pair_half"]}
			last = s
		return {}
