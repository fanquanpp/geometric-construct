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


static func eff_weight(p: Player) -> float:
	return p.def.weight


static func accel_factor(p: Player) -> float:
	var t := MovementTuning.I
	return clampf(t.accel_base - t.accel_weight_k * eff_weight(p),
			t.accel_min, t.accel_base) \
		* (t.accel_ski_mult if p.skiing else 1.0)


static func friction_factor(p: Player) -> float:
	var t := MovementTuning.I
	return clampf(t.friction_base - t.friction_weight_k * eff_weight(p),
			t.friction_min, t.friction_base)


static func friction_mu(p: Player) -> float:
	var t := MovementTuning.I
	return t.standard_mu * friction_factor(p) \
		* (t.ski_friction_mult if p.skiing else 1.0)


static func horizontal_step(vel: Vector2, p: Player, move_input: Vector2,
		target_mult: float, on_ground: bool, dt: float) -> float:
	var t := MovementTuning.I
	var target_vx := move_input.x * target_mult * t.run_speed
	var accel := t.base_accel * accel_factor(p)
	# 空中动量分级:速度越接近极速,空中转向权越低(lerp 到下限),慢速仍灵。
	if not on_ground:
		accel *= lerpf(t.air_accel_ratio, t.air_accel_min_ratio,
			clampf(absf(vel.x) / maxf(absf(target_vx), 1.0), 0.0, 1.0))
	if move_input.x != 0.0:
		# 超速带:同号超速不施加 accel 回拉,只按渗漏率滑向目标极速——
		# 动量当状态而非上限(冲刺松键/加速门余速自然衰减,不建第二衰减窗)。
		if absf(vel.x) > absf(target_vx) and signf(vel.x) == signf(target_vx):
			var bleed := friction_mu(p) * t.gravity * t.air_friction_mult \
				* t.over_speed_bleed_mult
			return move_toward(vel.x, target_vx, bleed * dt)
		return move_toward(vel.x, target_vx, accel * dt)
	var friction := friction_mu(p) * t.gravity
	if not on_ground:
		friction *= t.air_friction_mult
	return move_toward(vel.x, 0.0, friction * dt)
