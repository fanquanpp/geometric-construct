class_name MovementCore
extends RefCounted
## 运动核心(REFACTOR Phase 4,player.gd 拆分之一):三段重力曲线与
## 水平加速 / 摩擦的步进公式,无副作用——输入当前速度与姿态参数,
## 返回新值。手感数值权威在 MovementTuning(data/tuning/movement_default.tres
## ,场景资源强制约束 R2 / REFACTOR §八 M-1);本文件只剩公式,零数值。
## 每局修正(肉鸽词条)走 RunState 修饰链,与调参资源正交。


## —— 三段重力:上升恒定(顶点窗口内减轻,制造"微悬停"的目标感),
## 下落为牛顿阻力模型 ma = mg − kv²(二次空气阻力),速度逼近终端
## 速度时阻力抵消重力,加速度平滑归零 —— 长落体速度曲线连续无拐点 ——
static func gravity_step(vel: Vector2, def: GeometryDef, gravity_dir: int,
		dt: float) -> Vector2:
	var t := MovementTuning.I
	var v := vel
	var g_mult := 1.0
	if v.y * gravity_dir < 0.0:
		if absf(v.y) < t.apex_window:
			g_mult = RunState.modified(def, "gravity_apex_mult")
		v.y += t.gravity * g_mult * gravity_dir * dt
	else:
		var v_n := clampf(absf(v.y) / t.max_fall, 0.0, 1.0)   # 归一化落速 v/v∞
		var a_fall := t.gravity \
			* RunState.modified(def, "gravity_fall_mult") * (1.0 - v_n * v_n)
		v.y += a_fall * gravity_dir * dt
		if absf(v.y) > t.max_fall:
			v.y = t.max_fall * signf(v.y)   # 极端帧安全阀(渐近线之内)
	return v


## 等效重量(曲面 buff 减半在调用方以 ramp_buffed 表达)。
static func eff_weight(p: Player, ramp_buffed: bool) -> float:
	return RunState.modified(p.def, "weight") \
		* (MovementTuning.I.ramp_weight_ratio if ramp_buffed else 1.0)


## 加速因子:越重起步越慢;滑雪带骤降;圆球不低于 1.0(滚动灵活)。
static func accel_factor(p: Player, ramp_buffed: bool) -> float:
	var t := MovementTuning.I
	var a := clampf(t.accel_base - t.accel_weight_k * eff_weight(p, ramp_buffed),
			t.accel_min, t.accel_base) \
		* (t.accel_ski_mult if p.skiing else 1.0)
	if p.def.shape == GeometryDef.Shape.BALL:
		a = maxf(a, t.ball_accel_floor)
	return a


## 摩擦因子(与加速因子分离:越重越难停下也是设计特性)。
static func friction_factor(p: Player, ramp_buffed: bool) -> float:
	var t := MovementTuning.I
	return clampf(t.friction_base - t.friction_weight_k * eff_weight(p, ramp_buffed),
			t.friction_min, t.friction_base)


## 本帧使用的摩擦系数 μ:圆球用滚动阻力(远小于滑动),其余按材质。
static func friction_mu(p: Player, ramp_buffed: bool) -> float:
	var t := MovementTuning.I
	if p.def.shape == GeometryDef.Shape.BALL:
		return t.ball_mu_roll * friction_factor(p, ramp_buffed)
	return t.standard_mu * friction_factor(p, ramp_buffed) \
		* RunState.modified(p.def, "friction") \
		* (t.ski_friction_mult if p.skiing else 1.0)


## —— 水平步进:有输入 = 加速度逼近目标速度(空中衰减),无输入 =
## 摩擦减速 a = μ·g(与质量无关的质量定律,μ 承载材质差异),
## 空中只有微弱空气阻力,惯性滑行。返回新 vel.x ——
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
