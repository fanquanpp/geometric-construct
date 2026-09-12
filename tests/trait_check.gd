extends SceneTree
## 开发验证:贰·跃「顶弹翻倍」/ 肆·圆「可推动」特性链路(v0.31.1 补实)。
## 纯物理仿真(headless):地板 + 玩家实体真跑 move_and_slide——
##   ①基线跳:疾平地起跳,跳高 ≈ 2.0 格(v₀²/2g);
##   ②顶弹跳:疾站跃头顶(承载判定 rider_of)起跳,跳高 ≈ 4.0 格(×2);
##   ③推挤:疾水平走入圆,圆获得滚动速度(可推动,传速 > 30 px/s)。
## 跳跃保持以「升速衰减到近顶点」松键(帧率波动下按物理量计时,早松会
## 触发 jump_cut 截断,量不到真跳高)。任一断言失败退出码 1。
## 运行:--headless --script res://tests/trait_check.gd

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")

## 承载随动循环读 Main.I.players(裸 SceneTree 无 Main,给空池桩);
## debug_move / debug_jump = Main 输入边沿检测字段(player_input 直读)。
class Stub:
	var players: Array = []
	var debug_move := Vector2.ZERO
	var debug_jump := false
	## InputSource 分区网关(net.md §2):false = 槽 0 恒读全局动作(单机)。
	func slot_actions() -> bool:
		return false

var _frame := 0
var _fails := 0
var _phase := 0        # 0 落定 → 1 基线跳 → 2 跃顶落定 → 3 顶弹跳 → 4 推挤 → 5 终态
var _settle := 0
var _airborne := false # 本轮跳已确认离地升空(防起跳帧误判"近顶点")
var _floor: StaticBody2D
var _spring: Player
var _dash: Player
var _roll: Player
var _jump_y := 0.0
var _min_y := 0.0


func _spawn(def_index: int, pos: Vector2) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.def = Geometries.get_def(def_index)
	p.index = def_index
	p.position = pos
	p.spawn_pos = pos
	root.add_child(p)
	return p


func _initialize() -> void:
	Engine.max_fps = 60   # headless process 不锁帧:不锁则 process≈150Hz,帧计时失真
	Main.I = Stub.new()
	_floor = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 100)
	shape.shape = rect
	shape.position = Vector2(0, 50)
	_floor.add_child(shape)
	_floor.position = Vector2(1000, 950)
	root.add_child(_floor)
	_spring = _spawn(1, Vector2(500, 910))
	_roll = _spawn(3, Vector2(900, 924))
	_dash = _spawn(0, Vector2(300, 924))
	_dash.is_active = true   # 输入只在受控体上读取(roster 语义;测试里手动点亮)
	# 数据旗标断言(.tres 装载正确性)
	if not _spring.def.can_top_boost:
		print("TRAIT CHECK FAIL: spring.can_top_boost 未置位")
		_fails += 1
	if not _roll.def.can_be_pushed:
		print("TRAIT CHECK FAIL: roll.can_be_pushed 未置位")
		_fails += 1


func _jump_and_measure() -> void:
	_jump_y = _dash.position.y
	_min_y = _jump_y
	_airborne = false
	Main.I.debug_jump = true   # 调试输入通道:边沿在 player 内合成,帧精确


## 升速衰减回近顶点(>|v₀| 以下)后松键并结算跳高。
func _eval_jump_if_apex(expect_px: float, tol_px: float, label: String,
		on_done: Callable) -> void:
	if not Main.I.debug_jump:
		return
	var vy := _dash.velocity.y
	if vy < -200.0:
		_airborne = true
	if _airborne and vy > -150.0:
		Main.I.debug_jump = false
		var rise := _jump_y - _min_y
		var ok := absf(rise - expect_px) <= tol_px
		print("TRAIT %s rise=%.0fpx(期望 %.0f±%.0f)%s" % [label, rise,
			expect_px, tol_px, "" if ok else " —— FAIL"])
		if not ok:
			_fails += 1
		on_done.call()


func _process(_delta: float) -> bool:
	_frame += 1
	_min_y = minf(_min_y, _dash.position.y)   # 追踪飞行最高点(最小 y)
	match _phase:
		0:
			if _frame >= 30 and _dash.is_on_floor():
				print("TRAIT baseline-jump start y=%.0f" % _dash.position.y)
				_jump_and_measure()
				_phase = 1
		1:
			_eval_jump_if_apex(200.0, 30.0, "BASELINE-JUMP", func() -> void:
				# ②把疾搬到跃头顶,走承载判定
				_dash.position = Vector2(500, 844)
				_dash.velocity = Vector2.ZERO
				_min_y = _dash.position.y
				_settle = 0
				_phase = 2)
		2:
			_settle += 1
			if _settle >= 30:
				if _dash.rider_of != _spring:
					print("TRAIT CHECK FAIL: 疾未判定为跃的骑乘者(rider_of=%s)"
						% [_dash.rider_of])
					_fails += 1
				else:
					print("TRAIT RIDER-OF PASS(承载判定成立)")
				_jump_and_measure()
				_phase = 3
		3:
			_eval_jump_if_apex(400.0, 50.0, "TOP-BOOST-JUMP", func() -> void:
				# ③推挤:疾落到圆左侧,按住右方向走入圆
				_dash.position = Vector2(700, 924)
				_dash.velocity = Vector2.ZERO
				Input.action_press("move_right")
				_settle = 0
				_phase = 4)
		4:
			_settle += 1
			if _roll.velocity.x > 30.0:
				print("TRAIT PUSH PASS: 圆获得滚动速度 vel.x=%.0f" % _roll.velocity.x)
				_phase = 5
			elif _settle >= 240:
				print("TRAIT CHECK FAIL: 圆未被推动 vel.x=%.0f" % _roll.velocity.x)
				_fails += 1
				_phase = 5
		5:
			if _fails == 0:
				print("TRAIT CHECK ALL PASS")
				quit(0)
			else:
				print("TRAIT CHECK %d FAIL" % _fails)
				quit(1)
			return true
	return false
