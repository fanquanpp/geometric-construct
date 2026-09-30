class_name PlayerCosmetics
extends RefCounted


static func swap_burst(p: Player) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 14
	burst.lifetime = 0.45
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 130.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 3.5
	burst.color = p.def.color
	burst.finished.connect(burst.queue_free)
	p.add_child(burst)


static func air_burst(p: Player) -> void:
	var ring := CPUParticles2D.new()
	ring.one_shot = true
	ring.emitting = true
	ring.amount = 8
	ring.lifetime = 0.3
	ring.explosiveness = 1.0
	ring.spread = 180.0
	ring.gravity = Vector2.ZERO
	ring.initial_velocity_min = 30.0
	ring.initial_velocity_max = 80.0
	ring.scale_amount_min = 1.5
	ring.scale_amount_max = 2.5
	ring.color = Color(p.def.color, 0.8)
	ring.finished.connect(ring.queue_free)
	p.add_child(ring)


static func skid_burst(p: Player) -> void:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = 7
	dust.lifetime = 0.26
	dust.explosiveness = 1.0
	dust.spread = 180.0
	dust.gravity = Vector2(0, 260 * p.gravity_dir)
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 90.0
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 2.2
	dust.color = Color(Palette.I.paper, 0.55)
	dust.finished.connect(dust.queue_free)
	p.add_child(dust)


static func death_burst(p: Player) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 18
	burst.lifetime = 0.55
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2(0, 900 * p.gravity_dir)
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 340.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 6.0
	burst.color = p.def.color
	burst.finished.connect(burst.queue_free)
	p.get_parent().add_child(burst)
	burst.global_position = p.global_position


static func update_trail(p: Player, vel: Vector2) -> void:
	if absf(vel.x) > MovementTuning.I.run_speed * 1.2:
		p._trail.append({"pos": p.position, "size": p.def.size})
		if p._trail.size() > 6:
			p._trail.pop_front()
	elif not p._trail.is_empty():
		p._trail.pop_front()


static func land_dust(p: Player, impact: float) -> void:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = 10
	dust.lifetime = 0.3
	dust.explosiveness = 1.0
	dust.spread = 150.0
	dust.direction = Vector2(0, -1 * p.gravity_dir)
	dust.gravity = Vector2(0, 340 * p.gravity_dir)
	dust.initial_velocity_min = 50.0 + impact * 0.04
	dust.initial_velocity_max = 110.0 + impact * 0.08
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.0
	dust.color = Color(Palette.I.paper, 0.5)
	dust.finished.connect(dust.queue_free)
	p.get_parent().add_child(dust)
	dust.global_position = p.global_position \
		+ Vector2(0, p.def.size.y * 0.5 * p.gravity_dir)


static func squash_recover(p: Player, dt: float) -> void:
	p._squash_x = move_toward(p._squash_x, 1.0, dt * 3.2)
	p._squash_y = move_toward(p._squash_y, 1.0, dt * 3.2)


static func draw(p: Player, size: Vector2) -> void:
	var trail_n: int = p._trail.size()
	for i in trail_n:
		var t: Dictionary = p._trail[i]
		var a := 0.16 * float(i + 1) / float(trail_n)
		var ts: Vector2 = t["size"] * p.shrink
		p.draw_rect(Rect2(t["pos"] - p.position - ts / 2.0, ts), Color(p.def.color, a * 0.7))

	draw_box(p, size)
	if p.is_active:
		draw_name_tag(p, size)


static func draw_box(p: Player, size: Vector2) -> void:
	var body := Rect2(-size / 2.0, size)
	var u := minf(size.x, size.y)

	if p.is_active:
		var glow := 0.10 + 0.10 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 380.0))
		p._body_box.bg_color = p.def.color.lerp(Color.WHITE, glow)
	else:
		p._body_box.bg_color = p.def.color
	p.draw_style_box(p._body_box, body)

	p.draw_rect(Rect2(body.position.x, body.end.y - body.size.y * 0.24,
		body.size.x, body.size.y * 0.24), Color(0, 0, 0, 0.18))
	p.draw_rect(Rect2(body.end.x - maxf(2.0, u * 0.045), body.position.y,
		maxf(2.0, u * 0.045), body.size.y), Color(0, 0, 0, 0.14))
	p.draw_rect(Rect2(body.position + Vector2(3, 3), Vector2(size.x * 0.42, 3)),
		Color(1.0, 1.0, 1.0, 0.5))

	if p._climbing:
		var gx := p._climb_side * size.x * 0.5
		for gy: float in [-size.y * 0.24, size.y * 0.04, size.y * 0.32]:
			p.draw_line(Vector2(gx - p._climb_side * 9.0, gy), Vector2(gx, gy),
				Color(1, 1, 1, 0.75), 2.5)


static func draw_name_tag(p: Player, size: Vector2) -> void:
	if Ui.HEAD == null:
		return
	var nm := p.display_name()
	var ts := Ui.HEAD.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var pos := Vector2(-ts.x / 2.0, (-size.y / 2.0 - 10.0) * p.gravity_dir)
	p.draw_string(Ui.HEAD, pos + Vector2(0, 1), nm,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.55))
	p.draw_string(Ui.HEAD, pos, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.92))
