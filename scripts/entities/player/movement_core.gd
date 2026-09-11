class_name MovementCore
extends RefCounted
## 运动核心(REFACTOR Phase 4,player.gd 拆分之一):三段重力曲线与
## 水平加速 / 摩擦的步进公式,无副作用——输入当前速度与姿态参数,
## 返回新值。手感常量的权威在此(与 docs/DESIGN.md 手感表同源);
## Player 侧以 const 别名引用,调用点不变。

const MAX_FALL := 1150.0      # 终端速度 v∞:二次空气阻力下落的渐近上限
const BASE_ACCEL := 2400.0    # 标准 1.0 重量几何体的地面加速度
const AIR_ACCEL_RATIO := 0.62
const APEX_WINDOW := 110.0    # 顶点判定窗口(|vy| 低于此值)
## 地面摩擦系数 μ(库伦摩擦:减速度 a = μ·g)。物理权威在 GeometryDef
## (标准几何体 μ ≈ 1.27;越重越难起动也越难停下是设计特性)。
const MU_FRICTION := GeometryDef.MU_FRICTION
const BALL_MU_ROLL := GeometryDef.BALL_MU_ROLL    # 圆球滚动阻力系数(μ 滚动版)


## —— 三段重力:上升恒定(顶点窗口内减轻,制造"微悬停"的目标感),
## 下落为牛顿阻力模型 ma = mg − kv²(二次空气阻力),速度逼近终端
## 速度时阻力抵消重力,加速度平滑归零 —— 长落体速度曲线连续无拐点 ——
static func gravity_step(vel: Vector2, def: GeometryDef, gravity_dir: int,
		dt: float) -> Vector2:
	var v := vel
	var g_mult := 1.0
	if v.y * gravity_dir < 0.0:
		if absf(v.y) < APEX_WINDOW:
			g_mult = RunState.modified(def, "gravity_apex_mult")
		v.y += Geometries.GRAVITY * g_mult * gravity_dir * dt
	else:
		var v_n := clampf(absf(v.y) / MAX_FALL, 0.0, 1.0)   # 归一化落速 v/v∞
		var a_fall := Geometries.GRAVITY \
			* RunState.modified(def, "gravity_fall_mult") * (1.0 - v_n * v_n)
		v.y += a_fall * gravity_dir * dt
		if absf(v.y) > MAX_FALL:
			v.y = MAX_FALL * signf(v.y)   # 极端帧安全阀(渐近线之内)
	return v


## 等效重量(曲面 buff 减半在调用方以 ramp_buffed 表达)。
static func eff_weight(p: Player, ramp_buffed: bool) -> float:
	return RunState.modified(p.def, "weight") \
		* (Player.RAMP_WEIGHT_RATIO if ramp_buffed else 1.0)


## 加速因子:越重起步越慢;滑雪带骤降;圆球不低于 1.0(滚动灵活)。
static func accel_factor(p: Player, ramp_buffed: bool) -> float:
	var a := clampf(1.15 - 0.3 * eff_weight(p, ramp_buffed), 0.55, 1.15) \
		* (0.4 if p.skiing else 1.0)
	if p.def.shape == GeometryDef.Shape.BALL:
		a = maxf(a, 1.0)
	return a


## 摩擦因子(与加速因子分离:越重越难停下也是设计特性)。
static func friction_factor(p: Player, ramp_buffed: bool) -> float:
	return clampf(1.1 - 0.35 * eff_weight(p, ramp_buffed), 0.4, 1.1)


## 本帧使用的摩擦系数 μ:圆球用滚动阻力(远小于滑动),其余按材质。
static func friction_mu(p: Player, ramp_buffed: bool) -> float:
	if p.def.shape == GeometryDef.Shape.BALL:
		return BALL_MU_ROLL * friction_factor(p, ramp_buffed)
	return MU_FRICTION * friction_factor(p, ramp_buffed) \
		* RunState.modified(p.def, "friction") * (0.12 if p.skiing else 1.0)


## —— 水平步进:有输入 = 加速度逼近目标速度(空中衰减),无输入 =
## 摩擦减速 a = μ·g(与质量无关的质量定律,μ 承载材质差异),
## 空中只有微弱空气阻力(0.28 倍),惯性滑行。返回新 vel.x ——
static func horizontal_step(vel: Vector2, p: Player, move_input: Vector2,
		target_mult: float, on_ground: bool, ramp_buffed: bool, dt: float) -> float:
	var target_vx := move_input.x * target_mult * Geometries.RUN_SPEED
	var accel := BASE_ACCEL * accel_factor(p, ramp_buffed)
	if not on_ground:
		accel *= AIR_ACCEL_RATIO
	if move_input.x != 0.0:
		return move_toward(vel.x, target_vx, accel * dt)
	var friction := friction_mu(p, ramp_buffed) * Geometries.GRAVITY
	if not on_ground:
		friction *= 0.28
	return move_toward(vel.x, 0.0, friction * dt)
