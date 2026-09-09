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
const MAX_FALL := 1150.0      # 终端速度 v∞:二次空气阻力下落 speed 的渐近上限
const BASE_ACCEL := 2400.0    # 标准 1.0 重量几何体的地面加速度
const AIR_ACCEL_RATIO := 0.62
## 地面摩擦系数 μ(库伦摩擦:减速度 a = μ·g)。物理权威在 GeometryDef
## (标准几何体 μ ≈ 1.27;越重越难起动也越难停下是设计特性),
## 此处引用保持调用点不变。
const MU_FRICTION := GeometryDef.MU_FRICTION
const BALL_MU_ROLL := GeometryDef.BALL_MU_ROLL    # 圆球滚动阻力系数(μ 滚动版)
const SWAP_LAUNCH := 300.0    # 置换瞬间射向新落点平台的初速度
const CLIMB_UP := 150.0       # 爬墙:按住跳跃键的上升速度
const CLIMB_SLIDE := 55.0     # 爬墙:只按方向贴墙时的缓降速度
const RAMP_BUFF_TIME := 1.5   # 曲面 buff:离开曲面后残留时长(秒)
const RAMP_BOOST := 1.5       # 曲面 buff:速度上限倍率
const RAMP_WEIGHT_RATIO := 0.5  # 曲面 buff:等效重量倍率(减半)
const FALL_GRAVITY_MULT := 1.24 # 三段重力:下落加重,跳-落曲线不对称(更利落)
const APEX_GRAVITY_MULT := 0.86 # 三段重力:抛物线顶点轻微悬停(目标感)
const APEX_WINDOW := 110.0      # 顶点判定窗口(|vy| 低于此值)
## 词条「玻璃疾走」:重落地即碎的冲击阈值。
const GLASS_IMPACT := 620.0
## 词条速度上限的绝对钳制(与门厅"加速门×曲面"峰值 3.75 一致,
## 非强化状态的旧手感完全不变)。
const MOD_SPEED_CAP := 3.75
## 可推动(肆·圆):推挤传速加速度(px/s²,characters.md §4)。
const PUSH_TRANSFER := 1800.0
## 轻点/长按跳判定(v0.16 常量化,characters.md §2):
## 按下即起跳(缓冲 0.12s)→ 上升中松键且速度仍超起跳速的 JUMP_CUT_RATIO
## → 剩余速度 ×JUMP_CUT_MULT(轻点 ≈ 满跳 55% 高,长按全程不截断)。
const JUMP_CUT_MULT := 0.55
const JUMP_CUT_RATIO := 0.45

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
## 世界碰撞位并集(LevelBuilder 构建期按语义组合算定,levels.md §7.6;
## 缺省组合恒为位 1,与旧版 mask=3 行为逐位一致)。
var world_mask := 1

## 进门时的缩小系数,由 Tween 驱动。
var shrink := 1.0

var facing := 1.0
var input_x := 0.0            # 本帧水平输入(载体侧刚性随动的自走判定)
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
var _skidding := false        # 急转打滑(反馈只发一次,速度回落后复位)
var _ramp_timer := 0.0        # 曲面 buff 剩余时长;站在曲面上时持续刷新
var _squash_x := 1.0
var _squash_y := 1.0
var _roll_angle := 0.0        # 圆球累计滚动角(rad),每帧按角速度推进
var _roll_speed := 0.0        # 圆球角速度(rad/s):地面 = v/r 纯滚动,空中保留角动量
var _roll_loop: AudioStreamPlayer  # 圆球滚动轰鸣(音量/音高随速度连续调制)
var _trail: Array = []        # 高速残影的位置记录 [{pos, size}]
var _piano_touch: Array = []  # 上一帧接触的钢琴砖(接触沿判定,防静止连响)
var _shadow_dist: float = INF
var _body_box: StyleBoxFlat


func _ready() -> void:
	collision_layer = 2
	collision_mask = 2 | world_mask
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

	# 圆球滚动轰鸣:循环噪声底,音量/音高由每帧速度调制
	if def.shape == GeometryDef.Shape.BALL:
		_roll_loop = AudioStreamPlayer.new()
		_roll_loop.stream = Sfx.loop_stream("roll")
		_roll_loop.volume_db = -60.0
		add_child(_roll_loop)
		_roll_loop.play()


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
	input_x = move_input.x
	if move_input.x != 0.0:
		facing = signf(move_input.x)

	# ———— 重力:升 / 顶 / 落三段曲线(下落加重、顶点微悬停,抛物感更强) ————
	# 上升段:恒定重力(顶点窗口内减轻,制造"微悬停"的目标感);
	# 下落段:牛顿阻力模型 ma = mg − kv²(二次空气阻力),
	#         速度逼近终端速度 MAX_FALL 时阻力抵消重力,加速度平滑归零 ——
	#         取代旧的硬 clamp 截断,长落体的速度曲线连续无拐点。
	var g_mult := 1.0
	if vel.y * gravity_dir < 0.0:
		if absf(vel.y) < APEX_WINDOW:
			g_mult = APEX_GRAVITY_MULT
		vel.y += Geometries.GRAVITY * g_mult * gravity_dir * dt
	else:
		var v_n := clampf(absf(vel.y) / MAX_FALL, 0.0, 1.0)   # 归一化落速 v/v∞
		var a_fall := Geometries.GRAVITY * FALL_GRAVITY_MULT * (1.0 - v_n * v_n)
		vel.y += a_fall * gravity_dir * dt
		if absf(vel.y) > MAX_FALL:
			vel.y = MAX_FALL * signf(vel.y)   # 极端帧安全阀(渐近线之内)

	# ———— 水平移动:加速度 + 惯性(摩擦按 μ·g 库伦模型公式化) ————
	var on_ground := is_on_floor()
	var target_mult := _target_multiplier(sprinting)
	var target_vx := move_input.x * target_mult * Geometries.RUN_SPEED
	var eff_weight := RunState.modified(def, "weight") \
		* (RAMP_WEIGHT_RATIO if ramp_buffed else 1.0)
	var accel_factor := clampf(1.15 - 0.3 * eff_weight, 0.55, 1.15)
	var friction_factor := clampf(1.1 - 0.35 * eff_weight, 0.4, 1.1)
	var mu := MU_FRICTION * friction_factor * RunState.modified(def, "friction")
	if def.shape == GeometryDef.Shape.BALL:
		accel_factor = maxf(accel_factor, 1.0)
		mu = BALL_MU_ROLL * friction_factor           # 滚动阻力系数远小于滑动
	if move_input.x != 0.0:
		var accel := BASE_ACCEL * accel_factor
		if not on_ground:
			accel *= AIR_ACCEL_RATIO
		vel.x = move_toward(vel.x, target_vx, accel * dt)
	else:
		# 松开输入:摩擦减速 a = μ·g(与质量无关的质量定律,μ 承载材质差异),
		# 空中只有微弱空气阻力(0.28 倍),惯性滑行
		var friction := mu * Geometries.GRAVITY
		if not on_ground:
			friction *= 0.28
		vel.x = move_toward(vel.x, 0.0, friction * dt)

	# ———— 急转打滑:地面反向发力且仍有速度 → 短挤压 + 脚下尘点(反馈可读) ————
	if on_ground and move_input.x != 0.0 and absf(vel.x) > 200.0 \
			and signf(move_input.x) != signf(vel.x) and not _skidding:
		_skidding = true
		_squash(1.10, 0.92)
		_skid_burst()
	elif move_input.x == 0.0 or absf(vel.x) < 40.0 or not on_ground:
		_skidding = false

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
			along = move_toward(along, 0.0, mu * Geometries.GRAVITY * dt)
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
		_coyote = RunState.modified(def, "coyote")
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

	var jump_power := RunState.jump_v(def) * _overload_jump_ratio()
	if _jump_buffer > 0.0 and def.can_jump:
		if on_ground or _coyote > 0.0:
			# 第一段跳(地面 / 土狼时间);跃顶起跳触发顶弹翻倍(characters.md §3)
			vel.y = -jump_power * _top_boost_ratio() * gravity_dir
			_jump_buffer = 0.0
			_coyote = 0.0
			_jump_cut = false
			_squash(0.78, 1.24)
			Sfx.play("jump", 0.0, _note_pitch())
		elif _air_jumps_left > 0:
			# 第二段跳(空中)
			_air_jumps_left -= 1
			vel.y = -jump_power * gravity_dir
			_jump_buffer = 0.0
			_jump_cut = false
			_squash(0.82, 1.18)
			Sfx.play("jump2", 0.0, _note_pitch() * 1.26)
			_air_burst()
	elif _swap_buffer > 0.0 and def.can_swap \
			and (on_ground or _coyote > 0.0) and _swap_cd <= 0.0:
		vel = _perform_swap(vel)
	# 松开跳跃键截断上升(只截断一次)
	if not _jump_cut and def.can_jump and not jump_held \
			and vel.y * gravity_dir < -def.jump_v * JUMP_CUT_RATIO:
		vel.y *= JUMP_CUT_MULT
		_jump_cut = true

	vel.y = clampf(vel.y, -MAX_FALL, MAX_FALL)

	# ———— 刚性携带·骑乘侧(v0.16,characters.md §2):无输入时水平运动
	# 交给载体随动(见载体侧,用载体本帧实际位移搬运,零滑移);
	# 头顶弹簧吸附已废除(用户实测:吸附感不行);有输入 = 自走,可走离头顶。
	# 垂直仍接收载体速度(叠叠乐一起升降);正在上跳(逆重力方向)时不覆盖 ————
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
		_coyote = RunState.modified(def, "coyote")

	# ———— 离地:发放空中跳跃次数(二段跳的第 2 跳额度;词条「云梯踏」+1) ————
	var now_on_floor := is_on_floor()
	if was_floor and not now_on_floor:
		_air_jumps_left = maxi(int(RunState.modified(def, "air_jumps")), 0)

	# ———— 落地判定:弹性反弹 or 站稳 ————
	var landed := now_on_floor and not was_floor
	if landed:
		if now_on_floor:
			_air_jumps_left = 0
		# 重落地的镜头轻沉(可叠加,幅度克制)
		if impact > 620.0:
			SettingsManager.haptic(40)
			if Main.I != null and Main.I.camera_rig != null:
				Main.I.camera_rig.kick(minf(1.6 + impact / 420.0, 4.6))
		var eff_bounce := effective_bounce()
		var carrying := _has_riders()
		# 玻璃疾走:重落地即碎(死亡按重拼结算,消耗红色刻度)
		if RunState.has_flag(def, "glass") and impact > GLASS_IMPACT:
			_swap_air = false
			die()
		elif carrying or impact <= BOUNCE_MIN or eff_bounce <= 0.0:
			# 驮着同伴时收力站稳 / 低速落地站稳;有一定冲击则补轻着地音
			if absf(vel.y) < 5.0:
				_squash(1.24, 0.78)
			elif impact > 120.0:
				Sfx.play("land", 0.0, _note_pitch())
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
			Sfx.play("bounce", 0.0, _note_pitch())
		_swap_air = false

	# ———— 圆球滚动:地面按 v/r 纯滚动;空中保留角动量(轻微空气阻尼),
	# 从曲面飞出后继续翻转,落地时姿态连续 ————
	if def.shape == GeometryDef.Shape.BALL:
		if now_on_floor:
			_roll_speed = vel.x / (def.size.x * 0.5)
		else:
			_roll_speed = move_toward(_roll_speed, 0.0, 0.9 * dt)
		_roll_angle += _roll_speed * dt

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

	# ———— 刚性携带·载体侧(v0.16):把骑乘者随动本帧实际水平位移——
	# 无论物理帧处理顺序先后都零相对滑移;急停不甩尾,骑乘者有输入则自走 ————
	var carry_dx := position.x - prev_x
	if carry_dx != 0.0:
		for p in Main.I.players:
			if p != self and is_instance_valid(p) and p.rider_of == self \
					and not p.dying and p.gravity_dir > 0 and p.input_x == 0.0:
				p.position.x += carry_dx
				p.velocity.x = velocity.x

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

	# ———— 钢琴地板砖:踩踏 / 滚过发声(audio.md §4);
	# 接触沿上报 + 离砖复位,静止压砖不再每帧重发(v0.16 机关枪修复) ————
	var piano_now: Array = []
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var obj = col.get_collider()
		if obj is LevelBuilder.PianoTile and col.get_normal().dot(up_direction) > 0.7:
			piano_now.append(obj)
			(obj as LevelBuilder.PianoTile).strike(self, vel.length())
	for t in _piano_touch:
		if not piano_now.has(t):
			t.release(index)
	_piano_touch = piano_now

	# ———— 可推动(肆·圆,characters.md §4):地面水平推挤圆球 → 传速滚动。
	# 只传速不改位置,圆球自身滚动摩擦自然衰减;推力不高于推者自身速度 ————
	if def.shape != GeometryDef.Shape.BALL and now_on_floor and absf(vel.x) > 20.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var other := col.get_collider() as Player
			if other != null and other.def.can_be_pushed \
					and signf(col.get_normal().x) == signf(-vel.x):
				other.velocity.x = move_toward(other.velocity.x, vel.x,
					PUSH_TRANSFER * dt)

	# 高速残影采样
	_update_trail(vel)

	# 圆球滚动轰鸣:贴地时音量/音高随速度爬升,离地淡出
	if _roll_loop != null:
		var spd := absf(vel.x)
		var k := clampf(spd / (Geometries.RUN_SPEED * 2.5), 0.0, 1.0)
		var target_db := lerpf(-46.0, -13.0, k) if now_on_floor else -60.0
		_roll_loop.volume_db = lerpf(_roll_loop.volume_db, target_db,
			1.0 - exp(-9.0 * dt))
		_roll_loop.pitch_scale = 0.72 + 0.6 * k

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
	_swap_cd = RunState.modified(def, "swap_cooldown")
	_coyote = 0.0
	_jump_cut = false
	_swap_air = true
	_squash(1.3, 0.74)
	Sfx.play("swap", 0.0, _note_pitch())
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


## 急转打滑的脚下尘点:纸白小方块,贴地横扫(与死亡碎片同语言,量级更小)。
func _skid_burst() -> void:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = 7
	dust.lifetime = 0.26
	dust.explosiveness = 1.0
	dust.spread = 180.0
	dust.gravity = Vector2(0, 260 * gravity_dir)
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 90.0
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 2.2
	dust.color = Color(Ui.PAPER, 0.55)
	add_child(dust)


## 当前应瞄准的速度倍率:基础 → 加速门/曲面 → 冲刺。
## 曲面 buff 临时把上限抬到 ×1.5;加速门为永久强化;冲刺取最高者。
## 词条钩子:base_speed / buff_sprint_speed 覆盖读取,双倍门(gate_mult)
## 只放大加速门强化后的上限,全局钳制在 MOD_SPEED_CAP。
func _target_multiplier(sprinting: bool) -> float:
	var cap := RunState.modified(def, "base_speed")
	if speed_buffed:
		cap = maxf(cap, RunState.modified(def, "buff_sprint_speed"))
	if sprinting and def.can_sprint:
		cap = maxf(cap, RunState.modified(def, "buff_sprint_speed") if speed_buffed
			else def.sprint_speed)
	if speed_buffed:
		cap = minf(cap * RunState.modified(def, "gate_mult"), MOD_SPEED_CAP)
	if _ramp_timer > 0.0:
		cap = minf(cap * RAMP_BOOST, MOD_SPEED_CAP)
	return cap


## 实际弹性:基础值(0.5;跃为 2.0)+ 词条覆盖。
func effective_bounce() -> float:
	return RunState.modified(def, "bounce")


## 背负超载时跳跃高度减半:头顶来者总重大于自身负重力 → 0.5,否则 1.0。
## 只削弱跳跃,不禁止跳跃(超载的几何体仍能背着同伴跳起一半高度)。
func _overload_jump_ratio() -> float:
	if Main.I == null:
		return 1.0
	var rider_load := 0.0
	for p in Main.I.players:
		if p != self and is_instance_valid(p) and p.rider_of == self:
			rider_load += RunState.modified(p.def, "weight")
	if rider_load > RunState.modified(def, "carry") + 0.01:
		return GeometryDef.OVERLOAD_JUMP_RATIO
	return 1.0


## 顶弹翻倍(贰·跃,characters.md §3):从可顶弹几何体头顶起跳 → 该跳高度 ×2。
## 只作用于第一段跳(地面/土狼);空中跳不继承。与超载减半自然相乘。
func _top_boost_ratio() -> float:
	if rider_of != null and is_instance_valid(rider_of) and rider_of.def.can_top_boost:
		return 2.0
	return 1.0


## 几何体主题音符变调比(壹=do / 贰=re / 叁=mi / 肆=fa;glossary.md §1):
## 跳跃与落地音效各唱各的音,同一几何体的音效恒在它的音位上。
func _note_pitch() -> float:
	return Sfx.note_ratio(def.note)


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


## 向下(重力方向)射线找地面,供 _Draw 绘制脚下投影。
## 查询走自身碰撞位:对我不适用的组件既不碰撞也不投影(视觉即机制)。
func _update_ground_shadow() -> void:
	var down := Vector2(0, gravity_dir)
	var q := PhysicsRayQueryParameters2D.create(
		position, position + down * 460.0, collision_mask)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	_shadow_dist = position.distance_to(hit["position"]) if not hit.is_empty() else INF


func die() -> void:
	if dying or in_exit or arrived:
		return
	dying = true
	Sfx.play("die", 0.0, _note_pitch())
	SettingsManager.haptic(60)
	if _roll_loop != null:
		_roll_loop.volume_db = -60.0
	_death_burst()
	if Main.I != null and Main.I.camera_rig != null:
		Main.I.camera_rig.kick(7.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_callback(_reset_for_respawn)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_callback(_finish_respawn)
	Main.I.on_player_died(self)


## 死亡碎片爆裂:挂关卡层(避开本体淡出 modulate 的牵连),方块碎片受重力散落。
func _death_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 18
	burst.lifetime = 0.55
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2(0, 900 * gravity_dir)
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 340.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 6.0
	burst.color = def.color
	burst.finished.connect(burst.queue_free)
	get_parent().add_child(burst)
	burst.global_position = global_position


func _reset_for_respawn() -> void:
	position = spawn_pos
	rider_of = null               # 重生位置远离载体:立即解除骑乘,防刚性随动拉扯
	velocity = Vector2.ZERO
	gravity_dir = def.gravity_dir
	up_direction = Vector2(0, -gravity_dir)
	speed_buffed = false
	_swap_air = false
	_air_jumps_left = 0
	_climbing = false
	_climb_budget = GeometryDef.CLIMB_UNITS * Geometries.UNIT_PX
	_ramp_timer = 0.0
	_roll_angle = 0.0
	_roll_speed = 0.0
	_squash_x = 1.0
	_squash_y = 1.0
	for t in _piano_touch:
		t.release(index)
	_piano_touch.clear()
	_trail.clear()


func _finish_respawn() -> void:
	dying = false
	Main.I.on_respawn_done()


## 到达专属终点门:原地待命并保持可操控;离开门区则由 ExitDoor 取消到达。
func arrive_at(door: ExitDoor) -> void:
	if arrived or in_exit or dying:
		return
	arrived = true
	Sfx.play("arrive")
	SettingsManager.haptic(30)
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
	if _roll_loop != null:
		_roll_loop.volume_db = -60.0

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

	# 本体:棱角分明的几何形(不带外框 —— 活跃指示靠亮度脉冲 + 名牌 + 队伍 chips)
	if def.shape == GeometryDef.Shape.BALL:
		_draw_ball(size)
	else:
		_draw_box(size)

	if is_active:
		_draw_name_tag(size)


func _draw_box(size: Vector2) -> void:
	var body := Rect2(-size / 2.0, size)
	var u := minf(size.x, size.y)
	# 活跃几何体的亮度呼吸:整块提亮(亮度连续变化,无像素取整,慢速也平滑)
	if is_active:
		var glow := 0.10 + 0.10 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 380.0))
		_body_box.bg_color = def.color.lerp(Color.WHITE, glow)
	else:
		_body_box.bg_color = def.color
	draw_style_box(_body_box, body)

	# 精度与对比度:底部暗带(接地体量)+ 左上高光条 + 右缘窄暗边,
	# 让形体在深色场地上"立"起来(全部硬边色块,无渐变)。
	# 局内自机不带图案:印刷错位主纹只出现在档案肖像(GeometryPanel.GeoPortrait)。
	draw_rect(Rect2(body.position.x, body.end.y - body.size.y * 0.24,
		body.size.x, body.size.y * 0.24), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(body.end.x - maxf(2.0, u * 0.045), body.position.y,
		maxf(2.0, u * 0.045), body.size.y), Color(0, 0, 0, 0.14))
	draw_rect(Rect2(body.position + Vector2(3, 3), Vector2(size.x * 0.42, 3)),
		Color(1.0, 1.0, 1.0, 0.5))

	# 爬墙握点:贴墙时在墙面一侧的白色横向刻度
	if _climbing:
		var gx := _climb_side * size.x * 0.5
		for gy: float in [-size.y * 0.24, size.y * 0.04, size.y * 0.32]:
			draw_line(Vector2(gx - _climb_side * 9.0, gy), Vector2(gx, gy),
				Color(1, 1, 1, 0.75), 2.5)


## 圆球形象:基盘 + 暗色半月(滚动方向可读性主元素)+ 轮毂。
## 局内自机不带图案:指针辐条等印刷错位图案只出现在档案肖像。
## 转动图案先在单位圆内随物理滚动旋转、再整体压扁成椭圆——
## 挤压/拉伸在屏幕空间进行、与旋转解耦,形变不扭曲转动姿态(动画十二法则)。
## 高速时半月对比自动承载转动可读:明暗半球随滚动翻转,无需额外刻度。
func _draw_ball(size: Vector2) -> void:
	var squash := Transform2D(
		Vector2(size.x * 0.5, 0.0), Vector2(0.0, size.y * 0.5), Vector2.ZERO)
	draw_set_transform_matrix(squash * Transform2D(_roll_angle, Vector2.ZERO))

	# 基盘
	draw_circle(Vector2.ZERO, 1.0, def.color)
	# 暗色半月:一半明一半暗,滚动方向一眼可读
	var half := PackedVector2Array([Vector2(-1.0, 0.0)])
	for i in 17:
		var a := PI * float(i) / 16.0
		half.append(Vector2(cos(a), sin(a)))
	half.append(Vector2(1.0, 0.0))
	draw_colored_polygon(half, def.color.darkened(0.26))

	# 轮毂
	draw_circle(Vector2.ZERO, 0.2, Ui.PAPER)
	draw_circle(Vector2.ZERO, 0.085, Color(Ui.INK, 0.85))

	# 活跃取景环:单位空间画等宽圆环(随椭圆变换,挤压时不变形走样)
	if is_active:
		var ring_out := PackedVector2Array()
		var ring_in := PackedVector2Array()
		for i in 33:
			var a := TAU * float(i) / 32.0
			ring_out.append(Vector2(cos(a), sin(a)))
			ring_in.append(Vector2(cos(a), sin(a)) * 0.94)
		for i in 32:
			draw_colored_polygon(PackedVector2Array([
				ring_out[i], ring_out[i + 1], ring_in[i + 1], ring_in[i]]),
				Color(1, 1, 1, 0.85))

	draw_set_transform_matrix(Transform2D())


func _draw_name_tag(size: Vector2) -> void:
	if Ui.HEAD == null:
		return
	var ts := Ui.HEAD.get_string_size(def.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var pos := Vector2(-ts.x / 2.0, (-size.y / 2.0 - 10.0) * gravity_dir)
	draw_string(Ui.HEAD, pos + Vector2(0, 1), def.name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.55))
	draw_string(Ui.HEAD, pos, def.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.92))
