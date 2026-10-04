class_name PlayerCosmetics
extends RefCounted


## 冲刺拖尾 = Vector2 环形缓冲(6 格预分配复用):槽体存于 p._trail
## (player.gd 死亡/召回 _trail.clear() 归零,下次调用按容量不符重建),
## 首尾游标挂 Player meta——逐物理帧零字典、零数组分配。
const TRAIL_CAP := 6


## 动效门控单一出口:death/swap/air/skid 四类爆发粒子在本层内读
## SettingsManager.reduced_motion(player.gd 四个调用点零改动);
## land_dust 保留 player.gd 既有外部门控,此处内门控成双保险(语义不变)。
static func _motion_allowed() -> bool:
	return not SettingsManager.reduced_motion


static func swap_burst(p: Player) -> void:
	if not _motion_allowed():
		return
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
	if not _motion_allowed():
		return
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
	if not _motion_allowed():
		return
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
	if not _motion_allowed():
		return
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
	var trail: Array = p._trail
	var head: int = p.get_meta("_trail_head", 0)
	var n: int = p.get_meta("_trail_n", 0)
	if trail.size() != TRAIL_CAP:
		trail.resize(TRAIL_CAP)
		trail.fill(Vector2.ZERO)
		head = 0
		n = 0
	if absf(vel.x) > MovementTuning.I.run_speed * 1.2:
		trail[(head + n) % TRAIL_CAP] = p.position
		if n < TRAIL_CAP:
			n += 1
		else:
			head = (head + 1) % TRAIL_CAP
	elif n > 0:
		n -= 1
		head = (head + 1) % TRAIL_CAP
	p.set_meta("_trail_head", head)
	p.set_meta("_trail_n", n)


static func land_dust(p: Player, impact: float) -> void:
	if not _motion_allowed():
		return
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
	# 拖尾条目只存位置,尺寸现读 p.def.size(def 恒定)——免逐条字典哈希。
	# player.gd 死亡/召回会 _trail.clear():槽容量不符(尚未经物理帧重建)
	# 时计数视零,防渲染帧先于物理帧索引空数组。
	var trail: Array = p._trail
	var trail_n: int = p.get_meta("_trail_n", 0) \
		if trail.size() == TRAIL_CAP else 0
	var head: int = p.get_meta("_trail_head", 0)
	var ts: Vector2 = p.def.size * p.shrink
	for k in trail_n:
		var tpos: Vector2 = trail[(head + k) % TRAIL_CAP]
		var a := 0.16 * float(k + 1) / float(trail_n)
		p.draw_rect(Rect2(tpos - p.position - ts / 2.0, ts), Color(p.def.color, a * 0.7))

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
		Color(Palette.I.paper, 0.5))

	if p._climbing:
		var gx := p._climb_side * size.x * 0.5
		for gy: float in [-size.y * 0.24, size.y * 0.04, size.y * 0.32]:
			p.draw_line(Vector2(gx - p._climb_side * 9.0, gy), Vector2(gx, gy),
				Color(Palette.I.paper, 0.75), 2.5)


static func draw_name_tag(p: Player, size: Vector2) -> void:
	if Ui.HEAD == null:
		return
	var nm := p.display_name()
	var ts := Ui.HEAD.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var pos := Vector2(-ts.x / 2.0, (-size.y / 2.0 - 10.0) * p.gravity_dir)
	p.draw_string(Ui.HEAD, pos + Vector2(0, 1), nm,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.55))
	p.draw_string(Ui.HEAD, pos, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(Palette.I.paper, 0.92))
