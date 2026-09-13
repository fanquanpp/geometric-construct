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

# 手感数值已下沉 MovementTuning(data/tuning/movement_default.tres,
# 场景资源强制约束 R2 / REFACTOR §八 M-1);原 MovementCore 常量别名
# 随 M-1 迁移删除,调用点直读资源实例。
# 三段重力倍率(FALL 1.24 / APEX 0.86)走 RunState 修饰链
# (DEFAULTS.gravity_fall_mult / gravity_apex_mult,Sprint 2 入链)
## 词条「玻璃疾走」:重落地即碎的冲击阈值。
const GLASS_IMPACT := 620.0
## 词条速度上限的绝对钳制(与门厅"加速门×曲面"峰值 3.75 一致,
## 非强化状态的旧手感完全不变)。
const MOD_SPEED_CAP := 3.75
## 可推动(肆·圆):推挤传速加速度(px/s²,characters.md §4)。
const PUSH_TRANSFER := 1800.0
## 轻点/长按跳判定(v0.16 常量化,characters.md §2):
## 按下即起跳(缓冲 0.12s)→ 上升中松键且速度仍超起跳速的 MovementTuning.I.jump_cut_ratio
## → 剩余速度 ×MovementTuning.I.jump_cut_mult(轻点 ≈ 满跳 55% 高,长按全程不截断)。

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
## 世界碰撞位并集(LevelBuilder 构建期按实体签名算定,分层语义 v3
## levels.md §7.10:签名 = (layer, who),仅实体层组件占位,空集 = 1)。
var world_mask := 1

## 进门时的缩小系数,由 Tween 驱动。
var shrink := 1.0

var facing := 1.0
var skiing := false           # 滑雪带覆盖中(SkiPatch 写入):低摩擦低加速
var input_x := 0.0            # 本帧水平输入(载体侧刚性随动的自走判定)
## 输入槽注入(net.md §2 N0):null = 本地槽位 0(既有动作,行为零变化);
## 联机时主机侧客机绑定体 = RemoteInputSource,同屏双人 = 分区 LocalInputSource。
var input_source: InputSource = null
## 远端驱动(客机端一切几何体):不做本地物理,跟随主机快照(net.md §6 D2)。
var remote_driven := false
var _net_pos := Vector2.ZERO
var _net_vel := Vector2.ZERO
## 双子(伍·界/边,characters.md §5):-1 非双子;0 = 界(上三角) 1 = 边(下三角)
var pair_half := -1
var partner: Player = null    # 另一半(双体专用)


## 体身份键(双体系统契约,characters.md §5):凡按"个体"区分的状态
## (记录点 / 琴键接触沿 / 任何逐体登记)一律以此键存取——
## 双体两半共享 index 但各占一键;普通体 pair_half = -1 退化为 index*STRIDE。
## STRIDE 是体数跨度:预留每一下标至多 4 具;未来出现更多体的特殊几何体
## 只需扩此常数,body_key 永不跨下标冲突(Godot 社区多角色架构惯例:
## 逐体状态用稳定身份键,不用几何体下标)。
const BODY_STRIDE := 4

func body_key() -> int:
	return index * BODY_STRIDE + clampi(pair_half, 0, BODY_STRIDE - 1)
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
var _occluder: LightOccluder2D  # 引擎光影遮挡体:形体即影子(art-style.md §8)
var _body_box: StyleBoxFlat


func _ready() -> void:
	collision_layer = 2
	collision_mask = 2 | world_mask
	gravity_dir = def.gravity_dir
	# 双子(伍·界/边,characters.md §5):界生于天花板(重力天生反向,天路是她的地面),
	# 边行于地面;磁界线张在两者之间,横跨上下两层。须在 up_direction 之前生效。
	if pair_half == 0:
		gravity_dir = -1
	# 磁力边界(伍):除逆(穿透)与双子自身外,人人受阻(characters.md §5)
	if not def.can_pass_boundary and pair_half < 0:
		collision_mask |= TerrainKit.BOUNDARY_BIT
	up_direction = Vector2(0, -gravity_dir)
	z_index = 5
	_climb_budget = RunState.modified(def, "climb_units") * MovementTuning.I.climb_units * Geometries.UNIT_PX
	# 曲面跳跃板:圆球需要贴住更陡的坡面并在末端切线飞出
	if def.shape == GeometryDef.Shape.BALL:
		floor_max_angle = deg_to_rad(60.0)

	var shape_node := CollisionShape2D.new()
	if def.shape == GeometryDef.Shape.BALL:
		var circle := CircleShape2D.new()
		circle.radius = def.size.x / 2.0
		shape_node.shape = circle
	elif def.shape == GeometryDef.Shape.TRIANGLE:
		# 双子形体(v0.17.2 修正):界(天花板)= 倒三角▽平边贴顶;
		# 边(地面)= 正三角△平边落地;磁力线连接两个顶点(尖对尖)
		var poly := ConvexPolygonShape2D.new()
		var hw := def.size.x * 0.5
		var hh := def.size.y * 0.5
		if pair_half == 0:
			poly.points = PackedVector2Array([
				Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(0, hh)])
		else:
			poly.points = PackedVector2Array([
				Vector2(-hw, hh), Vector2(hw, hh), Vector2(0, -hh)])
		shape_node.shape = poly
	else:
		var rect := RectangleShape2D.new()
		rect.size = def.size
		shape_node.shape = rect
	add_child(shape_node)
	_init_occluder()

	_body_box = StyleBoxFlat.new()
	_body_box.bg_color = def.color

	# 圆球滚动轰鸣:循环噪声底,音量/音高由每帧速度调制
	if def.shape == GeometryDef.Shape.BALL:
		_roll_loop = AudioStreamPlayer.new()
		_roll_loop.stream = Sfx.loop_stream("roll")
		_roll_loop.volume_db = -60.0
		add_child(_roll_loop)
		_roll_loop.play()


## 引擎光影遮挡体(v0.19 art-style §8):形体即影子 —— 多边形与碰撞形一致,
## 顺时针绕行;cull_mode 挡掉自投影(本体不被自己的遮挡体压暗)。
func _init_occluder() -> void:
	_occluder = LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
	var hw := def.size.x * 0.5
	var hh := def.size.y * 0.5
	if def.shape == GeometryDef.Shape.BALL:
		var pts := PackedVector2Array()
		for i in 18:
			var a := TAU * float(i) / 18.0
			pts.append(Vector2(cos(a) * hw, sin(a) * hh))
		poly.polygon = pts
	elif def.shape == GeometryDef.Shape.TRIANGLE:
		# 界(天花板)= 倒三角▽平边贴顶;边(地面)= 正三角△平边落地
		poly.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(0, hh)]) \
			if pair_half == 0 else PackedVector2Array([
			Vector2(0, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	else:
		poly.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	_occluder.occluder = poly
	add_child(_occluder)


## 挤压 / 缩小 / 残影都需要逐帧重绘;遮挡体随挤压与进门缩小同步,
## 死亡淡出时收掉影子(淡走的是整个存在)。
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
	var ramp_buffed := _ramp_timer > 0.0   # 本帧开始时是否带曲面 buff(加速/减重)
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

	# ———— 重力:三段曲线(升 / 顶 / 落)公式下沉 MovementCore(REFACTOR P4) ————
	vel = MovementCore.gravity_step(vel, def, gravity_dir, dt)

	# ———— 水平移动:加速度 + 惯性(摩擦按 μ·g 库伦模型)公式下沉 MovementCore ————
	var on_ground := is_on_floor()
	var target_mult := _target_multiplier(sprinting)
	vel.x = MovementCore.horizontal_step(vel, self, move_input, target_mult,
		on_ground, ramp_buffed, dt)

	# ———— 急转打滑:地面反向发力且仍有速度 → 短挤压 + 脚下尘点(反馈可读) ————
	if on_ground and move_input.x != 0.0 and absf(vel.x) > 200.0 \
			and signf(move_input.x) != signf(vel.x) and not _skidding:
		_skidding = true
		_squash(1.10, 0.92)
		PlayerCosmetics.skid_burst(self)
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
		var target_along := target_mult * MovementTuning.I.run_speed / maxf(absf(t.x), 0.35)
		if dir == 0.0:
			along = move_toward(along, 0.0,
				MovementCore.friction_mu(self, ramp_buffed) * MovementTuning.I.gravity * dt)
		else:
			along = move_toward(along, dir * target_along,
				MovementTuning.I.base_accel * MovementCore.accel_factor(self, ramp_buffed) * dt)
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
		_climb_budget = RunState.modified(def, "climb_units") * MovementTuning.I.climb_units * Geometries.UNIT_PX

	# ———— 疾 · 爬墙:离地贴住世界墙面(非同伴)且朝墙压方向 → 吸附;
	# 只按方向 = 缓降滑壁,按住跳跃键 = 沿墙向上爬(受单次 2.0 格预算限制)。
	# 贴墙时点按跳跃仍会触发空中跳(沿墙上蹭),按住则平稳爬升;
	# 爬到墙顶失去接触后,水平动量自然把身体带过墙沿 ————
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
			PlayerCosmetics.air_burst(self)
	elif _swap_buffer > 0.0 and def.can_swap \
			and (on_ground or _coyote > 0.0) and _swap_cd <= 0.0:
		vel = _perform_swap(vel)
		# 置换锚闪(fx-light 卷一 P0):世界翻了,上下刻度带色序互换一闪
		if Main.I != null:
			Main.I.hud_swap_flash()
	# 松开跳跃键截断上升(只截断一次)
	if not _jump_cut and def.can_jump and not jump_held \
			and vel.y * gravity_dir < -def.jump_v * MovementTuning.I.jump_cut_ratio:
		vel.y *= MovementTuning.I.jump_cut_mult
		_jump_cut = true

	vel.y = clampf(vel.y, -MovementTuning.I.max_fall, MovementTuning.I.max_fall)

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
		elif carrying or impact <= MovementTuning.I.bounce_min or eff_bounce <= 0.0:
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
				restitution *= MovementTuning.I.bounce_settle
				if _swap_air:
					restitution *= MovementTuning.I.swap_settle
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
	if MechanismSurface.touching_ramp(self):
		if _ramp_timer <= 0.0 and Main.I != null:
			Sfx.play("buff")
			Main.I.notify_ramp(def)
		_ramp_timer = MovementTuning.I.ramp_buff_time
	elif _ramp_timer > 0.0:
		_ramp_timer = maxf(_ramp_timer - dt, 0.0)

	# ———— 钢琴地板砖:接触沿登记 / 踩踏发声下沉 MechanismSurface(REFACTOR P4) ————
	MechanismSurface.piano_step(self, vel)

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

	# 表现侧收尾:残影采样 / 滚动轰鸣 / 挤压恢复下沉 PlayerCosmetics(REFACTOR P4)
	PlayerCosmetics.update_trail(self, vel)
	PlayerCosmetics.roll_loop_update(self, vel, now_on_floor, dt)
	PlayerCosmetics.squash_recover(self, dt)


## 置换:翻转重力,射向另一侧平台;水平惯性完整保留。返回更新后的速度。
func _perform_swap(vel: Vector2) -> Vector2:
	gravity_dir *= -1
	up_direction = Vector2(0, -gravity_dir)
	vel.y = MovementTuning.I.swap_launch * gravity_dir
	_swap_buffer = 0.0
	_swap_cd = RunState.modified(def, "swap_cooldown")
	_coyote = 0.0
	_jump_cut = false
	_swap_air = true
	_squash(1.3, 0.74)
	Sfx.play("swap", 0.0, _note_pitch())
	PlayerCosmetics.swap_burst(self)
	return vel


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
		cap = minf(cap * MovementTuning.I.ramp_boost, MOD_SPEED_CAP)
	return cap


## 实际弹性:基础值(0.5;跃为 2.0)+ 词条覆盖。
func effective_bounce() -> float:
	return RunState.modified(def, "bounce")


## 背负超载时跳跃高度减半:头顶来者总重大于自身负重力 → 0.5,否则 1.0。
## 只削弱跳跃,不禁止跳跃(超载的几何体仍能背着同伴跳起一半高度)。
## 倍率是「高度」语义,起跳速度乘 √值(h = v₀²/2g,characters.md §2)。
func _overload_jump_ratio() -> float:
	if Main.I == null:
		return 1.0
	var rider_load := 0.0
	for p in Main.I.players:
		if p != self and is_instance_valid(p) and p.rider_of == self:
			rider_load += RunState.modified(p.def, "weight")
	if rider_load > RunState.modified(def, "carry") + 0.01:
		return sqrt(MovementTuning.I.overload_jump_ratio)
	return 1.0


## 顶弹翻倍(贰·跃,characters.md §3):从可顶弹几何体头顶起跳 → 跳高 ×2。
## 高度 ×2 ⇔ 起跳速度 ×√2;只作用于第一段跳(地面/土狼),空中跳不继承。
## 与超载减半按高度相乘(×2 × ×0.5 = 原地满跳)。
func _top_boost_ratio() -> float:
	if rider_of != null and is_instance_valid(rider_of) and rider_of.def.can_top_boost:
		return sqrt(MovementTuning.I.top_boost_height_ratio)
	return 1.0


## 几何体主题音符变调比(壹=do / 贰=re / 叁=mi / 肆=fa;glossary.md §1):
## 跳跃与落地音效各唱各的音,同一几何体的音效恒在它的音位上。
func _note_pitch() -> float:
	if pair_half == 1:
		return Sfx.note_ratio("A4")   # 边 = la(sol/la 双音位的第二半,glossary §1)
	return Sfx.note_ratio(def.note)


## 台词 / 代号(双体第二半用"边"的版本)。
func quote_text() -> String:
	return def.quote_half if pair_half == 1 and not def.quote_half.is_empty() 		else def.quote


func display_name() -> String:
	return def.name_half if pair_half == 1 and not def.name_half.is_empty() 		else def.name


## 基础重力:界(上半)反向(挂天花板),其余按名册默认。
func _base_gravity() -> int:
	return -1 if pair_half == 0 else def.gravity_dir


## 磁力线锚点 = 两半的顶点(界尖朝下 / 边尖朝上,尖对尖,characters.md §5)。
func boundary_anchor() -> Vector2:
	return position + Vector2(0.0, -def.size.y * 0.5 * gravity_dir)


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


## 主机快照落地(net.md §6):登记目标态,由 _net_follow 逐帧靠拢。
func net_apply_state(pos: Vector2, vel: Vector2, gdir: int, face: float, flags: int) -> void:
	_net_pos = pos
	_net_vel = vel
	gravity_dir = gdir
	up_direction = Vector2(0, -gravity_dir)
	facing = face
	speed_buffed = speed_buffed or (flags & 1) != 0


## 远端驱动跟随:速度外推 + 位置误差指数收敛(20Hz 快照间不跳步),
## 外观件(滚动角 / 残影 / 琴键接触 / 挤压恢复)照常运行,物理判定全免。
func _net_follow(dt: float) -> void:
	position += velocity * dt
	var err := _net_pos - position
	position += err * (1.0 - exp(-14.0 * dt))
	velocity = _net_vel
	input_x = 0.0
	if absf(velocity.x) > 12.0:
		facing = signf(velocity.x)
	if def.shape == GeometryDef.Shape.BALL:
		var target := velocity.x / (def.size.x * 0.5) if is_on_floor() else _roll_speed
		_roll_speed = move_toward(_roll_speed, target, 6.0 * dt)
		_roll_angle += _roll_speed * dt
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
	if _roll_loop != null:
		_roll_loop.volume_db = -60.0
	PlayerCosmetics.death_burst(self)
	if Main.I != null and Main.I.camera_rig != null:
		Main.I.camera_rig.kick(7.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_callback(_reset_for_respawn)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_callback(_finish_respawn)
	Main.I.on_player_died(self)


func _reset_for_respawn() -> void:
	position = spawn_pos
	rider_of = null               # 重生位置远离载体:立即解除骑乘,防刚性随动拉扯
	velocity = Vector2.ZERO
	gravity_dir = _base_gravity()   # 界:反向重力随重生还原(修"卡住"错根)
	up_direction = Vector2(0, -gravity_dir)
	speed_buffed = false
	_swap_air = false
	_air_jumps_left = 0
	_climbing = false
	_climb_budget = MovementTuning.I.climb_units * Geometries.UNIT_PX
	_ramp_timer = 0.0
	_roll_angle = 0.0
	_roll_speed = 0.0
	_squash_x = 1.0
	_squash_y = 1.0
	for t in _piano_touch:
		t.release(body_key())
	_piano_touch.clear()
	_trail.clear()


func _finish_respawn() -> void:
	dying = false
	Main.I.on_respawn_done()


## 召回(v0.17.3):传送到指定点并复位瞬态(速度/重力/缓冲/残影),
## 不触发死亡演出;用于右上"召回"(回到记录点/出生点)。
func recall_to(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	gravity_dir = _base_gravity()
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
	PlayerCosmetics.draw(self, size)
