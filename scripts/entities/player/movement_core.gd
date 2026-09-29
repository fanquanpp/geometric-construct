class_name MovementCore
extends RefCounted


const APEX_MULT := 0.86
const FALL_MULT := 1.24


static func gravity_step(vel: Vector2, def: GeometryDef, gravity_dir: int,
		dt: float) -> Vector2:
	var t := MovementTuning.I
	var v := vel
	var g_mult := 1.0
	if v.y * gravity_dir < 0.0:
		if absf(v.y) < t.apex_window:
			g_mult = APEX_MULT
		v.y += t.gravity * g_mult * gravity_dir * dt
	else:
		var v_n := clampf(absf(v.y) / t.max_fall, 0.0, 1.0)
		var a_fall := t.gravity \
			* FALL_MULT * (1.0 - v_n * v_n)
		v.y += a_fall * gravity_dir * dt
		if absf(v.y) > t.max_fall:
			v.y = t.max_fall * signf(v.y)
	return v


static func eff_weight(p: Player, ramp_buffed: bool) -> float:
	return p.def.weight \
		* (MovementTuning.I.ramp_weight_ratio if ramp_buffed else 1.0)


static func accel_factor(p: Player, ramp_buffed: bool) -> float:
	var t := MovementTuning.I
	return clampf(t.accel_base - t.accel_weight_k * eff_weight(p, ramp_buffed),
			t.accel_min, t.accel_base) \
		* (t.accel_ski_mult if p.skiing else 1.0)


static func friction_factor(p: Player, ramp_buffed: bool) -> float:
	var t := MovementTuning.I
	return clampf(t.friction_base - t.friction_weight_k * eff_weight(p, ramp_buffed),
			t.friction_min, t.friction_base)


static func friction_mu(p: Player, ramp_buffed: bool) -> float:
	var t := MovementTuning.I
	return t.standard_mu * friction_factor(p, ramp_buffed) \
		* (t.ski_friction_mult if p.skiing else 1.0)


static func horizontal_step(vel: Vector2, p: Player, move_input: Vector2,
		target_mult: float, on_ground: bool, ramp_buffed: bool, dt: float) -> float:
	var t := MovementTuning.I
	var target_vx := move_input.x * target_mult * t.run_speed
	var accel := t.base_accel * accel_factor(p, ramp_buffed)
	if not on_ground:
		accel *= t.air_accel_ratio
	if move_input.x != 0.0:
		return move_toward(vel.x, target_vx, accel * dt)
	var friction := friction_mu(p, ramp_buffed) * t.gravity
	if not on_ground:
		friction *= t.air_friction_mult
	return move_toward(vel.x, 0.0, friction * dt)
