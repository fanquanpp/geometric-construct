class_name TransitionFX
extends CanvasLayer


signal covered

enum Style { FADE, SWEEP, BLOCKS_RED, CORNERS, CURTAIN }

const SWEEP_SHADER := preload("res://assets/fx/sweep_diagonal.gdshader")
const BLOCKS_SHADER := preload("res://assets/fx/block_dissolve.gdshader")

var _veil: ColorRect
var _mat: ShaderMaterial
var _corners: Array[ColorRect] = []
var _curtain: CurtainDraw
var _busy := false
var _seq := 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_veil.material = _mat
	add_child(_veil)
	for i in 4:
		var q := ColorRect.new()
		q.color = Color("101216")
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.visible = false
		add_child(q)

		var edge := ColorRect.new()
		edge.color = Color(Palette.I.red, 0.85)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.add_child(edge)
		_corners.append(q)
	_curtain = CurtainDraw.new()
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.visible = false
	add_child(_curtain)
	visible = false


func is_busy() -> bool:
	return _busy


func transition(style: int, dur: float, on_covered: Callable) -> bool:
	if _busy:
		return false
	_busy = true
	_seq += 1
	var my := _seq
	if SettingsManager.reduced_motion:

		_set_covered_look(style)
		visible = true
		on_covered.call()
		covered.emit()
		visible = false
		_busy = false
		return true
	match style:
		Style.SWEEP:
			_run_shader(SWEEP_SHADER, dur, my, on_covered)
		Style.BLOCKS_RED:
			_run_shader(BLOCKS_SHADER, dur, my, on_covered)
		Style.CORNERS:
			_run_corners(dur, my, on_covered)
		Style.CURTAIN:
			_run_curtain(dur, my, on_covered)
		_:
			_run_fade(dur, my, on_covered)
	return true


func reveal(style: int, dur: float) -> void:
	if _busy:
		return
	_busy = true
	_seq += 1
	var my := _seq
	if SettingsManager.reduced_motion:
		visible = false
		_busy = false
		return
	match style:
		Style.CORNERS:
			_corners_cover_instant()
			visible = true
			_open_corners(dur, my)
		_:
			_veil.color = Color(0, 0, 0, 1)
			_veil.material = null
			visible = true
			var tw := create_tween()
			tw.tween_property(_veil, "color:a", 0.0, dur)
			tw.tween_callback(func() -> void: _finish(my))


func _finish(my: int) -> void:
	if my != _seq:
		return
	visible = false
	_veil.color = Color(0, 0, 0, 0)
	_busy = false


func _set_covered_look(style: int) -> void:
	visible = true
	match style:
		Style.CORNERS:
			_corners_cover_instant()
		Style.CURTAIN:
			_curtain.phase = 1.0
			_curtain.visible = true
		_:
			_veil.color = Color(0, 0, 0, 1)


func _run_shader(shader: Shader, dur: float, my: int,
		on_covered: Callable) -> void:
	_mat.shader = shader
	_mat.set_shader_parameter("progress", 0.0)
	_veil.color = Color.WHITE
	visible = true
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_mat.set_shader_parameter("progress", v), 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		if my == _seq:
			on_covered.call()
			covered.emit())
	tw.tween_method(func(v: float) -> void:
		_mat.set_shader_parameter("progress", v), 1.0, 2.0, dur * 1.1)
	tw.tween_callback(func() -> void: _finish(my))


func _run_fade(dur: float, my: int, on_covered: Callable) -> void:
	_veil.material = null
	_veil.color = Color(0, 0, 0, 0)
	visible = true
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 1.0, dur)
	tw.tween_callback(func() -> void:
		if my == _seq:
			on_covered.call()
			covered.emit())
	tw.tween_property(_veil, "color:a", 0.0, dur * 1.1)
	tw.tween_callback(func() -> void: _finish(my))


func _corners_slide(phase: float) -> void:

	var vs := _veil.get_viewport_rect().size
	var hw := vs.x / 2.0
	var hh := vs.y / 2.0
	var starts := [Vector2(-hw, -hh), Vector2(vs.x, -hh),
		Vector2(-hw, vs.y), Vector2(vs.x, vs.y)]
	for i in 4:
		var q := _corners[i]
		q.visible = true
		var target := Vector2(hw * float(i % 2), hh * floorf(i / 2.0))
		q.position = starts[i].lerp(target, phase)
		q.size = Vector2(hw, hh)

		var edge: ColorRect = q.get_child(0)
		edge.position = Vector2(q.size.x - 2.0, 0.0) if i % 2 == 0 			else Vector2.ZERO
		edge.size = Vector2(2.0, q.size.y)


func _corners_cover_instant() -> void:
	_corners_slide(1.0)
	visible = true


func _run_corners(dur: float, my: int, on_covered: Callable) -> void:
	_veil.material = null
	_veil.color = Color(0, 0, 0, 0)
	var tw := create_tween()
	tw.tween_method(_corners_slide, 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		if my == _seq:
			on_covered.call()
			covered.emit())
	tw.tween_method(_corners_slide, 1.0, 0.0, dur * 1.15)
	tw.tween_callback(func() -> void:
		for q in _corners:
			q.visible = false
		_finish(my))


func _run_curtain(dur: float, my: int, on_covered: Callable) -> void:
	_veil.material = null
	_veil.color = Color(0, 0, 0, 0)
	visible = true
	_curtain.visible = true
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _curtain.phase = v, 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		if my == _seq:
			on_covered.call()
			covered.emit())
	tw.tween_method(func(v: float) -> void: _curtain.phase = v, 1.0, 2.0,
		dur * 1.15)
	tw.tween_callback(func() -> void:
		_curtain.visible = false
		_finish(my))


func _open_corners(dur: float, my: int) -> void:
	var tw := create_tween()
	tw.tween_method(_corners_slide, 1.0, 0.0, dur)
	tw.tween_callback(func() -> void:
		for q in _corners:
			q.visible = false
		_finish(my))


class CurtainDraw extends Control:
	var phase := 0.0:
		set(v):
			phase = v
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var z := 44.0
		var bands := 6
		var bw := w / bands
		for i in bands:
			var bottom: float = phase * (h + 2.0 * z) - z 				+ (z if i % 2 == 1 else 0.0)
			var top: float = bottom - (h + 2.0 * z)
			var pts := PackedVector2Array([
				Vector2(i * bw, top), Vector2((i + 1) * bw, top)])
			var teeth := 4
			var tw: float = bw / teeth

			for k in range(teeth, -1, -1):
				var x: float = i * bw + k * tw
				var y: float = bottom - (z if k % 2 == 1 else 0.0)
				pts.append(Vector2(x, y))
			draw_colored_polygon(pts, Color("101216"))

			var line := PackedVector2Array()
			for k in pts.size() - 2:
				line.append(pts[pts.size() - 1 - k])
			draw_polyline(line, Color(Palette.I.red, 0.55), 2.0)
