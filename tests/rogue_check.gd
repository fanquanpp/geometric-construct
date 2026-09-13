extends SceneTree
## --roguecheck headless 走查机器人(v0.38.0 肉鸽片段库门禁):
## 逐枚装载 levels/rogue/*.json → LevelBuilder 真建关卡 → 真玩家实体
## 按**主角策略**实跑 move_and_slide,走到专属归门(arrived)= PASS:
##   疾(0):地面遇缺口 / 遇墙起跳;空中贴墙按住跳(爬墙,150px/s)。
##   跃(1):同疾的地面判定(弹性反弹交给物理,不特殊处理)。
##   逆(2):推右仍被拦(velocity.x≈0)→ 按跳(=置换翻转)走另一面。
##   圆(3):只推右——坡道 / 加速门 / 弹射板自会接管;卡死即设计失败。
## 判 FAIL:无进展(卡墙 / 坠坑死亡)超 2.5s,或 50s 未到门。
## 计时以物理量与帧守卫(headless 不锁帧陷阱见 trait_check.gd)。
## 运行:godot --headless --script res://tests/rogue_check.gd
##       (可加 -- --focus=N 只查一位主角的片段链)

const CHARACTER_MANAGER_SCENE := preload("res://scenes/core/character_manager.tscn")

const TIMEOUT_FRAMES := 3000   # 50s @60fps
const STUCK_FRAMES := 150      # 2.5s 无进展

## 承载循环读 Main.I.players(裸 SceneTree 无 Main,给空池桩,同 trait_check);
## touch_controls 必须存在(null 属性访问在 LevelBuilder 里会报错)。
class Stub:
	var players: Array = []
	var debug_move := Vector2.ZERO
	var debug_jump := false
	var debug_zoom := 0.0
	var debug_grid := false
	var camera_rig = null
	var touch_controls = null
	func slot_actions() -> bool:
		return false
	func hud_swap_flash() -> void:
		pass
	func set_checkpoint(_k: int, _p: Vector2) -> void:
		pass
	func on_player_arrived(_p: Player) -> void:
		pass
	func on_player_departed(_p: Player) -> void:
		pass
	func on_player_exited(_p: Player) -> void:
		pass
	func on_player_died(_p: Player) -> void:
		pass

var _queue: Array = []
var _cur: Dictionary = {}
var _focus := 0
var _label := ""
var _player: Player
var _level: Node2D
var _fails := 0
var _passed := 0
var _frames := 0
var _stuck := 0
var _last := Vector2.ZERO
var _since_swap := 0
var _jump_hold := false
var _trace := false


func _initialize() -> void:
	Engine.max_fps = 60
	Ui.init_font()   # 字体缓存未初始化会让 Ui.l 的 font.get_instance_id() 报空
	Main.I = Stub.new()
	for raw in OS.get_cmdline_user_args():
		if raw == "--trace":
			_trace = true
	# R3 装配顺序同 Main:角色管理器最先入树,LevelBuilder 经它建体入池
	# (world_mask / 双子接线都在 build 侧完成,机器人不手工 spawn)
	var cm: CharacterManager = CHARACTER_MANAGER_SCENE.instantiate()
	root.add_child(cm)
	if CharacterManager.I == null:
		CharacterManager.I = cm   # --script 模式 _ready 可能晚于本次构建
	_queue = RogueFragments.all_defs()
	for raw in OS.get_cmdline_user_args():
		if raw.begins_with("--focus="):
			var f := int(raw.substr(8))
			_queue = _queue.filter(func(it: Dictionary) -> bool:
				return it["def"].focus == f)
	if _queue.is_empty():
		print("ROGUECHECK FAILED: 片段队列为空(片段库未装载)")
		quit(1)
		return
	_next()


func _next() -> void:
	if _player != null:
		_player.is_active = false
		_player = null
	if _level != null:
		# 立即释放(非 queue_free):LevelRoot._init 每次构建都会重连
		# character_created,垂死节点的旧连接会在同帧抢挂新玩家
		_level.free()
		_level = null
	if _queue.is_empty():
		if _fails == 0:
			print("ROGUECHECK ALL PASS (%d fragments)" % _passed)
			quit(0)
		else:
			print("ROGUECHECK %d FAIL / %d PASS" % [_fails, _passed])
			quit(1)
		return
	_cur = _queue.pop_front()
	var def: LevelDef = _cur["def"]
	_focus = def.focus
	_label = _cur["label"]
	_level = LevelBuilder.build(def)
	root.add_child(_level)
	for c in _level.get_children():
		if c is Player and (c as Player).index == def.focus:
			_player = c
			break
	if _player == null:
		_fail("建体失败:关卡内无主角实体")
		return
	_player.is_active = true
	Input.action_press("move_right")
	if _focus == 0:
		Input.action_press("sprint")   # 疾:恒冲刺(快路缺口按冲刺射程铺设)
	_frames = 0
	_stuck = 0
	_since_swap = 0
	_last = _player.position
	print("ROGUECHECK run %s (spawn %s / def %s)" % [_label, _player.position,
		def.spawns])


func _process(_delta: float) -> bool:
	if _player == null:
		return false
	_frames += 1
	_since_swap += 1
	if _trace and _frames % 15 == 0:
		print("TRACE %s f=%d pos=%s vel=%s floor=%s hold=%s" % [_label, _frames,
			_player.position, _player.velocity, _player.is_on_floor(), _jump_hold])
	# —— 到站 = PASS,换下一枚 ——
	if _player.arrived:
		print("ROGUECHECK PASS %s (%.1fs)" % [_label, _frames / 60.0])
		_passed += 1
		_release_jump()
		_next()
		return false
	# —— 坠坑(Stub 无死亡判定,按关卡 kill_y 直判)/ 卡死 / 超时 = FAIL ——
	if _player.position.y > float(_cur["def"].kill_y) \
			or _player.position.y < float(_cur["def"].top_kill_y):
		_fail("坠坑 pos=%s" % _player.position)
		return false
	var moved := (_player.position - _last).length()
	var idle := moved < 2.0 and absf(_player.velocity.y) < 20.0
	_stuck = _stuck + 1 if idle else 0
	_last = _player.position
	if _stuck >= STUCK_FRAMES:
		_fail("卡死 pos=%s" % _player.position)
		return false
	if _frames >= TIMEOUT_FRAMES:
		_fail("超时 pos=%s" % _player.position)
		return false
	# —— 主角策略 ——
	match _focus:
		0:
			_policy_dash()
		1:
			_policy_jumper()
		2:
			_policy_swap()
		3:
			pass   # 圆:只推右,机关自会接管
	return false


## 疾:地面缺口/墙起跳;空中按住不松(松键会触发 jump_cut 截断射程),
## 贴墙按住即爬墙。
func _policy_dash() -> void:
	if _player.is_on_floor():
		if _gap_ahead(70.0) or _wall_ahead(46.0):
			_press_jump()
		elif _jump_hold:
			_release_jump()


## 跃:地面缺口/墙起跳;空中贴墙停滞(顶不上去)时松→再按,消费二段跳。
## (不做「回弹按住」策略:跃处处满反弹,按持会在窄塔段过弹坠亡;
##  弹毯折返关的可通过性由 reach_check 数学门禁与关卡几何保证。)
func _policy_jumper() -> void:
	if _player.is_on_floor():
		if _gap_ahead(70.0) or _wall_ahead(46.0):
			_press_jump()
		elif _jump_hold:
			_release_jump()
	elif _wall_ahead(40.0) and _player.velocity.y > -120.0:
		if _jump_hold:
			_release_jump()
	else:
		_press_jump()


## 逆:被拦(推右而横向速度归零)且过了置换冷却 → 按跳 = 翻转。
func _policy_swap() -> void:
	var vx := absf(_player.velocity.x)
	var blocked := _wall_ahead(40.0) or vx < 15.0
	if blocked and _since_swap > 30:
		_press_jump()
		_since_swap = 0
	elif _jump_hold and _frames % 8 == 0:
		_release_jump()


func _press_jump() -> void:
	if not _jump_hold:
		Input.action_press("jump")
		_jump_hold = true


func _release_jump() -> void:
	if _jump_hold:
		Input.action_release("jump")
		_jump_hold = false


## 前方 dx 处下方是否有可站立面(射线向下探 160px)。
func _gap_ahead(dx: float) -> bool:
	return not _cast(_player.global_position + Vector2(dx, 0.0),
		Vector2(0, 160.0))


func _wall_ahead(dx: float) -> bool:
	return _cast(_player.global_position, Vector2(dx + 26.0, 0.0))


func _cast(from: Vector2, motion: Vector2) -> bool:
	var space := _player.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, from + motion)
	q.collision_mask = 0xFFFFFFFF
	q.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(q)
	return not hit.is_empty()


func _fail(reason: String) -> void:
	print("ROGUECHECK FAIL %s —— %s" % [_label, reason])
	_fails += 1
	_release_jump()
	_next()
