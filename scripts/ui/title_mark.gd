class_name TitleMark
extends Control


var _chars: Array[Label] = []
var _base_x: Array[float] = []
var _mark: ColorRect
var _sweep: ColorRect
var _t := 0.0
var _entered := false
var _glitch_idx := -1
var _glitch_left := 0.0
var _glitch_next := 4.0
var _rng := RandomNumberGenerator.new()


func setup(text: String, font_size: int, color: Color, mark_color: Color) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = Ui.weight(900, 2)
	_rng.randomize()

	_mark = ColorRect.new()
	_mark.color = mark_color
	_mark.size = Vector2(font_size * 0.24, font_size * 0.24)
	_mark.position = Vector2(0, font_size * 0.52)
	_mark.pivot_offset = _mark.size / 2.0
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mark)

	var pad := font_size * 0.42
	var x := pad
	for ch in text:
		var lb := Label.new()
		lb.text = ch
		lb.label_settings = Ui.ls(font_size, font, color)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.position = Vector2(x, 0)
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		lb.pivot_offset = Vector2(w / 2.0, font_size * 0.62)
		add_child(lb)
		_chars.append(lb)
		_base_x.append(x)
		x += w
	custom_minimum_size = Vector2(x + font_size * 0.1, font_size * 1.3)

	_sweep = ColorRect.new()
	_sweep.color = Color(mark_color, 0.85)
	_sweep.size = Vector2(0, 3)
	_sweep.position = Vector2(0, font_size * 1.08)
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sweep)


func play_entrance() -> void:
	_entered = false
	for lb in _chars:
		lb.modulate.a = 0.0
		lb.position.y = -44.0
		lb.rotation_degrees = -9.0
	_mark.scale = Vector2.ZERO
	_mark.modulate.a = 0.0
	_sweep.size.x = 0.0
	_sweep.modulate.a = 0.0
	Sfx.play("ui_open")

	var tw := create_tween()
	tw.set_parallel(true)

	tw.tween_property(_mark, "modulate:a", 1.0, 0.12)
	tw.tween_property(_mark, "scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for i in _chars.size():
		var delay := 0.16 + i * 0.10
		var lb := _chars[i]
		var ctw := create_tween()
		ctw.set_parallel(true)
		ctw.tween_property(lb, "modulate:a", 1.0, 0.05).set_delay(delay)
		ctw.tween_property(lb, "position:y", 0.0, 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		ctw.tween_property(lb, "rotation_degrees", 0.0, 0.30) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)
		ctw.chain().tween_callback(func() -> void: Sfx.play("ui_page"))

	var last_delay := 0.16 + (_chars.size() - 1) * 0.10 + 0.36
	var stw := create_tween()
	stw.tween_interval(last_delay)
	stw.tween_callback(func() -> void: Sfx.play("ui_click"))
	stw.tween_property(_sweep, "modulate:a", 1.0, 0.05)
	stw.parallel().tween_property(_sweep, "size:x", custom_minimum_size.x, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	stw.tween_property(_sweep, "modulate:a", 0.0, 0.22)
	stw.tween_callback(func() -> void: _entered = true)


func _process(delta: float) -> void:
	_t += delta
	if not _entered:
		return

	for i in _chars.size():
		var c := 0.90 + 0.14 * (0.5 + 0.5 * sin(_t * 2.0 + i * 1.05))
		_chars[i].modulate = Color(c, c, c, 1.0)

	var beat := fmod(_t, 2.2) / 2.2
	var pulse := pow(maxf(0.0, 1.0 - beat * 4.0), 2.0)
	_mark.scale = Vector2.ONE * (1.0 + pulse * 0.10)

	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0 and _glitch_idx >= 0:
			_chars[_glitch_idx].position.x = _base_x[_glitch_idx]
			_glitch_idx = -1
	else:
		_glitch_next -= delta
		if _glitch_next <= 0.0:
			_glitch_next = _rng.randf_range(3.2, 5.6)
			_glitch_idx = _rng.randi_range(0, _chars.size() - 1)
			_glitch_left = 0.06
			var dx := 2.5 if _rng.randf() < 0.5 else -2.5
			_chars[_glitch_idx].position.x = _base_x[_glitch_idx] + dx
