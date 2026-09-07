class_name Player
extends CharacterBody2D
## 方块几何体控制器:加速度与惯性移动 / 二段跳 / 冲刺 / 弹性反弹 / 置换 /
## 圆球滚动 / 死亡重生,以及"站上同伴头顶、被同伴携带"的承载逻辑。
##
## 手感设计(docs/DESIGN.md):
##   - 加速度与摩擦力按重量缩放:越重起步越慢、滑行越远(惯性)。
##   - 冲刺(Shift)把目标速度抬到冲刺上限,速度靠加速度自然攀升。
##   - 二段跳:每个几何体最多主动跳 2 次(地面 1 次 + 空中 1 次),落地重置。
##   - 背负超载:头顶来者总重大于自身负重力时,跳跃高度减半(仍可跳)。
##   - 弹性 = 落地反弹系数(全员固定 0.5,跃 2.0);跳高 = jump_units
##     (二段跳角色统一 2.0 格/跳,与弹性解耦);松开跳跃的落地会自然收敛。
##   - 置换(逆):跳跃键改为在上下平台间翻转,空中惯性保留。

const BOUNCE_MIN := 240.0     # 低于该落地速度不反弹,直接站稳
const BOUNCE_SETTLE := 0.8    # 未按住跳跃的落地反弹衰减(自然收敛)
const SWAP_SETTLE := 0.55     # 置换落地缓冲(避免上下平台间乒乓)
const MAX_FALL := 1150.0
const BASE_ACCEL := 2400.0    # 标准 1.0 重量几何体的地面加速度
const AIR_ACCEL_RATIO := 0.62
const BASE_FRICTION := 1900.0 # 标准几何体的地面摩擦(无输入时的减速度)
const BALL_FRICTION_RATIO := 0.34  # 圆球滚动:摩擦极低,强调惯性
const SWAP_LAUNCH := 300.0    # 置换瞬间射向新落点平台的初速度
const CLIMB_UP := 150.0       # 爬墙:按住跳跃键的上升速度
const CLIMB_SLIDE := 55.0     # 爬墙:只按方向贴墙时的缓降速度
const RAMP_BUFF_TIME := 1.5   # 曲面 buff:离开曲面后残留时长(秒)
const RAMP_BOOST := 1.5       # 曲面 buff:速度上限倍率
const RAMP_WEIGHT_RATIO := 0.5  # 曲面 buff:等效重量倍率(减半)

var def: GeometryDef
var index: int
var spawn_pos: Vector2
var in_exit := false
var arrived := false          # 已到终点门待命:仍受控制,离开门区则取消
var dying := false
var is_active := false
var rider_of: Player = null
var speed_buffed := false     # 加速门强化(永久,直至死亡重生)
var gravity_dir: int = 1      # 当前重力方向(置换会翻转;1 = 向下,-1 = 向上)

## 进门时的缩小系数,由 Tween 驱动。
var shrink := 1.0

var facing := 1.0
## 逐帧物理探针(自动化验证用)。
var debug_probe := false
var _coyote := 0.0
var _jump_buffer := 0.0
var _air_jumps_left := 0      # 空中剩余跳跃次数(二段跳的第 2 跳)
var _swap_buffer := 0.0
var _swap_cd := 0.0
var _swap_air := false        # 本次滞空来自置换(落地时加缓冲)
var _was_on_floor := false
var _jump_cut := false
var _debug_jump_prev := false
var _climbing := false        # 正在贴墙(滑壁或攀爬)
var _climb_budget := 0.0      # 本次离地期间的剩余可爬高度(px),落地重置
var _climb_side := 0          # 墙在身体哪一侧:-1 左 / +1 右(绘制握点用)
var _climb_tick := 0.0        # 爬升音效节拍
var _ramp_timer := 0.0        # 曲面 buff 剩余时长;站在曲面上时持续刷新
var _squash_x := 1.0
var _squash_y := 1.0
var _roll_angle := 0.0
var _trail: Array = []        # 高速残影的位置记录 [{pos, size}]
var _shadow_dist: float = INF
var _body_box: StyleBoxFlat


func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	gravity_dir = def.gravity_dir
	up_direction = Vector2(0, -gravity_dir)
	z_index = 5
	_climb_budget = GeometryDef.CLIMB_UNITS * Geometries.UNIT_PX
	# 曲面跳跃板:圆球需要贴住更陡的坡面并在末端切线飞出
	if def.shape == GeometryDef.Shape.BALL:
		floor_max_angle = deg_to_rad(60.0)

	var shape_node := CollisionShape2D.new()
	if def.shape == GeometryDef.Shape.BALL:
		var circle := CircleShape2D.new()
		circle.radius = def.size.x / 2.0
		shape_node.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = def.size
		shape_node.shape = rect
	add_child(shape_node)

	_body_box = StyleBoxFlat.new()
	_body_box.bg_color = def.color


## 挤压 / 缩小 / 残影都需要逐帧重绘。
func _process(_delta: float) -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	var dt := delta
	if in_exit or dying or Main.I == null:
		return

	_update_ground_shadow()
	var vel := velocity

	var move_input := Vector2.ZERO
	var sprinting := false
	var jump_pressed := false
	var jump_held := false
	var ramp_buffed := _ramp_timer > 0.0   # 本帧开始时是否带曲面 buff(加速/减重)
	if is_active:
		move_input = _read_move()
		sprinting = _read_sprint()
		jump_pressed = _read_jump_edge()
		jump_held = _read_jump_held()
		if Main.I.debug_move != Vector2.ZERO:
			move_input = Main.I.debug_move
		if Main.I.debug_jump and not _debug_jump_prev:
			jump_pressed = true
		if Main.I.debug_jump:
			jump_held = true
	_debug_jump_prev = Main.I != null and Main.I.debug_jump
	if move_input.x != 0.0:
		facing = signf(move_input.x)

	# ———— 重力 ————
	vel.y += Geometries.GRAVITY * gravity_dir * dt

	# ———— 水平移动:加速度 + 惯性 ————
	var on_ground := is_on_floor()
	var target_mult := _target_multiplier(sprinting)
	var target_vx := move_input.x * target_mult * Geometries.RUN_SPEED
	var eff_weight := def.weight * (RAMP_WEIGHT_RATIO if ramp_buffed else 1.0)
	var accel_factor := clampf(1.15 - 0.3 * eff_weight, 0.55, 1.15)
	var friction_factor := clampf(1.1 - 0.35 * eff_weight, 0.4, 1.1)
	if def.shape == GeometryDef.Shape.BALL:
		accel_factor = maxf(accel_factor, 1.0)
		friction_factor = BALL_FRICTION_RATIO
	if move_input.x != 0.0:
		var accel := BASE_ACCEL * accel_factor
		if not on_ground:
			accel *= AIR_ACCEL_RATIO
		vel.x = move_toward(vel.x, target_vx, accel * dt)
	else:
		# 松开输入:靠摩擦消耗速度,惯性滑行
		var friction := BASE_FRICTION * friction_factor
		if not on_ground:
			friction *= 0.28
		vel.x = move_toward(vel.x, 0.0, friction * dt)

	# ———— 圆球坡面切线:贴坡时把速度对齐坡面切线(保持水平分量 = 目标速度),
	# 滑到坡端自然沿切线飞出 —— 过山车的核心(速度越大,飞跃越远) ————
	if def.shape == GeometryDef.Shape.BALL and on_ground \
			and get_floor_angle() > deg_to_rad(4.0):
		var n := get_floor_normal()
		var t := Vector2(-n.y, n.x)          # 坡面切线(朝 +x)
		var dir := signf(move_input.x) if move_input.x != 0.0 else signf(vel.x)
		if dir != 0.0 and t.x * dir < 0.0:
			t = -t                            # 切线指向行进方向
		var along := vel.dot(t)
		var target_along := target_mult * Geometries.RUN_SPEED / maxf(absf(t.x), 0.35)
		if dir == 0.0:
			along = move_toward(along, 0.0, BASE_FRICTION * friction_factor * dt)
		else:
			along = move_toward(along, dir * target_along, BASE_ACCEL * accel_factor * dt)
		vel = t * along

	# ———— 跳跃(二段跳)/ 置换(土狼时间 + 输入缓冲) ————
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
		_coyote = 0.09
		_jump_cut = false
		_climb_budget = GeometryDef.CLIMB_UNITS * Geometries.UNIT_PX

	# ———— 疾 · 爬墙:离地贴住世界墙面(非同伴)且朝墙压方向 → 吸附;
	# 只按方向 = 缓降滑壁,按住跳跃键 = 沿墙向上爬(受单次 2.0 格预算限制)。
	# 贴墙时点按跳跃仍会触发空中跳(沿墙上蹭),按住则平稳爬升;
	# 爬到墙顶失去接触后,水平动量自然把身体带过墙沿 ————
	var wall_normal := _world_wall_normal()
	var cling := def.can_climb and not on_ground and gravity_dir > 0 \
		and wall_normal.x != 0.0 and move_input.x * wall_normal.x < -0.25
	if cling:
		_climbing = true
		_climb_side = -1 if wall_normal.x > 0.0 else 1
		if jump_held and _climb_budget > 0.0:
			vel.y = -CLIMB_UP * gravity_dir
			_climb_budget = maxf(_climb_budget - CLIMB_UP * dt, 0.0)
			_climb_tick -= dt
			if _climb_tick <= 0.0:
				_climb_tick = 0.16
				Sfx.play("climb")
		else:
			vel.y = CLIMB_SLIDE * gravity_dir
	else:
		_climbing = false

	var jump_power := def.jump_v * _overload_jump_ratio()
	if _jump_buffer > 0.0 and def.can_jump:
		if on_ground or _coyote > 0.0:
			# 第一段跳(地面 / 土狼时间)
			vel.y = -jump_power * gravity_dir
			_jump_buffer = 0.0
			_coyote = 0.0
			_jump_cut = false
			_squash(0.78, 1.24)
			Sfx.play("jump")
		elif _air_jumps_left > 0:
			# 第二段跳(空中)
			_air_jumps_left -= 1
			vel.y = -jump_power * gravity_dir
			_jump_buffer = 0.0
			_jump_cut = false
			_squash(0.82, 1.18)
			Sfx.play("jump")
			_air_burst()
	elif _swap_buffer > 0.0 and def.can_swap \
			and (on_ground or _coyote > 0.0) and _swap_cd <= 0.0:
		vel = _perform_swap(vel)
	# 松开跳跃键截断上升(只截断一次)
	if not _jump_cut and def.can_jump and not jump_held \
			and vel.y * gravity_dir < -def.jump_v * 0.45:
		vel.y *= 0.55
		_jump_cut = true

	vel.y = clampf(vel.y, -MAX_FALL, MAX_FALL)

	# ———— 承载同步:站上同伴头顶时,无输入则完全继承载体的速度(叠叠乐一起走)。
	# 放在摩擦之后,保证同步值不被衰减;正在上跳(逆重力方向)时不覆盖 ————
	if rider_of != null and is_instance_valid(rider_of) \
			and move_input.x == 0.0 and gravity_dir > 0 \
			and vel.y * gravity_dir >= 0.0:
		vel.x = rider_of.velocity.x
		if rider_of.is_on_floor() or rider_of.velocity.y * gravity_dir < 0.0:
			vel.y = rider_of.velocity.y
		# 头顶弹簧:垂直接触时做水平对齐(死区 4px,限速),高速移动不滑落也不卡角
		if gravity_dir > 0 and rider_of.gravity_dir > 0:
			var foot := position.y + def.size.y * 0.5
			var head_top := rider_of.position.y - rider_of.def.size.y * 0.5
			if absf(foot - head_top) < 8.0:
				var head_dx := position.x - rider_of.position.x
				if absf(head_dx) > 4.0:
					var pull := minf(absf(head_dx) - 4.0, 200.0 * dt)
					position.x -= signf(head_dx) * pull

	var impact := absf(vel.y)
	var was_floor := _was_on_floor
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
		_coyote = 0.09

	# ———— 离地:发放空中跳跃次数(二段跳的第 2 跳额度) ————
	var now_on_floor := is_on_floor()
	if was_floor and not now_on_floor:
		_air_jumps_left = maxi(GeometryDef.MAX_JUMPS - 1, 0)

	# ———— 落地判定:弹性反弹 or 站稳 ————
	var landed := now_on_floor and not was_floor
	if landed:
		if now_on_floor:
			_air_jumps_left = 0
		var eff_bounce := effective_bounce()
		var carrying := _has_riders()
		if carrying or impact <= BOUNCE_MIN or eff_bounce <= 0.0:
			# 驮着同伴时收力站稳 / 低速落地站稳
			if absf(vel.y) < 5.0:
				_squash(1.24, 0.78)
		else:
			var restitution := clampf(eff_bounce * 0.5, 0.0, 1.0)
			if jump_held and def.can_jump:
				# 落地瞬间按住跳跃:主动发力,反弹更高
				restitution = minf(restitution + 0.18, 1.12)
			else:
				restitution *= BOUNCE_SETTLE
				if _swap_air:
					restitution *= SWAP_SETTLE
			vel.y = -impact * restitution * gravity_dir
			velocity = vel
			_squash(0.72, 1.3)
			Sfx.play("bounce")
		_swap_air = false

		# ———— 圆球滚动 ————
		if def.shape == GeometryDef.Shape.BALL:
			_roll_angle += (vel.x / (def.size.x / 2.0)) * dt

	_was_on_floor = now_on_floor

	# 检测站在谁头上(承载判定:任何几何体都可落脚;超载只削弱跳跃,不禁止)
	var new_rider: Player = null
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider() as Player
		if collider != null and col.get_normal().dot(up_direction) > 0.7 \
				and gravity_dir > 0:
			new_rider = collider
			break
	rider_of = new_rider

	# ———— 曲面 buff:踩在曲面跳跃板上 → 刷新残留时长;离开后逐帧耗尽。
	# 加速(上限 ×1.5)与减重(等效重量减半)在 buff 存续期间始终生效 ————
	var on_ramp := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var obj := col.get_collider() as Node
		if col.get_normal().dot(up_direction) > 0.7 and obj != null \
				and obj.is_in_group("ramp"):
			on_ramp = true
			break
	if on_ramp:
		if _ramp_timer <= 0.0 and Main.I != null:
			Sfx.play("buff")
			Main.I.notify_ramp(def)
		_ramp_timer = RAMP_BUFF_TIME
	elif _ramp_timer > 0.0:
		_ramp_timer = maxf(_ramp_timer - dt, 0.0)

	# 高速残影采样
	_update_trail(vel)

	# 挤压恢复
	_squash_x = move_toward(_squash_x, 1.0, dt * 3.2)
	_squash_y = move_toward(_squash_y, 1.0, dt * 3.2)


## 最近一次碰撞里"世界墙面"的法线(排除同伴几何体;没有墙返回 ZERO)。
## 供爬墙判定:只有近似竖直(法线近似水平)的面才算墙。
func _world_wall_normal() -> Vector2:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.x) > 0.7 and not (col.get_collider() is Player):
			return n
	return Vector2.ZERO


## 置换:翻转重力,射向另一侧平台;水平惯性完整保留。返回更新后的速度。
func _perform_swap(vel: Vector2) -> Vector2:
	gravity_dir *= -1
	up_direction = Vector2(0, -gravity_dir)
	vel.y = SWAP_LAUNCH * gravity_dir
	_swap_buffer = 0.0
	_swap_cd = 0.25
	_coyote = 0.0
	_jump_cut = false
	_swap_air = true
	_squash(1.3, 0.74)
	Sfx.play("swap")
	_swap_burst()
	return vel


func _swap_burst() -> void:
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
	burst.color = def.color
	add_child(burst)


## 二段跳的小型气流点(与置换爆点同语言,平面色块)。
func _air_burst() -> void:
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
	ring.color = Color(def.color, 0.8)
	add_child(ring)


## 当前应瞄准的速度倍率:基础 → 加速门/曲面 → 冲刺。
## 曲面 buff 临时把上限抬到 ×1.5;加速门为永久强化;冲刺取最高者。
func _target_multiplier(sprinting: bool) -> float:
	var cap := def.base_speed
	if speed_buffed:
		cap = maxf(cap, def.buff_sprint_speed)
	if sprinting and def.can_sprint:
		cap = maxf(cap, def.buff_sprint_speed if speed_buffed else def.sprint_speed)
	if _ramp_timer > 0.0:
		cap *= RAMP_BOOST
	return cap


## 实际弹性:全员固定值(0.5;跃为 2.0)。
func effective_bounce() -> float:
	return def.bounce


## 背负超载时跳跃高度减半:头顶来者总重大于自身负重力 → 0.5,否则 1.0。
## 只削弱跳跃,不禁止跳跃(超载的几何体仍能背着同伴跳起一半高度)。
func _overload_jump_ratio() -> float:
	if Main.I == null:
		return 1.0
	var rider_load := 0.0
	for p in Main.I.players:
		if p != self and is_instance_valid(p) and p.rider_of == self:
			rider_load += p.def.weight
	if rider_load > def.carry + 0.01:
		return GeometryDef.OVERLOAD_JUMP_RATIO
	return 1.0


## 是否正驮着同伴(驮人时落地收力站稳,做稳定平台)。
func _has_riders() -> bool:
	if Main.I == null:
		return false
	for p in Main.I.players:
		if p != self and p.rider_of == self:
			return true
	return false


## 加速门:立即把速度抬到门后上限,并永久提升速度上限。
func apply_speed_gate() -> void:
	var was := speed_buffed
	speed_buffed = true
	var cap := _target_multiplier(true) * Geometries.RUN_SPEED
	if absf(velocity.x) > 20.0:
		velocity.x = signf(velocity.x) * maxf(absf(velocity.x), cap)
	elif facing != 0.0:
		velocity.x = facing * cap
	if not was:
		Sfx.play("buff")
		if Main.I != null:
			Main.I.notify_buff(_target_multiplier(true), def)


func _update_trail(vel: Vector2) -> void:
	var speed := absf(vel.x)
	if speed > Geometries.RUN_SPEED * 1.2:
		_trail.append({"pos": position, "size": def.size})
		if _trail.size() > 6:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()


# ———— 输入:统一走 InputMap 动作(键盘 / 手柄 / 虚拟触摸按键共用) ————

func _read_move() -> Vector2:
	return Vector2(Input.get_axis("move_left", "move_right"), 0)


func _read_sprint() -> bool:
	return Input.is_action_pressed("sprint")


## 跳跃键按下沿(真实输入)。调试输入由 debug_jump 在外层合成边沿。
func _read_jump_edge() -> bool:
	return Input.is_action_just_pressed("jump")


func _read_jump_held() -> bool:
	return Input.is_action_pressed("jump")


func _squash(sx: float, sy: float) -> void:
	_squash_x = sx
	_squash_y = sy


## 向下射线找地面,供 _Draw 绘制脚下投影。
func _update_ground_shadow() -> void:
	var down := Vector2(0, gravity_dir)
	var q := PhysicsRayQueryParameters2D.create(position, position + down * 460.0, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	_shadow_dist = position.distance_to(hit["position"]) if not hit.is_empty() else INF


func die() -> void:
	if dying or in_exit or arrived:
		return
	dying = true
	Sfx.play("die")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_callback(_reset_for_respawn)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_callback(_finish_respawn)
	Main.I.on_player_died(self)


func _reset_for_respawn() -> void:
	position = spawn_pos
	velocity = Vector2.ZERO
	gravity_dir = def.gravity_dir
	up_direction = Vector2(0, -gravity_dir)
	speed_buffed = false
	_swap_air = false
	_air_jumps_left = 0
	_climbing = false
	_climb_budget = GeometryDef.CLIMB_UNITS * Geometries.UNIT_PX
	_ramp_timer = 0.0
	_trail.clear()


func _finish_respawn() -> void:
	dying = false
	Main.I.on_respawn_done()


## 到达专属终点门:原地待命并保持可操控;离开门区则由 ExitDoor 取消到达。
func arrive_at(door: ExitDoor) -> void:
	if arrived or in_exit or dying:
		return
	arrived = true
	Sfx.play("switch")
	var tw := create_tween()
	tw.tween_property(self, "position:x", door.center.x, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Main.I.on_player_arrived(self)


## 离开终点门区:取消到达待命(终点未封印时)。
func depart_exit() -> void:
	if in_exit or dying:
		return
	arrived = false
	Main.I.on_player_departed(self)


func enter_exit(door: ExitDoor) -> void:
	if in_exit or dying:
		return
	in_exit = true
	is_active = false
	arrived = false
	velocity = Vector2.ZERO
	Sfx.play("enter")

	# 进门粒子
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
	door.add_child(burst)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", door.center + Vector2(0, 4 * gravity_dir), 0.4) \
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

	# 脚下硬投影(几何色块,随离地高度缩小)
	if _shadow_dist < 440.0 and shrink > 0.4:
		var k := 1.0 - _shadow_dist / 440.0
		var w := size.x * (0.55 + 0.35 * k)
		draw_set_transform(Vector2(0, (size.y / 2.0 + 5.0) * gravity_dir), 0.0,
			Vector2(w, w * 0.26))
		var shadow_col := Color(0, 0, 0, 0.34 * k)
		if def.shape == GeometryDef.Shape.BALL:
			draw_circle(Vector2.ZERO, 1.0, shadow_col)
		else:
			draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), shadow_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 高速残影(构成主义式的速度拖尾)
	var trail_n := _trail.size()
	for i in trail_n:
		var t: Dictionary = _trail[i]
		var a := 0.16 * float(i + 1) / float(trail_n)
		var ts: Vector2 = t["size"] * shrink
		if def.shape == GeometryDef.Shape.BALL:
			draw_circle(t["pos"] - position, ts.x / 2.0, Color(def.color, a * 0.7))
		else:
			draw_rect(Rect2(t["pos"] - position - ts / 2.0, ts), Color(def.color, a * 0.7))

	# 本体:棱角分明的几何形
	if def.shape == GeometryDef.Shape.BALL:
		_draw_ball(size)
	else:
		_draw_box(size)

	# 活跃几何体的取景框:细白方框 + 呼吸刻度
	if is_active:
		var frame := Rect2(-size / 2.0, size).grow(7.0)
		draw_rect(frame, Color(1, 1, 1, 0.85), false, 1.6)
		var pulse := 0.6 + 0.4 * sin((Time.get_ticks_msec() % 1000000) / 190.0)
		draw_rect(Rect2(frame.position - Vector2(4, 4), Vector2(8, 8)),
			Color(def.color.lerp(Color.WHITE, 0.4), pulse))
		_draw_name_tag(size)


func _draw_box(size: Vector2) -> void:
	var body := Rect2(-size / 2.0, size)
	_body_box.bg_color = def.color
	if is_active:
		_body_box.border_color = Color.WHITE
		_body_box.set_border_width_all(2)
	else:
		_body_box.border_color = Color(def.color, 0.0)
		_body_box.set_border_width_all(0)
	draw_style_box(_body_box, body)

	# 左上硬高光条(锐利,不渐变)
	draw_rect(Rect2(body.position + Vector2(3, 3), Vector2(size.x * 0.42, 3)),
		Color(1.0, 1.0, 1.0, 0.4))

	# 爬墙握点:贴墙时在墙面一侧的白色横向刻度
	if _climbing:
		var gx := _climb_side * size.x * 0.5
		for gy: float in [-size.y * 0.24, size.y * 0.04, size.y * 0.32]:
			draw_line(Vector2(gx - _climb_side * 9.0, gy), Vector2(gx, gy),
				Color(1, 1, 1, 0.75), 2.5)

	# 置换几何体:躯干上的上下双向箭头刻度
	if def.can_swap:
		var s := minf(size.x, size.y) * 0.14
		var gap := s * 1.5
		for dir: int in [-1, 1]:
			var cy := dir * gap
			var arrow := PackedVector2Array([
				Vector2(0, cy + dir * s), Vector2(-s * 0.85, cy - dir * s * 0.4),
				Vector2(-s * 0.3, cy - dir * s * 0.4), Vector2(-s * 0.3, cy - dir * s * 1.1),
				Vector2(s * 0.3, cy - dir * s * 1.1), Vector2(s * 0.3, cy - dir * s * 0.4),
				Vector2(s * 0.85, cy - dir * s * 0.4),
			])
			draw_colored_polygon(arrow, Color(1, 1, 1, 0.85))
	# 反重力几何体:躯干上的向上箭头刻度
	elif gravity_dir < 0:
		var cx := 0.0
		var cy := -size.y / 2.0 + size.y * 0.30
		var s := minf(size.x, size.y) * 0.13
		var arrow := PackedVector2Array([
			Vector2(cx, cy - s), Vector2(cx + s * 0.85, cy + s * 0.4),
			Vector2(cx + s * 0.3, cy + s * 0.4), Vector2(cx + s * 0.3, cy + s * 1.1),
			Vector2(cx - s * 0.3, cy + s * 1.1), Vector2(cx - s * 0.3, cy + s * 0.4),
			Vector2(cx - s * 0.85, cy + s * 0.4),
		])
		draw_colored_polygon(arrow, Color(1, 1, 1, 0.85))


func _draw_ball(size: Vector2) -> void:
	var r := size.x / 2.0
	draw_circle(Vector2.ZERO, r, def.color)
	if is_active:
		draw_arc(Vector2.ZERO, r - 1.0, 0.0, TAU, 40, Color.WHITE, 2.0)
	# 滚动辐条:让旋转可见
	draw_set_transform(Vector2.ZERO, _roll_angle, Vector2.ONE)
	var spoke := r * 0.62
	draw_line(Vector2(-spoke, 0), Vector2(spoke, 0), Color(0, 0, 0, 0.4), 3.0)
	draw_line(Vector2(0, -spoke), Vector2(0, spoke), Color(0, 0, 0, 0.28), 2.0)
	draw_circle(Vector2.ZERO, r * 0.16, Color(1, 1, 1, 0.75))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_name_tag(size: Vector2) -> void:
	if Ui.HEAD == null:
		return
	var ts := Ui.HEAD.get_string_size(def.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var pos := Vector2(-ts.x / 2.0, (-size.y / 2.0 - 10.0) * gravity_dir)
	draw_string(Ui.HEAD, pos + Vector2(0, 1), def.name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.55))
	draw_string(Ui.HEAD, pos, def.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.92))
