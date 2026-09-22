class_name Adaptive


const DESIGN := Vector2(1280, 720)


static func is_touch_mode() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	var m = Main.I
	return m != null and m.touch_controls != null and m.touch_controls.is_forced()


static func visible_size(vp: Viewport) -> Vector2:
	return vp.get_visible_rect().size


static func safe_insets(vp: Viewport) -> Vector4:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 1.0 or win.y < 1.0:
		return Vector4.ZERO
	var sa := DisplayServer.get_display_safe_area()
	var s := visible_size(vp).x / win.x
	return Vector4(
		maxf(sa.position.x, 0.0) * s,
		maxf(sa.position.y, 0.0) * s,
		maxf(win.x - sa.end.x, 0.0) * s,
		maxf(win.y - sa.end.y, 0.0) * s)


static func apply_safe_area(c: Control) -> void:
	var ins := safe_insets(c.get_viewport())
	c.offset_left = ins.x
	c.offset_top = ins.y
	c.offset_right = -ins.z
	c.offset_bottom = -ins.w


static func fit_design(c: Control) -> void:
	var vis := visible_size(c.get_viewport())
	var s := minf(vis.x / DESIGN.x, vis.y / DESIGN.y)
	c.size = DESIGN
	c.pivot_offset = DESIGN * 0.5
	c.scale = Vector2(s, s)
	c.position = (vis - DESIGN) * 0.5


static func register_card(card: Control, margin := Vector2(56, 40)) -> void:
	var update := func() -> void:
		var vp := card.get_viewport()
		if vp == null or card.size.x <= 1.0:
			return
		var vis := visible_size(vp)
		var s: float = minf(1.0, minf(
			(vis.x - margin.x) / card.size.x,
			(vis.y - margin.y) / card.size.y))
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(s, s)
	card.resized.connect(update)
	if card.get_parent() != null:
		card.get_parent().resized.connect(update)
	card.get_viewport().size_changed.connect(update)

	for i in 3:
		update.call_deferred()
	var guard := Timer.new()
	guard.wait_time = 0.05
	guard.timeout.connect(update)
	card.get_viewport().call_deferred("add_child", guard)
	guard.call_deferred("start")
