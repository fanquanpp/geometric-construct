class_name Player
extends CharacterBody2D


const AIR_JUMPS := 1

const MOD_SPEED_CAP := 3.75

const PUSH_TRANSFER := 1800.0


var def: GeometryDef
var index: int
var spawn_pos: Vector2
var in_exit := false
var arrived := false
var dying := false
var is_active := false
var rider_of: Player = null
var speed_buffed := false
var gravity_dir: int = 1


var world_mask := 1


var shrink := 1.0

var facing := 1.0
var skiing := false
var input_x := 0.0


var input_source: InputSource = null

var remote_driven := false
var _net_pos := Vector2.ZERO
var _net_vel := Vector2.ZERO

var debug_probe := false
var _coyote := 0.0
var _jump_buffer := 0.0
var _air_jumps_left := 0
var _swap_buffer := 0.0
var _swap_cd := 0.0
var _swap_air := false
var _was_on_floor := false
var _jump_cut := false
var _debug_jump_prev := false
var _climbing := false
var _climb_budget := 0.0
var _climb_side := 0
var _climb_tick := 0.0
var _skidding := false
var _ramp_timer := 0.0
var _squash_x := 1.0
var _squash_y := 1.0
var _trail: Array = []
var _piano_touch: Array = []
var _occluder: LightOccluder2D
var _body_box: StyleBoxFlat


func _ready() -> void:
	collision_layer = 2
	collision_mask = 2 | world_mask
	gravity_dir = def.gravity_dir
	up_direction = Vector2(0, -gravity_dir)
	z_index = 5
	_climb_budget = (1.0 if def.can_climb else 0.0) * MovementTuning.I.climb_units * Geometries.UNIT_PX

	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = def.size
	shape_node.shape = rect
	add_child(shape_node)
	_init_occluder()

	_body_box = StyleBoxFlat.new()
	_body_box.bg_color = def.color


func _init_occluder() -> void:
	_occluder = LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
	var hw := def.size.x * 0.5
	var hh := def.size.y * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	_occluder.occluder = poly
	add_child(_occluder)


func _process(_delta: float) -> void:
	queue_redraw()
	if _occluder != null:
		_occluder.scale = Vector2(_squash_x, _squash_y) * shrink
		_occluder.visible = visible and not dying and shrink > 0.09


func _physics_process(delta: float) -> void:
	var dt := delta
	if in_exit or dying or Main.I == null:
		return
	if remote_driven:
		_net_follow(dt)
		return

	var vel := velocity

	var move_input := Vector2.ZERO
	var sprinting := false
	var jump_pressed := false
	var jump_held := false
	var ramp_buffed := _ramp_timer > 0.0
	if is_active:
		move_input = PlayerInput.move_axis(_src())
		sprinting = PlayerInput.sprint(_src())
		jump_pressed = PlayerInput.jump_edge(_src())
		jump_held = PlayerInput.jump_held(_src())
		if Main.I.debug_move != Vector2.ZERO:
			move_input = Main.I.debug_move
		if Main.I.debug_jump and not _debug_jump_prev:
			jump_pressed = true
		if Main.I.debug_jump:
			jump_held = true
	_debug_jump_prev = Main.I != null and Main.I.debug_jump
	input_x = move_input.x
	if move_input.x != 0.0:
		facing = signf(move_input.x)

	vel = MovementCore.gravity_step(vel, def, gravity_dir, dt)

	var on_ground := is_on_floor()
	var target_mult := _target_multiplier(sprinting)
	vel.x = MovementCore.horizontal_step(vel, self, move_input, target_mult,
		on_ground, ramp_buffed, dt)

	if on_ground and move_input.x != 0.0 and absf(vel.x) > 200.0 \
			and signf(move_input.x) != signf(vel.x) and not _skidding:
		_skidding = true
		_squash(1.10, 0.92)
		PlayerCosmetics.skid_burst(self)
	elif move_input.x == 0.0 or absf(vel.x) < 40.0 or not on_ground:
		_skidding = false

	if jump_pressed:
		if def.can_jump:
			_jump_buffer = 0.12
		elif def.can_swap:
			_swap_buffer = 0.12
	_jump_buffer -= dt
	_swap_buffer -= dt
	_swap_cd -= dt
	_coyote -= dt
	if on_ground:
		_coyote = MovementTuning.I.coyote
		_jump_cut = false
		_climb_budget = (1.0 if def.can_climb else 0.0) * MovementTuning.I.climb_units * Geometries.UNIT_PX

	var wall_normal := MechanismSurface.world_wall_normal(self)
	var cling := def.can_climb and not on_ground and gravity_dir > 0 \
		and wall_normal.x != 0.0 and move_input.x * wall_normal.x < -0.25
	if cling:
		_climbing = true
		_climb_side = -1 if wall_normal.x > 0.0 else 1
		if jump_held and _climb_budget > 0.0:
			vel.y = -MovementTuning.I.climb_up * gravity_dir
			_climb_budget = maxf(_climb_budget - MovementTuning.I.climb_up * dt, 0.0)
			_climb_tick -= dt
			if _climb_tick <= 0.0:
				_climb_tick = 0.16
				Sfx.play("climb")
		else:
			vel.y = MovementTuning.I.climb_slide * gravity_dir
	else:
		_climbing = false

	var jump_power := def.jump_v * _overload_jump_ratio()
	if _jump_buffer > 0.0 and def.can_jump:
		if on_ground or _coyote > 0.0:

			vel.y = -jump_power * _top_boost_ratio() * gravity_dir
			_jump_buffer = 0.0
			_coyote = 0.0
			_jump_cut = false
			_squash(0.78, 1.24)
			Sfx.play("jump", 0.0, _note_pitch())
		elif _air_jumps_left > 0:

			_air_jumps_left -= 1
			vel.y = -jump_power * gravity_dir
			_jump_buffer = 0.0
			_jump_cut = false
			_squash(0.82, 1.18)
			Sfx.play("jump2", 0.0, _note_pitch() * 1.26)
			PlayerCosmetics.air_burst(self)
	elif _swap_buffer > 0.0 and def.can_swap \
			and (on_ground or _coyote > 0.0) and _swap_cd <= 0.0:
		vel = _perform_swap(vel)

		if Main.I != null:
			Main.I.hud_swap_flash()

	if not _jump_cut and def.can_jump and not jump_held \
			and vel.y * gravity_dir < -def.jump_v * MovementTuning.I.jump_cut_ratio:
		vel.y *= MovementTuning.I.jump_cut_mult
		_jump_cut = true

	vel.y = clampf(vel.y, -MovementTuning.I.max_fall, MovementTuning.I.max_fall)

	if rider_of != null and is_instance_valid(rider_of) \
			and gravity_dir > 0 and vel.y * gravity_dir >= 0.0:
		if move_input.x == 0.0:
			vel.x = 0.0
		if rider_of.is_on_floor() or rider_of.velocity.y * gravity_dir < 0.0:
			vel.y = rider_of.velocity.y

	var impact := absf(vel.y)
	var was_floor := _was_on_floor
	var prev_x := position.x
	velocity = vel
	if debug_probe:
		print("PHY pre f=", Engine.get_physics_frames(), " vel=", velocity.snapped(Vector2(1, 1)))
	move_and_slide()
	vel = velocity
	if debug_probe:
		print("PHY post f=", Engine.get_physics_frames(), " vel=", velocity.snapped(Vector2(1, 1)),
			" slides=", get_slide_collision_count(), " floor=", is_on_floor(),
			" deg=%.0f" % rad_to_deg(get_floor_angle() if is_on_floor() else 0.0))
	if not is_on_floor() and was_floor and vel.y * gravity_dir > 0:
		_coyote = MovementTuning.I.coyote

	var now_on_floor := is_on_floor()
	if was_floor and not now_on_floor:
		_air_jumps_left = AIR_JUMPS

	var landed := now_on_floor and not was_floor
	if landed:
		if now_on_floor:
			_air_jumps_left = 0

		if Main.I != null and Main.I.backdrop != null:
			Main.I.backdrop.pulse_land(impact)
		if impact > 620.0:
			SettingsManager.haptic(40)
			if Main.I != null and Main.I.camera_rig != null:
				Main.I.camera_rig.kick(minf(1.6 + impact / 420.0, 4.6))
			if not SettingsManager.reduced_motion:
				PlayerCosmetics.land_dust(self, impact)
		var eff_bounce := effective_bounce()
		var carrying := _has_riders()
		if carrying or impact <= MovementTuning.I.bounce_min or eff_bounce <= 0.0:

			if absf(vel.y) < 5.0:
				_squash(1.24, 0.78)
			elif impact > 120.0:
				Sfx.play("land", 0.0, _note_pitch())
		else:
			var restitution := clampf(eff_bounce * 0.5, 0.0, 1.0)
			if jump_held and def.can_jump:

				restitution = minf(restitution + 0.18, 1.12)
			else:
				restitution *= MovementTuning.I.bounce_settle
				if _swap_air:
					restitution *= MovementTuning.I.swap_settle
			vel.y = -impact * restitution * gravity_dir
			velocity = vel
			_squash(0.72, 1.3)
			Sfx.play("bounce", 0.0, _note_pitch())
		_swap_air = false

	_was_on_floor = now_on_floor

	var new_rider: Player = null
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider() as Player
		if collider != null and col.get_normal().dot(up_direction) > 0.7 \
				and gravity_dir > 0:
			new_rider = collider
			break
	rider_of = new_rider

	var carry_dx := position.x - prev_x
	if carry_dx != 0.0:
		for p in Main.I.players:
			if p != self and is_instance_valid(p) and p.rider_of == self \
					and not p.dying and p.gravity_dir > 0 and p.input_x == 0.0:
				p.position.x += carry_dx
				p.velocity.x = velocity.x

	if MechanismSurface.touching_ramp(self):
		if _ramp_timer <= 0.0 and Main.I != null:
			Sfx.play("buff")
			Main.I.notify_ramp(def)
		_ramp_timer = MovementTuning.I.ramp_buff_time
	elif _ramp_timer > 0.0:
		_ramp_timer = maxf(_ramp_timer - dt, 0.0)

	MechanismSurface.piano_step(self, vel)

	if now_on_floor and absf(vel.x) > 20.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var other := col.get_collider() as Player
			if other != null and other.def.can_be_pushed \
					and signf(col.get_normal().x) == signf(-vel.x):
				other.velocity.x = move_toward(other.velocity.x, vel.x,
					PUSH_TRANSFER * dt)

	PlayerCosmetics.update_trail(self, vel)
	PlayerCosmetics.squash_recover(self, dt)


func _perform_swap(vel: Vector2) -> Vector2:
	gravity_dir *= -1
	up_direction = Vector2(0, -gravity_dir)
	vel.y = MovementTuning.I.swap_launch * gravity_dir
	_swap_buffer = 0.0
	_swap_cd = MovementTuning.I.swap_cooldown
	_coyote = 0.0
	_jump_cut = false
	_swap_air = true
	_squash(1.3, 0.74)
	Sfx.play("swap", 0.0, _note_pitch())
	PlayerCosmetics.swap_burst(self)
	return vel


func _target_multiplier(sprinting: bool) -> float:
	var cap := def.base_speed
	if speed_buffed:
		cap = maxf(cap, def.buff_sprint_speed)
	if sprinting and def.can_sprint:
		cap = maxf(cap, def.buff_sprint_speed if speed_buffed else def.sprint_speed)
	if speed_buffed:
		cap = minf(cap, MOD_SPEED_CAP)
	if _ramp_timer > 0.0:
		cap = minf(cap * MovementTuning.I.ramp_boost, MOD_SPEED_CAP)
	return cap


func effective_bounce() -> float:
	return def.bounce


func _overload_jump_ratio() -> float:
	if Main.I == null:
		return 1.0
	var rider_load := 0.0
	for p in Main.I.players:
		if p != self and is_instance_valid(p) and p.rider_of == self:
			rider_load += p.def.weight
	if rider_load > def.carry + 0.01:
		return sqrt(MovementTuning.I.overload_jump_ratio)
	return 1.0


func _top_boost_ratio() -> float:
	if rider_of != null and is_instance_valid(rider_of) and rider_of.def.can_top_boost:
		return sqrt(MovementTuning.I.top_boost_height_ratio)
	return 1.0


func _note_pitch() -> float:
	return Sfx.note_ratio(def.note)


func quote_text() -> String:
	return def.quote


func display_name() -> String:
	return def.name


func _has_riders() -> bool:
	if Main.I == null:
		return false
	for p in Main.I.players:
		if p != self and p.rider_of == self:
			return true
	return false


func apply_speed_gate() -> void:
	var was := speed_buffed
	speed_buffed = true
	var cap := _target_multiplier(true) * MovementTuning.I.run_speed
	if absf(velocity.x) > 20.0:
		velocity.x = signf(velocity.x) * maxf(absf(velocity.x), cap)
	elif facing != 0.0:
		velocity.x = facing * cap
	if not was:
		Sfx.play("buff")
		if Main.I != null:
			Main.I.notify_buff(_target_multiplier(true), def)


func _src() -> InputSource:
	if input_source == null:
		input_source = InputSource.local(0)
	return input_source


func net_apply_state(pos: Vector2, vel: Vector2, gdir: int, face: float, flags: int) -> void:
	_net_pos = pos
	_net_vel = vel
	gravity_dir = gdir
	up_direction = Vector2(0, -gravity_dir)
	facing = face
	speed_buffed = speed_buffed or (flags & 1) != 0


func _net_follow(dt: float) -> void:
	position += velocity * dt
	var err := _net_pos - position
	position += err * (1.0 - exp(-14.0 * dt))
	velocity = _net_vel
	input_x = 0.0
	if absf(velocity.x) > 12.0:
		facing = signf(velocity.x)
	MechanismSurface.piano_cosmetic(self)
	PlayerCosmetics.squash_recover(self, dt)
	PlayerCosmetics.update_trail(self, velocity)


func _squash(sx: float, sy: float) -> void:
	_squash_x = sx
	_squash_y = sy


func die() -> void:
	if dying or in_exit or arrived:
		return
	dying = true
	Sfx.play("die", 0.0, _note_pitch())
	SettingsManager.haptic(60)
	PlayerCosmetics.death_burst(self)
	if Main.I != null and Main.I.camera_rig != null:
		Main.I.camera_rig.kick(7.0)
	if Main.I != null and Main.I.backdrop != null:
		Main.I.backdrop.pulse_death()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.20)
	tw.tween_callback(_reset_for_respawn)
	tw.tween_property(self, "modulate:a", 1.0, 0.26)
	tw.tween_callback(_finish_respawn)
	Main.I.on_player_died(self)


func _reset_for_respawn() -> void:
	position = spawn_pos
	rider_of = null
	velocity = Vector2.ZERO
	gravity_dir = def.gravity_dir
	up_direction = Vector2(0, -gravity_dir)
	speed_buffed = false
	_swap_air = false
	_air_jumps_left = 0
	_climbing = false
	_climb_budget = MovementTuning.I.climb_units * Geometries.UNIT_PX
	_ramp_timer = 0.0
	_squash_x = 1.0
	_squash_y = 1.0
	for t in _piano_touch:
		t.release(index)
	_piano_touch.clear()
	_trail.clear()


func _finish_respawn() -> void:
	dying = false
	Main.I.on_respawn_done()


func recall_to(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	gravity_dir = def.gravity_dir
	up_direction = Vector2(0, -gravity_dir)
	_swap_air = false
	_swap_buffer = 0.0
	_swap_cd = 0.0
	_jump_buffer = 0.0
	_jump_cut = false
	_air_jumps_left = 0
	_coyote = 0.0
	_ramp_timer = 0.0
	_climb_budget = MovementTuning.I.climb_units * Geometries.UNIT_PX
	_trail.clear()
	_squash(1.15, 0.88)


var arrived_door: ExitDoor


func arrive_at(door: ExitDoor) -> void:
	if arrived or in_exit or dying:
		return
	arrived = true
	arrived_door = door
	Sfx.play("arrive")
	SettingsManager.haptic(30)
	var tw := create_tween()
	tw.tween_property(self, "position:x", door.position.x, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Main.I.on_player_arrived(self)


func depart_exit() -> void:
	if in_exit or dying:
		return
	arrived = false
	arrived_door = null
	Main.I.on_player_departed(self)


func enter_exit(door: ExitDoor) -> void:
	if in_exit or dying:
		return
	in_exit = true
	is_active = false
	arrived = false
	velocity = Vector2.ZERO
	Sfx.play("enter")

	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 22
	burst.lifetime = 0.7
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2(0, 200 * gravity_dir)
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 170.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = def.color
	burst.finished.connect(burst.queue_free)
	door.add_child(burst)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", door.position + Vector2(0, 4 * gravity_dir), 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "shrink", 0.08, 0.42) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.15, 0.42)
	tw.chain().tween_callback(func() -> void: visible = false)
	Main.I.on_player_exited(self)


func _draw() -> void:
	if shrink <= 0.09:
		return
	var size := Vector2(def.size.x * _squash_x, def.size.y * _squash_y) * shrink
	PlayerCosmetics.draw(self, size)
